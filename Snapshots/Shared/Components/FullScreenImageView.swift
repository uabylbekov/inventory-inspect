import SwiftUI
import UniformTypeIdentifiers

enum ImageSource {
    case local(PlatformImage)
    case remote(URL)
}

struct FullScreenImageView: View {
    let image: ImageSource
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: PlatformImage?
    @State private var exportDocument: ExportedImageDocument?
    @State private var exportFilename = ""
    @State private var showingExporter = false
    @State private var savedToPhotos = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            Group {
                switch image {
                case .local(let image):
                    zoomableImage(Image(platformImage: image))
                        .onAppear { loadedImage = image }
                case .remote(let url):
                    CachedAsyncImage(url: url) { image in
                        zoomableImage(image)
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                    .task {
                        // Use the cache instead of direct network fetch
                        if let cached = ImageCache.shared.get(for: url) {
                            loadedImage = cached
                        } else if let (data, _) = try? await URLSession.shared.data(from: url),
                                  let image = makePlatformImage(from: data) {
                            ImageCache.shared.set(image, for: url)
                            loadedImage = image
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Toolbar overlay
            HStack(spacing: 20) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                if let img = loadedImage {
                    #if canImport(UIKit)
                    Button {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        withAnimation { savedToPhotos = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedToPhotos = false }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    #endif
                    
                    // Share
                    Button {
                        if let data = platformJPEGData(from: img, compressionQuality: 0.9) {
                            exportDocument = ExportedImageDocument(data: data)
                            exportFilename = String(localized: "image.filename")
                            showingExporter = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Saved toast
            if savedToPhotos {
                VStack {
                    Spacer()
                    Label("image.saved_to_photos", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .jpeg,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
    }
    
    @ViewBuilder
    private func zoomableImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in scale = lastScale * value }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
            }
    }
}
