import SwiftUI

struct AgentTrackerView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    let sessionId: String
    let businessName: String

    @StateObject private var ws: WebSocketService
    @State private var isLoadingResults = false
    @State private var errorMessage: String?
    @State private var widgetUpdateTask: Task<Void, Never>?

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

    /// Stable fingerprint so we catch status changes, not just array count.
    private var pipelineFingerprint: String {
        allSteps.map { step in
            let s = ws.stepUpdates.first(where: { $0.step == step })?.status.rawValue ?? "none"
            return "\(step.rawValue):\(s)"
        }.joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                Text("Analyzing \(businessName)")
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: FaroSpacing.sm + 2) {
                        ForEach(Array(allSteps.enumerated()), id: \.element) { _, step in
                            StepCard(
                                step: step,
                                update: ws.stepUpdates.first(where: { $0.step == step })
                            )
                            .id(step)
                        }
                    }
                    .padding(FaroSpacing.md)
                }
                .onChange(of: ws.stepUpdates.count) { _, _ in
                    if let active = allSteps.first(where: { step in
                        ws.stepUpdates.first(where: { $0.step == step })?.status == .running
                    }) ?? allSteps.last(where: { step in
                        ws.stepUpdates.first(where: { $0.step == step })?.status == .complete
                    }) {
                        withAnimation { proxy.scrollTo(active, anchor: .center) }
                    }
                }
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isComplete {
                Button {
                    Task { await loadResults() }
                } label: {
                    Group {
                        if isLoadingResults {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: 8) {
                                Text("View coverage options")
                                    .font(FaroType.headline())
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.faroGradient)
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
        .onAppear {
            Task { @MainActor in
                let token = await authManager.accessToken()
                ws.connect(accessToken: token)
            }
        }
        .onDisappear {
            ws.disconnect()
            widgetUpdateTask?.cancel()
            widgetUpdateTask = nil
        }
        .onChange(of: pipelineFingerprint) { _, _ in
            guard !isComplete else { return }
            scheduleWidgetPipelineUpdate()
        }
        .onChange(of: isComplete) { _, complete in
            guard complete else { return }
            widgetUpdateTask?.cancel()
            widgetUpdateTask = nil
            WidgetDataWriter.updatePipelineProgress(
                businessName: businessName,
                completedSteps: allSteps.count,
                totalSteps: allSteps.count,
                headline: "Analysis complete",
                message: "Tap to view coverage options"
            )
        }
    }

    private func scheduleWidgetPipelineUpdate() {
        widgetUpdateTask?.cancel()
        widgetUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            WidgetDataWriter.updatePipelineProgress(
                businessName: businessName,
                completedSteps: completedCount,
                totalSteps: allSteps.count,
                headline: pipelineWidgetHeadline,
                message: "Faro is reasoning through coverage options"
            )
        }
    }

    private var pipelineWidgetHeadline: String {
        if let running = allSteps.first(where: { step in
            ws.stepUpdates.first(where: { $0.step == step })?.status == .running
        }) {
            switch running {
            case .riskProfiler: return "Profiling risk"
            case .coverageMapper: return "Mapping coverage"
            case .submissionBuilder: return "Building submission"
            case .explainer: return "Writing summary"
            }
        }
        if completedCount > 0 {
            return "Analysis in progress"
        }
        return "Analysis in progress"
    }

    private func loadResults() async {
        isLoadingResults = true
        errorMessage = nil
        do {
            let fetched = try await APIService.shared.fetchResults(sessionId: sessionId)
            appState.completeAnalysis(results: fetched)
            // Tab switches to Coverage via completeAnalysis — do not push CoverageDashboardView here.
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
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 46, height: 46)

                if update?.status == .running {
                    Circle()
                        .fill(FaroPalette.info.opacity(0.08))
                        .frame(width: 46, height: 46)
                        .phaseAnimator([false, true]) { content, phase in
                            content.overlay {
                                Circle()
                                    .stroke(FaroPalette.info.opacity(phase ? 0 : 0.35), lineWidth: 2)
                                    .scaleEffect(phase ? 1.6 : 1)
                            }
                        } animation: { _ in .easeOut(duration: 1.4) }

                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(FaroPalette.info)
                } else if update?.status == .error {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FaroPalette.danger)
                } else if update?.status == .complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(FaroPalette.success)
                } else {
                    Image(systemName: stepIcon)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
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
                    Text("Processing...")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.info)
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
        .faroGlassCard(cornerRadius: FaroRadius.lg)
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
    .environmentObject(AuthManager())
}
