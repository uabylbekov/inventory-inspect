import SwiftUI

struct AppDesign {
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let card: CGFloat = 18
        static let image: CGFloat = 12
        static let container: CGFloat = 24
    }
    
    // MARK: - Icon Sizes
    struct IconSize {
        static let micro: CGFloat = 12
        static let small: CGFloat = 18
        static let medium: CGFloat = 24
        static let large: CGFloat = 32
        static let rowIcon: CGFloat = 44
        static let featureIcon: CGFloat = 52
    }
    
    // MARK: - Layout Constants
    struct Layout {
        static let cardPadding: CGFloat = 12
        static let maxWidth: CGFloat = 600
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let subtle = ShadowStyle(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        static let floating = ShadowStyle(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func appShadow(_ style: AppDesign.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
