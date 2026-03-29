import Auth0
import Combine
import Foundation
import SwiftUI

/// Auth0 PKCE login via system browser; tokens stored with `CredentialsManager`.
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var lastError: String?

    private let credentialsManager: CredentialsManager?
    private let clientId: String?
    private let domain: String?
    private let audience: String?

    init() {
        clientId = APIConfig.auth0ClientId
        domain = APIConfig.auth0Domain
        audience = APIConfig.auth0Audience
        if let clientId, let domain {
            let auth = Auth0.authentication(clientId: clientId, domain: domain)
            credentialsManager = CredentialsManager(authentication: auth)
        } else {
            credentialsManager = nil
        }
        Task { await refreshLoginState() }
    }

    var isAuthConfigured: Bool {
        APIConfig.isAuth0Configured
    }

    /// Access token for API and WebSocket `Authorization` header.
    /// Prefers ``CredentialsManager/apiCredentials(forAudience:...)`` so the JWT matches the Auth0 API audience the backend validates.
    func accessToken() async -> String? {
        guard let credentialsManager, let audience else { return nil }
        do {
            let apiCreds = try await credentialsManager.apiCredentials(forAudience: audience, minTTL: 120)
            return apiCreds.accessToken
        } catch {
            do {
                let credentials = try await credentialsManager.credentials(minTTL: 120)
                return credentials.accessToken
            } catch {
                return nil
            }
        }
    }

    func refreshLoginState() async {
        guard credentialsManager != nil else {
            isLoggedIn = false
            return
        }
        isLoggedIn = await accessToken() != nil
    }

    func login() async {
        guard let clientId, let domain, let audience, let credentialsManager else {
            lastError = "Auth0 is not configured in Info.plist."
            return
        }
        guard let callbackURL = Self.auth0CallbackRedirectURL() else {
            lastError = "Could not build Auth0 callback URL (missing bundle identifier?)."
            return
        }
        lastError = nil
        do {
            let credentials = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Credentials, Error>) in
                Auth0.webAuth(clientId: clientId, domain: domain)
                    .redirectURL(callbackURL)
                    .audience(audience)
                    .scope("openid profile email offline_access")
                    // Omit useEphemeralSession: ephemeral sessions often break return-to-app / SSO during debugging.
                    .start { result in
                        switch result {
                        case .success(let creds):
                            continuation.resume(returning: creds)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
            }
            guard credentialsManager.store(credentials: credentials) else {
                lastError = "Could not store credentials in the keychain."
                isLoggedIn = false
                return
            }
            isLoggedIn = true
        } catch {
            lastError = error.localizedDescription
            isLoggedIn = false
        }
    }

    func logout() async {
        lastError = nil
        if let clientId, let domain, let callbackURL = Self.auth0CallbackRedirectURL() {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Auth0.webAuth(clientId: clientId, domain: domain)
                    .redirectURL(callbackURL)
                    .clearSession { _ in
                        continuation.resume()
                    }
            }
        }
        _ = credentialsManager?.clear()
        isLoggedIn = false
    }

    /// Must match **Allowed Callback URLs** and **Allowed Logout URLs** in the Auth0 application and `CFBundleURLSchemes` (`{bundle}.auth0`).
    private static func auth0CallbackRedirectURL() -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let host = APIConfig.auth0Domain else { return nil }
        return URL(string: "\(bundleId).auth0://\(host)/ios/\(bundleId)/callback")
    }
}
