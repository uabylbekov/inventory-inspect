import SwiftUI

enum ImageSource {
    case local(UIImage)
    case remote(URL)
}

struct FullScreenImageView: View {
    let image: ImageSource
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: UIImage?
    @State private var showShareSheet = false
    @State private var savedToPhotos = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            Group {
                switch image {
                case .local(let uiImage):
                    zoomableImage(Image(uiImage: uiImage))
                        .onAppear { loadedImage = uiImage }
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
                                  let uiImg = UIImage(data: data) {
                            ImageCache.shared.set(uiImg, for: url)
                            loadedImage = uiImg
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
                    // Save to Photos
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
                    
                    // Share
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .sheet(isPresented: $showShareSheet) {
                        if let data = img.jpegData(compressionQuality: 0.9) {
                            ShareSheet(data: data, filename: String(localized: "image.filename"))
                        }
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
