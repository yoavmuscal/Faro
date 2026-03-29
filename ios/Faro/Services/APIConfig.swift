import Foundation

/// Shared API base URLs (HTTP + WebSocket) from Info.plist `API_BASE_URL` or localhost for simulator dev.
enum APIConfig {
    /// Effective HTTP API root: Settings override, then `API_BASE_URL` in Info.plist, then localhost.
    static var httpBaseURL: String {
        if let o = storedHttpBaseURLOverride, !o.isEmpty {
            return o
        }
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
        guard let raw = string(forInfoKey: "AUTH0_DOMAIN") else { return nil }
        if let host = URL(string: raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)")?.host {
            return host
        }
        return raw.split(separator: "/").first.map(String.init)
    }

    static var auth0Audience: String? {
        string(forInfoKey: "AUTH0_AUDIENCE")
    }

    static var isAuth0Configured: Bool {
        auth0ClientId != nil && auth0Domain != nil && auth0Audience != nil
    }

    /// Domain + API audience are in the plist but `AUTH0_CLIENT_ID` is empty — WebAuth cannot start until you add the Native app's Client ID.
    static var auth0MissingClientIdOnly: Bool {
        auth0ClientId == nil && auth0Domain != nil && auth0Audience != nil
    }

    /// Show Auth0 UI: fully configured, or needs the client id only.
    static var shouldShowAuth0InUI: Bool {
        isAuth0Configured || auth0MissingClientIdOnly
    }

    /// When `false`, users can use the app after the name screen without signing in; Auth0 remains optional in Settings / Profile.
    static var isAuth0Required: Bool { false }

    /// Shown in-app as a hint; must match Allowed Callback / Logout URLs in Auth0 for this Native app.
    static var auth0CallbackURLHint: String? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let host = auth0Domain else { return nil }
        return "\(bundleId).auth0://\(host)/ios/\(bundleId)/callback"
    }

    private static func string(forInfoKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - HTTP base URL override (Settings → local backend)

    private static let httpBaseURLOverrideKey = "FaroHTTPBaseURLOverride"

    static var storedHttpBaseURLOverride: String? {
        guard let raw = UserDefaults.standard.string(forKey: httpBaseURLOverrideKey) else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func setHttpBaseURLOverride(_ url: String?) {
        if let url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.set(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: httpBaseURLOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: httpBaseURLOverrideKey)
        }
        NotificationCenter.default.post(name: .faroHTTPBaseURLDidChange, object: nil)
    }

    // MARK: - Offline demo (Settings)

    static let demoModeUserDefaultsKey = "faro_offline_demo_mode"

    static var isDemoModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: demoModeUserDefaultsKey)
    }

    static func setDemoModeEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: demoModeUserDefaultsKey)
    }

    /// Simulator / debug: allow editing the API base URL from Profile. Release builds use plist default unless overridden.
    static var showsDeviceBackendURLOptions: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

extension Notification.Name {
    static let faroHTTPBaseURLDidChange = Notification.Name("faroHTTPBaseURLDidChange")
    static let faroDemoModeDidChange = Notification.Name("faroDemoModeDidChange")
}
