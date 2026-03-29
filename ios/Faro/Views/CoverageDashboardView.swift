import SwiftUI
import Charts
import AVFoundation

/// Presents `ActivityShareSheet` after PDF generation.
private struct PDFShareDocument: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PremiumSlice: Identifiable {
    let id: String
    let name: String
    let value: Double
    let color: Color
}

// MARK: - View Model

@MainActor
final class CoverageDashboardViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isPlayingAudio = false
    @Published var isGeneratingPDF = false

    private var audioPlayer: AVPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var itemErrorObservation: NSKeyValueObservation?
    let results: ResultsResponse

    override init() {
        fatalError("Use init(results:)")
    }

    init(results: ResultsResponse) {
        self.results = results
        super.init()
        speechSynthesizer.delegate = self
    }

    var canPlaySummary: Bool {
        !results.voiceSummaryUrl.isEmpty || !(results.plainEnglishSummary ?? "").isEmpty
    }

    func preparePlaybackSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        #endif
    }

    func playVoiceSummary() {
        if !results.voiceSummaryUrl.isEmpty {
            playRemoteAudio()
        } else if let text = results.plainEnglishSummary, !text.isEmpty {
            speakText(text)
        }
    }

    private func playRemoteAudio() {
        preparePlaybackSession()
        isPlayingAudio = true

        let urlString: String
        if results.voiceSummaryUrl.hasPrefix("/") {
            urlString = APIConfig.httpBaseURL + results.voiceSummaryUrl
        } else {
            urlString = results.voiceSummaryUrl
        }

        guard let url = URL(string: urlString) else {
            fallbackToSpeech()
            return
        }
        let item = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: item)

        itemErrorObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor in self?.fallbackToSpeech() }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlayingAudio = false }
        }
        audioPlayer?.play()
    }

    private func fallbackToSpeech() {
        audioPlayer?.pause()
        audioPlayer = nil
        itemErrorObservation = nil
        if let text = results.plainEnglishSummary, !text.isEmpty {
            speakText(text)
        } else {
            isPlayingAudio = false
        }
    }

    private func speakText(_ text: String) {
        preparePlaybackSession()
        isPlayingAudio = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    func stopAudio() {
        audioPlayer?.pause()
        audioPlayer = nil
        itemErrorObservation = nil
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isPlayingAudio = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isPlayingAudio = false }
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
    @State private var dashboardAppeared = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(results: ResultsResponse, sessionId: String, businessName: String = "Business") {
        self.results = results
        self.sessionId = sessionId
        self.businessName = businessName
        _vm = StateObject(wrappedValue: CoverageDashboardViewModel(results: results))
    }

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

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

    private var avgConfidence: Double {
        let opts = results.coverageOptions
        guard !opts.isEmpty else { return 0 }
        return opts.map(\.confidence).reduce(0, +) / Double(opts.count)
    }

    private var premiumSlices: [PremiumSlice] {
        let order: [CoverageCategory] = [.required, .recommended, .projected]
        return order.compactMap { cat -> PremiumSlice? in
            let sum = sortedCoverage.filter { $0.category == cat }.map(\.premiumMidpoint).reduce(0, +)
            guard sum > 0 else { return nil }
            return PremiumSlice(
                id: cat.rawValue,
                name: cat.label,
                value: sum,
                color: categoryTint(cat)
            )
        }
    }

    private var requiredOptions: [CoverageOption] {
        sortedCoverage.filter { $0.category == .required }
    }

    private var widestRangeOption: CoverageOption? {
        sortedCoverage.max(by: {
            ($0.estimatedPremiumHigh - $0.estimatedPremiumLow) < ($1.estimatedPremiumHigh - $1.estimatedPremiumLow)
        })
    }

    private var topPremiumOption: CoverageOption? {
        sortedCoverage.max(by: { $0.premiumMidpoint < $1.premiumMidpoint })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isWideLayout ? FaroSpacing.xl : FaroSpacing.lg) {
                if isWideLayout {
                    iPadDashboardContent
                } else {
                    phoneDashboardContent
                }
            }
            .padding(.top, isWideLayout ? FaroSpacing.lg : FaroSpacing.md)
            .padding(.bottom, FaroSpacing.xl)
        }
        .faroCanvasBackground()
        .navigationTitle("Coverage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            WidgetDataWriter.update(from: results, businessName: businessName)
            vm.preparePlaybackSession()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                dashboardAppeared = true
            }
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

    // MARK: - Layouts

    private var horizontalPagePadding: CGFloat { isWideLayout ? FaroSpacing.xl : FaroSpacing.md }

    private var iPadDashboardContent: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xl) {
            dashboardHero
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 14)

            metricStrip
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 18)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.04), value: dashboardAppeared)

            HStack(alignment: .top, spacing: FaroSpacing.lg) {
                premiumMixColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                confidenceInsightColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(dashboardAppeared ? 1 : 0)
            .offset(y: dashboardAppeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08), value: dashboardAppeared)

            premiumRangeChartCard
                .opacity(dashboardAppeared ? 1 : 0)
            .offset(y: dashboardAppeared ? 0 : 22)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.12), value: dashboardAppeared)

            HStack(alignment: .top, spacing: FaroSpacing.lg) {
                coverageGapsCard
                    .frame(maxWidth: .infinity)
                snapshotActivityCard
                    .frame(maxWidth: .infinity)
            }
            .opacity(dashboardAppeared ? 1 : 0)
            .offset(y: dashboardAppeared ? 0 : 24)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.16), value: dashboardAppeared)

            coverageOptionsSectionHeader

            coverageList(sortedCoverage: sortedCoverage)

            actionButtons
        }
        .padding(.horizontal, horizontalPagePadding)
    }

    private var phoneDashboardContent: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg) {
            dashboardHero
            metricStrip
            premiumMixCard(maxWidth: 320, stackVertically: true)
            confidenceInsightCard
            premiumRangeChartCard
            coverageGapsCard
            snapshotActivityCard
            coverageOptionsSectionHeader
            coverageList(sortedCoverage: sortedCoverage)
            actionButtons
        }
        .padding(.horizontal, horizontalPagePadding)
    }

    // MARK: - Hero & metrics

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: FaroSpacing.sm) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 36, height: 5)
                Text("Analysis")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.purpleDeep.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(businessName.isEmpty ? "Your coverage" : businessName)
                .font(isWideLayout ? FaroType.largeTitle() : FaroType.title())
                .foregroundStyle(FaroPalette.ink)
                .multilineTextAlignment(.leading)

            Text("Premium estimates, confidence, and priority mix in one place.")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.5))
                .frame(maxWidth: isWideLayout ? 520 : .infinity, alignment: .leading)

            FlowLayout(spacing: FaroSpacing.sm) {
                let req = sortedCoverage.filter { $0.category == .required }.count
                let rec = sortedCoverage.filter { $0.category == .recommended }.count
                let proj = sortedCoverage.filter { $0.category == .projected }.count

                if req > 0 { TagPill(text: "\(req) required", icon: "exclamationmark.circle.fill", tint: FaroPalette.danger) }
                if rec > 0 { TagPill(text: "\(rec) recommended", icon: "star.fill", tint: FaroPalette.warning) }
                if proj > 0 { TagPill(text: "\(proj) projected", icon: "arrow.up.right", tint: FaroPalette.purple) }
            }
            .padding(.top, FaroSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricStrip: some View {
        Group {
            if isWideLayout {
                HStack(alignment: .top, spacing: FaroSpacing.md) {
                    metricTiles
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FaroSpacing.md) {
                        metricTiles
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var metricTiles: some View {
        Group {
            DashboardMetricTile(
                title: "Policies",
                value: "\(results.coverageOptions.count)",
                subtitle: "lines reviewed",
                icon: "shield.checkered",
                tint: FaroPalette.purpleDeep
            )
            .frame(maxWidth: .infinity, minHeight: isWideLayout ? 132 : nil, alignment: .topLeading)
            .frame(minWidth: isWideLayout ? 0 : 148)
            DashboardMetricTile(
                title: "Est. annual",
                value: "$\(Int(totalPremiumLow).formatted())–$\(Int(totalPremiumHigh).formatted())",
                subtitle: "combined range",
                icon: "dollarsign.circle.fill",
                tint: FaroPalette.success
            )
            .frame(maxWidth: .infinity, minHeight: isWideLayout ? 132 : nil, alignment: .topLeading)
            .frame(minWidth: isWideLayout ? 0 : 168)
            DashboardMetricTile(
                title: "Confidence",
                value: "\(avgConfidencePercent)%",
                subtitle: "avg. model fit",
                icon: "chart.line.uptrend.xyaxis",
                tint: FaroPalette.info
            )
            .frame(maxWidth: .infinity, minHeight: isWideLayout ? 132 : nil, alignment: .topLeading)
            .frame(minWidth: isWideLayout ? 0 : 148)
        }
    }

    // MARK: - Charts (iPad columns)

    /// iPad: full column width + vertical chart/legend so labels never get squeezed to zero width.
    private var premiumMixColumn: some View {
        premiumMixCard(maxWidth: .infinity, stackVertically: true)
    }

    private func premiumMixCard(maxWidth: CGFloat, stackVertically: Bool = false) -> some View {
        let chartSide: CGFloat = {
            if stackVertically {
                return min(240, max(200, maxWidth.isFinite ? maxWidth - FaroSpacing.lg * 2 : 220))
            }
            return min(maxWidth.isFinite ? maxWidth * 0.45 : 200, 220)
        }()
        return VStack(alignment: .leading, spacing: FaroSpacing.md) {
            sectionTitle("Premium by priority", subtitle: "Share of estimated premium")

            if premiumSlices.isEmpty {
                Text("No premium data yet.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                Group {
                    if stackVertically {
                        VStack(alignment: .center, spacing: FaroSpacing.md) {
                            premiumDonutChart(side: chartSide)
                            premiumMixLegend
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        HStack(alignment: .center, spacing: FaroSpacing.lg) {
                            premiumDonutChart(side: chartSide)
                            premiumMixLegend
                                .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1)
                        }
                    }
                }
            }
        }
        .faroCoverageDashboardCardSurface(maxOuterWidth: maxWidth.isInfinite ? nil : maxWidth)
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), FaroPalette.purple.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func premiumDonutChart(side: CGFloat) -> some View {
        Chart(premiumSlices) { slice in
            SectorMark(
                angle: .value("Premium", slice.value),
                innerRadius: .ratio(0.58),
                angularInset: 2
            )
            .foregroundStyle(slice.color.gradient)
            .cornerRadius(3)
        }
        .frame(width: side, height: side)
        .chartBackground { _ in
            Circle()
                .fill(FaroPalette.purpleDeep.opacity(0.04))
        }
        .animation(.smooth(duration: 0.65), value: premiumSlices.map(\.value))
    }

    private var premiumMixLegend: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            ForEach(premiumSlices) { slice in
                HStack(alignment: .center, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.name)
                        .font(FaroType.caption(.semibold))
                        .foregroundStyle(FaroPalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(slice.value, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(FaroType.caption(.bold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confidenceInsightColumn: some View {
        confidenceInsightCard
    }

    private var confidenceInsightCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            sectionTitle("Model confidence", subtitle: "Per line confidence trend")

            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                Gauge(value: avgConfidence) {
                    Text("Average")
                        .font(FaroType.caption2(.semibold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                } currentValueLabel: {
                    Text("\(avgConfidencePercent)%")
                        .font(FaroType.title3(.bold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(
                    LinearGradient(
                        colors: [FaroPalette.info, FaroPalette.purpleDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                Chart(Array(sortedCoverage.enumerated()), id: \.element.id) { index, option in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Confidence", option.confidence)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(FaroPalette.purpleDeep.gradient)

                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Confidence", option.confidence)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FaroPalette.purpleDeep.opacity(0.28), FaroPalette.purpleDeep.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(FaroPalette.ink.opacity(0.08))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(FaroType.caption2())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.4))
                            }
                        }
                    }
                }
                .frame(height: isWideLayout ? 220 : 120)
                .frame(maxWidth: .infinity)
                .animation(.smooth(duration: 0.7), value: sortedCoverage.count)
            }
            .frame(maxWidth: .infinity, minHeight: isWideLayout ? 300 : nil, alignment: .topLeading)
        }
        .faroCoverageDashboardCardSurface()
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), FaroPalette.info.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var premiumRangeChartCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            sectionTitle("Premium bands", subtitle: "Low–high estimate by line")

            if sortedCoverage.isEmpty {
                Text("No premium data yet.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                PremiumBandsTable(
                    options: sortedCoverage,
                    isWideLayout: isWideLayout,
                    categoryTint: categoryTint
                )
            }
        }
        .faroCoverageDashboardCardSurface()
    }

    // MARK: - Insight cards

    private var coverageGapsCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.sm) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(FaroPalette.danger)
                sectionTitle("Coverage gaps", subtitle: "Required items to address first")
            }

            if requiredOptions.isEmpty {
                Text("No required gaps flagged — review recommended lines to strengthen protection.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                    ForEach(requiredOptions.prefix(5)) { opt in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(FaroPalette.danger.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.type)
                                    .font(FaroType.subheadline(.semibold))
                                    .foregroundStyle(FaroPalette.ink)
                                Text(opt.description)
                                    .font(FaroType.caption())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                                    .lineLimit(2)
                            }
                        }
                    }
                    if requiredOptions.count > 5 {
                        Text("+ \(requiredOptions.count - 5) more required")
                            .font(FaroType.caption(.semibold))
                            .foregroundStyle(FaroPalette.purpleDeep)
                    }
                }
            }
        }
        .faroCoverageDashboardCardSurface()
    }

    private var snapshotActivityCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(FaroPalette.purpleDeep)
                sectionTitle("Snapshot", subtitle: "Highest-impact lines")
            }

            VStack(alignment: .leading, spacing: FaroSpacing.md) {
                snapshotRow(
                    title: "Largest premium",
                    value: topPremiumOption?.type ?? "—",
                    detail: topPremiumOption.map { opt in
                        "$\(Int(opt.premiumMidpoint).formatted()) est."
                    } ?? ""
                )
                snapshotRow(
                    title: "Widest uncertainty",
                    value: widestRangeOption?.type ?? "—",
                    detail: widestRangeOption.map { opt in
                        "$\(Int(opt.estimatedPremiumLow).formatted())–$\(Int(opt.estimatedPremiumHigh).formatted())"
                    } ?? ""
                )
                snapshotRow(
                    title: "Total exposure band",
                    value: "$\(Int(totalPremiumLow).formatted())–$\(Int(totalPremiumHigh).formatted())",
                    detail: "Across \(results.coverageOptions.count) policies"
                )
            }
        }
        .faroCoverageDashboardCardSurface()
    }

    private func snapshotRow(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(FaroType.caption2(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.38))
                .tracking(0.4)
            Text(value)
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)
                .lineLimit(2)
            if !detail.isEmpty {
                Text(detail)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FaroSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .fill(FaroPalette.surface.opacity(0.5))
        )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)
            Text(subtitle)
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
        }
    }

    private var coverageOptionsSectionHeader: some View {
        HStack {
            Text("All coverages")
                .font(FaroType.title3())
                .foregroundStyle(FaroPalette.ink)
            Spacer()
            Text("\(sortedCoverage.count) lines")
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.4))
        }
        .padding(.top, FaroSpacing.sm)
        .padding(.horizontal, FaroSpacing.lg)
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
                Label(
                    vm.isPlayingAudio ? "Stop" : "Hear your summary",
                    systemImage: vm.isPlayingAudio ? "stop.fill" : "speaker.wave.2.fill"
                )
                .font(FaroType.headline())
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.faroGradient)
            .disabled(!vm.canPlaySummary)

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

// MARK: - Dashboard card surface (aligned padding / width)

private extension View {
    /// Consistent inner padding and glass card so Coverage dashboard tiles line up on iPad.
    func faroCoverageDashboardCardSurface(maxOuterWidth: CGFloat? = nil) -> some View {
        self
            .padding(FaroSpacing.lg)
            .frame(maxWidth: maxOuterWidth ?? .infinity, alignment: .leading)
            .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

// MARK: - Premium bands table (aligned rows; fixes Chart Y-axis / bar center mismatch)

private struct PremiumBandsTable: View {
    let options: [CoverageOption]
    let isWideLayout: Bool
    let categoryTint: (CoverageCategory) -> Color

    private var maxDomain: Double {
        let peak = options.map(\.estimatedPremiumHigh).max() ?? 1
        return max(peak * 1.06, 1)
    }

    private var labelColumnWidth: CGFloat { isWideLayout ? 272 : 156 }
    private var valueColumnWidth: CGFloat { isWideLayout ? 108 : 96 }
    private var barHeight: CGFloat { isWideLayout ? 22 : 20 }
    private var rowVerticalPadding: CGFloat { isWideLayout ? 10 : 8 }
    private var columnGap: CGFloat { FaroSpacing.md }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                PremiumBandRow(
                    option: option,
                    maxDomain: maxDomain,
                    labelWidth: labelColumnWidth,
                    valueWidth: valueColumnWidth,
                    barHeight: barHeight,
                    rowPadding: rowVerticalPadding,
                    columnGap: columnGap,
                    categoryTint: categoryTint,
                    stripe: index.isMultiple(of: 2)
                )

                if index < options.count - 1 {
                    Rectangle()
                        .fill(FaroPalette.ink.opacity(0.1))
                        .frame(height: 0.5)
                        .padding(.leading, labelColumnWidth + columnGap)
                }
            }

            premiumAxisRow
                .padding(.top, FaroSpacing.sm)
        }
    }

    private var premiumAxisRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: columnGap) {
            Color.clear
                .frame(width: labelColumnWidth)
                .accessibilityHidden(true)

            HStack {
                Text("$0")
                Spacer(minLength: 8)
                Text(maxDomain / 2, format: .currency(code: "USD").precision(.fractionLength(0)))
                Spacer(minLength: 8)
                Text(maxDomain, format: .currency(code: "USD").precision(.fractionLength(0)))
            }
            .font(FaroType.caption2())
            .foregroundStyle(FaroPalette.ink.opacity(0.42))
            .monospacedDigit()
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: valueColumnWidth)
                .accessibilityHidden(true)
        }
    }
}

private struct PremiumBandRow: View {
    let option: CoverageOption
    let maxDomain: Double
    let labelWidth: CGFloat
    let valueWidth: CGFloat
    let barHeight: CGFloat
    let rowPadding: CGFloat
    let columnGap: CGFloat
    let categoryTint: (CoverageCategory) -> Color
    let stripe: Bool

    var body: some View {
        HStack(alignment: .center, spacing: columnGap) {
            Text(option.type)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: labelWidth, alignment: .leading)
                .layoutPriority(1)

            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let lowX = (option.estimatedPremiumLow / maxDomain) * w
                let highX = (option.estimatedPremiumHigh / maxDomain) * w
                let barW = max(highX - lowX, 5)
                let tint = categoryTint(option.category)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(FaroPalette.ink.opacity(0.07))
                        .frame(height: barHeight)

                    ForEach([0.25, 0.5, 0.75], id: \.self) { frac in
                        Rectangle()
                            .fill(FaroPalette.ink.opacity(0.06))
                            .frame(width: 1, height: barHeight)
                            .offset(x: CGFloat(frac) * w - 0.5)
                    }

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barW, height: barHeight)
                        .offset(x: lowX)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: max(barHeight, 28))
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(option.premiumMidpoint).formatted())")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                    .monospacedDigit()
                Text("$\(Int(option.estimatedPremiumLow).formatted())–$\(Int(option.estimatedPremiumHigh).formatted())")
                    .font(FaroType.caption2())
                    .foregroundStyle(FaroPalette.ink.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }
            .frame(width: valueWidth, alignment: .trailing)
        }
        .padding(.vertical, rowPadding)
        .background(stripe ? FaroPalette.purpleDeep.opacity(0.04) : Color.clear)
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

                if !option.resolvedCarriers.isEmpty {
                    Text("e.g. \(option.resolvedCarriers.joined(separator: ", "))")
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.purpleDeep.opacity(0.6))
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

                if !option.resolvedCarriers.isEmpty {
                    VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                        Text("Sample Carriers")
                            .font(FaroType.headline())
                            .foregroundStyle(FaroPalette.ink)

                        FlowLayout(spacing: 8) {
                            ForEach(option.resolvedCarriers, id: \.self) { carrier in
                                Text(carrier)
                                    .font(FaroType.caption(.semibold))
                                    .foregroundStyle(FaroPalette.purpleDeep)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(FaroPalette.purpleDeep.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(FaroPalette.purpleDeep.opacity(0.2), lineWidth: 0.5)
                                    }
                            }
                        }
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

// MARK: - Dashboard metric tile

private struct DashboardMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            HStack(spacing: FaroSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(tint.gradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: tint.opacity(0.28), radius: 10, y: 3)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }

            Text(value)
                .font(FaroType.title3(.bold))
                .foregroundStyle(FaroPalette.ink)
                .minimumScaleFactor(0.55)
                .lineLimit(2)

            Text(title)
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.55))

            Text(subtitle)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.38))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FaroSpacing.md + 2)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.14), FaroPalette.surface.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), tint.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
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
                    CoverageOption(type: "General Liability", description: "Covers third-party bodily injury and property damage claims.", estimatedPremiumLow: 800, estimatedPremiumHigh: 1500, confidence: 0.95, category: .required, triggerEvent: nil, exampleCarriers: nil),
                    CoverageOption(type: "Workers Compensation", description: "Required by NJ law for any business with employees.", estimatedPremiumLow: 2000, estimatedPremiumHigh: 4000, confidence: 0.99, category: .required, triggerEvent: nil, exampleCarriers: nil),
                    CoverageOption(type: "Cyber Liability", description: "Covers data breaches, ransomware, and regulatory fines.", estimatedPremiumLow: 1200, estimatedPremiumHigh: 3000, confidence: 0.80, category: .recommended, triggerEvent: nil, exampleCarriers: nil),
                    CoverageOption(type: "EPLI", description: "Protects against wrongful termination, discrimination, and harassment claims.", estimatedPremiumLow: 1500, estimatedPremiumHigh: 4000, confidence: 0.72, category: .projected, triggerEvent: "Trigger: Headcount projected to exceed 15 employees", exampleCarriers: nil),
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
