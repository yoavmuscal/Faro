import SwiftUI
import Charts
import QuickLook
#if canImport(UIKit)
import UIKit
#endif

private struct PremiumSlice: Identifiable {
    let id: String
    let name: String
    let value: Double
    let color: Color
}

private struct AgentChatLine: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

/// Renders assistant replies that may contain Markdown (e.g. **bold**); falls back to plain text if parsing fails.
private func agentChatMarkdownAttributed(_ raw: String) -> AttributedString {
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .full
    if let attributed = try? AttributedString(markdown: raw, options: options) {
        return attributed
    }
    return AttributedString(raw)
}

private struct AgentChatLineRow: View {
    let line: AgentChatLine

    var body: some View {
        if line.isUser {
            HStack(alignment: .bottom, spacing: 0) {
                Spacer(minLength: 56)
                VStack(alignment: .trailing, spacing: 6) {
                    Text("You")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.42))
                    Text(line.text)
                        .font(FaroType.body())
                        .foregroundStyle(FaroPalette.ink)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                                .fill(FaroPalette.purpleDeep.opacity(0.12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous)
                                        .strokeBorder(FaroPalette.purpleDeep.opacity(0.28), lineWidth: 0.75)
                                }
                        }
                }
            }
        } else {
            HStack(alignment: .top, spacing: FaroSpacing.md) {
                ZStack {
                    Circle()
                        .fill(FaroPalette.purpleDeep.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Faro")
                        .font(FaroType.caption(.semibold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.48))
                    Text(agentChatMarkdownAttributed(line.text))
                        .font(FaroType.body())
                        .foregroundStyle(FaroPalette.ink.opacity(0.92))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
            }
        }
    }
}

// MARK: - Dashboard

struct CoverageDashboardView: View {
    let results: ResultsResponse
    let sessionId: String
    let businessName: String

    @State private var showCoverageDetail: CoverageOption?
    @State private var dashboardAppeared = false
    @State private var agentChatLines: [AgentChatLine] = []
    @State private var agentChatDraft = ""
    @State private var agentChatSending = false
    @State private var voiceDraftPrefix = ""
    @State private var voiceCaptureActive = false
    @State private var coverageVoiceConnecting = false
    @FocusState private var agentChatFocused: Bool
    @StateObject private var coverageChatSpeech = CoverageChatSpeechTranscriber()
    @StateObject private var coverageElevenLabs = ElevenLabsLiveConversationService()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var pdfPreviewURL: URL?
    @State private var isBuildingPDF = false
    @State private var showPDFExportFailed = false

    init(results: ResultsResponse, sessionId: String, businessName: String = "Business") {
        self.results = results
        self.sessionId = sessionId
        self.businessName = businessName
    }

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    /// Gives the message thread room to breathe and fills more of the card instead of a short strip.
    private var chatMessageAreaHeight: CGFloat {
        #if canImport(UIKit)
        let h = UIScreen.main.bounds.height
        return min(max(h * (isWideLayout ? 0.30 : 0.34), 260), 520)
        #else
        return 300
        #endif
    }

    /// Mic is actively capturing (on-device speech or live ElevenLabs session).
    private var coverageVoiceMicIsHot: Bool {
        if coverageChatSpeech.isRecording { return true }
        if voiceCaptureActive, case .connected = coverageElevenLabs.state { return true }
        return false
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    @ViewBuilder
    private var priorityBadgesRow: some View {
        let req = sortedCoverage.filter { $0.category == .required }.count
        let rec = sortedCoverage.filter { $0.category == .recommended }.count
        let proj = sortedCoverage.filter { $0.category == .projected }.count

        if req == 0 && rec == 0 && proj == 0 {
            EmptyView()
        } else {
            Group {
                if isWideLayout {
                    HStack(spacing: FaroSpacing.sm) {
                        if req > 0 {
                            TagPill(
                                text: "\(req) required",
                                icon: "exclamationmark.circle.fill",
                                tint: FaroPalette.danger,
                                expandToFillWidth: true
                            )
                        }
                        if rec > 0 {
                            TagPill(
                                text: "\(rec) recommended",
                                icon: "star.fill",
                                tint: FaroPalette.warning,
                                expandToFillWidth: true
                            )
                        }
                        if proj > 0 {
                            TagPill(
                                text: "\(proj) projected",
                                icon: "arrow.up.right",
                                tint: FaroPalette.purple,
                                expandToFillWidth: true
                            )
                        }
                    }
                } else {
                    FlowLayout(spacing: FaroSpacing.sm) {
                        if req > 0 {
                            TagPill(text: "\(req) required", icon: "exclamationmark.circle.fill", tint: FaroPalette.danger)
                        }
                        if rec > 0 {
                            TagPill(text: "\(rec) recommended", icon: "star.fill", tint: FaroPalette.warning)
                        }
                        if proj > 0 {
                            TagPill(text: "\(proj) projected", icon: "arrow.up.right", tint: FaroPalette.purple)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// When largest premium and widest band are the same policy, avoid repeating the name in Snapshot.
    private var snapshotWidestTitle: String {
        guard let w = widestRangeOption, let t = topPremiumOption else {
            return widestRangeOption?.type ?? "—"
        }
        if w.type == t.type {
            return "Same line as largest premium"
        }
        return w.type
    }

    /// Builds the export PDF on the main actor and presents Quick Look (toolbar + hero row).
    private func openPDFExport() {
        guard !isBuildingPDF else { return }
        isBuildingPDF = true
        let res = results
        let name = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            defer { isBuildingPDF = false }
            guard let url = PDFBuilder.build(from: res, businessName: name.isEmpty ? "Business" : name) else {
                showPDFExportFailed = true
                return
            }
            pdfPreviewURL = url
        }
    }

    private var pdfExportHeroRow: some View {
        Button(action: openPDFExport) {
            HStack(spacing: FaroSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                        .fill(FaroPalette.purpleDeep.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("PDF report")
                        .font(FaroType.subheadline(.semibold))
                        .foregroundStyle(FaroPalette.ink)
                    Text("Open a full branded export — preview, AirDrop, or save to Files")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if isBuildingPDF {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.35))
                }
            }
            .padding(FaroSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .fill(FaroPalette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                            .strokeBorder(FaroPalette.glassStroke.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBuildingPDF)
        .accessibilityLabel("View PDF report")
    }

    var body: some View {
        ScrollView {
            unifiedDashboardContent
                .padding(.top, isWideLayout ? FaroSpacing.lg : FaroSpacing.md)
                .padding(.bottom, FaroSpacing.xl)
        }
        .faroCanvasBackground()
        .navigationTitle("Coverage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openPDFExport) {
                    if isBuildingPDF {
                        ProgressView()
                    } else {
                        Label("PDF", systemImage: "doc.text.fill")
                    }
                }
                .disabled(isBuildingPDF)
                .accessibilityLabel("View PDF report")
            }
        }
        .quickLookPreview($pdfPreviewURL)
        .alert("Couldn’t create PDF", isPresented: $showPDFExportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        #endif
        .onAppear {
            WidgetDataWriter.update(from: results, businessName: businessName)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                dashboardAppeared = true
            }
        }
        .onDisappear {
            if coverageElevenLabs.state == .connected || coverageElevenLabs.state == .connecting {
                coverageElevenLabs.suppressAgentPlayback = false
                coverageElevenLabs.disconnect()
            }
        }
        .sheet(item: $showCoverageDetail) { option in
            NavigationStack {
                CoverageDetailSheet(option: option)
            }
        }
    }

    // MARK: - Layouts

    private var horizontalPagePadding: CGFloat { FaroSpacing.dashboardPageHorizontal(isWideLayout: isWideLayout) }

    private var unifiedDashboardContent: some View {
        let stackSpacing = isWideLayout ? FaroSpacing.xl : FaroSpacing.lg
        return VStack(alignment: .leading, spacing: stackSpacing) {
            dashboardHero
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: dashboardAppeared)

            metricStrip
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 18)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.04), value: dashboardAppeared)

            Group {
                if isWideLayout {
                    HStack(alignment: .top, spacing: FaroSpacing.lg) {
                        premiumMixColumn
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        confidenceInsightColumn
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                        premiumMixCard(maxWidth: .infinity, stackVertically: true, fillAvailableHeight: false)
                        confidenceInsightCard(fillAvailableHeight: false)
                    }
                }
            }
            .opacity(dashboardAppeared ? 1 : 0)
            .offset(y: dashboardAppeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08), value: dashboardAppeared)

            premiumRangeChartCard
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 22)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.12), value: dashboardAppeared)

            Group {
                if isWideLayout {
                    HStack(alignment: .top, spacing: FaroSpacing.lg) {
                        coverageGapsCard(fillAvailableHeight: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        snapshotActivityCard(fillAvailableHeight: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                        coverageGapsCard(fillAvailableHeight: false)
                        snapshotActivityCard(fillAvailableHeight: false)
                    }
                }
            }
            .opacity(dashboardAppeared ? 1 : 0)
            .offset(y: dashboardAppeared ? 0 : 24)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.16), value: dashboardAppeared)

            coverageAgentChatCard
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 26)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.18), value: dashboardAppeared)

            coverageOptionsSectionHeader
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 28)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.2), value: dashboardAppeared)

            coverageGallery(sortedCoverage: sortedCoverage)
                .opacity(dashboardAppeared ? 1 : 0)
                .offset(y: dashboardAppeared ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.22), value: dashboardAppeared)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPagePadding)
    }

    // MARK: - Hero & metrics

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text(timeBasedGreeting)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.45))

            HStack(alignment: .firstTextBaseline, spacing: FaroSpacing.sm) {
                Capsule()
                    .fill(
                        colorScheme == .dark
                            ? AnyShapeStyle(FaroPalette.purpleDeep.opacity(0.85))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
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

            Text("Premium estimates and priority mix for your business.")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.5))
                .frame(maxWidth: isWideLayout ? 520 : .infinity, alignment: .leading)

            priorityBadgesRow
                .padding(.top, FaroSpacing.xs)

            pdfExportHeroRow
                .padding(.top, FaroSpacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricStrip: some View {
        metricTiles
            .frame(maxWidth: .infinity)
    }

    private var metricTiles: some View {
        let tileMinHeight = FaroSpacing.dashboardMetricTileMinHeight(isWideLayout: isWideLayout)
        return HStack(alignment: .top, spacing: FaroSpacing.md) {
            FaroDashboardMetricTile(
                title: "Policies",
                value: "\(results.coverageOptions.count)",
                subtitle: "lines reviewed",
                icon: "shield.checkered",
                tint: FaroPalette.purpleDeep
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: tileMinHeight, alignment: .topLeading)

            FaroDashboardMetricTile(
                title: "Est. annual",
                value: "$\(Int(totalPremiumLow).formatted())–$\(Int(totalPremiumHigh).formatted())",
                subtitle: "combined range",
                icon: "dollarsign.circle.fill",
                tint: FaroPalette.success
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: tileMinHeight, alignment: .topLeading)
        }
    }

    // MARK: - Charts (iPad columns)

    /// iPad: full column width + vertical chart/legend so labels never get squeezed to zero width.
    private var premiumMixColumn: some View {
        premiumMixCard(maxWidth: .infinity, stackVertically: true, fillAvailableHeight: isWideLayout)
            .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func premiumMixCard(maxWidth: CGFloat, stackVertically: Bool = false, fillAvailableHeight: Bool = false) -> some View {
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

            if fillAvailableHeight {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .faroDashboardCardSurface(
            maxOuterWidth: maxWidth.isInfinite ? nil : maxWidth,
            fillAvailableHeight: fillAvailableHeight
        )
        .overlay { FaroDashboardCardOutline() }
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
                .fill(FaroPalette.purpleDeep.opacity(colorScheme == .dark ? 0.06 : 0.04))
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
        confidenceInsightCard(fillAvailableHeight: isWideLayout)
            .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func confidenceInsightCard(fillAvailableHeight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            sectionTitle("Confidence by line", subtitle: "Average and trend across policies")

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
                    colorScheme == .dark
                        ? AnyShapeStyle(FaroPalette.purpleDeep.opacity(0.9))
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [FaroPalette.info, FaroPalette.purpleDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )

                Chart(Array(sortedCoverage.enumerated()), id: \.element.id) { index, option in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Confidence", option.confidence)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? AnyShapeStyle(FaroPalette.purpleDeep.opacity(0.95))
                            : AnyShapeStyle(FaroPalette.purpleDeep.gradient)
                    )

                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Confidence", option.confidence)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? AnyShapeStyle(FaroPalette.purpleDeep.opacity(0.14))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep.opacity(0.22), FaroPalette.purpleDeep.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
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
                .frame(height: isWideLayout ? 220 : 180)
                .frame(maxWidth: .infinity)
                .animation(.smooth(duration: 0.7), value: sortedCoverage.count)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if fillAvailableHeight {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .faroDashboardCardSurface(fillAvailableHeight: fillAvailableHeight)
        .overlay { FaroDashboardCardOutline() }
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
        .faroDashboardCardSurface()
        .clipShape(RoundedRectangle(cornerRadius: FaroRadius.xl, style: .continuous))
    }

    // MARK: - Insight cards

    private func coverageGapsCard(fillAvailableHeight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg) {
            FaroDashboardInsightSectionHeader(
                icon: "exclamationmark.shield.fill",
                iconTint: FaroPalette.danger,
                title: "Coverage gaps",
                subtitle: "Required items to address first"
            )

            if requiredOptions.isEmpty {
                Text("No required gaps flagged — review recommended lines to strengthen protection.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: FaroSpacing.md) {
                    ForEach(requiredOptions.prefix(5)) { opt in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(FaroPalette.danger)
                                .frame(width: 3, height: 16)
                                .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(opt.type)
                                    .font(FaroType.subheadline(.semibold))
                                    .foregroundStyle(FaroPalette.ink)
                                Text(opt.description)
                                    .font(FaroType.caption())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.48))
                                    .lineSpacing(3)
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if requiredOptions.count > 5 {
                        Text("+ \(requiredOptions.count - 5) more required")
                            .font(FaroType.caption(.semibold))
                            .foregroundStyle(FaroPalette.purpleDeep)
                            .padding(.top, FaroSpacing.xs)
                    }
                }
            }

            if fillAvailableHeight {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .faroDashboardCardSurface(fillAvailableHeight: fillAvailableHeight)
    }

    private func snapshotActivityCard(fillAvailableHeight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg) {
            FaroDashboardInsightSectionHeader(
                icon: "sparkles",
                iconTint: FaroPalette.purpleDeep,
                title: "Snapshot",
                subtitle: "Highest-impact lines"
            )

            VStack(alignment: .leading, spacing: FaroSpacing.sm + 2) {
                FaroDashboardSnapshotRow(
                    title: "Largest premium",
                    value: topPremiumOption?.type ?? "—",
                    detail: topPremiumOption.map { opt in
                        "$\(Int(opt.premiumMidpoint).formatted()) est."
                    } ?? ""
                )
                FaroDashboardSnapshotRow(
                    title: "Widest uncertainty",
                    value: snapshotWidestTitle,
                    detail: widestRangeOption.map { opt in
                        "$\(Int(opt.estimatedPremiumLow).formatted())–$\(Int(opt.estimatedPremiumHigh).formatted())"
                    } ?? ""
                )
                FaroDashboardSnapshotRow(
                    title: "Total exposure band",
                    value: "$\(Int(totalPremiumLow).formatted())–$\(Int(totalPremiumHigh).formatted())",
                    detail: "Across \(results.coverageOptions.count) policies"
                )
            }

            if fillAvailableHeight {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillAvailableHeight ? .infinity : nil, alignment: .topLeading)
        .faroDashboardCardSurface(fillAvailableHeight: fillAvailableHeight)
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
    }

    private var coverageGridColumns: [GridItem] {
        let spacing = FaroSpacing.sm + 2
        if isWideLayout {
            return [
                GridItem(.flexible(minimum: 0), spacing: spacing),
                GridItem(.flexible(minimum: 0), spacing: spacing),
                GridItem(.flexible(minimum: 0), spacing: spacing),
            ]
        }
        return [
            GridItem(.flexible(minimum: 0), spacing: spacing),
            GridItem(.flexible(minimum: 0), spacing: spacing),
        ]
    }

    private func coverageGallery(sortedCoverage: [CoverageOption]) -> some View {
        LazyVGrid(columns: coverageGridColumns, alignment: .center, spacing: FaroSpacing.sm + 2) {
            ForEach(sortedCoverage) { option in
                Button {
                    showCoverageDetail = option
                } label: {
                    CoverageGalleryTile(option: option, isWideLayout: isWideLayout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.faroScale)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var coverageAgentChatCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack(alignment: .top, spacing: FaroSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(FaroPalette.purpleDeep.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(FaroPalette.purpleDeep.opacity(0.9))
                }
                sectionTitle("Ask Faro", subtitle: "Your advisor for this analysis — type or speak naturally.")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                        if agentChatLines.isEmpty {
                            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                                Text("\(timeBasedGreeting) — when you’re ready, ask anything about premiums, gaps, or what to do next. There’s no script.")
                                    .font(FaroType.body())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, FaroSpacing.xs)
                        } else {
                            ForEach(agentChatLines) { line in
                                AgentChatLineRow(line: line)
                                    .id(line.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: chatMessageAreaHeight)
                .onChange(of: agentChatLines.count) { _, _ in
                    if let last = agentChatLines.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            if agentChatSending {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FaroPalette.purpleDeep)
                    Text("Faro is writing a reply…")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                }
            }

            if coverageVoiceConnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FaroPalette.purpleDeep)
                    Text("Connecting voice (ElevenLabs)…")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                }
            }

            if let err = coverageChatSpeech.lastError, !err.isEmpty {
                Text(err)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger.opacity(0.9))
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    toggleVoiceCapture()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                coverageVoiceMicIsHot
                                    ? FaroPalette.danger.opacity(0.92)
                                    : FaroPalette.surface.opacity(0.55)
                            )
                            .overlay {
                                Circle()
                                    .strokeBorder(FaroPalette.glassStroke.opacity(0.35), lineWidth: 0.5)
                            }
                        if coverageVoiceConnecting {
                            ProgressView()
                                .tint(FaroPalette.purpleDeep)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: coverageVoiceMicIsHot ? "mic.fill" : "mic")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    coverageVoiceMicIsHot ? Color.white : FaroPalette.purpleDeep
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(coverageVoiceConnecting)
                .accessibilityLabel(coverageVoiceMicIsHot ? "Stop dictation" : "Voice input (ElevenLabs)")

                TextField("Write a message…", text: $agentChatDraft, axis: .vertical)
                    .font(FaroType.body())
                    .lineLimit(2...8)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    .faroGlassCard(cornerRadius: FaroRadius.xl)
                    .focused($agentChatFocused)

                Button {
                    sendAgentChat()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(agentChatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentChatSending)
                .opacity(
                    agentChatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentChatSending ? 0.4 : 1
                )
            }
        }
        .onChange(of: coverageChatSpeech.partialTranscript) { _, new in
            guard voiceCaptureActive, coverageChatSpeech.isRecording else { return }
            let sep = voiceDraftPrefix.isEmpty ? "" : " "
            agentChatDraft = voiceDraftPrefix + sep + new
        }
        .onChange(of: coverageElevenLabs.transcript.count) { _, _ in
            guard voiceCaptureActive, !APIConfig.isDemoModeEnabled else { return }
            guard case .connected = coverageElevenLabs.state else { return }
            syncAgentDraftFromElevenLabsTranscript()
        }
        .faroDashboardCardSurface()
        .overlay { FaroDashboardCardOutline() }
    }

    private func syncAgentDraftFromElevenLabsTranscript() {
        let userText = coverageElevenLabs.transcript
            .filter { $0.role == "user" }
            .map(\.message)
            .joined(separator: " ")
        let sep = voiceDraftPrefix.isEmpty || userText.isEmpty ? "" : " "
        agentChatDraft = voiceDraftPrefix + sep + userText
    }

    private func stopCoverageElevenLabsVoiceSession() {
        coverageElevenLabs.suppressAgentPlayback = false
        coverageElevenLabs.disconnect()
        voiceCaptureActive = false
        voiceDraftPrefix = ""
        coverageVoiceConnecting = false
    }

    private func toggleVoiceCapture() {
        if coverageChatSpeech.isRecording {
            let sep = voiceDraftPrefix.isEmpty ? "" : " "
            agentChatDraft = voiceDraftPrefix + sep + coverageChatSpeech.partialTranscript
            voiceDraftPrefix = ""
            voiceCaptureActive = false
            coverageChatSpeech.stop()
            return
        }

        if voiceCaptureActive, case .connected = coverageElevenLabs.state {
            syncAgentDraftFromElevenLabsTranscript()
            stopCoverageElevenLabsVoiceSession()
            return
        }

        if coverageVoiceConnecting { return }

        voiceDraftPrefix = agentChatDraft
        coverageChatSpeech.clearError()

        if APIConfig.isDemoModeEnabled {
            voiceCaptureActive = true
            Task { @MainActor in
                do {
                    try await coverageChatSpeech.start()
                } catch {
                    voiceCaptureActive = false
                    voiceDraftPrefix = ""
                    coverageChatSpeech.noteError(error.localizedDescription)
                }
            }
            return
        }

        coverageVoiceConnecting = true
        coverageElevenLabs.suppressAgentPlayback = true
        Task { @MainActor in
            do {
                let start = try await APIService.shared.startConversation()
                try await coverageElevenLabs.connect(signedUrl: start.signedUrl)
                coverageVoiceConnecting = false
                voiceCaptureActive = true
                syncAgentDraftFromElevenLabsTranscript()
            } catch let elError {
                coverageElevenLabs.suppressAgentPlayback = false
                coverageElevenLabs.disconnect()
                coverageVoiceConnecting = false
                do {
                    try await coverageChatSpeech.start()
                    voiceCaptureActive = true
                    coverageChatSpeech.clearError()
                } catch {
                    voiceCaptureActive = false
                    voiceDraftPrefix = ""
                    coverageChatSpeech.noteError(
                        "On-device dictation: \(error.localizedDescription). ElevenLabs: \(elError.localizedDescription)"
                    )
                }
            }
        }
    }

    private func sendAgentChat() {
        if coverageChatSpeech.isRecording {
            let sep = voiceDraftPrefix.isEmpty ? "" : " "
            agentChatDraft = voiceDraftPrefix + sep + coverageChatSpeech.partialTranscript
            voiceDraftPrefix = ""
            voiceCaptureActive = false
            coverageChatSpeech.stop()
        }
        if case .connected = coverageElevenLabs.state {
            syncAgentDraftFromElevenLabsTranscript()
            stopCoverageElevenLabsVoiceSession()
        }
        let q = agentChatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !agentChatSending else { return }
        agentChatDraft = ""
        agentChatFocused = false
        agentChatLines.append(AgentChatLine(isUser: true, text: q))
        agentChatSending = true
        Task {
            do {
                let reply = try await APIService.shared.sendCoverageChat(sessionId: sessionId, message: q)
                await MainActor.run {
                    agentChatLines.append(AgentChatLine(isUser: false, text: reply))
                    agentChatSending = false
                }
            } catch {
                await MainActor.run {
                    let msg: String
                    if let api = error as? APIError {
                        msg = api.message
                    } else {
                        msg = error.localizedDescription
                    }
                    agentChatLines.append(AgentChatLine(isUser: false, text: "Couldn’t reach Faro: \(msg)"))
                    agentChatSending = false
                }
            }
        }
    }

    private func categoryTint(_ category: CoverageCategory) -> Color {
        switch category {
        case .required: return FaroPalette.danger
        case .recommended: return FaroPalette.warning
        case .projected: return FaroPalette.purple
        }
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

    private var labelColumnWidth: CGFloat { isWideLayout ? 272 : 132 }
    private var valueColumnWidth: CGFloat { isWideLayout ? 108 : 84 }
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
        HStack(alignment: .center, spacing: columnGap) {
            Color.clear
                .frame(width: labelColumnWidth)
                .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                axisLabels(showsMidpoint: true)
                axisLabels(showsMidpoint: false)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Color.clear
                .frame(width: valueColumnWidth)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func axisLabels(showsMidpoint: Bool) -> some View {
        HStack(spacing: 0) {
            Text("$0")
            Spacer(minLength: 8)
            if showsMidpoint {
                Text(maxDomain / 2, format: .currency(code: "USD").precision(.fractionLength(0)))
                Spacer(minLength: 8)
            }
            Text(maxDomain, format: .currency(code: "USD").precision(.fractionLength(0)))
        }
        .font(FaroType.caption2())
        .foregroundStyle(FaroPalette.ink.opacity(0.42))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .multilineTextAlignment(.center)
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
                .clipped()
            }
            .frame(height: max(barHeight, 28))
            .frame(maxWidth: .infinity)
            .clipped()

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

// MARK: - Coverage gallery tile

private struct CoverageGalleryTile: View {
    let option: CoverageOption
    var isWideLayout: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var cardHeight: CGFloat { isWideLayout ? 152 : 164 }

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
        HStack(alignment: .top, spacing: FaroSpacing.sm) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? AnyShapeStyle(categoryColor.opacity(0.92))
                        : AnyShapeStyle(categoryColor.gradient)
                )
                .frame(width: 3, height: 42)

            VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(categoryLabel)
                        .font(FaroType.caption2(.bold))
                        .foregroundStyle(categoryColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(FaroPalette.ink.opacity(0.28))
                }

                Text(option.type)
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("$\(Int(option.estimatedPremiumLow).formatted())–$\(Int(option.estimatedPremiumHigh).formatted())")
                    .font(FaroType.caption(.bold))
                    .foregroundStyle(FaroPalette.ink)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle().fill(confidenceColor).frame(width: 5, height: 5)
                    Text("\(Int(option.confidence * 100))%")
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }

                if !option.resolvedCarriers.isEmpty {
                    Text(option.resolvedCarriers.joined(separator: ", "))
                        .font(FaroType.caption2())
                        .foregroundStyle(FaroPalette.ink.opacity(0.48))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(FaroSpacing.sm + 2)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
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
