import SwiftUI

struct FaroSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            Section {
                Label("Privacy policy will appear here in a future update.", systemImage: "hand.raised.fill")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Legal")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(FaroPalette.background)
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        FaroSettingsView()
    }
    .faroCanvasBackground()
}
