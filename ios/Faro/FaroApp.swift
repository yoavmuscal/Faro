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
                    WebAuth.resume(with: url)
                }
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
