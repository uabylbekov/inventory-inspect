import SwiftUI
import UserNotifications
import Supabase
import Realtime

@Observable
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    
    var notifications: [NotificationModel] = []
    var unreadCount: Int = 0
    private var channel: RealtimeChannelV2?
    private var currentToken: String?
    
    // Deep linking state
    var selectedNotificationID: UUID?
    
    private let supabase = SupabaseClient(
        supabaseURL: EnvConfig.supabaseURL,
        supabaseKey: EnvConfig.supabaseKey
    )
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func registerDeviceToken(_ token: String) async {
        self.currentToken = token
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let pushToken = [
                "user_id": userId.uuidString.lowercased(),
                "device_token": token,
                "platform": "ios"
            ]
            
            try await supabase.from("user_push_tokens")
                .upsert(pushToken, onConflict: "user_id,device_token")
                .execute()
                
            print("Successfully registered push token")
        } catch {
            print("Error registering push token: \(error)")
        }
    }
    
    func unregisterDeviceToken() async {
        guard let token = currentToken else { return }
        do {
            try await supabase.from("user_push_tokens")
                .delete()
                .eq("device_token", value: token)
                .execute()
            self.currentToken = nil
            print("Successfully unregistered push token")
        } catch {
            print("Error unregistering push token: \(error)")
        }
    }
    
    func fetchNotifications() async {
        do {
            let fetched: [NotificationModel] = try await supabase
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            await MainActor.run {
                self.notifications = fetched
                self.unreadCount = fetched.filter { !$0.is_read }.count
                
                // Clear the app icon badge number if we're up to date
                UNUserNotificationCenter.current().setBadgeCount(self.unreadCount) { error in
                    if let error = error {
                        print("Error setting badge count: \(error)")
                    }
                }
            }
        } catch {
            print("Error fetching notifications: \(error)")
        }
    }
    
    func markAsRead(_ notification: NotificationModel) async {
        // Find local index
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        
        // Optimistic UI update
        notifications[index].is_read = true
        self.unreadCount = notifications.filter { !$0.is_read }.count
        
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            // Sync badge count
            UNUserNotificationCenter.current().setBadgeCount(self.unreadCount) { _ in }
        } catch {
            print("Error marking notification as read: \(error)")
            // Re-fetch on actual failure
            await fetchNotifications()
        }
    }
    
    func deleteNotifications(at offsets: IndexSet) {
        // OPTIMISTIC UI: Remove items immediately for instant swipe response
        let toDelete = offsets.map { notifications[$0] }
        let idsToDelete = toDelete.map { $0.id.uuidString.lowercased() }
        
        // Remove locally first (MainActor ensures thread-safety for @Observable)
        notifications.remove(atOffsets: offsets)
        self.unreadCount = notifications.filter { !$0.is_read }.count
        
        Task {
            do {
                // Batch delete from Supabase in ONE network trip
                try await supabase
                    .from("notifications")
                    .delete()
                    .in("id", values: idsToDelete)
                    .execute()
                
                // Sync the badge count locally
                await MainActor.run {
                    UNUserNotificationCenter.current().setBadgeCount(self.unreadCount) { _ in }
                }
            } catch {
                print("Error batch deleting notifications: \(error)")
                // Background re-fetch in case of failure to keep UI synced
                await fetchNotifications()
            }
        }
    }
    
    func markAllAsRead() async {
        do {
            try await supabase.rpc("mark_all_notifications_read").execute()
            await fetchNotifications()
        } catch {
            print("Error marking all as read: \(error)")
        }
    }
    
    func setupRealtime() async {
        let channel = supabase.channel("public:notifications")
        
        let observation = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications"
        )
        
        Task {
            for await change in observation {
                switch change {
                case .insert(let action):
                    if let newNotification = try? action.decodeRecord(as: NotificationModel.self, decoder: JSONDecoder()) {
                        await MainActor.run {
                            self.notifications.insert(newNotification, at: 0)
                            self.unreadCount += 1
                            self.triggerLocalNotification(for: newNotification)
                        }
                    }
                default:
                    await fetchNotifications()
                }
            }
        }
        
        try? await channel.subscribeWithError()
        self.channel = channel
    }
    
    private func triggerLocalNotification(for notification: NotificationModel) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        
        // Add data for deep linking
        content.userInfo = ["id": notification.id.uuidString]
        
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
        HapticManager.shared.notification(type: .success)
    }
}

struct NotificationModel: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let body: String
    let type: String
    let data: [String: AnyJSON]
    var is_read: Bool
    let created_at: String
}
