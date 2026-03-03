import SwiftUI
import Supabase

struct SettingsView: View {
    @State private var isSigningOut = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    Button(action: signOut) {
                        HStack {
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func signOut() {
        isSigningOut = true
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
            isSigningOut = false
        }
    }
}

#Preview {
    SettingsView()
}
