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
        List {
            Section {
                Picker("Condition", selection: $status) {
                    Text("Present").tag("present")
                    Text("Missing").tag("missing")
                    Text("Damaged").tag("damaged")
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            } header: {
                Text("Condition")
            }
            
            Section {
                TextField("Describe condition, issues…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.body)
            } header: {
                Text("Notes")
            }
            
            Section {
                Button {
                    showingImageSource = true
                } label: {
                    Label(
                        (pendingImageData != nil || imageURL != nil) ? "Replace Photo" : "Attach Photo",
                        systemImage: (pendingImageData != nil || imageURL != nil) ? "arrow.triangle.2.circlepath" : "camera.fill"
                    )
                    .font(.body)
                    .fontWeight(.medium)
                }
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
                
                if isUploading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Uploading…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Group {
                    if let data = pendingImageData, let uiImage = UIImage(data: data) {
                        ImagePreviewButton(uiImage: uiImage) {
                            showFullScreenImage = true
                        }
                    } else if let urlStr = imageURL, let publicURL = URL(string: urlStr) {
                        RemoteImagePreviewButton(url: publicURL) {
                            showFullScreenImage = true
                        }
                    }
                }
            } header: {
                Text("Photo Evidence")
            }
            
            Section {
                Button(action: {
                    Task {
                        HapticManager.shared.impact(style: .medium)
                        await performSave()
                        if saveError == nil {
                            savedSuccessfully = true
                            HapticManager.shared.notification(type: .success)
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            dismiss()
                        } else {
                            HapticManager.shared.notification(type: .error)
                        }
                    }
                }) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .padding(.trailing, 4)
                        } else if savedSuccessfully {
                            Label("Saved!", systemImage: "checkmark.circle.fill")
                        } else {
                            Text("Save")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSaving)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            if let err = saveError {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(item.name)
                        .font(.headline)
                    Text(room.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        .overlay {
            if isProcessingImage {
                LoadingOverlay(message: "Optimizing Photo…")
            }
        }
    }
    

    private func performSave() async {
        isSaving = true
        do {
            if let data = pendingImageData {
                isUploading = true
                let fileName = "\(inspection.id.uuidString)/\(self.item.id.uuidString).jpg"
                _ = try await supabase.storage
                    .from("inspection-images")
                    .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                let publicURL = try supabase.storage
                    .from("inspection-images")
                    .getPublicURL(path: fileName)
                self.imageURL = publicURL.absoluteString
                pendingImageData = nil
                isUploading = false
            }
            
            var params: [String: AnyJSON] = [
                "inspection_id": .string(inspection.id.uuidString.lowercased()),
                "room_id": .string(room.id.uuidString.lowercased()),
                "inventory_item_id": .string(item.id.uuidString.lowercased()),
                "status": .string(status),
                "notes": .string(notes)
            ]
            if let img = imageURL, !img.isEmpty {
                params["image_url"] = .string(img)
            } else {
                params["image_url"] = .null
            }
            
            try await supabase
                .from("inspection_items")
                .upsert(params, onConflict: "inspection_id,inventory_item_id")
                .execute()
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
                // Small delay to ensure the loading overlay is dismissed before showing sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showingAnnotation = true
                }
            }
        }
    }
}

// MARK: - Subviews

struct ImagePreviewButton: View {
    let uiImage: UIImage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RemoteImagePreviewButton: View {
    let url: URL
    let action: () -> Void
    
    var body: some View {
        CachedAsyncImage(url: url) { image in
            Button(action: action) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } placeholder: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(height: 200)
                .overlay(ProgressView())
        }
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
