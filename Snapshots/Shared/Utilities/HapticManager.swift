#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#else
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    enum FeedbackType {
        case success
        case error
        case warning
    }

    enum ImpactStyle {
        case light
        case medium
        case heavy
    }

    func notification(type: FeedbackType) {}
    func impact(style: ImpactStyle) {}
}
#endif
