import SwiftUI
import UserNotifications

import Auth
import Supabase

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Task {
            await NotificationManager.shared.registerDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound, .badge]])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task {
            await NotificationManager.shared.handleNotificationTap(userInfo: userInfo)
        }
        completionHandler()
    }
}
#else
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Task {
            await NotificationManager.shared.registerDeviceToken(token)
        }
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        await NotificationManager.shared.handleNotificationTap(userInfo: userInfo)
    }
}
#endif

@main
struct InspectionsApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                if let uiTestScenarioView = UITestScenarioView() {
                    uiTestScenarioView
                } else {
                    RootView()
                        .environment(SnapshotsAccessManager.shared)
                        .onOpenURL { url in
                            Task {
                                do {
                                    try await supabase.auth.session(from: url)
                                } catch {
                                    print("Failed to handle deep link: \(error.localizedDescription)")
                                }
                            }
                        }
                }
            }
            .environment(SnapshotsAccessManager.shared)
        }
    }
}
