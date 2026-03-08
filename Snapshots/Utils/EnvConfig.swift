//
//  Environment.swift
//  Inspections
//
//  Created by Uluk Abylbekov on 3/2/26.
//
import Foundation
enum EnvConfig {
    static var supabaseURL: URL {
        // Find the SupabaseURL key in Info.plist
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String else {
            fatalError("SupabaseURL not found in Info.plist")
        }
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL string: \(urlString)")
        }
        return url
    }
    
    static var supabaseKey: String {
        // Find the SupabaseKey key in Info.plist
        guard let key = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String else {
            fatalError("SupabaseKey not found in Info.plist")
        }
        return key
    }
}
