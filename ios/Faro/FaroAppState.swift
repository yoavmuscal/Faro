import SwiftUI

/// Shared session + results so the Coverage tab/sidebar and analyze flow stay in sync.
@MainActor
final class FaroAppState: ObservableObject {
    @Published var sessionId: String?
    @Published var businessName: String = ""
    @Published var results: ResultsResponse?

    func beginNewAnalysis(sessionId: String, businessName: String) {
        self.sessionId = sessionId
        self.businessName = businessName
        self.results = nil
    }

    func completeAnalysis(results: ResultsResponse) {
        self.results = results
    }
}
