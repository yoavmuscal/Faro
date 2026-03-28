import SwiftUI

enum FaroSection: String, CaseIterable, Identifiable, Hashable {
    case analyze
    case coverage
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analyze: return "Analyze"
        case .coverage: return "Coverage"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .analyze: return "sparkles"
        case .coverage: return "shield.checkered"
        case .settings: return "gearshape"
        }
    }
}

struct FaroRootView: View {
    @EnvironmentObject private var appState: FaroAppState
    @State private var section: FaroSection = .analyze

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(FaroSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("Faro")
            .listStyle(.sidebar)
            .frame(minWidth: 220, idealWidth: 240)
        } detail: {
            detailStack
        }
        .navigationSplitViewStyle(.balanced)
        .tint(FaroPalette.purpleDeep)
        #else
        TabView(selection: $section) {
            NavigationStack {
                OnboardingView()
            }
            .tabItem { Label(FaroSection.analyze.title, systemImage: FaroSection.analyze.systemImage) }
            .tag(FaroSection.analyze)

            NavigationStack {
                coverageRoot
            }
            .tabItem { Label(FaroSection.coverage.title, systemImage: FaroSection.coverage.systemImage) }
            .tag(FaroSection.coverage)

            NavigationStack {
                FaroSettingsView()
            }
            .tabItem { Label(FaroSection.settings.title, systemImage: FaroSection.settings.systemImage) }
            .tag(FaroSection.settings)
        }
        .tint(FaroPalette.purpleDeep)
        #endif
    }

    @ViewBuilder
    private var detailStack: some View {
        switch section {
        case .analyze:
            NavigationStack {
                OnboardingView()
            }
        case .coverage:
            NavigationStack {
                coverageRoot
            }
        case .settings:
            NavigationStack {
                FaroSettingsView()
            }
        }
    }

    @ViewBuilder
    private var coverageRoot: some View {
        if let results = appState.results, let sid = appState.sessionId {
            CoverageDashboardView(
                results: results,
                sessionId: sid,
                businessName: appState.businessName
            )
        } else {
            ContentUnavailableView {
                Label("No coverage analysis yet", systemImage: "shield.lefthalf.filled")
            } description: {
                Text("Run an analysis from the Analyze section. Your summary and charts will appear here.")
                    .multilineTextAlignment(.center)
            } actions: {
                Button("Go to Analyze") {
                    section = .analyze
                }
                .buttonStyle(.borderedProminent)
                .tint(FaroPalette.purpleDeep)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .faroCanvasBackground()
        }
    }
}

#Preview {
    FaroRootView()
        .environmentObject(FaroAppState())
}
