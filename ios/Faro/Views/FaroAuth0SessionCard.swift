import SwiftUI

// MARK: - Settings only (Analyze / Welcome use the toolbar)

/// Sign in / out and plist hints. Keep Auth0 UI in one place.
struct FaroAuthCard: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if APIConfig.shouldShowAuth0InUI {
                card
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Account", icon: "person.crop.circle.fill", tint: FaroPalette.purpleDeep)

            if APIConfig.auth0MissingClientIdOnly {
                Text("Set AUTH0_CLIENT_ID in Info.plist (Native app Client ID from Auth0).")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.65))
                if let hint = APIConfig.auth0CallbackURLHint {
                    Text(hint)
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                        .textSelection(.enabled)
                }
            } else if authManager.isLoggedIn {
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(FaroPalette.success)
                Button("Sign out") {
                    Task { await authManager.logout() }
                }
                .font(FaroType.subheadline(.medium))
                .foregroundStyle(FaroPalette.purpleDeep)
            } else {
                Button {
                    Task { await authManager.login() }
                } label: {
                    HStack {
                        if authManager.isLoggingIn {
                            ProgressView().tint(.white)
                        }
                        Text(authManager.isLoggingIn ? "Signing in…" : "Sign in")
                            .font(FaroType.headline())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(FaroPalette.purpleDeep)
                .disabled(authManager.isLoggingIn)
            }

            if let err = authManager.lastError, !err.isEmpty {
                Text(err)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
            }
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

// MARK: - Toolbar (Welcome + Analyze)

struct FaroAuthToolbarTray: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if APIConfig.isAuth0Configured {
                if authManager.isLoggedIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FaroPalette.success)
                        .accessibilityLabel("Signed in")
                } else {
                    Button {
                        Task { await authManager.login() }
                    } label: {
                        if authManager.isLoggingIn {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Log in")
                                .font(FaroType.subheadline(.semibold))
                        }
                    }
                    .disabled(authManager.isLoggingIn)
                }
            } else if APIConfig.auth0MissingClientIdOnly {
                Button("Setup") {
                    appState.openSection("settings")
                }
                .font(FaroType.subheadline(.semibold))
            }
        }
    }
}
