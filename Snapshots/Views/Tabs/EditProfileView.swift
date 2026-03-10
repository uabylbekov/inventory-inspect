import SwiftUI
import Supabase
import PhotosUI

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
    @State private var selectedLogoItem: PhotosPickerItem? = nil
    @State private var selectedLogoImage: UIImage? = nil
    @State private var isUploadingLogo = false
    @Environment(SnapshotsAccessManager.self) private var accessManager
    
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
            
            // MARK: - Company Logo (Pro + Enterprise)
            if accessManager.isPro {
                Section {
                    HStack(spacing: 14) {
                        // Logo preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                )
                            if let image = selectedLogoImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else if let logoUrlStr = accessManager.profile?.company_logo_url,
                                      let logoUrl = URL(string: logoUrlStr) {
                                AsyncImage(url: logoUrl) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .id(logoUrlStr)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Company Logo")
                                .font(.subheadline)
                            Text(isEditing ? "Tap to change" : (accessManager.profile?.company_logo_url != nil ? "Logo configured" : "No logo set"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isEditing {
                            PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                                Text("Choose")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .onChange(of: selectedLogoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedLogoImage = image
                            }
                        }
                    }
                } header: {
                    Text("Company Logo")
                } footer: {
                    Text("Appears in the header of your PDF inspection reports.")
                }
            }

            // MARK: - Business Details (Enterprise only)
            if accessManager.isEnterprise {
                Section {
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
                } header: {
                    Text("Business Details")
                } footer: {
                    Text("Business details and logo appear on all generated PDF reports. The Snapshots branding is removed.")
                }
            }

            // MARK: - Branding Upsell (Free users)
            if !accessManager.isPro {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundColor(.accentColor)
                            Text("Business Branding")
                                .font(.headline)
                        }

                        Text("Add your company logo to PDF reports. Enterprise users get full white-label reports with business details.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        NavigationLink(destination: PremiumPaywallView()) {
                            Text("Unlock Professional Branding")
                                .font(.subheadline.bold())
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Business Branding")
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
                    .disabled(isSaving || isDeletingAccount || isUploadingLogo)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") {
                        selectedLogoImage = nil
                        selectedLogoItem = nil
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
        // Clear any locally-held image so the view loads fresh from the profile URL
        selectedLogoImage = nil
        selectedLogoItem = nil
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
                // 1. Update auth user (name + email)
                let userData: [String: AnyJSON] = ["full_name": .string(name)]
                try await supabase.auth.update(user: UserAttributes(email: email.isEmpty ? nil : email, data: userData))

                let userId = try await supabase.auth.session.user.id.uuidString.lowercased()

                // 2. Upload logo if a new one was selected
                var logoUrl: String? = accessManager.profile?.company_logo_url
                if let logoImage = selectedLogoImage,
                   let jpegData = preparedLogoData(from: logoImage) {
                    isUploadingLogo = true

                    let fileName = "\(userId)/logo.jpg"
                    _ = try await supabase.storage
                        .from("company-logos")
                        .upload(fileName, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    let publicURL = try supabase.storage
                        .from("company-logos")
                        .getPublicURL(path: fileName)
                    // Timestamp query param busts CDN and iOS URLSession cache on each re-upload
                    let version = Int(Date().timeIntervalSince1970)
                    logoUrl = "\(publicURL.absoluteString)?v=\(version)"
                    isUploadingLogo = false
                }

                // 3. Update profiles table (logo + business details)
                var profileUpdate: [String: AnyJSON] = [:]
                if let url = logoUrl {
                    profileUpdate["company_logo_url"] = .string(url)
                }
                if accessManager.isEnterprise {
                    let details: [String: Any] = [
                        "business_name": businessName,
                        "business_address": businessAddress,
                        "business_phone": businessPhone,
                        "business_website": businessWebsite
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: details),
                       let jsonStr = String(data: jsonData, encoding: .utf8) {
                        profileUpdate["business_details"] = .string(jsonStr)
                    }
                }
                if !profileUpdate.isEmpty {
                    try await supabase
                        .from("profiles")
                        .update(profileUpdate)
                        .eq("id", value: userId)
                        .execute()
                }

                // 4. Refresh local profile cache
                await accessManager.refreshProfile()

                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isSaving = false
                    isEditing = false
                    // Keep selectedLogoImage so the logo is visible immediately in view mode.
                    // It resets when the user taps Edit again or the view re-appears.
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                    isSaving = false
                    isUploadingLogo = false
                }
            }
        }
    }
    
    /// Resize to max 512 pt and compress to stay under 1 MB.
    private func preparedLogoData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

        // Try progressively lower quality until under 1 MB
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let data = resized.jpegData(compressionQuality: quality), data.count < 1_000_000 {
                return data
            }
        }
        return resized.jpegData(compressionQuality: 0.3)
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
