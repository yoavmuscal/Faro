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
<<<<<<< HEAD
                .task {
                    await APIService.shared.setAccessTokenProvider {
                        await authManager.accessToken()
                    }
                }
                .onOpenURL { url in
                    WebAuth.resume(with: url)
                }
=======
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "faro" else { return }
                    if let host = url.host, !host.isEmpty {
                        appState.openSection(host)
                        return
                    }
                    let target = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if !target.isEmpty {
                        appState.openSection(target)
                    }
                }
>>>>>>> e52b147b11078088ed646e8a2ee256e102628758
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
