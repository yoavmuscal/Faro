import SwiftUI

// MARK: - Glass Card (translucent, frosted)
// Uses regularMaterial so the Liquid Glass environment colour bleeds through.

struct FaroGlassCard: ViewModifier {
    var cornerRadius: CGFloat = FaroRadius.lg

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(FaroPalette.surface.opacity(0.28))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), FaroPalette.glassStroke.opacity(0.15)],
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
                    .fill(.regularMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(FaroPalette.surface.opacity(0.28))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), FaroPalette.glassStroke.opacity(0.15)],
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

    /// Full-screen or section background: soft cream in light mode; flat neutral dark (no purple “wash”).
    func faroCanvasBackground() -> some View {
        self.background {
            FaroCanvasBackgroundLayer()
        }
    }
}

// MARK: - Canvas background

private struct FaroCanvasBackgroundLayer: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            FaroPalette.background.ignoresSafeArea()
            if colorScheme == .light {
                LinearGradient(
                    colors: [
                        FaroPalette.purple.opacity(0.06),
                        FaroPalette.purpleDeep.opacity(0.025),
                        FaroPalette.background.opacity(0.001),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        FaroPalette.purpleDeep.opacity(0.035),
                        Color.clear,
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        FaroPalette.ink.opacity(0.04),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Gradient Button Style (flat pill — no shadow, colour does the work)

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
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                }
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Danger Pill Button Style (destructive actions)

struct FaroDangerPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FaroPalette.danger)
            .background {
                Capsule(style: .continuous)
                    .fill(FaroPalette.danger.opacity(0.09))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(FaroPalette.danger.opacity(0.28), lineWidth: 0.75)
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FaroDangerPillButtonStyle {
    static var faroDangerPill: FaroDangerPillButtonStyle { .init() }
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

// MARK: - Dashboard surfaces (Coverage / Risk / Submission alignment)

extension View {
    /// Padding + glass card so dashboard-style screens share the same tile geometry as Coverage.
    /// Set `fillAvailableHeight` when the card sits in an equal-height row (e.g. iPad two-column stacks).
    func faroDashboardCardSurface(
        maxOuterWidth: CGFloat? = nil,
        innerPadding: CGFloat = FaroSpacing.lg,
        fillAvailableHeight: Bool = false
    ) -> some View {
        self
            .padding(innerPadding)
            .frame(
                maxWidth: maxOuterWidth ?? .infinity,
                maxHeight: fillAvailableHeight ? .infinity : nil,
                alignment: .topLeading
            )
            .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

/// Titles and icon scale for `FaroDashboardInsightSectionHeader`.
enum FaroDashboardInsightHeaderStyle {
    case standard
    /// Larger type and icon for Risk / Submission and other reading-heavy screens.
    case emphasized
}

/// Metric tile used on Coverage dashboard and aligned Risk / Submission screens.
struct FaroDashboardMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    private var tileRadius: CGFloat { FaroRadius.xl }

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            HStack(spacing: FaroSpacing.sm) {
                ZStack {
                    metricIconCircle
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }

            Text(value)
                .font(FaroType.title3(.bold))
                .foregroundStyle(FaroPalette.ink)
                .minimumScaleFactor(0.55)
                .lineLimit(2)

            Text(title)
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.55))

            Text(subtitle)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.38))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(FaroSpacing.md + 2)
        .background { metricTileBackground }
        .overlay { metricTileOutline }
    }

    @ViewBuilder
    private var metricIconCircle: some View {
        if colorScheme == .dark {
            Circle()
                .fill(tint.opacity(0.55))
                .frame(width: 40, height: 40)
        } else {
            Circle()
                .fill(tint.gradient)
                .frame(width: 40, height: 40)
                .shadow(color: tint.opacity(0.22), radius: 10, y: 3)
        }
    }

    @ViewBuilder
    private var metricTileBackground: some View {
        RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                        .fill(tint.opacity(0.07))
                } else {
                    RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.12), FaroPalette.surface.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
    }

    @ViewBuilder
    private var metricTileOutline: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.32), lineWidth: 0.75)
        } else {
            RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.42), tint.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
    }
}

/// Section header with icon well — matches Coverage insight cards.
struct FaroDashboardInsightSectionHeader: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    var style: FaroDashboardInsightHeaderStyle = .standard

    private var iconWellSize: CGFloat { style == .emphasized ? 52 : 44 }
    private var iconGlyphSize: Font { style == .emphasized ? .title : .title2 }

    var body: some View {
        HStack(alignment: .center, spacing: FaroSpacing.md) {
            Image(systemName: icon)
                .font(iconGlyphSize)
                .foregroundStyle(iconTint)
                .frame(width: iconWellSize, height: iconWellSize)
                .background(iconTint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: style == .emphasized ? 6 : 4) {
                Text(title)
                    .font(style == .emphasized ? FaroType.title3(.semibold) : FaroType.headline())
                    .foregroundStyle(style == .emphasized ? FaroPalette.purpleDeep : FaroPalette.ink)
                Text(subtitle)
                    .font(style == .emphasized ? FaroType.subheadline() : FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(style == .emphasized ? 0.48 : 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Leading vertical stripe + multiline label; stripe height always matches the text block (no HStack measurement quirks).
struct FaroDashboardStripeBulletRow: View {
    let text: String
    let stripe: Color
    var textOpacity: Double = 0.88

    var body: some View {
        Text(text)
            .font(FaroType.body())
            .foregroundStyle(FaroPalette.ink.opacity(textOpacity))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(stripe)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
            }
            .padding(.vertical, FaroSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Hairline / soft gradient card edge — matches Coverage dashboard tiles.
struct FaroDashboardCardOutline: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke.opacity(0.38), lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), FaroPalette.purple.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
    }
}

/// Labeled row inside dashboard cards (Coverage snapshot style).
struct FaroDashboardSnapshotRow: View {
    let title: String
    let value: String
    let detail: String
    /// Extra padding for reading-heavy screens (e.g. Risk revenue band).
    var comfortable: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: comfortable ? 8 : 6) {
            Text(title.uppercased())
                .font(FaroType.caption2(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.4))
                .tracking(0.35)
            Text(value)
                .font(comfortable ? FaroType.title3() : FaroType.headline())
                .foregroundStyle(FaroPalette.ink)
                .lineLimit(comfortable ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)
            if !detail.isEmpty {
                Text(detail)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.48))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(comfortable ? FaroSpacing.lg : FaroSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                .fill(FaroPalette.surface.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.2), lineWidth: 0.5)
        }
    }
}
