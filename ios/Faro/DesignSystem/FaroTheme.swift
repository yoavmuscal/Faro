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
    static let lg: CGFloat = 22
    static let xl: CGFloat = 32
    static let pill: CGFloat = 999
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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
