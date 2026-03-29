import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @Binding var selectedSection: FaroSection
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isIPad: Bool { hSizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                headerRow
                overviewCard
                getStartedCard
                sectionCards
            }
            .padding(.horizontal, isIPad ? FaroSpacing.xl : FaroSpacing.md)
            .padding(.top, FaroSpacing.sm)
            .padding(.bottom, FaroSpacing.xl)
            .frame(maxWidth: isIPad ? 760 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .faroCanvasBackground()
        .navigationTitle("Home")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: FaroSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeGreeting)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(appState.userDisplayName)
                    .font(FaroType.title2())
                    .foregroundStyle(FaroPalette.ink)
            }

            Spacer()

            Button {
                selectedSection = .profile
            } label: {
                profileAvatar
            }
            .buttonStyle(.faroScale)
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        ZStack {
            if let data = appState.userProfilePhotoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                    }
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(initials)
                            .font(FaroType.subheadline(.bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }
            }
        }
        .shadow(color: FaroPalette.purpleDeep.opacity(0.3), radius: 8, y: 3)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.xs) {
                appIconBadge
                Text("Faro")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .textCase(.uppercase)
                    .kerning(1)
            }

            Text(overviewHeadline)
                .font(FaroType.title3())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(overviewSubtitle)
                .font(FaroType.subheadline())
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            if appState.hasResults {
                HStack(spacing: FaroSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Analysis complete")
                        .font(FaroType.caption(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.18))
                }
            }
        }
        .padding(FaroSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FaroPalette.purpleDeep,
                            FaroPalette.purple.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.12),
                                    .white.opacity(0.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: FaroPalette.purpleDeep.opacity(0.35), radius: 20, y: 8)
    }

    @ViewBuilder
    private var appIconBadge: some View {
        if let uiIcon = UIImage(named: "AppIcon") {
            Image(uiImage: uiIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            Image(systemName: "shield.checkered")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Section Cards

    @ViewBuilder
    private var sectionCards: some View {
        if isIPad {
            Grid(horizontalSpacing: FaroSpacing.md, verticalSpacing: FaroSpacing.md) {
                GridRow {
                    sectionCard(section: .coverage)
                    sectionCard(section: .riskProfile)
                }
                GridRow {
                    sectionCard(section: .submission)
                        .gridCellColumns(2)
                }
            }
        } else {
            VStack(spacing: FaroSpacing.md) {
                sectionCard(section: .coverage)
                sectionCard(section: .riskProfile)
                sectionCard(section: .submission)
            }
        }
    }

    private func sectionCard(section: FaroSection) -> some View {
        let cfg = cardConfig(for: section)
        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: FaroSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: cfg.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: cfg.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: cfg.gradient.first?.opacity(0.3) ?? .clear, radius: 8, y: 3)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.ink)
                    Text(cfg.summary)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }

                Spacer(minLength: FaroSpacing.xs)

                // Status + chevron
                VStack(alignment: .trailing, spacing: 6) {
                    Text(cfg.statusLabel)
                        .font(FaroType.caption2(.semibold))
                        .foregroundStyle(cfg.statusColor)
                        .faroPillTag(color: cfg.statusColor, intensity: cfg.isReady ? 0.12 : 0.06)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.3))
                }
            }
            .padding(FaroSpacing.md)
            .faroGlassCard(cornerRadius: FaroRadius.xl)
        }
        .buttonStyle(.faroScale)
    }

    // MARK: - Get Started

    private var getStartedCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            SectionHeader(title: "Get Started", icon: "sparkles", tint: FaroPalette.purpleDeep)

            if APIConfig.auth0MissingClientIdOnly {
                homeAuthWarningBanner
            } else if authManager.isAuthConfigured && !authManager.isLoggedIn {
                homeAuthSignInPrompt
            }

            VStack(spacing: FaroSpacing.sm) {
                NavigationLink { OnboardingView() } label: {
                    homeIntakeRow(
                        title: "Guided Questionnaire",
                        subtitle: "Step-by-step form — type at your own pace.",
                        icon: "list.bullet.rectangle",
                        iconColor: FaroPalette.purpleDeep
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.4)

                NavigationLink { VoiceIntakeView() } label: {
                    homeIntakeRow(
                        title: "Conversational Intake",
                        subtitle: "Talk through the details with your AI agent.",
                        icon: "waveform",
                        iconColor: FaroPalette.info
                    )
                }
                .buttonStyle(.plain)

                Divider().opacity(0.4)

                NavigationLink { OnboardingView(isDemo: true) } label: {
                    homeIntakeDemoRow
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    private func homeIntakeRow(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: FaroSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FaroRadius.sm, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                Text(subtitle)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.25))
        }
        .padding(.vertical, FaroSpacing.xs)
    }

    private var homeIntakeDemoRow: some View {
        HStack(spacing: FaroSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FaroRadius.sm, style: .continuous)
                    .fill(FaroPalette.purple.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "play.circle.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(FaroPalette.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Quick Demo")
                        .font(FaroType.subheadline(.semibold))
                        .foregroundStyle(FaroPalette.ink)
                    Text("PRE-FILLED")
                        .font(FaroType.caption2(.bold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .faroPillTag(color: FaroPalette.purpleDeep, intensity: 0.1)
                }
                Text("See a full analysis using sample daycare data.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.25))
        }
        .padding(.vertical, FaroSpacing.xs)
    }

    private var homeAuthWarningBanner: some View {
        HStack(spacing: FaroSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FaroPalette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Auth0 not configured")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                Text("Add AUTH0_CLIENT_ID in Info.plist to enable API access.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FaroSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .fill(FaroPalette.warning.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .strokeBorder(FaroPalette.warning.opacity(0.3), lineWidth: 0.5)
        }
    }

    private var homeAuthSignInPrompt: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text("Sign in with Auth0 so your analysis requests reach the Faro API.")
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await authManager.login() }
            } label: {
                Label("Sign in with Auth0", systemImage: "person.badge.key.fill")
                    .font(FaroType.headline())
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.faroGradient)

            if let err = authManager.lastError, !err.isEmpty {
                Text(err)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
            }
        }
    }

    // MARK: - Computed helpers

    private var initials: String {
        let first = appState.userFirstName.prefix(1).uppercased()
        let last = appState.userLastName.prefix(1).uppercased()
        if first.isEmpty && last.isEmpty { return "F" }
        return "\(first)\(last)"
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    private var overviewHeadline: String {
        if appState.hasResults {
            let biz = appState.businessName.isEmpty ? "Your Business" : appState.businessName
            return "Analysis complete for \(biz)"
        } else if appState.sessionId != nil {
            return "Analysis in progress…"
        } else {
            return "Ready when you are"
        }
    }

    private var overviewSubtitle: String {
        if let summary = appState.results?.plainEnglishSummary, !summary.isEmpty {
            return summary
        }
        if appState.hasResults {
            let count = appState.results?.coverageOptions.count ?? 0
            let premium = appState.totalEstimatedPremium
            if premium.lowerBound > 0 {
                let fmt = NumberFormatter()
                fmt.numberStyle = .currency
                fmt.maximumFractionDigits = 0
                let lo = fmt.string(from: NSNumber(value: premium.lowerBound)) ?? ""
                let hi = fmt.string(from: NSNumber(value: premium.upperBound)) ?? ""
                return "\(count) coverage\(count == 1 ? "" : "s") mapped • \(lo)–\(hi)/yr estimated"
            }
            return "\(count) coverage option\(count == 1 ? "" : "s") mapped and ready to review."
        }
        if appState.sessionId != nil {
            return "Your AI agents are working. Results will appear here when ready."
        }
        return "Start an analysis below to map your coverage, assess risk, and generate a submission packet."
    }

    private struct CardConfig {
        let icon: String
        let gradient: [Color]
        let summary: String
        let statusLabel: String
        let statusColor: Color
        let isReady: Bool
    }

    private func cardConfig(for section: FaroSection) -> CardConfig {
        switch section {
        case .coverage:
            let ready = appState.results != nil
            let count = appState.results?.coverageOptions.count ?? 0
            return CardConfig(
                icon: "shield.checkered",
                gradient: [FaroPalette.purpleDeep, FaroPalette.purple],
                summary: ready
                    ? "\(count) coverage option\(count == 1 ? "" : "s") mapped for your business."
                    : "Your coverage map will appear after running an analysis.",
                statusLabel: ready ? "Ready" : "Pending",
                statusColor: ready ? FaroPalette.success : FaroPalette.ink.opacity(0.4),
                isReady: ready
            )

        case .riskProfile:
            let rp = appState.results?.riskProfile
            let ready = rp != nil
            let level = rp?.riskLevel ?? ""
            let industry = rp?.industry ?? ""
            return CardConfig(
                icon: "exclamationmark.triangle.fill",
                gradient: [Color(red: 0.95, green: 0.5, blue: 0.1), Color(red: 0.9, green: 0.35, blue: 0.05)],
                summary: ready
                    ? (industry.isEmpty ? "Risk assessment complete." : "\(industry) risk profile complete.")
                    : "AI-powered risk assessment with exposures and state requirements.",
                statusLabel: ready ? (level.isEmpty ? "Ready" : level.capitalized) : "Pending",
                statusColor: ready ? riskColor(level) : FaroPalette.ink.opacity(0.4),
                isReady: ready
            )

        case .submission:
            let ready = appState.results?.submissionPacket != nil
            let biz = appState.businessName.isEmpty ? "your business" : appState.businessName
            return CardConfig(
                icon: "doc.text.fill",
                gradient: [FaroPalette.info, FaroPalette.info.opacity(0.7)],
                summary: ready
                    ? "Carrier-ready submission packet for \(biz)."
                    : "A carrier-ready submission document will be generated after your analysis.",
                statusLabel: ready ? "Ready" : "Pending",
                statusColor: ready ? FaroPalette.success : FaroPalette.ink.opacity(0.4),
                isReady: ready
            )

        default:
            return CardConfig(
                icon: "questionmark",
                gradient: [FaroPalette.ink.opacity(0.3), FaroPalette.ink.opacity(0.2)],
                summary: "",
                statusLabel: "",
                statusColor: .clear,
                isReady: false
            )
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "low":      return FaroPalette.success
        case "moderate": return FaroPalette.warning
        case "high":     return FaroPalette.danger
        default:         return FaroPalette.info
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedSection: .constant(.home))
    }
    .environmentObject(FaroAppState())
    .environmentObject(AuthManager())
}
