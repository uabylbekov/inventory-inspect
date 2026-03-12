import SwiftUI

#if canImport(UIKit)
import UIKit

typealias PlatformImage = UIImage

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}

extension Color {
    static let platformSystemBackground = Color(uiColor: .systemBackground)
    static let platformSecondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    static let platformSecondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let platformGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let platformSeparator = Color(uiColor: .separator)
    static let platformGray5 = Color(uiColor: .systemGray5)
}

func makePlatformImage(from data: Data) -> PlatformImage? {
    UIImage(data: data)
}

func platformJPEGData(from image: PlatformImage, compressionQuality: CGFloat) -> Data? {
    image.jpegData(compressionQuality: compressionQuality)
}

func resizedPlatformImage(_ image: PlatformImage, to size: CGSize) -> PlatformImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}

func platformSystemVersionString() -> String {
    UIDevice.current.systemVersion
}

func dismissPlatformKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#elseif canImport(AppKit)
import AppKit

typealias PlatformImage = NSImage

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}

extension Color {
    static let platformSystemBackground = Color(nsColor: .windowBackgroundColor)
    static let platformSecondarySystemBackground = Color(nsColor: .controlBackgroundColor)
    static let platformSecondaryGroupedBackground = Color(nsColor: .controlBackgroundColor)
    static let platformGroupedBackground = Color(nsColor: .windowBackgroundColor)
    static let platformSeparator = Color(nsColor: .separatorColor)
    static let platformGray5 = Color(nsColor: .quaternaryLabelColor)
}

func makePlatformImage(from data: Data) -> PlatformImage? {
    NSImage(data: data)
}

func platformJPEGData(from image: PlatformImage, compressionQuality: CGFloat) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }

    return bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionQuality]
    )
}

func resizedPlatformImage(_ image: PlatformImage, to size: CGSize) -> PlatformImage {
    let result = NSImage(size: size)
    result.lockFocus()
    image.draw(
        in: CGRect(origin: .zero, size: size),
        from: CGRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1
    )
    result.unlockFocus()
    return result
}

func platformSystemVersionString() -> String {
    ProcessInfo.processInfo.operatingSystemVersionString
}

func dismissPlatformKeyboard() {}
#endif
