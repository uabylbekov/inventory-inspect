import SwiftUI
import Supabase
import PhotosUI
import UniformTypeIdentifiers

struct InspectionItemDetailView: View {
    let item: RoomInventoryItemModel
    let inspection: InspectionModel
    let room: PropertyRoomModel
    let property: PropertyModel?
    
    @State private var viewModel: InspectionItemDetailViewModel
    @State private var savedSuccessfully = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFullScreenImage = false
    @State private var showingAnnotation = false
    @State private var showingImageSource = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showingFileImporter = false
    @State private var capturedImage: PlatformImage?
    @Environment(\.dismiss) private var dismiss
    private let accessManager = SnapshotsAccessManager.shared
    
    init(item: RoomInventoryItemModel, inspection: InspectionModel, room: PropertyRoomModel, property: PropertyModel?, initialRecord: InspectionItemModel?) {
        self.item = item
        self.inspection = inspection
        self.room = room
        self.property = property
        _viewModel = State(initialValue: InspectionItemDetailViewModel(item: item, inspection: inspection, room: room, property: property, initialRecord: initialRecord))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                LabeledContent("Item", value: item.name)
                LabeledContent("Room", value: room.name)
            }

            Section {
                conditionRow(
                    title: String(localized: "inspection_item.status.present"),
                    icon: "checkmark.circle",
                    selectedIcon: "checkmark.circle.fill",
                    tint: .green,
                    statusKey: "present"
                )
                conditionRow(
                    title: String(localized: "inspection_item.status.missing"),
                    icon: "questionmark.circle",
                    selectedIcon: "questionmark.circle.fill",
                    tint: .orange,
                    statusKey: "missing"
                )
                conditionRow(
                    title: String(localized: "inspection_item.status.damaged"),
                    icon: "exclamationmark.triangle",
                    selectedIcon: "exclamationmark.triangle.fill",
                    tint: .red,
                    statusKey: "damaged"
                )
            } header: {
                Text("inspection_item.condition")
            }

            Section {
                evidenceRow
            } header: {
                Text("inspection_item.evidence")
            } footer: {
                if !accessManager.hasDirectPaidAccess,
                   let property,
                   property.ownerTier != "free" {
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("inspection_item.inherited_plan", comment: ""),
                        property.ownerDisplayName,
                        property.ownerTier.capitalized
                    ))
                } else {
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("inspection_item.photo_limit_footer", comment: ""),
                        accessManager.photoUsageCount,
                        accessManager.directTierLimits.photoLimit
                    ))
                }
            }

            Section {
                TextField("inspection_item.notes_placeholder", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("inspection_item.notes")
            } footer: {
                if let err = viewModel.saveError {
                    Text(err)
                        .foregroundColor(.red)
                }
            }

            if viewModel.imageURL != nil || viewModel.pendingImageData != nil {
                Section {
                    Button("inspection_item.remove_photo", role: .destructive) {
                        withAnimation {
                            viewModel.removePhoto()
                        }
                    }
                }
            }
        }
        .navigationTitle("inspection_item.title")
        .applyInlineNavigationTitleIfSupported()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    Task {
                        HapticManager.shared.impact(style: .medium)
                        let saved = await viewModel.save()
                        if saved {
                            savedSuccessfully = true
                            HapticManager.shared.notification(type: .success)
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(viewModel.isSaving || savedSuccessfully)
            }
        }
        .overlay {
            if viewModel.isProcessingImage {
                LoadingOverlay(message: String(localized: "inspection_item.optimizing_photo"))
            }
        }
        .sheet(isPresented: $showingAnnotation) {
            if let img = viewModel.annotatingImage {
                InventoryImageAnnotationView(image: img, isPresented: $showingAnnotation, onSave: { annotatedData in
                    withAnimation {
                        viewModel.setAnnotatedImageData(annotatedData)
                        viewModel.annotatingImage = nil
                    }
                })
            }
        }
        .adaptiveImagePresentation(isPresented: $showFullScreenImage) {
            if let data = viewModel.pendingImageData, let image = makePlatformImage(from: data) {
                FullScreenImageView(image: .local(image))
            } else if let urlStr = viewModel.imageURL, let publicURL = URL(string: urlStr) {
                FullScreenImageView(image: .remote(publicURL))
            }
        }
        .photosPicker(isPresented: $showingLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = makePlatformImage(from: data) {
                    viewModel.prepareAnnotation(image)
                }
            }
        }
        .onChange(of: viewModel.isProcessingImage) { _, isProcessing in
            if !isProcessing, viewModel.annotatingImage != nil {
                showingAnnotation = true
            }
        }
    }
    
    @ViewBuilder
    private func conditionRow(title: String, icon: String, selectedIcon: String, tint: Color, statusKey: String) -> some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            withAnimation {
                viewModel.updateStatus(statusKey)
            }
        }) {
            HStack {
                Image(systemName: viewModel.status == statusKey ? selectedIcon : icon)
                    .foregroundColor(viewModel.status == statusKey ? tint : .secondary)
                Text(title)
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private var evidenceRow: some View {
        if let data = viewModel.pendingImageData, let image = makePlatformImage(from: data) {
            Button { showFullScreenImage = true } label: {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            }
            .buttonStyle(.plain)
        } else if let urlStr = viewModel.imageURL, let publicURL = URL(string: urlStr) {
            CachedAsyncImage(url: publicURL) { image in
                Button { showFullScreenImage = true } label: {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                }
                .buttonStyle(.plain)
            } placeholder: {
                Rectangle()
                    .fill(Color.platformSecondarySystemBackground)
                    .frame(height: 200)
                    .overlay(ProgressView())
            }
        }

        Button(action: { showingImageSource = true }) {
            HStack {
                Text(viewModel.imageURL == nil && viewModel.pendingImageData == nil
                     ? String(localized: "inspection_item.add_photo")
                     : String(localized: "inspection_item.change_photo"))
                Spacer()
                if viewModel.isUploading {
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isUploading)
        .confirmationDialog("inspection_item.attach_photo", isPresented: $showingImageSource) {
            if supportsCameraCapture {
                Button("inspection_item.camera") { showingCamera = true }
            }
            Button("inspection_item.photo_library") { showingLibrary = true }
            Button("Files") { showingFileImporter = true }
            Button("common.cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.image]) { result in
            handleImportedImage(result)
        }
        .onChange(of: capturedImage) { _, newValue in
            if let img = newValue {
                viewModel.prepareAnnotation(img)
            }
        }
    }

    private var supportsCameraCapture: Bool {
#if !canImport(UIKit)
        false
#else
        true
#endif
    }

    private func handleImportedImage(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let image = makePlatformImage(from: data) else {
            return
        }

        viewModel.prepareAnnotation(image)
    }
}

private extension View {
    @ViewBuilder
    func applyInlineNavigationTitleIfSupported() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func adaptiveImagePresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
#if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
#else
        self.sheet(isPresented: isPresented, content: content)
#endif
    }
}
