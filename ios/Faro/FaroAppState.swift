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

    @Published var sessionId: String?
    @Published var businessName: String = ""
    @Published var contactFirstName: String = ""
    @Published var contactMiddleName: String = ""
    @Published var contactLastName: String = ""
    @Published var results: ResultsResponse?
    @Published var selectedSectionRawValue: String = "analyze"

    var isSignedIn: Bool {
        isOnboarded && !userFirstName.trimmingCharacters(in: .whitespaces).isEmpty
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
    }

    func signIn(firstName: String, lastName: String, email: String) {
        userFirstName = firstName
        userLastName = lastName
        userEmail = email
        isOnboarded = true
    }

    func signOut() {
        userFirstName = ""
        userLastName = ""
        userEmail = ""
        isOnboarded = false
        sessionId = nil
        businessName = ""
        contactFirstName = ""
        contactMiddleName = ""
        contactLastName = ""
        results = nil
        selectedSectionRawValue = "analyze"
        WidgetDataWriter.clear()
    }

    func beginNewAnalysis(sessionId: String, businessName: String) {
        self.sessionId = sessionId
        self.businessName = businessName
        self.results = nil
        self.selectedSectionRawValue = "analyze"
        WidgetDataWriter.beginAnalysis(businessName: businessName)
    }

    func completeAnalysis(results: ResultsResponse) {
        self.results = results
        self.selectedSectionRawValue = "coverage"
        WidgetDataWriter.update(from: results, businessName: businessName)
    }

    func openSection(_ rawValue: String) {
        // Legacy widget/deep links used "summary"; summary lives on Coverage now.
        if rawValue == "summary" {
            selectedSectionRawValue = "coverage"
        } else {
            selectedSectionRawValue = rawValue
        }
    }
}
