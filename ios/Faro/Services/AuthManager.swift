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
    func accessToken() async -> String? {
        guard let credentialsManager else { return nil }
        do {
            let credentials = try await credentialsManager.credentials(minTTL: 120)
            return credentials.accessToken
        } catch {
            return nil
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
        lastError = nil
        do {
            let credentials = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Credentials, Error>) in
                Auth0.webAuth(clientId: clientId, domain: domain)
                    .audience(audience)
                    .scope("openid profile email")
                    .start { result in
                        switch result {
                        case .success(let creds):
                            continuation.resume(returning: creds)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
            }
            _ = credentialsManager.store(credentials: credentials)
            isLoggedIn = true
        } catch {
            lastError = error.localizedDescription
            isLoggedIn = false
        }
    }

    func logout() async {
        lastError = nil
        if let clientId, let domain {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Auth0.webAuth(clientId: clientId, domain: domain)
                    .clearSession { _ in
                        continuation.resume()
                    }
            }
        }
        _ = credentialsManager?.clear()
        isLoggedIn = false
    }
}
