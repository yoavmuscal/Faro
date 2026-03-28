import SwiftUI

@main
struct FaroApp: App {
    @StateObject private var appState = FaroAppState()

    var body: some Scene {
        WindowGroup {
            FaroRootView()
                .environmentObject(appState)
                .tint(FaroPalette.purpleDeep)
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
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
