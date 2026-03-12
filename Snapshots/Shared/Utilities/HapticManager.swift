#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)

    private init() {}

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = impactGenerator(for: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightImpactGenerator
        case .medium:
            return mediumImpactGenerator
        case .heavy, .rigid, .soft:
            return heavyImpactGenerator
        @unknown default:
            return mediumImpactGenerator
        }
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
    func selection() {}
}
#endif
