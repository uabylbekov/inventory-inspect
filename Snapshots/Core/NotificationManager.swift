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
            }
        } catch {
            print("Error fetching notifications: \(error)")
        }
    }
    
    func markAsRead(_ notification: NotificationModel) async {
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            await fetchNotifications()
        } catch {
            print("Error marking notification as read: \(error)")
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
    let is_read: Bool
    let created_at: String
}
