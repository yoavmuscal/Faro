import SwiftUI
import Charts
import AVFoundation

/// Presents `ActivityShareSheet` after PDF generation.
private struct PDFShareDocument: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - View Model

@MainActor
final class CoverageDashboardViewModel: ObservableObject {
    @Published var isPlayingAudio = false
    @Published var isPreparingAudio = false
    @Published var isGeneratingPDF = false
    @Published var audioErrorMessage: String?

    private var audioPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var downloadedAudioURL: URL?
    private var audioLoadTask: Task<Void, Never>?
    let results: ResultsResponse

    init(results: ResultsResponse) {
        self.results = results
    }

    func preparePlaybackSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback may still work with default session; ignore configuration errors.
        }
        #endif
    }

    func playVoiceSummary() {
        guard !results.voiceSummaryUrl.isEmpty else { return }
        preparePlaybackSession()
        audioErrorMessage = nil
        isPreparingAudio = true
        audioLoadTask?.cancel()
        removeAudioObserver()

        audioLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let localURL = try await APIService.shared.downloadAuthenticatedFile(from: results.voiceSummaryUrl)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.configureAudioPlayer(fileURL: localURL)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isPreparingAudio = false
                    self.isPlayingAudio = false
                }
            } catch {
                await MainActor.run {
                    self.isPreparingAudio = false
                    self.isPlayingAudio = false
                    self.audioErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopAudio() {
        audioLoadTask?.cancel()
        audioLoadTask = nil
        audioPlayer?.pause()
        audioPlayer = nil
        removeAudioObserver()
        cleanupDownloadedAudio()
        isPreparingAudio = false
        isPlayingAudio = false
    }

    private func configureAudioPlayer(fileURL: URL) {
        cleanupDownloadedAudio()
        downloadedAudioURL = fileURL

        let item = AVPlayerItem(url: fileURL)
        audioPlayer = AVPlayer(playerItem: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlayingAudio = false
                self?.isPreparingAudio = false
            }
        }

        audioPlayer?.play()
        isPreparingAudio = false
        isPlayingAudio = true
    }

    private func removeAudioObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func cleanupDownloadedAudio() {
        if let downloadedAudioURL {
            try? FileManager.default.removeItem(at: downloadedAudioURL)
            self.downloadedAudioURL = nil
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        audioLoadTask?.cancel()
        if let downloadedAudioURL {
            try? FileManager.default.removeItem(at: downloadedAudioURL)
        }
    }
}

// MARK: - Dashboard

struct CoverageDashboardView: View {
    let results: ResultsResponse
    let sessionId: String
    let businessName: String

    @StateObject private var vm: CoverageDashboardViewModel
    @State private var pdfURL: URL?
    @State private var pdfShareDocument: PDFShareDocument?
    @State private var showCoverageDetail: CoverageOption?

    init(results: ResultsResponse, sessionId: String, businessName: String = "Business") {
        self.results = results
        self.sessionId = sessionId
        self.businessName = businessName
        _vm = StateObject(wrappedValue: CoverageDashboardViewModel(results: results))
    }

    private var sortedCoverage: [CoverageOption] {
        let order: [CoverageCategory] = [.required, .recommended, .projected]
        return results.coverageOptions.sorted {
            (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
        }
    }

    private var totalPremiumLow: Double {
        results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumLow }
    }

    private var totalPremiumHigh: Double {
        results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumHigh }
    }

    private var avgConfidencePercent: Int {
        let opts = results.coverageOptions
        guard !opts.isEmpty else { return 0 }
        let sum = opts.map(\.confidence).reduce(0, +)
        return Int(sum / Double(opts.count) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                headerSection

                overviewRow

                premiumBarChart
                    .padding(.horizontal, FaroSpacing.md)

                Text("Coverage Options")
                    .font(FaroType.headline())
                    .foregroundStyle(FaroPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, FaroSpacing.md)

                coverageList(sortedCoverage: sortedCoverage)

                actionButtons
                    .padding(.horizontal, FaroSpacing.md)

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Coverage Analysis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            WidgetDataWriter.update(from: results, businessName: businessName)
            vm.preparePlaybackSession()
        }
        #if os(iOS)
        .sheet(item: $pdfShareDocument) { doc in
            ActivityShareSheet(activityItems: [doc.url])
        }
        #endif
        .sheet(item: $showCoverageDetail) { option in
            NavigationStack {
                CoverageDetailSheet(option: option)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                pdfToolbarButtons
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            Text(businessName.isEmpty ? "Your Coverage" : "\(businessName)")
                .font(FaroType.title())
                .foregroundStyle(FaroPalette.ink)

            HStack(spacing: FaroSpacing.sm) {
                let req = sortedCoverage.filter { $0.category == .required }.count
                let rec = sortedCoverage.filter { $0.category == .recommended }.count
                let proj = sortedCoverage.filter { $0.category == .projected }.count

                if req > 0 { TagPill(text: "\(req) required", icon: "exclamationmark.circle.fill", tint: FaroPalette.danger) }
                if rec > 0 { TagPill(text: "\(rec) recommended", icon: "star.fill", tint: FaroPalette.warning) }
                if proj > 0 { TagPill(text: "\(proj) projected", icon: "arrow.up.right", tint: FaroPalette.purple) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FaroSpacing.md)
    }

    private var overviewRow: some View {
        HStack(spacing: FaroSpacing.sm + 2) {
            StatCard(
                title: "Policies",
                value: "\(results.coverageOptions.count)",
                icon: "shield.checkered",
                tint: FaroPalette.purpleDeep
            )
            StatCard(
                title: "Est. Total",
                value: "$\(Int(totalPremiumLow).formatted())–$\(Int(totalPremiumHigh).formatted())",
                icon: "dollarsign.circle.fill",
                tint: FaroPalette.success
            )
            StatCard(
                title: "Confidence",
                value: "\(avgConfidencePercent)%",
                icon: "chart.bar.fill",
                tint: FaroPalette.info
            )
        }
        .padding(.horizontal, FaroSpacing.md)
    }

    private var premiumBarChart: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text("Premium Estimates")
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)

            Chart(sortedCoverage) { option in
                BarMark(
                    x: .value("Premium", option.premiumMidpoint),
                    y: .value("Type", option.type)
                )
                .foregroundStyle(categoryTint(option.category).gradient)
                .cornerRadius(8)
                .annotation(position: .trailing) {
                    Text("$\(Int(option.premiumMidpoint).formatted())")
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.ink.opacity(0.6))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(FaroType.caption2())
                }
            }
            .frame(height: CGFloat(sortedCoverage.count) * 44 + 20)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    @ViewBuilder
    private func coverageList(sortedCoverage: [CoverageOption]) -> some View {
        VStack(spacing: FaroSpacing.sm + 2) {
            ForEach(sortedCoverage) { option in
                Button {
                    showCoverageDetail = option
                } label: {
                    CoverageListRow(option: option)
                }
                .buttonStyle(.faroScale)
            }
        }
        .padding(.horizontal, FaroSpacing.md)
    }

    @ViewBuilder
    private var pdfToolbarButtons: some View {
        Button {
            Task { await exportPDF() }
        } label: {
            Label("Export PDF", systemImage: "arrow.up.doc.fill")
        }
        .disabled(vm.isGeneratingPDF)
    }

    private var actionButtons: some View {
        VStack(spacing: FaroSpacing.sm + 2) {
            Button {
                if vm.isPlayingAudio { vm.stopAudio() } else { vm.playVoiceSummary() }
            } label: {
                Group {
                    if vm.isPreparingAudio {
                        HStack(spacing: FaroSpacing.sm) {
                            ProgressView()
                            Text("Loading summary...")
                        }
                    } else {
                        Label(
                            vm.isPlayingAudio ? "Stop" : "Hear your summary",
                            systemImage: vm.isPlayingAudio ? "stop.fill" : "speaker.wave.2.fill"
                        )
                    }
                }
                .font(FaroType.headline())
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.faroGradient)
            .disabled(results.voiceSummaryUrl.isEmpty || vm.isPreparingAudio)

            if let audioErrorMessage = vm.audioErrorMessage {
                Text(audioErrorMessage)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await exportPDF() }
            } label: {
                Label(vm.isGeneratingPDF ? "Generating PDF…" : "Export full PDF", systemImage: "arrow.up.doc.fill")
                    .font(FaroType.headline())
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.faroGlassProminent)
            .disabled(vm.isGeneratingPDF)
        }
    }

    private func exportPDF() async {
        vm.isGeneratingPDF = true
        defer { vm.isGeneratingPDF = false }
        guard let url = PDFBuilder.build(from: results, businessName: businessName) else { return }
        pdfURL = url
        pdfShareDocument = PDFShareDocument(url: url)
    }

    private func categoryTint(_ category: CoverageCategory) -> Color {
        switch category {
        case .required: return FaroPalette.danger
        case .recommended: return FaroPalette.warning
        case .projected: return FaroPalette.purple
        }
    }
}

// MARK: - Coverage List Row

struct CoverageListRow: View {
    let option: CoverageOption

    private var categoryColor: Color {
        switch option.category {
        case .required: return FaroPalette.danger
        case .recommended: return FaroPalette.warning
        case .projected: return FaroPalette.purple
        }
    }

    private var categoryLabel: String {
        switch option.category {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
    }

    private var confidenceColor: Color {
        switch option.confidence {
        case 0.8...: return FaroPalette.success
        case 0.5..<0.8: return FaroPalette.warning
        default: return FaroPalette.ink.opacity(0.4)
        }
    }

    var body: some View {
        HStack(spacing: FaroSpacing.sm + 2) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(categoryColor.gradient)
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.type)
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.ink)

                HStack(spacing: 6) {
                    Text(categoryLabel)
                        .font(FaroType.caption2(.bold))
                        .foregroundStyle(categoryColor)

                    Text("·")
                        .foregroundStyle(FaroPalette.ink.opacity(0.3))

                    Text(option.description)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("$\(Int(option.estimatedPremiumLow).formatted())–$\(Int(option.estimatedPremiumHigh).formatted())")
                    .font(FaroType.caption(.bold))
                    .foregroundStyle(FaroPalette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                HStack(spacing: 3) {
                    Circle().fill(confidenceColor).frame(width: 6, height: 6)
                    Text("\(Int(option.confidence * 100))%")
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(FaroPalette.ink.opacity(0.3))
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.lg)
    }
}

// MARK: - Coverage Detail Sheet

struct CoverageDetailSheet: View {
    let option: CoverageOption
    @Environment(\.dismiss) private var dismiss

    private var categoryColor: Color {
        switch option.category {
        case .required: return FaroPalette.danger
        case .recommended: return FaroPalette.warning
        case .projected: return FaroPalette.purple
        }
    }

    private var confidenceColor: Color {
        switch option.confidence {
        case 0.8...: return FaroPalette.success
        case 0.5..<0.8: return FaroPalette.warning
        default: return FaroPalette.ink.opacity(0.4)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                    HStack {
                        Text(option.category.rawValue.capitalized)
                            .font(FaroType.caption(.bold))
                            .foregroundStyle(categoryColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(categoryColor.opacity(0.14))
                            .clipShape(Capsule())

                        Spacer()

                        HStack(spacing: 4) {
                            Circle().fill(confidenceColor).frame(width: 8, height: 8)
                            Text("\(Int(option.confidence * 100))% confidence")
                                .font(FaroType.caption())
                                .foregroundStyle(FaroPalette.ink.opacity(0.55))
                        }
                    }

                    Text(option.type)
                        .font(FaroType.title2())
                        .foregroundStyle(FaroPalette.ink)
                }

                Text(option.description)
                    .font(FaroType.body())
                    .foregroundStyle(FaroPalette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                    Text("Estimated Annual Premium")
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.ink)

                    HStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("Low")
                                .font(FaroType.caption2())
                                .foregroundStyle(FaroPalette.ink.opacity(0.4))
                            Text("$\(Int(option.estimatedPremiumLow).formatted())")
                                .font(FaroType.title3())
                                .foregroundStyle(FaroPalette.success)
                        }
                        Spacer()
                        VStack {
                            Text("Mid")
                                .font(FaroType.caption2())
                                .foregroundStyle(FaroPalette.ink.opacity(0.4))
                            Text("$\(Int(option.premiumMidpoint).formatted())")
                                .font(FaroType.title3())
                                .foregroundStyle(FaroPalette.ink)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("High")
                                .font(FaroType.caption2())
                                .foregroundStyle(FaroPalette.ink.opacity(0.4))
                            Text("$\(Int(option.estimatedPremiumHigh).formatted())")
                                .font(FaroType.title3())
                                .foregroundStyle(FaroPalette.danger)
                        }
                    }
                    .padding(FaroSpacing.md)
                    .faroGlassCard(cornerRadius: FaroRadius.lg)
                }

                if let trigger = option.triggerEvent {
                    VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                        Text("Trigger Event")
                            .font(FaroType.headline())
                            .foregroundStyle(FaroPalette.ink)
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(FaroPalette.purpleDeep)
                            Text(trigger)
                                .font(FaroType.subheadline())
                                .foregroundStyle(FaroPalette.ink.opacity(0.75))
                        }
                        .padding(FaroSpacing.sm + 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FaroPalette.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous))
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle(option.type)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: FaroSpacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.gradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: tint.opacity(0.25), radius: 8, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(value)
                .font(FaroType.subheadline(.bold))
                .foregroundStyle(FaroPalette.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(title)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FaroSpacing.md + 4)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

extension CoverageCategory {
    var label: String {
        switch self {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
    }
}

// MARK: - Glass button style

struct FaroGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(FaroPalette.ink)
            .background(
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .fill(FaroPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .fill(FaroPalette.purple.opacity(configuration.isPressed ? 0.14 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke.opacity(0.55), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FaroGlassProminentButtonStyle {
    static var faroGlassProminent: FaroGlassProminentButtonStyle { FaroGlassProminentButtonStyle() }
}

// MARK: - CoverageOption Identifiable for sheet

extension CoverageOption: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }

    public static func == (lhs: CoverageOption, rhs: CoverageOption) -> Bool {
        lhs.type == rhs.type
    }
}

#Preview {
    NavigationStack {
        CoverageDashboardView(
            results: ResultsResponse(
                coverageOptions: [
                    CoverageOption(type: "General Liability", description: "Covers third-party bodily injury and property damage claims.", estimatedPremiumLow: 800, estimatedPremiumHigh: 1500, confidence: 0.95, category: .required, triggerEvent: nil),
                    CoverageOption(type: "Workers Compensation", description: "Required by NJ law for any business with employees.", estimatedPremiumLow: 2000, estimatedPremiumHigh: 4000, confidence: 0.99, category: .required, triggerEvent: nil),
                    CoverageOption(type: "Cyber Liability", description: "Covers data breaches, ransomware, and regulatory fines.", estimatedPremiumLow: 1200, estimatedPremiumHigh: 3000, confidence: 0.80, category: .recommended, triggerEvent: nil),
                    CoverageOption(type: "EPLI", description: "Protects against wrongful termination, discrimination, and harassment claims.", estimatedPremiumLow: 1500, estimatedPremiumHigh: 4000, confidence: 0.72, category: .projected, triggerEvent: "Trigger: Headcount projected to exceed 15 employees"),
                ],
                submissionPacketUrl: "",
                voiceSummaryUrl: "",
                riskProfile: nil,
                submissionPacket: nil,
                plainEnglishSummary: nil
            ),
            sessionId: "preview"
        )
    }
}
