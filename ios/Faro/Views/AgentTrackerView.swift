import SwiftUI

struct AgentTrackerView: View {
    @EnvironmentObject private var appState: FaroAppState
    let sessionId: String
    let businessName: String

    @StateObject private var ws: WebSocketService
    @State private var navigateToDashboard = false
    @State private var results: ResultsResponse?
    @State private var isLoadingResults = false
    @State private var errorMessage: String?

    private let allSteps: [AgentStep] = [.riskProfiler, .coverageMapper, .submissionBuilder, .explainer]

    init(sessionId: String, businessName: String = "Business") {
        self.sessionId = sessionId
        self.businessName = businessName
        _ws = StateObject(wrappedValue: WebSocketService(sessionId: sessionId))
    }

    var isComplete: Bool {
        ws.stepUpdates.filter({ $0.status == .complete }).count == allSteps.count
    }

    var hasError: Bool {
        ws.stepUpdates.contains(where: { $0.status == .error })
    }

    private var completedCount: Int {
        ws.stepUpdates.filter({ $0.status == .complete }).count
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

                ProgressView(value: Double(completedCount), total: Double(allSteps.count))
                    .tint(hasError ? FaroPalette.danger : FaroPalette.purpleDeep)
                    .padding(.top, FaroSpacing.xs)
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

            if let error = errorMessage {
                HStack(spacing: FaroSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(FaroPalette.danger)
                    Text(error)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.danger)
                }
                .padding(.horizontal, FaroSpacing.md)
                .padding(.bottom, FaroSpacing.xs)
            }

            if isComplete {
                Button {
                    Task { await loadResults() }
                } label: {
                    Group {
                        if isLoadingResults {
                            ProgressView()
                                .tint(FaroPalette.onAccent)
                        } else {
                            Text("View coverage options")
                                .font(FaroType.headline())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(FaroPalette.purpleDeep)
                    .foregroundStyle(FaroPalette.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
                }
                .disabled(isLoadingResults)
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
        isLoadingResults = true
        errorMessage = nil
        do {
            let fetched = try await APIService.shared.fetchResults(sessionId: sessionId)
            results = fetched
            appState.completeAnalysis(results: fetched)
            navigateToDashboard = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load results: \(error.localizedDescription)"
        }
        isLoadingResults = false
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

    var stepSubtitle: String {
        switch step {
        case .riskProfiler: return "Analyzing industry risks and regulatory exposure"
        case .coverageMapper: return "Mapping risks to specific policy types"
        case .submissionBuilder: return "Generating carrier-ready submission packet"
        case .explainer: return "Writing plain-English summary"
        }
    }

    var stepIcon: String {
        switch step {
        case .riskProfiler: return "magnifyingglass"
        case .coverageMapper: return "map"
        case .submissionBuilder: return "doc.text"
        case .explainer: return "text.bubble"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                if update?.status == .running {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(FaroPalette.info)
                } else if update?.status == .error {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FaroPalette.danger)
                } else {
                    Image(systemName: update?.status == .complete ? "checkmark" : stepIcon)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                } else if update == nil {
                    Text(stepSubtitle)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.35))
                } else if update?.status == .running {
                    HStack(spacing: 4) {
                        Text("Processing")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.info)
                        Text("···")
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.info)
                    }
                }
            }

            Spacer()

            if update?.status == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(FaroPalette.success)
                    .font(.body)
            }
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
