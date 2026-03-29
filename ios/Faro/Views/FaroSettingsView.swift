import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

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
                            .frame(width: 96, height: 96)
                            .clipped()
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
                            .frame(width: 96, height: 96)
                    }
                }

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
            .fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(.plain)
    }
}

struct FaroSettingsView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @Binding var selectedSection: FaroSection
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    @AppStorage(APIConfig.demoModeUserDefaultsKey) private var offlineDemoMode = false
    @State private var localBackendDraft = ""
    @State private var displayedHttpBaseURL = ""

    private var isIPad: Bool { hSizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                greetingLine

                profileHero

                unifiedStatusCard

                offlineDemoCard

                getStartedCard

                if APIConfig.showsDeviceBackendURLOptions {
                    localBackendServerCard
                }

                aboutCard

                legalCard

                signOutButton

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
            .padding(.horizontal, FaroSpacing.dashboardPageHorizontal(isWideLayout: isIPad))
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
        .onChange(of: offlineDemoMode) { _, _ in
            NotificationCenter.default.post(name: .faroDemoModeDidChange, object: nil)
        }
        .onAppear {
            syncLocalBackendURLFields()
        }
        .onReceive(NotificationCenter.default.publisher(for: .faroHTTPBaseURLDidChange)) { _ in
            syncLocalBackendURLFields()
        }
    }

    private func syncLocalBackendURLFields() {
        displayedHttpBaseURL = APIConfig.httpBaseURL
        localBackendDraft = APIConfig.storedHttpBaseURLOverride ?? ""
    }

    private func saveLocalBackendOverride() {
        if localBackendDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            APIConfig.setHttpBaseURLOverride(nil)
        } else {
            APIConfig.setHttpBaseURLOverride(localBackendDraft)
        }
        syncLocalBackendURLFields()
    }

    // MARK: - Offline demo (device / no backend)

    private var offlineDemoCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            SectionHeader(title: "Offline demo", icon: "iphone", tint: FaroPalette.info)
                .padding(.horizontal, FaroSpacing.xs)

            Toggle(isOn: $offlineDemoMode) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use on-device sample analysis")
                        .font(FaroType.subheadline(.semibold))
                        .foregroundStyle(FaroPalette.ink)
                    Text("Skips your Faro API and Gemini — full coverage, risk, and submission UI with the data you enter (or Quick Demo). For real iPhone builds without backend env files.")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(FaroPalette.purpleDeep)
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    // MARK: - Greeting

    private var greetingLine: some View {
        HStack {
            Text(timeGreeting)
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
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

    // MARK: - Unified status (overview + session detail)

    private var unifiedStatusCard: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .foregroundStyle(.white.opacity(0.85))
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
                LinearGradient(
                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if appState.sessionId != nil {
                VStack(alignment: .leading, spacing: FaroSpacing.sm) {
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
                }
                .padding(FaroSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FaroPalette.surface.opacity(0.65))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.35), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var appIconBadge: some View {
        brandLogoImage(side: 22, corner: 5)
    }

    /// App mark for status strip and About — prefers `FaroAppLogo` in Assets, then `AppIcon`, then gradient shield.
    @ViewBuilder
    private func brandLogoImage(side: CGFloat, corner: CGFloat) -> some View {
        if UIImage(named: "FaroAppLogo") != nil {
            Image("FaroAppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        } else if let uiIcon = UIImage(named: "AppIcon") {
            Image(uiImage: uiIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: side, height: side)
                .overlay {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: side * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    private var appMarketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Get Started

    private var getStartedCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            SectionHeader(title: "Get Started", icon: "sparkles", tint: FaroPalette.purpleDeep)
                .padding(.horizontal, FaroSpacing.xs)

            VStack(spacing: FaroSpacing.xs) {
                NavigationLink { OnboardingView() } label: {
                    homeIntakeRow(
                        title: "Guided Questionnaire",
                        subtitle: "Step-by-step form — type at your own pace.",
                        icon: "list.bullet.rectangle",
                        iconColor: FaroPalette.purpleDeep
                    )
                }
                .buttonStyle(.faroScale)

                NavigationLink { VoiceIntakeView() } label: {
                    homeIntakeRow(
                        title: "Conversational Intake",
                        subtitle: "Talk through the details with your AI agent.",
                        icon: "waveform",
                        iconColor: FaroPalette.info
                    )
                }
                .buttonStyle(.faroScale)

                NavigationLink { OnboardingView(isDemo: true) } label: {
                    homeIntakeDemoRow
                }
                .buttonStyle(.faroScale)
            }

            if APIConfig.shouldShowAuth0InUI {
                Divider()
                    .padding(.vertical, FaroSpacing.xs)
                auth0InlineSection
            }
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    private var localBackendServerCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            SectionHeader(title: "Backend on a real device", icon: "network", tint: FaroPalette.info)
                .padding(.horizontal, FaroSpacing.xs)

            Text(
                "On a physical iPhone or iPad, “localhost” is the device—not your Mac. Run the API from the repo (`./backend/run.sh`), use the same Wi‑Fi as this device, enter your Mac’s IP with port 8000, then Save."
            )
            .font(FaroType.caption())
            .foregroundStyle(FaroPalette.ink.opacity(0.55))
            .fixedSize(horizontal: false, vertical: true)

            TextField("http://192.168.1.12:8000", text: $localBackendDraft)
                .font(FaroType.body())
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.URL)
                #endif

            HStack(spacing: FaroSpacing.sm) {
                Button {
                    saveLocalBackendOverride()
                } label: {
                    Text("Save")
                        .font(FaroType.subheadline(.semibold))
                        .frame(minWidth: 88, minHeight: 40)
                }
                .buttonStyle(.faroGradient)

                if APIConfig.storedHttpBaseURLOverride != nil {
                    Button("Clear") {
                        APIConfig.setHttpBaseURLOverride(nil)
                        localBackendDraft = ""
                        syncLocalBackendURLFields()
                    }
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.danger)
                }
            }

            Text("Using: \(displayedHttpBaseURL)")
                .font(FaroType.caption(.medium))
                .foregroundStyle(FaroPalette.ink.opacity(0.65))
                .textSelection(.enabled)
        }
        .padding(FaroSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    private func homeIntakeRow(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: FaroSpacing.sm) {
            Circle()
                .fill(iconColor.opacity(0.13))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.medium))
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.22))
        }
        .padding(.horizontal, FaroSpacing.sm)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous)
                .fill(FaroPalette.surface.opacity(0.5))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.25), lineWidth: 0.5)
        }
    }

    private var homeIntakeDemoRow: some View {
        HStack(spacing: FaroSpacing.sm) {
            Circle()
                .fill(FaroPalette.purple.opacity(0.13))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.medium))
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.22))
        }
        .padding(.horizontal, FaroSpacing.sm)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous)
                .fill(FaroPalette.surface.opacity(0.5))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.25), lineWidth: 0.5)
        }
    }

    // MARK: - Auth0 (inside Get Started)

    private var auth0InlineSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Auth0", icon: "person.badge.key.fill", tint: FaroPalette.purpleDeep)
                .padding(.horizontal, FaroSpacing.xs)

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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - About

    private var aboutCard: some View {
        HStack(alignment: .center, spacing: FaroSpacing.md) {
            brandLogoImage(side: 56, corner: 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(FaroPalette.glassStroke.opacity(0.35), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Faro")
                    .font(FaroType.title3(.bold))
                    .foregroundStyle(FaroPalette.ink)
                Text("AI Insurance Agent")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
            }

            Spacer(minLength: 8)

            Text("v\(appMarketingVersion)")
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.42))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(colorScheme == .dark ? FaroPalette.ink.opacity(0.12) : FaroPalette.ink.opacity(0.06))
                }
        }
        .padding(FaroSpacing.md + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .fill(colorScheme == .dark ? FaroPalette.surface.opacity(0.88) : Color.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(colorScheme == .dark ? 0.38 : 0.22), lineWidth: 0.5)
        }
    }

    // MARK: - Legal

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3)
                    .foregroundStyle(FaroPalette.info)
                Text("Legal")
                    .font(FaroType.title3(.bold))
                    .foregroundStyle(FaroPalette.ink)
            }

            legalSubsection(title: "Privacy") {
                Text("Faro collects information you provide during intake (typed answers, voice, or uploads) and data needed to run the app—such as device type and, if you use it, account details from sign-in. We use this to generate your analysis, operate the service, and improve the product. We do not sell your personal information.")
            }

            legalSubsection(title: "Insurance & professional advice") {
                Text("Faro is an AI assistant. It is not an insurance carrier, broker, agent, or law firm. Premium estimates, coverage summaries, and recommendations are informational only—not binding quotes, policies, or legal advice. Confirm all coverage decisions with a licensed insurance professional.")
            }

            legalSubsection(title: "AI limitations") {
                Text("Generated outputs may be incomplete, outdated, or inaccurate. You are responsible for how you use information produced by Faro.")
            }

            legalSubsection(title: "Contact") {
                Text("For privacy questions or to exercise your rights, reach out through the support channel for your Faro deployment or your organization’s administrator.")
            }
        }
        .padding(FaroSpacing.md + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .fill(colorScheme == .dark ? FaroPalette.surface.opacity(0.88) : Color.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(colorScheme == .dark ? 0.38 : 0.22), lineWidth: 0.5)
        }
    }

    private func legalSubsection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            Text(title)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink)
            content()
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
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
            return "Your AI agents are working. Results will appear when ready."
        }
        return "Use Get Started below to run an analysis, then switch tabs for Coverage, Risk Profile, or Submission."
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
        FaroSettingsView(selectedSection: .constant(.profile))
    }
    .environmentObject(FaroAppState())
    .environmentObject(AuthManager())
}
