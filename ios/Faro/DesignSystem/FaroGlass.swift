import SwiftUI

// MARK: - Glass Card (translucent, frosted)

struct FaroGlassCard: ViewModifier {
    var cornerRadius: CGFloat = FaroRadius.lg

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(FaroPalette.surface.opacity(0.45))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), FaroPalette.glassStroke.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Glass Capsule (pill shape, translucent)

struct FaroGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(FaroPalette.surface.opacity(0.45))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), FaroPalette.glassStroke.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Tinted Pill (status badges)

struct FaroPillTag: ViewModifier {
    var color: Color
    var intensity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(color.opacity(intensity))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            }
    }
}

extension View {
    func faroGlassCard(cornerRadius: CGFloat = FaroRadius.lg) -> some View {
        modifier(FaroGlassCard(cornerRadius: cornerRadius))
    }

    func faroGlassCapsule() -> some View {
        modifier(FaroGlassCapsule())
    }

    func faroPillTag(color: Color, intensity: Double = 0.12) -> some View {
        modifier(FaroPillTag(color: color, intensity: intensity))
    }

    /// Full-screen or section background: cream/dark base with a layered purple wash.
    func faroCanvasBackground() -> some View {
        self.background {
            ZStack {
                FaroPalette.background.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        FaroPalette.purple.opacity(0.1),
                        FaroPalette.purpleDeep.opacity(0.04),
                        FaroPalette.background.opacity(0.001),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        FaroPalette.purpleDeep.opacity(0.06),
                        Color.clear,
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 400
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
                Capsule(style: .continuous)
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
                    Capsule(style: .continuous)
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

// MARK: - Scale Press Button Style

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
