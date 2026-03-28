import SwiftUI

enum FaroSection: String, CaseIterable, Identifiable, Hashable {
    case analyze
    case coverage
    case riskProfile
    case submission
    case summary
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analyze: return "Analyze"
        case .coverage: return "Coverage"
        case .riskProfile: return "Risk Profile"
        case .submission: return "Submission"
        case .summary: return "Summary"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .analyze: return "sparkles"
        case .coverage: return "shield.checkered"
        case .riskProfile: return "exclamationmark.triangle.fill"
        case .submission: return "doc.text.fill"
        case .summary: return "text.bubble.fill"
        case .settings: return "gearshape"
        }
    }

    static var analysisSections: [FaroSection] {
        [.coverage, .riskProfile, .submission, .summary]
    }
}

struct FaroRootView: View {
    @EnvironmentObject private var appState: FaroAppState
    @State private var section: FaroSection = .analyze

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailStack
        }
        .navigationSplitViewStyle(.balanced)
        .tint(FaroPalette.purpleDeep)
        #else
        TabView(selection: $section) {
            NavigationStack {
                IntakeChoiceView()
            }
            .tabItem { Label(FaroSection.analyze.title, systemImage: FaroSection.analyze.systemImage) }
            .tag(FaroSection.analyze)

            NavigationStack {
                coverageRoot
            }
            .tabItem { Label(FaroSection.coverage.title, systemImage: FaroSection.coverage.systemImage) }
            .tag(FaroSection.coverage)

            NavigationStack {
                riskProfileRoot
            }
            .tabItem { Label(FaroSection.riskProfile.title, systemImage: FaroSection.riskProfile.systemImage) }
            .tag(FaroSection.riskProfile)

            NavigationStack {
                submissionRoot
            }
            .tabItem { Label(FaroSection.submission.title, systemImage: FaroSection.submission.systemImage) }
            .tag(FaroSection.submission)

            NavigationStack {
                summaryRoot
            }
            .tabItem { Label(FaroSection.summary.title, systemImage: FaroSection.summary.systemImage) }
            .tag(FaroSection.summary)

            NavigationStack {
                FaroSettingsView()
            }
            .tabItem { Label(FaroSection.settings.title, systemImage: FaroSection.settings.systemImage) }
            .tag(FaroSection.settings)
        }
        .tint(FaroPalette.purpleDeep)
        #endif
    }

    // MARK: - macOS Sidebar
    // `List(selection:)` is macOS-only; keep this block out of the iOS compile unit.

    #if os(macOS)
    private var sidebarContent: some View {
        List(selection: $section) {
            Section {
                Label(FaroSection.analyze.title, systemImage: FaroSection.analyze.systemImage)
                    .tag(FaroSection.analyze)
            }

            if appState.hasResults {
                Section("Analysis") {
                    ForEach(FaroSection.analysisSections) { sec in
                        Label(sec.title, systemImage: sec.systemImage)
                            .tag(sec)
                    }
                }
            }

            Section {
                Label(FaroSection.settings.title, systemImage: FaroSection.settings.systemImage)
                    .tag(FaroSection.settings)
            }
        }
        .navigationTitle("Faro")
        .listStyle(.sidebar)
        .frame(minWidth: 220, idealWidth: 240)
    }
    #endif

    // MARK: - Detail

    @ViewBuilder
    private var detailStack: some View {
        switch section {
        case .analyze:
            NavigationStack { IntakeChoiceView() }
        case .coverage:
            NavigationStack { coverageRoot }
        case .riskProfile:
            NavigationStack { riskProfileRoot }
        case .submission:
            NavigationStack { submissionRoot }
        case .summary:
            NavigationStack { summaryRoot }
        case .settings:
            NavigationStack { FaroSettingsView() }
        }
    }

    // MARK: - Section Roots

    @ViewBuilder
    private var coverageRoot: some View {
        if let results = appState.results, let sid = appState.sessionId {
            CoverageDashboardView(results: results, sessionId: sid, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No coverage analysis yet",
                message: "Run an analysis from the Analyze tab to see your coverage recommendations, charts, and premium estimates.",
                icon: "shield.lefthalf.filled"
            ) { section = .analyze }
        }
    }

    @ViewBuilder
    private var riskProfileRoot: some View {
        if let rp = appState.results?.riskProfile {
            RiskProfileView(riskProfile: rp, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No risk profile yet",
                message: "After analyzing your business, the AI risk assessment with exposures, state requirements, and risk level will appear here.",
                icon: "exclamationmark.triangle"
            ) { section = .analyze }
        }
    }

    @ViewBuilder
    private var submissionRoot: some View {
        if let packet = appState.results?.submissionPacket {
            SubmissionPacketView(packet: packet, businessName: appState.businessName)
        } else {
            AnalysisPlaceholderView(
                title: "No submission packet yet",
                message: "The carrier-ready submission document will be generated after your analysis completes.",
                icon: "doc.text"
            ) { section = .analyze }
        }
    }

    @ViewBuilder
    private var summaryRoot: some View {
        if let summary = appState.results?.plainEnglishSummary, !summary.isEmpty {
            SummaryPlayerView(
                summary: summary,
                voiceURL: appState.results?.voiceSummaryUrl ?? "",
                businessName: appState.businessName
            )
        } else {
            AnalysisPlaceholderView(
                title: "No summary yet",
                message: "A plain-English summary of your coverage recommendations with voice playback will appear here after analysis.",
                icon: "text.bubble"
            ) { section = .analyze }
        }
    }
}

// MARK: - Placeholder

struct AnalysisPlaceholderView: View {
    let title: String
    let message: String
    let icon: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
        } actions: {
            Button("Go to Analyze", action: action)
                .buttonStyle(.borderedProminent)
                .tint(FaroPalette.purpleDeep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .faroCanvasBackground()
    }
}

#Preview {
    FaroRootView()
        .environmentObject(FaroAppState())
}
