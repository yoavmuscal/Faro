import SwiftUI
import PhotosUI

/// `PhotosPicker`'s label builder is not main-actor-isolated; keeping this separate avoids
/// capturing `@MainActor`-isolated members of the parent settings view in that closure.
private struct ProfileAvatarPhotoPicker: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    /// Snapshot from parent `@State`; avoids referencing `@Binding` inside `PhotosPicker`'s label closure.
    let isLoadingPhoto: Bool
    let photoData: Data?
    let initials: String

    var body: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = photoData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 2) }
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                Text(initials)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .overlay { Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2) }
                    }
                }
                .frame(width: 96, height: 96)

                ZStack {
                    Circle()
                        .fill(FaroPalette.purpleDeep)
                        .frame(width: 30, height: 30)
                    Image(systemName: isLoadingPhoto ? "arrow.2.circlepath" : "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: FaroPalette.purpleDeep.opacity(0.4), radius: 6, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FaroSettingsView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    private var isIPad: Bool { hSizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                profileHero
                    .padding(.horizontal, FaroSpacing.md)

                if APIConfig.shouldShowAuth0InUI {
                    auth0Card
                        .padding(.horizontal, FaroSpacing.md)
                }

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
            .frame(maxWidth: isIPad ? 620 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .faroCanvasBackground()
        .navigationTitle("Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadProfilePhoto(from: newItem) }
        }
    }

    // MARK: - Profile Hero

    private var profileHero: some View {
        VStack(spacing: FaroSpacing.md) {
            ProfileAvatarPhotoPicker(
                selectedPhoto: $selectedPhoto,
                isLoadingPhoto: isLoadingPhoto,
                photoData: appState.userProfilePhotoData,
                initials: initials
            )

            VStack(spacing: 4) {
                Text("\(appState.userFirstName) \(appState.userLastName)")
                    .font(FaroType.title3())
                    .foregroundStyle(FaroPalette.ink)

                if !appState.userEmail.isEmpty {
                    Text(appState.userEmail)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FaroSpacing.lg)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    // MARK: - Auth0

    private var auth0Card: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Auth0", icon: "person.badge.key.fill", tint: FaroPalette.purpleDeep)

            /// Same codebase can produce different redirect URLs per developer if `PRODUCT_BUNDLE_IDENTIFIER` differs — each URL must be allow-listed in Auth0.
            if APIConfig.isAuth0Configured, let hint = APIConfig.auth0CallbackURLHint {
                VStack(alignment: .leading, spacing: 6) {
                    Text("If sign-in works for one device but not another, Auth0 must allow this app’s redirect URL (it depends on Bundle ID). Add it under Allowed Callback URLs and Allowed Logout URLs:")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(hint)
                        .font(FaroType.caption(.medium))
                        .foregroundStyle(FaroPalette.ink.opacity(0.75))
                        .textSelection(.enabled)
                }
            }

            if APIConfig.auth0MissingClientIdOnly {
                Text("AUTH0_CLIENT_ID in Info.plist is empty. Add your Auth0 Native app Client ID or sign-in cannot start.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Auth0 → Applications → your app: copy Client ID. Allowed Callback and Logout URLs must include the redirect for this bundle. After Client ID is set, the exact URL appears in this card; the pattern is {bundleId}.auth0://domain/ios/{bundleId}/callback")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            } else if authManager.isLoggedIn {
                HStack(spacing: FaroSpacing.sm) {
                    Label("Signed in", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(FaroPalette.success)
                    Spacer()
                    Button("Sign out") {
                        Task {
                            await authManager.logout()
                            appState.signOut()
                        }
                    }
                    .font(FaroType.subheadline(.medium))
                    .foregroundStyle(FaroPalette.danger)
                }
            } else {
                Button {
                    Task { await authManager.login() }
                } label: {
                    Label("Sign in with Auth0", systemImage: "person.badge.key.fill")
                        .font(FaroType.headline())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.faroGradient)

                Text(APIConfig.isAuth0Required
                     ? "Required when the API enforces Auth0 (same AUTH0_DOMAIN and AUTH0_AUDIENCE as backend .env)."
                     : "Optional: sign in if your Faro API expects an Auth0 token.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
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

    // MARK: - Analysis

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Current Analysis", icon: "chart.bar.xaxis", tint: FaroPalette.purpleDeep)

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
                            .frame(width: 7, height: 7)
                        Text(appState.hasResults ? "Complete" : "In Progress")
                            .font(FaroType.caption(.semibold))
                            .foregroundStyle(appState.hasResults ? FaroPalette.success : FaroPalette.warning)
                    }
                    .faroPillTag(
                        color: appState.hasResults ? FaroPalette.success : FaroPalette.warning,
                        intensity: 0.1
                    )
                }
            } else {
                HStack(spacing: FaroSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(FaroPalette.purpleDeep.opacity(0.7))
                    Text("No analysis yet — start one from the Home tab.")
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
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.8))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        HStack(spacing: FaroSpacing.md) {
            // App icon or fallback
            ZStack {
                if let uiIcon = UIImage(named: "AppIcon") {
                    Image(uiImage: uiIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(FaroPalette.glassStroke.opacity(0.4), lineWidth: 0.5)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FaroPalette.purpleDeep.gradient)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "shield.checkered")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Faro")
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)
                Text("AI Insurance Agent")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
            }

            Spacer()

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.35))
                .faroPillTag(color: FaroPalette.ink, intensity: 0.05)
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

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await authManager.logout()
                appState.signOut()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body.weight(.medium))
                Text("Sign Out")
                    .font(FaroType.headline())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.faroDangerPill)
    }

    // MARK: - Helpers

    private var initials: String {
        let first = appState.userFirstName.prefix(1).uppercased()
        let last = appState.userLastName.prefix(1).uppercased()
        if first.isEmpty && last.isEmpty { return "?" }
        return "\(first)\(last)"
    }

    @MainActor
    private func loadProfilePhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return }
        let targetSize = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        if let compressed = resized.jpegData(compressionQuality: 0.82) {
            appState.userProfilePhotoData = compressed
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        FaroSettingsView()
    }
    .environmentObject(FaroAppState())
    .environmentObject(AuthManager())
}
