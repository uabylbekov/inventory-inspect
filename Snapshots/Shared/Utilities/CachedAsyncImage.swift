import SwiftUI

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, PlatformImage>()
    
    private init() {
        cache.countLimit = 200 // Maximum 200 images in memory
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    func get(for url: URL) -> PlatformImage? {
        // 1. Check memory cache
        if let image = cache.object(forKey: url as NSURL) {
            return image
        }
        return nil
    }
    
    func set(_ image: PlatformImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let width: Int?      // Optional: Width for Supabase transformation
    let height: Int?     // Optional: Height for Supabase transformation
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: PlatformImage? = nil
    @State private var isLoading = false
    
    init(url: URL?, width: Int? = nil, height: Int? = nil, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.width = width
        self.height = height
        self.content = content
        self.placeholder = placeholder
    }
    
    private var transformedUrl: URL? {
        guard let url = url else { return nil }
        
        // Only transform Supabase public URLs
        if url.absoluteString.contains("/storage/v1/object/public/") {
            let transformed = url.absoluteString.replacingOccurrences(of: "/storage/v1/object/public/", with: "/storage/v1/render/image/public/")
            var components = URLComponents(string: transformed)
            var queryItems = components?.queryItems ?? []
            
            if let w = width {
                queryItems.append(URLQueryItem(name: "width", value: String(w)))
            }
            if let h = height {
                queryItems.append(URLQueryItem(name: "height", value: String(h)))
            }
            if width != nil || height != nil {
                queryItems.append(URLQueryItem(name: "quality", value: "80"))
                queryItems.append(URLQueryItem(name: "resize", value: "contain"))
            }
            
            components?.queryItems = queryItems
            return components?.url
        }
        
        return url
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(platformImage: image))
            } else {
                placeholder()
                    .onAppear {
                        if !isLoading {
                            Task {
                                await loadImage()
                            }
                        }
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let finalUrl = transformedUrl else { return }
        
        // 1. Check Memory Cache
        if let cached = ImageCache.shared.get(for: finalUrl) {
            self.image = cached
            return
        }
        
        isLoading = true
        
        // 2. Network Fetch + Disk Cache Handling (Native URLCache)
        let request = URLRequest(url: finalUrl, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let decodedImage = makePlatformImage(from: data) {
                ImageCache.shared.set(decodedImage, for: finalUrl)
                self.image = decodedImage
            }
        } catch {
            print("Failed to load image from \(finalUrl): \(error)")
        }
        
        isLoading = false
    }
}
