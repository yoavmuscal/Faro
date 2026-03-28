import SwiftUI

// MARK: - View

struct AgentTrackerView: View {
    @EnvironmentObject private var appState: FaroAppState
    let sessionId: String
    let businessName: String

    @StateObject private var ws: WebSocketService
    @State private var navigateToDashboard = false
    @State private var results: ResultsResponse?

    private let allSteps: [AgentStep] = [.riskProfiler, .coverageMapper, .submissionBuilder, .explainer]

    init(sessionId: String, businessName: String = "Business") {
        self.sessionId = sessionId
        self.businessName = businessName
        _ws = StateObject(wrappedValue: WebSocketService(sessionId: sessionId))
    }

    var isComplete: Bool {
        ws.stepUpdates.filter({ $0.status == .complete }).count == allSteps.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                Text("Analyzing your business")
                    .font(FaroType.title2())
                    .foregroundStyle(FaroPalette.ink)
                Text("The agent is reasoning through your coverage needs in real time.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FaroSpacing.md)

            ScrollView {
                LazyVStack(spacing: FaroSpacing.sm + 2) {
                    ForEach(allSteps, id: \.self) { step in
                        StepCard(
                            step: step,
                            update: ws.stepUpdates.first(where: { $0.step == step })
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(FaroSpacing.md)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ws.stepUpdates.count)
            }

            if isComplete {
                Button {
                    Task { await loadResults() }
                } label: {
                    Text("View coverage options")
                        .font(FaroType.headline())
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(FaroPalette.purpleDeep)
                        .foregroundStyle(FaroPalette.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
                }
                .padding(FaroSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .faroCanvasBackground()
        .navigationTitle("Analysis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(isComplete)
        .navigationDestination(isPresented: $navigateToDashboard) {
            if let results {
                CoverageDashboardView(results: results, sessionId: sessionId, businessName: businessName)
            }
        }
        .onAppear { ws.connect() }
        .onDisappear { ws.disconnect() }
    }

    private func loadResults() async {
        do {
            let fetched = try await APIService.shared.fetchResults(sessionId: sessionId)
            results = fetched
            appState.completeAnalysis(results: fetched)
            navigateToDashboard = true
        } catch {
            // TODO: show error
        }
    }
}

// MARK: - Step Card

struct StepCard: View {
    let step: AgentStep
    let update: StepUpdate?

    var stepTitle: String {
        switch step {
        case .riskProfiler: return "Risk Profiler"
        case .coverageMapper: return "Coverage Mapper"
        case .submissionBuilder: return "Submission Builder"
        case .explainer: return "Explainer"
        }
    }

    var stepIcon: String {
        switch step {
        case .riskProfiler: return "magnifyingglass"
        case .coverageMapper: return "map"
        case .submissionBuilder: return "doc.text"
        case .explainer: return "bubble.left"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                if update?.status == .running {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(FaroPalette.info)
                } else {
                    Image(systemName: update?.status == .complete ? "checkmark" : stepIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stepTitle)
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(update == nil ? FaroPalette.ink.opacity(0.45) : FaroPalette.ink)

                if let summary = update?.summary, update?.status != .running {
                    Text(summary)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.md, material: .ultraThinMaterial)
    }

    var statusColor: Color {
        switch update?.status {
        case .complete: return FaroPalette.success
        case .running: return FaroPalette.info
        case .error: return FaroPalette.danger
        case nil: return FaroPalette.ink.opacity(0.35)
        }
    }
}

#Preview {
    NavigationStack {
        AgentTrackerView(sessionId: "preview-session")
    }
    .environmentObject(FaroAppState())
}
