import SwiftUI
import Charts
import AVFoundation

// MARK: - View Model

@MainActor
final class CoverageDashboardViewModel: ObservableObject {
    @Published var isPlayingAudio = false
    @Published var isGeneratingPDF = false

    private var audioPlayer: AVPlayer?
    let results: ResultsResponse

    init(results: ResultsResponse) {
        self.results = results
    }

    func playVoiceSummary() {
        guard !results.voiceSummaryUrl.isEmpty else { return }
        isPlayingAudio = true

        let urlString: String
        if results.voiceSummaryUrl.hasPrefix("/") {
            urlString = APIConfig.httpBaseURL + results.voiceSummaryUrl
        } else {
            urlString = results.voiceSummaryUrl
        }

        guard let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: item)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlayingAudio = false }
        }
        audioPlayer?.play()
    }

    func stopAudio() {
        audioPlayer?.pause()
        isPlayingAudio = false
    }
}

// MARK: - Dashboard

struct CoverageDashboardView: View {
    let results: ResultsResponse
    let sessionId: String
    let businessName: String

    @StateObject private var vm: CoverageDashboardViewModel
    @State private var selectedIndex = 0
    @State private var pdfURL: URL?
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

    private var categoryChartData: [CategoryChartSlice] {
        let grouped = Dictionary(grouping: results.coverageOptions, by: \.category)
        let order: [CoverageCategory] = [.required, .recommended, .projected]
        return order.compactMap { cat in
            let n = grouped[cat]?.count ?? 0
            guard n > 0 else { return nil }
            return CategoryChartSlice(category: cat, count: n)
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

                if !categoryChartData.isEmpty {
                    coverageMixChart
                        .padding(.horizontal, FaroSpacing.md)
                }

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
        .onAppear { WidgetDataWriter.update(from: results, businessName: businessName) }
        .sheet(item: $showCoverageDetail) { option in
            NavigationStack {
                CoverageDetailSheet(option: option)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            Text("Your coverage")
                .font(FaroType.title())
                .foregroundStyle(FaroPalette.ink)
            Text("\(sortedCoverage.filter { $0.category == .required }.count) required · \(sortedCoverage.filter { $0.category == .recommended }.count) recommended · \(sortedCoverage.filter { $0.category == .projected }.count) projected")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.55))
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
                title: "Avg Confidence",
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
                .cornerRadius(6)
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
        .faroGlassCard(cornerRadius: FaroRadius.xl, material: .regularMaterial)
    }

    private var coverageMixChart: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text("Mix by category")
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)

            HStack(spacing: FaroSpacing.lg) {
                Chart(categoryChartData) { slice in
                    SectorMark(
                        angle: .value("Policies", slice.count),
                        innerRadius: .ratio(0.52),
                        angularInset: 1.5
                    )
                    .foregroundStyle(categoryTint(slice.category))
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                    ForEach(categoryChartData) { slice in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(categoryTint(slice.category))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading) {
                                Text(slice.category.label)
                                    .font(FaroType.caption(.semibold))
                                    .foregroundStyle(FaroPalette.ink)
                                Text("\(slice.count) \(slice.count == 1 ? "policy" : "policies")")
                                    .font(FaroType.caption2())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl, material: .regularMaterial)
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
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FaroSpacing.md)
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
                .background(FaroPalette.purpleDeep)
                .foregroundStyle(FaroPalette.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
            }
            .disabled(results.voiceSummaryUrl.isEmpty)

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

            if let url = pdfURL {
                ShareLink(item: url, preview: SharePreview("Faro export", image: Image(systemName: "doc.fill"))) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .font(FaroType.headline())
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.faroGlassProminent)
            }
        }
    }

    private func exportPDF() async {
        vm.isGeneratingPDF = true
        defer { vm.isGeneratingPDF = false }
        pdfURL = PDFBuilder.build(from: results, businessName: businessName)
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
            Circle()
                .fill(categoryColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.type)
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                Text(option.description)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(option.estimatedPremiumLow).formatted())–$\(Int(option.estimatedPremiumHigh).formatted())")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.ink)
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
        .faroGlassCard(cornerRadius: FaroRadius.lg, material: .ultraThinMaterial)
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
        VStack(spacing: FaroSpacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(FaroType.subheadline(.bold))
                .foregroundStyle(FaroPalette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.lg, material: .ultraThinMaterial)
    }
}

// MARK: - Chart model

private struct CategoryChartSlice: Identifiable {
    let category: CoverageCategory
    let count: Int
    var id: CoverageCategory { category }
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .fill(FaroPalette.purple.opacity(configuration.isPressed ? 0.14 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                    .strokeBorder(FaroPalette.glassStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
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
