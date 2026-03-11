import SwiftUI
import Supabase
import PhotosUI

struct EditProfileView: View {
    private enum Field: Hashable {
        case name
        case email
        case businessName
        case businessAddress
        case businessPhone
        case businessWebsite
    }

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
    @FocusState private var focusedField: Field?
    @Environment(SnapshotsAccessManager.self) private var accessManager
    
    var body: some View {
        Form {
            Section {
                TextField("profile.name", text: $name)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .disabled(!isEditing)
                
                TextField("auth.common.email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.done)
                    .disabled(!isEditing)
            } header: {
                Text("profile.account_details")
            } footer: {
                if isEditing {
                    Text("profile.email_update_notice")
                }
            }
            
            // MARK: - Company Logo (Pro + Enterprise)
            if accessManager.isPro {
                Section {
                    LogoPreview(
                        selectedLogoImage: selectedLogoImage,
                        logoURLString: accessManager.profile?.company_logo_url,
                        isUploading: isUploadingLogo
                    )

                    LabeledContent("profile.company_logo") {
                        Text(isEditing ? String(localized: "profile.logo.tap_to_change") : (accessManager.profile?.company_logo_url != nil ? String(localized: "profile.logo.configured") : String(localized: "profile.logo.empty")))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if isEditing {
                        PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                            Text("common.choose")
                        }
                        .onChange(of: selectedLogoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedLogoImage = image
                                }
                            }
                        }
                    }
                } header: {
                    Text("profile.company_logo")
                } footer: {
                    Text("profile.logo_footer")
                }
            }

            // MARK: - Business Details (Enterprise only)
            if accessManager.isEnterprise {
                Section {
                    TextField("profile.business_name", text: $businessName)
                        .focused($focusedField, equals: .businessName)
                        .disabled(!isEditing)
                    TextField("profile.address", text: $businessAddress)
                        .focused($focusedField, equals: .businessAddress)
                        .disabled(!isEditing)
                    TextField("profile.phone", text: $businessPhone)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .businessPhone)
                        .disabled(!isEditing)
                    TextField("profile.website", text: $businessWebsite)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .businessWebsite)
                        .disabled(!isEditing)
                } header: {
                    Text("profile.business_details")
                } footer: {
                    Text("profile.business_footer")
                }
            }

            // MARK: - Branding Upsell (Free users)
            if !accessManager.isPro {
                Section {
                    Text("profile.branding_upsell")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    NavigationLink("profile.unlock_branding") {
                        PremiumPaywallView()
                    }
                } header: {
                    Text("profile.business_branding")
                }
            }
            
            if isEditing {
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Text("profile.delete_account")
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
        .navigationTitle("profile.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        focusedField = nil
                        selectedLogoImage = nil
                        selectedLogoItem = nil
                        isEditing = false
                        loadUser()
                    }
                    .disabled(isSaving || isDeletingAccount || isUploadingLogo)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        focusedField = nil
                        saveProfile()
                    }
                    .disabled(isSaving || isDeletingAccount || isUploadingLogo)
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.edit") {
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
        .onChange(of: isEditing) { _, newValue in
            focusedField = newValue ? .name : nil
        }
        .alert("profile.delete_account", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive, action: deleteAccount)
        } message: {
            Text("profile.delete_message")
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

private struct LogoPreview: View {
    let selectedLogoImage: UIImage?
    let logoURLString: String?
    let isUploading: Bool

    var body: some View {
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
            } else if let logoURLString,
                      let logoURL = URL(string: logoURLString) {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.75)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    @unknown default:
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }

            if isUploading {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 56, height: 56)

                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
