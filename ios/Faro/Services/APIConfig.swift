import Foundation

/// Shared API base URLs (HTTP + WebSocket) from Info.plist `API_BASE_URL` or localhost for simulator dev.
enum APIConfig {
    static var httpBaseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String, !url.isEmpty {
            return url
        }
        return "http://localhost:8000"
    }

    /// Matches `httpBaseURL` (e.g. `ws://localhost:8000`, `wss://…`).
    static var webSocketBaseURL: String {
        let http = httpBaseURL
        if http.hasPrefix("https://") {
            return "wss://" + http.dropFirst("https://".count)
        }
        if http.hasPrefix("http://") {
            return "ws://" + http.dropFirst("http://".count)
        }
        return "ws://" + http
    }

    // MARK: - Auth0 (optional)

    static var auth0ClientId: String? {
        string(forInfoKey: "AUTH0_CLIENT_ID")
    }

    static var auth0Domain: String? {
        string(forInfoKey: "AUTH0_DOMAIN")
    }

    static var auth0Audience: String? {
        string(forInfoKey: "AUTH0_AUDIENCE")
    }

    static var isAuth0Configured: Bool {
        auth0ClientId != nil && auth0Domain != nil && auth0Audience != nil
    }

    private static func string(forInfoKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
