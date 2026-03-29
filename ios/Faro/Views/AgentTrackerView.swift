import SwiftUI

struct AgentTrackerView: View {
    @EnvironmentObject private var appState: FaroAppState
    @EnvironmentObject private var authManager: AuthManager
    let sessionId: String
    let businessName: String
    /// Called after results are fetched and saved — clear navigation `sessionId` and dismiss parent flows.
    var onAnalysisFinished: (() -> Void)?

    @StateObject private var ws: WebSocketService
    @State private var isLoadingResults = false
    @State private var errorMessage: String?
    @State private var widgetUpdateTask: Task<Void, Never>?
    @State private var didTriggerAutoFetch = false

    private let allSteps: [AgentStep] = [.riskProfiler, .coverageMapper, .submissionBuilder, .explainer]

    init(sessionId: String, businessName: String = "Business", onAnalysisFinished: (() -> Void)? = nil) {
        self.sessionId = sessionId
        self.businessName = businessName
        self.onAnalysisFinished = onAnalysisFinished
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

    private var processingActive: Bool {
        !isComplete && !hasError
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

                if !isComplete {
                    AnalysisProcessingHero(
                        isAnimating: processingActive,
                        completedFraction: Double(completedCount) / Double(max(allSteps.count, 1))
                    )
                    .padding(.top, FaroSpacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ProgressView(value: Double(completedCount), total: Double(allSteps.count))
                    .tint(hasError ? FaroPalette.danger : FaroPalette.purpleDeep)
                    .padding(.top, FaroSpacing.xs)
            }
            .animation(.easeInOut(duration: 0.35), value: isComplete)
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
            guard !didTriggerAutoFetch else { return }
            didTriggerAutoFetch = true
            Task { await loadResults() }
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
            onAnalysisFinished?()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load results: \(error.localizedDescription)"
        }
        isLoadingResults = false
    }
}

// MARK: - Analysis hero (data-stream visualization)

private struct AnalysisProcessingHero: View {
    var isAnimating: Bool
    var completedFraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            HStack(spacing: FaroSpacing.xs) {
                LivePulseDot(isActive: isAnimating)
                Text("Processing intake signals")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.ink.opacity(0.72))
                Spacer(minLength: 0)
                Text("\(Int(round(completedFraction * 100)))%")
                    .font(FaroType.caption(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(FaroPalette.purpleDeep.opacity(0.85))
            }

            ZStack(alignment: .bottom) {
                DataStreamSpectrum(isActive: isAnimating)
                    .frame(height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous))

                LinearGradient(
                    colors: [
                        FaroPalette.background.opacity(0.0),
                        FaroPalette.background.opacity(0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                FaroPalette.info.opacity(0.22),
                                FaroPalette.purple.opacity(0.12),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .background {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .fill(FaroPalette.surface.opacity(0.4))
            }

            Text("Synthesizing structured coverage insights from your answers — not a canned template.")
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analysis in progress")
        .accessibilityHint(isAnimating ? "Animated visualization of live data processing" : "")
    }
}

private struct LivePulseDot: View {
    var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ripplePeriod: TimeInterval = 1.35

    var body: some View {
        ZStack {
            if isActive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive || reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (t.truncatingRemainder(dividingBy: ripplePeriod)) / ripplePeriod
                    let eased = 1 - pow(1 - phase, 2)
                    Circle()
                        .fill(FaroPalette.success.opacity(0.38))
                        .frame(width: 10, height: 10)
                        .scaleEffect(1 + eased * 1.55)
                        .opacity(1 - eased)
                }
            }
            Circle()
                .fill(FaroPalette.success)
                .frame(width: 7, height: 7)
                .shadow(color: FaroPalette.success.opacity(0.45), radius: 3, y: 0)
        }
        .frame(width: 14, height: 14)
    }
}

private struct DataStreamSpectrum: View {
    var isActive: Bool
    private let barCount = 32

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            staticSpectrumPlaceholder
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isActive)) { timeline in
                spectrumContent(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private var staticSpectrumPlaceholder: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let h = 0.35 + 0.45 * sin(Double(i) * 0.42 + 1.2)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(barGradient(opacity: 0.55))
                    .frame(height: CGFloat(h) * 88 + 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func spectrumContent(time t: TimeInterval) -> some View {
        GeometryReader { geo in
            let usableW = max(geo.size.width - 20, 40)
            let gap: CGFloat = 3
            let n = CGFloat(barCount)
            let barW = max(2, (usableW - gap * (n - 1)) / n)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<barCount, id: \.self) { i in
                    let x = Double(i)
                    let wave1 = sin(x * 0.38 + t * 2.15)
                    let wave2 = sin(x * 0.62 - t * 1.72)
                    let wave3 = sin(x * 0.21 + t * 3.1 + 0.7)
                    let mix = (wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.2)
                    let norm = (mix + 1) / 2
                    let h = max(6, norm * Double(geo.size.height - 10) * 0.92 + 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barGradient(opacity: 0.45 + norm * 0.45))
                        .frame(width: barW, height: CGFloat(h))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    private func barGradient(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                FaroPalette.info.opacity(opacity * 0.95),
                FaroPalette.purpleDeep.opacity(opacity * 0.75),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

private struct RunningStepGlyph: View {
    var reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(FaroPalette.info.opacity(0.1))
                .frame(width: 46, height: 46)

            if reduceMotion {
                ProgressView()
                    .scaleEffect(0.78)
                    .tint(FaroPalette.info)
            } else {
                Circle()
                    .stroke(FaroPalette.info.opacity(0.32), lineWidth: 1.5)
                    .frame(width: 46, height: 46)
                    .phaseAnimator([false, true]) { content, phase in
                        content
                            .scaleEffect(phase ? 1.52 : 1)
                            .opacity(phase ? 0 : 0.95)
                    } animation: { _ in
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                    }

                Circle()
                    .stroke(FaroPalette.purpleDeep.opacity(0.2), lineWidth: 1)
                    .frame(width: 46, height: 46)
                    .phaseAnimator([false, true]) { content, phase in
                        content
                            .scaleEffect(phase ? 1.78 : 1)
                            .opacity(phase ? 0 : 0.6)
                    } animation: { _ in
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false)
                    }

                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FaroPalette.info, FaroPalette.purpleDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
            }
        }
        .frame(width: 46, height: 46)
    }
}

// MARK: - Step Card

struct StepCard: View {
    let step: AgentStep
    let update: StepUpdate?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    RunningStepGlyph(reduceMotion: reduceMotion)
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
                    Text("Reasoning with your inputs…")
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
