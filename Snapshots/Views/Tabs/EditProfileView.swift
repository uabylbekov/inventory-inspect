import SwiftUI
import Supabase

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var name: String = ""
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isDeletingAccount = false
    @State private var showingDeleteAlert = false
    @State private var errorMessage: String? = nil
    @State private var businessName: String = ""
    @State private var businessAddress: String = ""
    @State private var businessPhone: String = ""
    @State private var businessWebsite: String = ""
    private let accessManager = SnapshotsAccessManager.shared
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .disabled(!isEditing)
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(!isEditing)
            } header: {
                Text("Account Details")
            } footer: {
                if isEditing {
                    Text("Updating your email will require a verification email and sign you out.")
                }
            }
            
            // MARK: - Business Branding (Enterprise)
            Section {
                if accessManager.isEnterprise {
                    TextField("Business Name", text: $businessName)
                        .disabled(!isEditing)
                    TextField("Address", text: $businessAddress)
                        .disabled(!isEditing)
                    TextField("Phone", text: $businessPhone)
                        .keyboardType(.phonePad)
                        .disabled(!isEditing)
                    TextField("Website", text: $businessWebsite)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disabled(!isEditing)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundColor(.accentColor)
                            Text("Business Branding")
                                .font(.headline)
                        }
                        
                        Text("Add your company logo, address, and contact info to your PDF reports.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink(destination: PremiumPaywallView()) {
                            Text("Unlock Enterprise Branding")
                                .font(.subheadline.bold())
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Business Details")
            } footer: {
                if accessManager.isEnterprise {
                    Text("These details will appear on all your generated PDF reports.")
                }
            }
            
            if isEditing {
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Text("Delete Account")
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSaving || isDeletingAccount)
                }
            }
            
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditing = false
                        loadUser() // Revert changes
                    }
                    .disabled(isSaving || isDeletingAccount)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || isDeletingAccount)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
        }
        .task {
            loadUser()
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteAccount)
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    private func loadUser() {
        Task {
            if let user = try? await supabase.auth.session.user {
                await MainActor.run {
                    self.email = user.email ?? ""
                    
                    if case .string(let fetchedName) = user.userMetadata["full_name"] {
                        self.name = fetchedName
                    }
                    
                    // Load business details from public.profiles table (subscription-tier dependent)
                    if let profile = accessManager.profile {
                        if let detailsString = profile.business_details, !detailsString.isEmpty,
                           let data = detailsString.data(using: .utf8),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            self.businessName = dict["business_name"] as? String ?? ""
                            self.businessAddress = dict["business_address"] as? String ?? ""
                            self.businessPhone = dict["business_phone"] as? String ?? ""
                            self.businessWebsite = dict["business_website"] as? String ?? ""
                        } else {
                            // Fallback if stored differently or empty
                            self.businessName = ""
                            self.businessAddress = ""
                            self.businessPhone = ""
                            self.businessWebsite = ""
                        }
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        HapticManager.shared.impact(style: .medium)
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let data: [String: AnyJSON] = ["full_name": .string(name)]
                try await supabase.auth.update(user: UserAttributes(email: email.isEmpty ? nil : email, data: data))
                
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isSaving = false
                    isEditing = false
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
    
    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await supabase.rpc("delete_current_user").execute()
                try await supabase.auth.signOut()
                // dismiss after signing out is generally handled by the root view observing session, but we can pop just in case
                await MainActor.run {
                    isDeletingAccount = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error deleting account: \(error.localizedDescription)"
                    isDeletingAccount = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
    }
}
