import SwiftUI

/// Elevated card surfaces using semantic `FaroPalette.surface` (no translucent grey materials).
struct FaroGlassCard: ViewModifier {
    var cornerRadius: CGFloat = FaroRadius.lg

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(FaroPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke.opacity(0.55), lineWidth: 1)
            )
    }
}

struct FaroGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Capsule(style: .continuous).fill(FaroPalette.surface))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke.opacity(0.55), lineWidth: 1)
            )
    }
}

extension View {
    func faroGlassCard(cornerRadius: CGFloat = FaroRadius.lg) -> some View {
        modifier(FaroGlassCard(cornerRadius: cornerRadius))
    }

    func faroGlassCapsule() -> some View {
        modifier(FaroGlassCapsule())
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

// MARK: - Gradient Button Style

struct FaroGradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [FaroPalette.purpleDeep, FaroPalette.purple]
                                : [FaroPalette.ink.opacity(0.1), FaroPalette.ink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                if isEnabled {
                    RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: isEnabled
                    ? FaroPalette.purpleDeep.opacity(configuration.isPressed ? 0.15 : 0.3)
                    : .clear,
                radius: configuration.isPressed ? 6 : 14,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FaroGradientButtonStyle {
    static var faroGradient: FaroGradientButtonStyle { .init() }
}

// MARK: - Scale Press Button Style (for interactive cards)

struct FaroScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FaroScaleButtonStyle {
    static var faroScale: FaroScaleButtonStyle { FaroScaleButtonStyle() }
}
