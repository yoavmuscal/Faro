import SwiftUI

/// Semantic colors, typography (SF Rounded), spacing, and radii for Faro.
enum FaroPalette {
    static let background = Color("FaroBackground")
    static let surface = Color("FaroSurface")
    static let purple = Color("FaroPurple")
    static let purpleDeep = Color("FaroPurpleDeep")
    static let ink = Color("FaroInk")
    static let success = Color("FaroSuccess")
    static let warning = Color("FaroWarning")
    static let danger = Color("FaroDanger")
    static let info = Color("FaroInfo")
    static let glassStroke = Color("FaroGlassStroke")
    /// Text on filled purple / primary controls (adapts for light vs dark purple fills).
    static let onAccent = Color("FaroOnAccent")
}

enum FaroRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

enum FaroSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum FaroType {
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .rounded).weight(weight)
    }

    static func title(_ weight: Font.Weight = .bold) -> Font {
        .system(.title, design: .rounded).weight(weight)
    }

    static func title2(_ weight: Font.Weight = .bold) -> Font {
        .system(.title2, design: .rounded).weight(weight)
    }

    static func title3(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title3, design: .rounded).weight(weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .rounded).weight(weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .rounded).weight(weight)
    }

    static func subheadline(_ weight: Font.Weight = .regular) -> Font {
        .system(.subheadline, design: .rounded).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .rounded).weight(weight)
    }

    static func caption2(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption2, design: .rounded).weight(weight)
    }
}

extension Color {
    /// Preferred app canvas (cream / dark); use instead of plain `platformBackground` for chrome.
    static var faroCanvas: Color { FaroPalette.background }
}
