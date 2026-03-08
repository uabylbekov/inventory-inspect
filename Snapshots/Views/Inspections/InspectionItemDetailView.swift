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
    @Environment(\.dismiss) private var dismiss
    
    init(item: RoomInventoryItemModel, inspection: InspectionModel, room: PropertyRoomModel, initialRecord: InspectionItemModel?) {
        self.item = item
        self.inspection = inspection
        self.room = room
        _status = State(initialValue: initialRecord?.status ?? "present")
        _notes = State(initialValue: initialRecord?.notes ?? "")
        _imageURL = State(initialValue: initialRecord?.image_url)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // MARK: - Tactical Header
                itemHeaderSection
                
                // MARK: - Condition Picker
                conditionSelectionSection
                
                // MARK: - Evidence Section
                evidenceSection
                
                // MARK: - Notes Section
                notesSection
                
                // MARK: - Save Button
                saveButtonSection
                
                Spacer().frame(height: 50)
            }
            .padding(.top, 16)
        }
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
    
    private var itemHeaderSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title3.bold())
                HStack(spacing: 8) {
                    Image(systemName: PropertyUI.roomIcon(for: room.room_type ?? ""))
                    Text(room.name)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }
    
    private var conditionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select Condition")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                ConditionTile(title: "Present", icon: "checkmark.circle.fill", color: .green, isSelected: status == "present") {
                    updateStatus("present")
                }
                
                ConditionTile(title: "Missing", icon: "questionmark.circle.fill", color: .orange, isSelected: status == "missing") {
                    updateStatus("missing")
                }
                
                ConditionTile(title: "Damaged", icon: "exclamationmark.triangle.fill", color: .red, isSelected: status == "damaged") {
                    updateStatus("damaged")
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Photo Evidence")
                .font(.headline)
                .padding(.horizontal)
            
            ZStack {
                if let data = pendingImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(alignment: .bottomTrailing) {
                            photoActionsOverlay
                        }
                } else if let urlStr = imageURL, let publicURL = URL(string: urlStr) {
                    CachedAsyncImage(url: publicURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(alignment: .bottomTrailing) {
                                photoActionsOverlay
                            }
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 220)
                            .overlay(ProgressView())
                    }
                } else {
                    Button(action: { showingImageSource = true }) {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.badge.ellipsis")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.accentColor.gradient)
                            Text("Capture Photo Evidence")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Text("Essential for missing or damaged items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                if isUploading {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    ProgressView("Uploading...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .confirmationDialog("Attach Photo", isPresented: $showingImageSource) {
                Button("Camera") { showingCamera = true }
                Button("Photo Library") { showingLibrary = true }
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
    }
    
    private var photoActionsOverlay: some View {
        HStack(spacing: 8) {
            Button(action: { showFullScreenImage = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Button(action: { showingImageSource = true }) {
                Image(systemName: "pencil")
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .foregroundColor(.primary)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes")
                .font(.headline)
                .padding(.horizontal)
            
            TextField("Describe condition, missing parts, or signs of wear…", text: $notes, axis: .vertical)
                .lineLimit(4...8)
                .padding(16)
                .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal)
        }
    }
    
    private var saveButtonSection: some View {
        VStack(spacing: 12) {
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
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else if savedSuccessfully {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    Text(savedSuccessfully ? "Saved" : "Save Record")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(savedSuccessfully ? Color.green.gradient : Color.accentColor.gradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: (savedSuccessfully ? Color.green : Color.accentColor).opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isSaving || savedSuccessfully)
            .padding(.horizontal)
            
            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
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

struct ConditionTile: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .foregroundColor(isSelected ? color : .secondary)
            .contentShape(Rectangle())
            .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? color.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
