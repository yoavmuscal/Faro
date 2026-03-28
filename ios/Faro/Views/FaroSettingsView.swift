import SwiftUI

struct FaroSettingsView: View {
    @EnvironmentObject private var appState: FaroAppState

    var body: some View {
        Form {
            Section {
                HStack(spacing: FaroSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .fill(FaroPalette.purpleDeep.gradient)
                            .frame(width: 48, height: 48)
                        Image(systemName: "shield.checkered")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Faro")
                            .font(FaroType.headline())
                            .foregroundStyle(FaroPalette.ink)
                        Text("AI Insurance Agent")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    }
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.4))
                }
                .listRowBackground(Color.clear)
            }

            Section("Current Session") {
                if let sid = appState.sessionId {
                    LabeledContent("Session ID") {
                        Text(String(sid.prefix(8)) + "...")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    }
                    LabeledContent("Business") {
                        Text(appState.businessName.isEmpty ? "—" : appState.businessName)
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.hasResults ? FaroPalette.success : FaroPalette.warning)
                                .frame(width: 8, height: 8)
                            Text(appState.hasResults ? "Complete" : "In Progress")
                                .font(FaroType.caption())
                                .foregroundStyle(FaroPalette.ink.opacity(0.5))
                        }
                    }
                } else {
                    Text("No active session")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.4))
                }
            }

            Section("Server") {
                LabeledContent("API Endpoint") {
                    Text(APIConfig.httpBaseURL)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Section("Legal") {
                Label("Privacy policy will appear here in a future update.", systemImage: "hand.raised.fill")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.6))
            }

            Section("Tech") {
                LabeledContent("Pipeline") {
                    Text("LangGraph + K2 Think V2")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
                LabeledContent("Voice") {
                    Text("ElevenLabs TTS")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
                LabeledContent("Platform") {
                    #if os(macOS)
                    Text("macOS")
                    #else
                    Text("iOS / iPadOS")
                    #endif
                }
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.5))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .faroCanvasBackground()
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
    .environmentObject(FaroAppState())
}
