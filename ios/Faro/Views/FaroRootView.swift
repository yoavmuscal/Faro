import SwiftUI

enum FaroSection: String, CaseIterable, Identifiable, Hashable {
    case analyze
    case coverage
    case riskProfile
    case submission
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analyze: return "Analyze"
        case .coverage: return "Coverage"
        case .riskProfile: return "Risk Profile"
        case .submission: return "Submission"
        case .settings: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .analyze: return "sparkles"
        case .coverage: return "shield.checkered"
        case .riskProfile: return "exclamationmark.triangle.fill"
        case .submission: return "doc.text.fill"
        case .settings: return "ellipsis"
        }
    }

}

struct FaroRootView: View {
    @EnvironmentObject private var appState: FaroAppState
    @State private var section: FaroSection = .analyze

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
                IntakeChoiceView()
            }
            .tabItem { Label(FaroSection.analyze.title, systemImage: FaroSection.analyze.systemImage) }
            .tag(FaroSection.analyze)

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
            .tabItem { Label(FaroSection.settings.title, systemImage: FaroSection.settings.systemImage) }
            .tag(FaroSection.settings)
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
                message: "Run an analysis from the Analyze tab to see your coverage recommendations, charts, and premium estimates.",
                icon: "shield.lefthalf.filled"
            ) { section = .analyze }
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
            ) { section = .analyze }
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
            ) { section = .analyze }
        }
    }

}

private extension FaroRootView {
    func syncSectionFromAppState(_ rawValue: String) {
        guard let target = FaroSection(rawValue: rawValue), target != section else { return }
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

    private var welcomePrimaryButtonTitle: String {
        if authManager.isLoggingIn && APIConfig.isAuth0Configured {
            return "Signing in…"
        }
        return "Get Started"
    }

    var body: some View {
        NavigationStack {
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

                        Image(systemName: "shield.checkered")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white)
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
                        if authManager.isLoggingIn && APIConfig.isAuth0Configured {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(welcomePrimaryButtonTitle)
                            .font(FaroType.headline())
                        if !(authManager.isLoggingIn && APIConfig.isAuth0Configured) {
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(.white)
                    .background {
                        RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                            .fill(
                                canContinue
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                : AnyShapeStyle(FaroPalette.ink.opacity(0.08))
                            )
                    }
                    .overlay {
                        if canContinue {
                            RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                    }
                    .shadow(color: canContinue ? FaroPalette.purpleDeep.opacity(0.35) : .clear, radius: 16, y: 6)
                }
                .disabled(!canContinue || (APIConfig.isAuth0Configured && authManager.isLoggingIn))
                .animation(.easeInOut(duration: 0.25), value: canContinue)
                .frame(maxWidth: 380)
                .padding(.bottom, FaroSpacing.lg)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)

            }
            .padding(.horizontal, FaroSpacing.lg)
            }
            .faroCanvasBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    FaroAuthToolbarTray()
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    FaroAuthToolbarTray()
                }
                #endif
            }
            .task {
                await authManager.refreshLoginState()
            }
            .onChange(of: authManager.isLoggedIn) { _, loggedIn in
                guard loggedIn else { return }
                finishWelcomeAfterAuth0()
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
            .background {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .fill(FaroPalette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .strokeBorder(
                        focusedField == focused
                        ? FaroPalette.purpleDeep.opacity(0.5)
                        : FaroPalette.glassStroke,
                        lineWidth: focusedField == focused ? 1.5 : 1
                    )
            }
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
        if !APIConfig.isAuth0Configured {
            appState.signIn(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return
        }
        Task {
            if !authManager.isLoggedIn {
                await authManager.login()
            }
            await MainActor.run {
                finishWelcomeAfterAuth0()
            }
        }
    }

    /// Enter the app once Auth0 is ready (toolbar **Log in** or **Get Started**). Safe to call more than once.
    private func finishWelcomeAfterAuth0() {
        guard authManager.isLoggedIn, !appState.isSignedIn else { return }
        if canContinue {
            appState.signIn(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            let p = authManager.welcomeProfileFromSession()
            appState.signIn(firstName: p.firstName, lastName: p.lastName, email: p.email)
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
            Button("Go to Analyze", action: action)
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
