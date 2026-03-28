import SwiftUI

/// Translucent “liquid glass” surfaces using system materials and a soft hairline stroke.
struct FaroGlassCard: ViewModifier {
    var cornerRadius: CGFloat = FaroRadius.lg
    var material: Material = .regularMaterial

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke, lineWidth: 1)
            )
    }
}

struct FaroGlassCapsule: ViewModifier {
    var material: Material = .thinMaterial

    func body(content: Content) -> some View {
        content
            .background(material, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(FaroPalette.glassStroke, lineWidth: 1))
    }
}

extension View {
    func faroGlassCard(cornerRadius: CGFloat = FaroRadius.lg, material: Material = .regularMaterial) -> some View {
        modifier(FaroGlassCard(cornerRadius: cornerRadius, material: material))
    }

    func faroGlassCapsule(material: Material = .thinMaterial) -> some View {
        modifier(FaroGlassCapsule(material: material))
    }

    /// Full-screen or section background: cream/dark base with a subtle purple wash.
    func faroCanvasBackground() -> some View {
        self.background {
            ZStack {
                FaroPalette.background.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        FaroPalette.purple.opacity(0.08),
                        FaroPalette.background.opacity(0.001),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}
