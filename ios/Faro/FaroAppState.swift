import SwiftUI

@MainActor
final class FaroAppState: ObservableObject {
    @Published var sessionId: String?
    @Published var businessName: String = ""
    @Published var results: ResultsResponse?

    var hasResults: Bool { results != nil && sessionId != nil }

    var totalEstimatedPremium: ClosedRange<Double> {
        guard let opts = results?.coverageOptions, !opts.isEmpty else { return 0...0 }
        let low = opts.reduce(0) { $0 + $1.estimatedPremiumLow }
        let high = opts.reduce(0) { $0 + $1.estimatedPremiumHigh }
        return low...high
    }

    func beginNewAnalysis(sessionId: String, businessName: String) {
        self.sessionId = sessionId
        self.businessName = businessName
        self.results = nil
    }

    func completeAnalysis(results: ResultsResponse) {
        self.results = results
    }
}
