import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum FaroSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case coverage
    case riskProfile
    case submission
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:       return "Home"
        case .coverage:   return "Coverage"
        case .riskProfile: return "Risk Profile"
        case .submission: return "Submission"
        case .profile:    return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home:       return "house.fill"
        case .coverage:   return "shield.checkered"
        case .riskProfile: return "exclamationmark.triangle.fill"
        case .submission: return "doc.text.fill"
        case .profile:    return "person.crop.circle.fill"
        }
    }
}

struct FaroRootView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var section: FaroSection = .home

    var body: some View {
        Group {
            if appState.shouldShowMainApp(
                isAuth0Enabled: APIConfig.shouldShowAuth0InUI,
                isAuth0LoggedIn: authManager.isLoggedIn
            ) {
                mainContent
            } else if APIConfig.shouldShowAuth0InUI && !authManager.isLoggedIn && appState.hasSubmittedNameBeforeAuth0 {
                Auth0GateView()
            } else {
                WelcomeView()
                    .id(appState.onboardingFlowResetCount)
            }
        }
        .onAppear {
            syncSectionFromAppState(appState.selectedSectionRawValue)
        }
        .onChange(of: appState.selectedSectionRawValue) { _, newValue in
            syncSectionFromAppState(newValue)
        }
        .onChange(of: section) { _, newValue in
            if appState.selectedSectionRawValue != newValue.rawValue {
                appState.selectedSectionRawValue = newValue.rawValue
            }
        }
        .onChange(of: authManager.isLoggedIn) { _, _ in
            tryCompleteAuth0Flow()
        }
        .onChange(of: appState.hasSubmittedNameBeforeAuth0) { _, _ in
            tryCompleteAuth0Flow()
        }
        .task {
            await authManager.refreshLoginState()
            tryCompleteAuth0Flow()
        }
    }

    /// Finishes onboarding when the user already entered their name and has a valid Auth0 session (e.g. returning user).
    private func tryCompleteAuth0Flow() {
        guard APIConfig.shouldShowAuth0InUI else { return }
        guard appState.hasSubmittedNameBeforeAuth0, authManager.isLoggedIn else { return }
        appState.completeSignInAfterAuth0()
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $section) {
            NavigationStack {
                HomeView(selectedSection: $section)
            }
            .tabItem { Label(FaroSection.home.title, systemImage: FaroSection.home.systemImage) }
            .tag(FaroSection.home)

            NavigationStack {
                coverageRoot
            }
            .tabItem { Label(FaroSection.coverage.title, systemImage: FaroSection.coverage.systemImage) }
            .tag(FaroSection.coverage)

            NavigationStack {
                riskProfileRoot
            }
            .tabItem { Label(FaroSection.riskProfile.title, systemImage: FaroSection.riskProfile.systemImage) }
            .tag(FaroSection.riskProfile)

            NavigationStack {
                submissionRoot
            }
            .tabItem { Label(FaroSection.submission.title, systemImage: FaroSection.submission.systemImage) }
            .tag(FaroSection.submission)

            NavigationStack {
                FaroSettingsView()
            }
            .tabItem { Label(FaroSection.profile.title, systemImage: FaroSection.profile.systemImage) }
            .tag(FaroSection.profile)
        }
        .tint(FaroPalette.purpleDeep)
    }

    // MARK: - Section Roots

    @ViewBuilder
    private var coverageRoot: some View {
        if let results = appState.results, let sid = appState.sessionId {
            CoverageDashboardView(results: results, sessionId: sid, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No coverage analysis yet",
                message: "Run an analysis from the Home tab to see your coverage recommendations, charts, and premium estimates.",
                icon: "shield.lefthalf.filled"
            ) { section = .home }
        }
    }

    @ViewBuilder
    private var riskProfileRoot: some View {
        if let rp = appState.results?.riskProfile {
            RiskProfileView(riskProfile: rp, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No risk profile yet",
                message: "After analyzing your business, the AI risk assessment with exposures, state requirements, and risk level will appear here.",
                icon: "exclamationmark.triangle"
            ) { section = .home }
        }
    }

    @ViewBuilder
    private var submissionRoot: some View {
        if let packet = appState.results?.submissionPacket {
            SubmissionPacketView(packet: packet, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No submission packet yet",
                message: "The carrier-ready submission document will be generated after your analysis completes.",
                icon: "doc.text"
            ) { section = .home }
        }
    }
}

private extension FaroRootView {
    func syncSectionFromAppState(_ rawValue: String) {
        // Migrate legacy raw values (analyze → home, settings → profile)
        let mapped: String
        switch rawValue {
        case "analyze": mapped = "home"
        case "settings": mapped = "profile"
        default: mapped = rawValue
        }
        guard let target = FaroSection(rawValue: mapped), target != section else { return }
        section = target
    }
}

// MARK: - Auth0 gate

/// Step 2 of Auth0 flow: after the user entered their name on ``WelcomeView``.
struct Auth0GateView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var appeared = false

    var body: some View {
        ZStack {
            auth0GateBackdrop

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: FaroSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: FaroPalette.purpleDeep.opacity(0.4), radius: 24, y: 8)

                        if let uiIcon = UIImage(named: "AppIcon") {
                            Image(uiImage: uiIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: FaroSpacing.xs) {
                        Text("Sign in with Auth0")
                            .font(FaroType.largeTitle())
                            .foregroundStyle(FaroPalette.ink)

                        Text(auth0GateSubtitle)
                            .font(FaroType.subheadline())
                            .foregroundStyle(FaroPalette.ink.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: FaroSpacing.xl + FaroSpacing.md)

                VStack(spacing: FaroSpacing.md) {
                    if APIConfig.auth0MissingClientIdOnly {
                        Text("AUTH0_CLIENT_ID is missing in Info.plist. Add your Auth0 Native application Client ID to enable sign-in.")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.danger)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Button {
                            Task { await authManager.login() }
                        } label: {
                            HStack(spacing: 8) {
                                if authManager.isLoggingIn {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.key.fill")
                                        .font(.headline)
                                }
                                Text(authManager.isLoggingIn ? "Signing in…" : "Sign in with Auth0")
                                    .font(FaroType.headline())
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(.faroGradient)
                        .disabled(authManager.isLoggingIn || APIConfig.auth0MissingClientIdOnly)
                        .frame(maxWidth: 380)

                        if let err = authManager.lastError, !err.isEmpty {
                            Text(err)
                                .font(FaroType.caption())
                                .foregroundStyle(FaroPalette.danger)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: 380)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, FaroSpacing.lg)
        }
        .faroCanvasBackground()
        .task {
            await authManager.refreshLoginState()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var auth0GateSubtitle: String {
        let first = appState.userFirstName.trimmingCharacters(in: .whitespaces)
        if !first.isEmpty {
            return "Thanks, \(first). Use your account to finish and open Faro."
        }
        return "Use your account to finish and open Faro."
    }

    private var auth0GateBackdrop: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.7
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FaroPalette.purple.opacity(0.3),
                                FaroPalette.purpleDeep.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: size * 0.05,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)
                    .blur(radius: 60)
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Welcome / Sign-In

struct WelcomeView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var appeared = false
    /// Ensures we only clear stale profile / field state once per visit to this screen.
    @State private var didPrepareFreshNameFields = false
    @FocusState private var focusedField: WelcomeField?

    private enum WelcomeField: Hashable {
        case first, last, email
    }

    private var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: FaroSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: FaroPalette.purpleDeep.opacity(0.4), radius: 24, y: 8)

                        if let uiIcon = UIImage(named: "AppIcon") {
                            Image(uiImage: uiIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: FaroSpacing.xs) {
                        Text("Welcome to Faro")
                            .font(FaroType.largeTitle())
                            .foregroundStyle(FaroPalette.ink)

                        Text("Your AI-powered insurance companion")
                            .font(FaroType.subheadline())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))

                        Text(welcomeCaption)
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, FaroSpacing.xs)
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: FaroSpacing.xl + FaroSpacing.md)

                VStack(spacing: FaroSpacing.md) {
                    welcomeField(
                        "First name (required)",
                        text: $firstName,
                        focused: .first,
                        textContentType: nil
                    ) {
                        focusedField = .last
                    }
                    welcomeField(
                        "Last name (required)",
                        text: $lastName,
                        focused: .last,
                        textContentType: nil
                    ) {
                        focusedField = .email
                    }
                    welcomeField(
                        "Email (optional)",
                        text: $email,
                        focused: .email,
                        textContentType: .emailAddress
                    ) {
                        if canContinue { submitWelcome() }
                    }
                }
                .frame(maxWidth: 380)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)

                Spacer()

                Button(action: submitWelcome) {
                    HStack(spacing: 8) {
                        Text(APIConfig.shouldShowAuth0InUI ? "Continue" : "Get Started")
                            .font(FaroType.headline())
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.faroGradient)
                .disabled(!canContinue)
                .animation(.easeInOut(duration: 0.25), value: canContinue)
                .frame(maxWidth: 380)
                .padding(.bottom, FaroSpacing.lg)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, FaroSpacing.lg)
        }
        .faroCanvasBackground()
        .onAppear {
            prepareFreshNameEntryIfNeeded()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .first
            }
        }
    }

    // MARK: - Helpers

    /// Drop stale UserDefaults and clear fields before the user types their name (Auth0 flow, step 1).
    private func prepareFreshNameEntryIfNeeded() {
        guard !didPrepareFreshNameFields else { return }
        if APIConfig.shouldShowAuth0InUI, !appState.hasSubmittedNameBeforeAuth0 {
            appState.resetProfileForManualNameEntryIfNeeded()
            firstName = ""
            lastName = ""
            email = ""
        }
        didPrepareFreshNameFields = true
    }

    private var welcomeCaption: String {
        if APIConfig.shouldShowAuth0InUI {
            return "Step 1 of 2 — enter your name. You’ll sign in with Auth0 next."
        }
        return "Enter your first and last name to continue."
    }

    private func welcomeField(
        _ placeholder: String,
        text: Binding<String>,
        focused: WelcomeField,
        textContentType: UITextContentType?,
        onSubmit action: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: text)
            .font(FaroType.body())
            .focused($focusedField, equals: focused)
            .onSubmit(action)
            #if os(iOS)
            .textContentType(textContentType)
            .keyboardType(focused == .email ? .emailAddress : .default)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(focused != .email)
            #endif
            .padding(.horizontal, FaroSpacing.md)
            .frame(height: 52)
            .faroGlassCapsule()
    }

    private var backdrop: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.7
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FaroPalette.purple.opacity(0.3),
                                FaroPalette.purpleDeep.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: size * 0.05,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)
                    .blur(radius: 60)
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func submitWelcome() {
        guard canContinue else { return }
        let f = firstName.trimmingCharacters(in: .whitespaces)
        let l = lastName.trimmingCharacters(in: .whitespaces)
        let e = email.trimmingCharacters(in: .whitespaces)
        if APIConfig.shouldShowAuth0InUI {
            appState.saveNameBeforeAuth0(firstName: f, lastName: l, email: e)
        } else {
            appState.signIn(firstName: f, lastName: l, email: e)
        }
    }
}

// MARK: - Placeholder

struct AnalysisPlaceholderView: View {
    let title: String
    let message: String
    let icon: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
        } actions: {
            Button("Go to Home", action: action)
                .buttonStyle(.borderedProminent)
                .tint(FaroPalette.purpleDeep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .faroCanvasBackground()
    }
}

#Preview {
    FaroRootView()
        .environmentObject(FaroAppState())
        .environmentObject(AuthManager())
}
