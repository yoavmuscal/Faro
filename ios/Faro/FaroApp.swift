import SwiftUI

@main
struct FaroApp: App {
    @StateObject private var appState = FaroAppState()

    var body: some Scene {
        WindowGroup {
            FaroRootView()
                .environmentObject(appState)
                .tint(FaroPalette.purpleDeep)
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
