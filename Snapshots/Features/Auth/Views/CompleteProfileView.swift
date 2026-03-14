import SwiftUI
import Supabase

struct CompleteProfileView: View {
    @State private var name: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("profile.full_name", text: $name)
                        .platformNameTextInput()
                        .accessibilityIdentifier("complete_profile.name")
                } header: {
                    Text("profile.complete.welcome")
                } footer: {
                    Text("profile.complete.subtitle")
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .accessibilityIdentifier("complete_profile.error")
                    }
                }
                
                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("profile.complete.save")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("complete_profile.save")
                .listRowBackground(Color.accentColor)
                .foregroundColor(.white)
            }
            .navigationTitle("profile.complete.title")
            .interactiveDismissDisabled()
        }
    }
    
    private func saveProfile() {
        HapticManager.shared.impact(style: .medium)
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let data: [String: AnyJSON] = ["full_name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines))]
                try await supabase.auth.update(user: UserAttributes(data: data))
                
                // Refresh session state to immediately let RootView know
                if let _ = try? await supabase.auth.session {
                    await MainActor.run {
                        HapticManager.shared.notification(type: .success)
                        authManager.isProfileComplete = true
                    }
                }
                
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    CompleteProfileView()
        .environment(AuthManager())
}
