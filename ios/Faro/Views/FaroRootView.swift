import SwiftUI

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
    @State private var section: FaroSection = .home

    var body: some View {
        Group {
            if appState.isSignedIn {
                mainContent
            } else {
                WelcomeView()
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

// MARK: - Welcome / Sign-In

struct WelcomeView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var appeared = false
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
                    }
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: FaroSpacing.xl + FaroSpacing.md)

                VStack(spacing: FaroSpacing.md) {
                    welcomeField("First name", text: $firstName, focused: .first) {
                        focusedField = .last
                    }
                    welcomeField("Last name", text: $lastName, focused: .last) {
                        focusedField = .email
                    }
                    welcomeField("Email (optional)", text: $email, focused: .email) {
                        if canContinue { signIn() }
                    }
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    #endif
                }
                .frame(maxWidth: 380)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)

                Spacer()

                Button(action: signIn) {
                    HStack(spacing: 8) {
                        Text("Get Started")
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

                if APIConfig.shouldShowAuth0InUI {
                    VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                        if APIConfig.auth0MissingClientIdOnly {
                            Text("Auth0 Client ID is missing. Set AUTH0_CLIENT_ID in Info.plist (see Profile → Auth0).")
                                .font(FaroType.caption())
                                .foregroundStyle(FaroPalette.danger)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if authManager.isLoggedIn {
                            Label("API sign-in ready", systemImage: "checkmark.seal.fill")
                                .font(FaroType.subheadline(.medium))
                                .foregroundStyle(FaroPalette.success)
                        } else {
                            Text("This environment uses Auth0 for the Faro API. Sign in so analysis requests succeed.")
                                .font(FaroType.caption())
                                .foregroundStyle(FaroPalette.ink.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                Task { await authManager.login() }
                            } label: {
                                Label("Sign in with Auth0", systemImage: "person.badge.key.fill")
                                    .font(FaroType.headline())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(.faroGradient)
                            .tint(FaroPalette.purpleDeep)
                            if let err = authManager.lastError, !err.isEmpty {
                                Text(err)
                                    .font(FaroType.caption())
                                    .foregroundStyle(FaroPalette.danger)
                            }
                        }
                    }
                    .frame(maxWidth: 380)
                    .padding(.bottom, FaroSpacing.xl)
                    .offset(y: appeared ? 0 : 40)
                    .opacity(appeared ? 1 : 0)
                }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .first
            }
        }
    }

    // MARK: - Helpers

    private func welcomeField(
        _ placeholder: String,
        text: Binding<String>,
        focused: WelcomeField,
        onSubmit action: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: text)
            .font(FaroType.body())
            .focused($focusedField, equals: focused)
            .onSubmit(action)
            #if os(iOS)
            .textInputAutocapitalization(.words)
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

    private func signIn() {
        guard canContinue else { return }
        appState.signIn(firstName: firstName, lastName: lastName, email: email)
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
