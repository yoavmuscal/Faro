import SwiftUI

/// Entry point for the Analyze tab: structured form, voice intake, or quick demo.
struct IntakeChoiceView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var isDemoLoading = false
    @State private var demoSessionId: String?
    @State private var demoError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                VStack(spacing: FaroSpacing.sm) {
                    Text("Hey \(appState.userDisplayName), ready to go?")
                        .font(FaroType.title2())
                        .foregroundStyle(FaroPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Share a few details about your business so we can map coverage, premiums, and submission-ready documents.")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if authManager.isAuthConfigured && !authManager.isLoggedIn {
                    VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                        Label("Sign in to continue", systemImage: "person.badge.key.fill")
                            .font(FaroType.headline())
                            .foregroundStyle(FaroPalette.ink)
                        Text("Your Faro API expects an Auth0 access token. Open Settings, sign in with Auth0, then run an analysis.")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(FaroSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .faroGlassCard(cornerRadius: FaroRadius.lg, material: .regularMaterial)
                }

                VStack(spacing: FaroSpacing.md) {
                    NavigationLink {
                        OnboardingView()
                    } label: {
                        choiceRow(
                            title: "Guided questionnaire",
                            subtitle: "Step-by-step — best when you want to type at your own pace.",
                            systemImage: "list.bullet.rectangle"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        VoiceIntakeView()
                    } label: {
                        choiceRow(
                            title: "Conversational intake",
                            subtitle: "Same information through the voice pipeline when your server supports it.",
                            systemImage: "waveform"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        OnboardingView(isDemo: true)
                    } label: {
                        demoBadgeRow
                    }
                    .buttonStyle(.plain)
                }

                if let error = demoError {
                    Text(error)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.danger)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Analyze")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: Binding(
            get: { demoSessionId != nil },
            set: { if !$0 { demoSessionId = nil } }
        )) {
            if let sid = demoSessionId {
                AgentTrackerView(sessionId: sid, businessName: "Sunny Days Daycare")
            }
        }
    }

    private func choiceRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: FaroSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(FaroPalette.purpleDeep)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                Text(title)
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)
                Text(subtitle)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.35))
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.md)
    }

    private var demoBadgeRow: some View {
        HStack(alignment: .top, spacing: FaroSpacing.md) {
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(FaroPalette.purple)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                HStack(spacing: 6) {
                    Text("Quick demo")
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.ink)

                    Text("PRE-FILLED")
                        .font(FaroType.caption2(.bold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule(style: .continuous)
                                .fill(FaroPalette.purpleDeep.opacity(0.12))
                        }
                }
                Text("Skip the typing — see a full analysis using sample daycare business data.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.35))
        }
        .padding(FaroSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .fill(FaroPalette.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [FaroPalette.purpleDeep.opacity(0.3), FaroPalette.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

#Preview {
    NavigationStack {
        IntakeChoiceView()
    }
    .environmentObject(FaroAppState())
    .environmentObject(AuthManager())
}
