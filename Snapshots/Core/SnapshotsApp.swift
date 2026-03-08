//
//  InspectionsApp.swift
//  Inspections
//
//  Created by Uluk Abylbekov on 3/2/26.
//

import SwiftUI
import SwiftData
import Auth
import Supabase

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        Task {
            await NotificationManager.shared.registerDeviceToken(token)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Handle tapping on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["id"] as? String, let id = UUID(uuidString: idString) {
            NotificationManager.shared.selectedNotificationID = id
        }
        completionHandler()
    }
}

@main
struct InspectionsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
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
}
