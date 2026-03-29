import SwiftUI

@MainActor
final class FaroAppState: ObservableObject {
    private static let defaults = UserDefaults.standard

    @Published var userFirstName: String {
        didSet { Self.defaults.set(userFirstName, forKey: "faro_userFirstName") }
    }
    @Published var userLastName: String {
        didSet { Self.defaults.set(userLastName, forKey: "faro_userLastName") }
    }
    @Published var userEmail: String {
        didSet { Self.defaults.set(userEmail, forKey: "faro_userEmail") }
    }
    @Published var isOnboarded: Bool {
        didSet { Self.defaults.set(isOnboarded, forKey: "faro_isOnboarded") }
    }

    /// After Auth0-enabled flow: set to `true` only after Auth0 login succeeds (name was collected earlier).
    @Published var hasCompletedPostAuth0Profile: Bool {
        didSet { Self.defaults.set(hasCompletedPostAuth0Profile, forKey: "faro_completedPostAuth0Profile") }
    }

    /// User finished the name screen and should see Auth0 next (name-first, then sign-in).
    @Published var hasSubmittedNameBeforeAuth0: Bool {
        didSet { Self.defaults.set(hasSubmittedNameBeforeAuth0, forKey: "faro_submittedNameBeforeAuth0") }
    }

    @Published var userProfilePhotoData: Data? {
        didSet {
            if let data = userProfilePhotoData {
                Self.defaults.set(data, forKey: "faro_profilePhoto")
            } else {
                Self.defaults.removeObject(forKey: "faro_profilePhoto")
            }
        }
    }

    @Published var sessionId: String?
    @Published var businessName: String = ""
    @Published var contactFirstName: String = ""
    @Published var contactMiddleName: String = ""
    @Published var contactLastName: String = ""
    @Published var results: ResultsResponse?
    @Published var selectedSectionRawValue: String = "home"

    /// Bumps on ``signOut()`` so ``WelcomeView`` can remount with fresh `@State` (name fields empty).
    @Published private(set) var onboardingFlowResetCount: Int = 0

    var isSignedIn: Bool {
        isOnboarded && !userFirstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Main tabs: local profile is complete **and** (if Auth0 is in use) the post–sign-in name step has been completed for this account flow.
    func shouldShowMainApp(isAuth0Enabled: Bool, isAuth0LoggedIn: Bool) -> Bool {
        guard isSignedIn else { return false }
        if isAuth0Enabled {
            return isAuth0LoggedIn && hasCompletedPostAuth0Profile
        }
        return true
    }

    var userDisplayName: String {
        let first = userFirstName.trimmingCharacters(in: .whitespaces)
        if first.isEmpty { return "there" }
        return first
    }

    var contactDisplayName: String {
        let first = contactFirstName.trimmingCharacters(in: .whitespaces)
        if first.isEmpty { return userDisplayName }
        return first
    }

    var hasResults: Bool { results != nil && sessionId != nil }

    var totalEstimatedPremium: ClosedRange<Double> {
        guard let opts = results?.coverageOptions, !opts.isEmpty else { return 0...0 }
        let low = opts.reduce(0) { $0 + $1.estimatedPremiumLow }
        let high = opts.reduce(0) { $0 + $1.estimatedPremiumHigh }
        return low...high
    }

    init() {
        userFirstName = Self.defaults.string(forKey: "faro_userFirstName") ?? ""
        userLastName = Self.defaults.string(forKey: "faro_userLastName") ?? ""
        userEmail = Self.defaults.string(forKey: "faro_userEmail") ?? ""
        isOnboarded = Self.defaults.bool(forKey: "faro_isOnboarded")
        hasCompletedPostAuth0Profile = Self.defaults.bool(forKey: "faro_completedPostAuth0Profile")
        hasSubmittedNameBeforeAuth0 = Self.defaults.bool(forKey: "faro_submittedNameBeforeAuth0")
        userProfilePhotoData = Self.defaults.data(forKey: "faro_profilePhoto")
    }

    /// Full sign-in without Auth0 (or legacy). Not used when `shouldShowAuth0InUI` — use ``saveNameBeforeAuth0`` + Auth0 + ``completeSignInAfterAuth0()`` instead.
    func signIn(firstName: String, lastName: String, email: String) {
        userFirstName = firstName
        userLastName = lastName
        userEmail = email
        isOnboarded = true
    }

    /// Step 1 of Auth0 flow: store the name the user typed, then show Auth0.
    func saveNameBeforeAuth0(firstName: String, lastName: String, email: String) {
        userFirstName = firstName
        userLastName = lastName
        userEmail = email
        isOnboarded = false
        hasCompletedPostAuth0Profile = false
        hasSubmittedNameBeforeAuth0 = true
    }

    /// Step 2: call after Auth0 reports a valid session.
    func completeSignInAfterAuth0() {
        guard APIConfig.shouldShowAuth0InUI else { return }
        guard hasSubmittedNameBeforeAuth0 else { return }
        guard !hasCompletedPostAuth0Profile else { return }
        isOnboarded = true
        hasCompletedPostAuth0Profile = true
    }

    /// Clears stale UserDefaults before the user types their name (Auth0 flow, first step only).
    func resetProfileForManualNameEntryIfNeeded() {
        guard APIConfig.shouldShowAuth0InUI else { return }
        guard !hasCompletedPostAuth0Profile else { return }
        guard !hasSubmittedNameBeforeAuth0 else { return }
        userFirstName = ""
        userLastName = ""
        userEmail = ""
        isOnboarded = false
    }

    func signOut() {
        userFirstName = ""
        userLastName = ""
        userEmail = ""
        isOnboarded = false
        hasCompletedPostAuth0Profile = false
        hasSubmittedNameBeforeAuth0 = false
        onboardingFlowResetCount += 1
        sessionId = nil
        businessName = ""
        contactFirstName = ""
        contactMiddleName = ""
        contactLastName = ""
        results = nil
        selectedSectionRawValue = "home"
        WidgetDataWriter.clear()
    }

    func beginNewAnalysis(sessionId: String, businessName: String) {
        self.sessionId = sessionId
        self.businessName = businessName
        self.results = nil
        self.selectedSectionRawValue = "home"
        WidgetDataWriter.beginAnalysis(businessName: businessName)
    }

    func completeAnalysis(results: ResultsResponse) {
        self.results = results
        self.selectedSectionRawValue = "coverage"
        WidgetDataWriter.update(from: results, businessName: businessName)
    }

    func openSection(_ rawValue: String) {
        // Migrate legacy raw values and widget/deep-link aliases
        switch rawValue {
        case "summary", "coverage":
            selectedSectionRawValue = "coverage"
        case "analyze", "home":
            selectedSectionRawValue = "home"
        case "settings", "profile":
            selectedSectionRawValue = "profile"
        default:
            selectedSectionRawValue = rawValue
        }
    }
}
