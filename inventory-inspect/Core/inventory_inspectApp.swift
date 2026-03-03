//
//  inventory_inspectApp.swift
//  inventory-inspect
//
//  Created by Uluk Abylbekov on 3/2/26.
//

import SwiftUI
import SwiftData
import Auth
import Supabase

@main
struct inventory_inspectApp: App {
    
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
