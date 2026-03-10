import SwiftUI
import Supabase
import PhotosUI

struct InspectionItemDetailView: View {
    let item: RoomInventoryItemModel
    let inspection: InspectionModel
    let room: PropertyRoomModel
    
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
    
    init(item: RoomInventoryItemModel, inspection: InspectionModel, room: PropertyRoomModel, initialRecord: InspectionItemModel?) {
        self.item = item
        self.inspection = inspection
        self.room = room
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
                conditionRow(title: "Present", icon: "checkmark.circle.fill", color: .green, statusKey: "present")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                conditionRow(title: "Missing", icon: "questionmark.circle.fill", color: .orange, statusKey: "missing")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                conditionRow(title: "Damaged", icon: "exclamationmark.triangle.fill", color: .red, statusKey: "damaged")
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } header: {
                Text("Condition")
            }
            
            // MARK: - Evidence Section
            Section {
                if accessManager.isPro {
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
                            Text("Add Photo Evidence")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("PRO")
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
                Text("Evidence")
            } footer: {
                if !accessManager.isPro {
                    Text("Upgrade to Professional to attach photo evidence to inspections.")
                }
            }
            
            // MARK: - Notes Section
            Section {
                TextField("Add details about the condition...", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            } header: {
                Text("Notes")
            } footer: {
                if let err = saveError {
                    Text(err)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Check Item")
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
                        Text("Save")
                    }
                }
                .disabled(isSaving || savedSuccessfully)
            }
        }
        .overlay {
            if isProcessingImage {
                LoadingOverlay(message: "Optimizing Photo…")
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
                    Label(imageURL == nil && pendingImageData == nil ? "Add Photo Evidence" : "Change Photo", 
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
        .confirmationDialog("Attach Photo", isPresented: $showingImageSource) {
            Button("Camera") { showingCamera = true }
            Button("Photo Library") { showingLibrary = true }
            if imageURL != nil || pendingImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    withAnimation {
                        imageURL = nil
                        pendingImageData = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
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

// MARK: - Tactical Components


struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(message)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(20)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
