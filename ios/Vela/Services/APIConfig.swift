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
}
