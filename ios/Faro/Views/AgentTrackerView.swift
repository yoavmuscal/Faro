import SwiftUI

// MARK: - View

struct AgentTrackerView: View {
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Analyzing your business")
                    .font(.title2).fontWeight(.bold)
                Text("The agent is reasoning through your coverage needs in real time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(allSteps, id: \.self) { step in
                        StepCard(
                            step: step,
                            update: ws.stepUpdates.first(where: { $0.step == step })
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: ws.stepUpdates.count)
            }

            if isComplete {
                Button {
                    Task { await loadResults() }
                } label: {
                    Text("View coverage options")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primary)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
            results = try await APIService.shared.fetchResults(sessionId: sessionId)
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
                } else {
                    Image(systemName: update?.status == .complete ? "checkmark" : stepIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stepTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(update == nil ? .secondary : .primary)

                if let summary = update?.summary, update?.status != .running {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var statusColor: Color {
        switch update?.status {
        case .complete: return .green
        case .running: return .blue
        case .error: return .red
        case nil: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        AgentTrackerView(sessionId: "preview-session")
    }
}
