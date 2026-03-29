import SwiftUI

struct FaroSettingsView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                if APIConfig.shouldShowAuth0InUI {
                    FaroAuthCard()
                        .padding(.horizontal, FaroSpacing.md)
                }

                profileCard
                    .padding(.horizontal, FaroSpacing.md)

                analysisCard
                    .padding(.horizontal, FaroSpacing.md)

                aboutCard
                    .padding(.horizontal, FaroSpacing.md)

                legalCard
                    .padding(.horizontal, FaroSpacing.md)

                signOutButton
                    .padding(.horizontal, FaroSpacing.md)

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("More")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: FaroSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(initials)
                    .font(FaroType.title2(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Hi, \(appState.userDisplayName)!")
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)

                if !appState.userEmail.isEmpty {
                    Text(appState.userEmail)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                } else {
                    Text("\(appState.userFirstName) \(appState.userLastName)")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    // MARK: - Analysis

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Your Analysis", icon: "sparkles", tint: FaroPalette.purpleDeep)

            if appState.sessionId != nil {
                labeledRow("Business", value: appState.businessName.isEmpty ? "—" : appState.businessName)

                if !appState.contactFirstName.isEmpty {
                    labeledRow("Contact", value: "\(appState.contactFirstName) \(appState.contactLastName)")
                }

                HStack(spacing: 8) {
                    Text("Status")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.hasResults ? FaroPalette.success : FaroPalette.warning)
                            .frame(width: 8, height: 8)
                        Text(appState.hasResults ? "Complete" : "In Progress")
                            .font(FaroType.subheadline(.medium))
                            .foregroundStyle(FaroPalette.ink.opacity(0.75))
                    }
                }
            } else {
                HStack(spacing: FaroSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(FaroPalette.purpleDeep.opacity(0.7))
                    Text("No analysis yet — head to Analyze to get started.")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    private func labeledRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
            Spacer(minLength: FaroSpacing.sm)
            Text(value)
                .font(FaroType.subheadline(.medium))
                .foregroundStyle(FaroPalette.ink.opacity(0.8))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        HStack(spacing: FaroSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .fill(FaroPalette.purpleDeep.gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "shield.checkered")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Faro")
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)
                Text("AI Insurance Agent")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
            }
            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.4))
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    // MARK: - Legal

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            SectionHeader(title: "Legal", icon: "hand.raised.fill", tint: FaroPalette.info)
            Text("Privacy policy will appear here in a future update.")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await authManager.logout()
                appState.signOut()
            }
        } label: {
            Text("Sign Out")
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                        .fill(FaroPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                        .strokeBorder(FaroPalette.danger.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var initials: String {
        let first = appState.userFirstName.prefix(1).uppercased()
        let last = appState.userLastName.prefix(1).uppercased()
        if first.isEmpty && last.isEmpty { return "?" }
        return "\(first)\(last)"
    }
}

#Preview {
    NavigationStack {
        FaroSettingsView()
    }
    .environmentObject(FaroAppState())
    .environmentObject(AuthManager())
}
