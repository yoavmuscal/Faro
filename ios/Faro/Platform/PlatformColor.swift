import SwiftUI

extension Color {
    /// Background that reads as “card on top of app chrome” on both iOS and macOS.
    static var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}
