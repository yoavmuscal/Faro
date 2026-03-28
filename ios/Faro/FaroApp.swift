import Auth0
import SwiftUI

@main
struct FaroApp: App {
    @StateObject private var appState = FaroAppState()
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            FaroRootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .tint(FaroPalette.purpleDeep)
                .task {
                    await APIService.shared.setAccessTokenProvider {
                        await authManager.accessToken()
                    }
                }
                .onOpenURL { url in
                    if url.scheme?.lowercased() == "faro" {
                        if let host = url.host, !host.isEmpty {
                            appState.openSection(host)
                            return
                        }
                        let target = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        if !target.isEmpty {
                            appState.openSection(target)
                        }
                        return
                    }
                    WebAuth.resume(with: url)
                }
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
