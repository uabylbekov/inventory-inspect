import SwiftUI
import UserNotifications
import Supabase
import Realtime

@Observable @MainActor
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    
    var notifications: [NotificationModel] = []
    var unreadCount: Int = 0
    private var channel: RealtimeChannelV2?
    private var currentToken: String?
    private var observedUserId: UUID?
    private var realtimeTask: Task<Void, Never>?
    private var hasRequestedNotificationPermission = false
    
    // Deep linking state
    var selectedNotificationID: UUID?
    var joiningInspection: InspectionModel?
    var joinError: String?
    
    private let supabase = SupabaseClient(
        supabaseURL: EnvConfig.supabaseURL,
        supabaseKey: EnvConfig.supabaseKey
    )
    private let notificationQueryLimit = 50
    
    private init() {}
    
    func requestPermission() {
        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func bootstrapForAuthenticatedUser() async {
        guard let userId = await currentUserID() else {
            return
        }

        requestPermission()

        guard observedUserId != userId || channel == nil else { return }

        await teardownRealtime()
        observedUserId = userId
        await fetchNotifications()
        await setupRealtime()
    }

    func resetForSignedOutUser() async {
        await teardownRealtime()
        observedUserId = nil
        applyNotifications([])
    }
    
    func handleJoinRequest(id: UUID) async {
        joinError = nil
        do {
            let inspection: [InspectionModel] = try await supabase
                .from("inspections")
                .select()
                .eq("id", value: id.uuidString.lowercased())
                .execute()
                .value
            
            if let first = inspection.first {
                self.joiningInspection = first
            }
        } catch {
            self.joinError = "Unable to join inspection. The inspection may have been completed or deleted."
        }
    }
    
    func registerDeviceToken(_ token: String) async {
        self.currentToken = token
        guard let userId = await currentUserID() else {
            return
        }

        let pushToken = [
            "user_id": userId.uuidString.lowercased(),
            "device_token": token,
            "platform": "ios"
        ]

        do {
            try await supabase.from("user_push_tokens")
                .upsert(pushToken, onConflict: "user_id,device_token")
                .execute()
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
                .limit(notificationQueryLimit)
                .execute()
                .value
            
            applyNotifications(fetched)
        } catch {
            print("Error fetching notifications: \(error)")
        }
    }
    
    func markAsRead(_ notification: NotificationModel) async {
        // Find local index
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        
        // Optimistic UI update
        notifications[index].is_read = true
        syncUnreadCount()
        
        do {
            try await supabase
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notification.id)
                .execute()
            
            updateBadgeCount()
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
        syncUnreadCount()
        
        Task {
            do {
                // Batch delete from Supabase in ONE network trip
                try await supabase
                    .from("notifications")
                    .delete()
                    .in("id", values: idsToDelete)
                    .execute()
                
                updateBadgeCount()
            } catch {
                print("Error batch deleting notifications: \(error)")
                // Background re-fetch in case of failure to keep UI synced
                await fetchNotifications()
            }
        }
    }
    
    func clearAllNotifications() async {
        let idsToDelete = notifications.map { $0.id.uuidString.lowercased() }
        guard !idsToDelete.isEmpty else { return }

        let previous = notifications
        applyNotifications([])

        do {
            try await supabase
                .from("notifications")
                .delete()
                .in("id", values: idsToDelete)
                .execute()
        } catch {
            notifications = previous
            syncUnreadCount()
            print("Error clearing notifications: \(error)")
        }
    }
    
    func setupRealtime() async {
        guard channel == nil else { return }

        let channel = supabase.channel("public:notifications")
        
        let observation = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications"
        )
        
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            for await change in observation {
                switch change {
                case .insert(let action):
                    if let newNotification = try? action.decodeRecord(as: NotificationModel.self, decoder: JSONDecoder()) {
                        self.notifications.insert(newNotification, at: 0)
                        self.syncUnreadCount()
                        self.triggerLocalNotification(for: newNotification)
                    }
                default:
                    await fetchNotifications()
                }
            }
        }
        
        try? await channel.subscribeWithError()
        self.channel = channel
    }

    private func teardownRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel {
            await channel.unsubscribe()
            self.channel = nil
        }
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

    private func currentUserID() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            print("Error resolving current user for notifications: \(error)")
            return nil
        }
    }

    private func applyNotifications(_ fetched: [NotificationModel]) {
        notifications = fetched
        syncUnreadCount()
    }

    private func syncUnreadCount() {
        unreadCount = notifications.filter { !$0.is_read }.count
        updateBadgeCount()
    }

    private func updateBadgeCount() {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
            if let error {
                print("Error setting badge count: \(error)")
            }
        }
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
