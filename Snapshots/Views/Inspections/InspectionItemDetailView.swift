import SwiftUI
import Supabase
import PhotosUI

struct InspectionItemDetailView: View {
    let item: RoomInventoryItemModel
    let inspection: InspectionModel
    let room: PropertyRoomModel
    let property: PropertyModel?
    
    @State private var status: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var savedSuccessfully = false
    @State private var saveError: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageURL: String?
    @State private var pendingImageData: Data?
    @State private var isUploading = false
    @State private var showFullScreenImage = false
    @State private var showingAnnotation = false
    @State private var annotatingImage: UIImage?
    @State private var showingImageSource = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var capturedImage: UIImage?
    @State private var isProcessingImage = false
    @State private var showingPaywall = false
    @Environment(\.dismiss) private var dismiss
    private let accessManager = SnapshotsAccessManager.shared
    
    init(item: RoomInventoryItemModel, inspection: InspectionModel, room: PropertyRoomModel, property: PropertyModel?, initialRecord: InspectionItemModel?) {
        self.item = item
        self.inspection = inspection
        self.room = room
        self.property = property
        _status = State(initialValue: initialRecord?.status ?? "present")
        _notes = State(initialValue: initialRecord?.notes ?? "")
        _imageURL = State(initialValue: initialRecord?.image_url)
    }
    
    var body: some View {
        List {
            // MARK: - Item Header
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.gradient)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Text(room.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            
            // MARK: - Condition Section
            Section {
                conditionRow(title: String(localized: "inspection_item.status.present"), icon: "checkmark.circle.fill", color: .green, statusKey: "present")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                conditionRow(title: String(localized: "inspection_item.status.missing"), icon: "questionmark.circle.fill", color: .orange, statusKey: "missing")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                conditionRow(title: String(localized: "inspection_item.status.damaged"), icon: "exclamationmark.triangle.fill", color: .red, statusKey: "damaged")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } header: {
                Text("inspection_item.condition")
            }
            
            // MARK: - Evidence Section
            Section {
                if accessManager.isPro(for: property) {
                    if !accessManager.isDirectSubscriber,
                       let property,
                       property.ownerTier != "free" {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("inspection_item.included_here")
                                    .font(.subheadline.weight(.semibold))
                                Text(String.localizedStringWithFormat(
                                    NSLocalizedString("inspection_item.inherited_plan", comment: ""),
                                    property.ownerDisplayName,
                                    property.ownerTier.capitalized
                                ))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    evidenceRow
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                } else {
                    Button(action: { showingPaywall = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "camera.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("inspection_item.add_photo")
                                    .foregroundColor(.primary)
                                Text("inspection_item.requires_pro")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Text("plan.badge.pro")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                                .foregroundColor(.white)
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
            } header: {
                Text("inspection_item.evidence")
            } footer: {
                if !accessManager.isPro(for: property) {
                    Text("inspection_item.upgrade_footer")
                }
            }
            
            // MARK: - Notes Section
            Section {
                TextField("inspection_item.notes_placeholder", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } header: {
                Text("inspection_item.notes")
            } footer: {
                if let err = saveError {
                    Text(err)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("inspection_item.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    Task {
                        HapticManager.shared.impact(style: .medium)
                        await performSave()
                        if saveError == nil {
                            savedSuccessfully = true
                            HapticManager.shared.notification(type: .success)
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            dismiss()
                        }
                    }
                }) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(isSaving || savedSuccessfully)
            }
        }
        .overlay {
            if isProcessingImage {
                LoadingOverlay(message: String(localized: "inspection_item.optimizing_photo"))
            }
        }
        .sheet(isPresented: $showingAnnotation) {
            if let img = annotatingImage {
                InventoryImageAnnotationView(image: img, isPresented: $showingAnnotation, onSave: { annotatedData in
                    withAnimation {
                        self.pendingImageData = annotatedData
                        self.annotatingImage = nil
                    }
                })
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let data = pendingImageData, let uiImage = UIImage(data: data) {
                FullScreenImageView(image: .local(uiImage))
            } else if let urlStr = imageURL, let publicURL = URL(string: urlStr) {
                FullScreenImageView(image: .remote(publicURL))
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    prepareAnnotation(image)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func conditionRow(title: String, icon: String, color: Color, statusKey: String) -> some View {
        Button(action: { updateStatus(statusKey) }) {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(status == statusKey ? color : .primary)
                Spacer()
                if status == statusKey {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private var evidenceRow: some View {
        VStack(spacing: 12) {
            if let data = pendingImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) {
                        photoActionsOverlay
                    }
            } else if let urlStr = imageURL, let publicURL = URL(string: urlStr) {
                CachedAsyncImage(url: publicURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottomTrailing) {
                            photoActionsOverlay
                        }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 200)
                        .overlay(ProgressView())
                }
            }
            
            Button(action: { showingImageSource = true }) {
                HStack {
                    Label(imageURL == nil && pendingImageData == nil ? String(localized: "inspection_item.add_photo") : String(localized: "inspection_item.change_photo"), 
                          systemImage: "camera.fill")
                    Spacer()
                    if isUploading {
                        ProgressView()
                    }
                }
            }
            .disabled(isUploading)
        }
        .padding(.vertical, 4)
        .confirmationDialog("inspection_item.attach_photo", isPresented: $showingImageSource) {
            Button("inspection_item.camera") { showingCamera = true }
            Button("inspection_item.photo_library") { showingLibrary = true }
            if imageURL != nil || pendingImageData != nil {
                Button("inspection_item.remove_photo", role: .destructive) {
                    withAnimation {
                        imageURL = nil
                        pendingImageData = nil
                    }
                }
            }
            Button("common.cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newValue in
            if let img = newValue {
                prepareAnnotation(img)
            }
        }
    }
    
    private var photoActionsOverlay: some View {
        Button(action: { showFullScreenImage = true }) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(8)
    }
    
    private func updateStatus(_ newStatus: String) {
        HapticManager.shared.impact(style: .light)
        withAnimation {
            self.status = newStatus
        }
    }
    
    // MARK: - Logic (Unchanged but moved for clarity)
    
    private func performSave() async {
        isSaving = true
        saveError = nil
        
        do {
            var currentImageURL = self.imageURL
            
            if let data = pendingImageData {
                isUploading = true
                defer { isUploading = false }
                
                let fileName = "\(inspection.id.uuidString.lowercased())/\(self.item.id.uuidString.lowercased()).jpg"
                _ = try await supabase.storage
                    .from("inspection-images")
                    .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                
                let publicURL = try supabase.storage
                    .from("inspection-images")
                    .getPublicURL(path: fileName)
                
                currentImageURL = publicURL.absoluteString
            }
            
            let params: [String: AnyJSON] = [
                "inspection_id": .string(inspection.id.uuidString.lowercased()),
                "room_id": .string(room.id.uuidString.lowercased()),
                "inventory_item_id": .string(item.id.uuidString.lowercased()),
                "status": .string(status),
                "notes": .string(notes),
                "image_url": currentImageURL != nil ? .string(currentImageURL!) : .null
            ]
            
            try await supabase
                .from("inspection_items")
                .upsert(params, onConflict: "inspection_id,inventory_item_id")
                .execute()
            
            // Only clear local cache and update URL on total success
            await MainActor.run {
                self.imageURL = currentImageURL
                self.pendingImageData = nil
            }
            
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }
    
    private func prepareAnnotation(_ image: UIImage) {
        isProcessingImage = true
        Task.detached(priority: .userInitiated) {
            let maxDimension: CGFloat = 2048
            let resultImage: UIImage
            
            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale = maxDimension / max(image.size.width, image.size.height)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                resultImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                resultImage = image
            }
            
            await MainActor.run {
                self.isProcessingImage = false
                self.annotatingImage = resultImage
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showingAnnotation = true
                }
            }
        }
    }
}
