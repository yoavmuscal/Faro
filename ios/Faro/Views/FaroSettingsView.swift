import SwiftUI

struct FaroSettingsView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Form {
            auth0Section
            profileSection
            analysisSection
            aboutSection
            legalSection
            signOutSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .faroCanvasBackground()
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Auth0

    private var auth0Section: some View {
        Group {
            if authManager.isAuthConfigured {
                Section("Auth0") {
                    if authManager.isLoggedIn {
                        Label("Signed in", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(FaroPalette.success)
                        Button("Sign out of Auth0") {
                            Task { await authManager.logout() }
                        }
                        .font(FaroType.subheadline(.medium))
                    } else {
                        Button {
                            Task { await authManager.login() }
                        } label: {
                            Label("Sign in with Auth0", systemImage: "person.badge.key.fill")
                                .font(FaroType.headline())
                        }
                        .tint(FaroPalette.purpleDeep)

                        Text("Required when the API enforces Auth0 (see backend AUTH0_DOMAIN and AUTH0_AUDIENCE).")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    }

                    if let err = authManager.lastError, !err.isEmpty {
                        Text(err)
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.danger)
                    }
                }
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
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
                        .frame(width: 52, height: 52)

                    Text(initials)
                        .font(FaroType.title3(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, \(appState.userDisplayName)!")
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.ink)

                    if !appState.userEmail.isEmpty {
                        Text(appState.userEmail)
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    } else {
                        Text("\(appState.userFirstName) \(appState.userLastName)")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    }
                }

                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Current Analysis

    private var analysisSection: some View {
        Section("Your Analysis") {
            if let _ = appState.sessionId {
                LabeledContent("Business") {
                    Text(appState.businessName.isEmpty ? "—" : appState.businessName)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.6))
                }

                if !appState.contactFirstName.isEmpty {
                    LabeledContent("Contact") {
                        Text("\(appState.contactFirstName) \(appState.contactLastName)")
                            .font(FaroType.subheadline())
                            .foregroundStyle(FaroPalette.ink.opacity(0.6))
                    }
                }

                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.hasResults ? FaroPalette.success : FaroPalette.warning)
                            .frame(width: 8, height: 8)
                        Text(appState.hasResults ? "Complete" : "In Progress")
                            .font(FaroType.subheadline())
                            .foregroundStyle(FaroPalette.ink.opacity(0.6))
                    }
                }
            } else {
                HStack(spacing: FaroSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(FaroPalette.purpleDeep.opacity(0.6))
                    Text("No analysis yet — head to Analyze to get started.")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack(spacing: FaroSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FaroRadius.sm, style: .continuous)
                        .fill(FaroPalette.purpleDeep.gradient)
                        .frame(width: 40, height: 40)
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
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section("Legal") {
            Label("Privacy policy will appear here in a future update.", systemImage: "hand.raised.fill")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.6))
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    await authManager.logout()
                    appState.signOut()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(FaroType.headline())
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

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
