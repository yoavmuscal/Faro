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

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
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

                if !categoryChartData.isEmpty {
                    coverageMixChart
                        .padding(.horizontal, FaroSpacing.md)
                }

                coverageCarousel(sortedCoverage: sortedCoverage)

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
                        Label("Prepare submission packet", systemImage: "arrow.up.doc.fill")
                            .font(FaroType.headline())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.faroGlassProminent)

                    if let url = pdfURL {
                        ShareLink(item: url, preview: SharePreview("Faro submission", image: Image(systemName: "doc.fill"))) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                                .font(FaroType.headline())
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                        .buttonStyle(.faroGlassProminent)
                    }
                }
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
    }

    private var coverageMixChart: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text("Mix by category")
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)

            Chart(categoryChartData) { slice in
                SectorMark(
                    angle: .value("Policies", slice.count),
                    innerRadius: .ratio(0.52),
                    angularInset: 1.5
                )
                .foregroundStyle(categoryTint(slice.category))
            }
            .frame(height: 200)

            HStack(spacing: FaroSpacing.md) {
                ForEach(categoryChartData) { slice in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryTint(slice.category))
                            .frame(width: 8, height: 8)
                        Text(slice.category.label)
                            .font(FaroType.caption2())
                            .foregroundStyle(FaroPalette.ink.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl, material: .regularMaterial)
    }

    @ViewBuilder
    private func coverageCarousel(sortedCoverage: [CoverageOption]) -> some View {
        #if os(iOS)
        TabView(selection: $selectedIndex) {
            ForEach(sortedCoverage.indices, id: \.self) { i in
                CoverageCard(option: sortedCoverage[i])
                    .tag(i)
                    .padding(.horizontal)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 340)
        #else
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: FaroSpacing.md) {
                ForEach(sortedCoverage) { option in
                    CoverageCard(option: option)
                        .frame(width: 380)
                }
            }
            .padding(.horizontal, FaroSpacing.md)
        }
        .frame(minHeight: 300)
        #endif
    }

    private func exportPDF() async {
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

// MARK: - Chart model

private struct CategoryChartSlice: Identifiable {
    let category: CoverageCategory
    let count: Int
    var id: CoverageCategory { category }
}

private extension CoverageCategory {
    var label: String {
        switch self {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
    }
}

// MARK: - Glass button style

private struct FaroGlassProminentButtonStyle: ButtonStyle {
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

private extension ButtonStyle where Self == FaroGlassProminentButtonStyle {
    static var faroGlassProminent: FaroGlassProminentButtonStyle { FaroGlassProminentButtonStyle() }
}

// MARK: - Coverage Card

struct CoverageCard: View {
    let option: CoverageOption

    var categoryColor: Color {
        switch option.category {
        case .required: return FaroPalette.danger
        case .recommended: return FaroPalette.warning
        case .projected: return FaroPalette.purple
        }
    }

    var categoryLabel: String {
        switch option.category {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
    }

    var confidenceColor: Color {
        switch option.confidence {
        case 0.8...: return FaroPalette.success
        case 0.5..<0.8: return FaroPalette.warning
        default: return FaroPalette.ink.opacity(0.4)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            HStack {
                Text(categoryLabel)
                    .font(FaroType.caption(.bold))
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.14))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(option.confidence * 100))% confidence")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
            }

            Text(option.type)
                .font(FaroType.title3())
                .foregroundStyle(FaroPalette.ink)

            Text(option.description)
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            if let trigger = option.triggerEvent {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(FaroType.caption2())
                    Text(trigger)
                        .font(FaroType.caption())
                }
                .foregroundStyle(FaroPalette.purpleDeep)
                .padding(FaroSpacing.sm)
                .background(FaroPalette.purple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FaroRadius.sm, style: .continuous))
            }

            Spacer()

            HStack {
                Text("Est. premium")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                Spacer()
                Text("$\(Int(option.estimatedPremiumLow).formatted()) – $\(Int(option.estimatedPremiumHigh).formatted())/yr")
                    .font(FaroType.subheadline(.semibold))
                    .foregroundStyle(FaroPalette.ink)
            }
        }
        .padding(FaroSpacing.md + 4)
        .frame(maxWidth: .infinity)
        .faroGlassCard(cornerRadius: FaroRadius.xl, material: .regularMaterial)
    }
}

#Preview {
    NavigationStack {
        CoverageDashboardView(
            results: ResultsResponse(
                coverageOptions: [
                    CoverageOption(
                        type: "General Liability",
                        description: "Covers third-party bodily injury and property damage claims.",
                        estimatedPremiumLow: 800, estimatedPremiumHigh: 1500,
                        confidence: 0.95, category: .required, triggerEvent: nil
                    ),
                    CoverageOption(
                        type: "Workers Compensation",
                        description: "Required by NJ law for any business with employees.",
                        estimatedPremiumLow: 2000, estimatedPremiumHigh: 4000,
                        confidence: 0.99, category: .required, triggerEvent: nil
                    ),
                    CoverageOption(
                        type: "Cyber Liability",
                        description: "Covers data breaches, ransomware, and regulatory fines.",
                        estimatedPremiumLow: 1200, estimatedPremiumHigh: 3000,
                        confidence: 0.80, category: .recommended, triggerEvent: nil
                    ),
                    CoverageOption(
                        type: "Employment Practices Liability (EPLI)",
                        description: "Protects against claims of wrongful termination, discrimination, and harassment.",
                        estimatedPremiumLow: 1500, estimatedPremiumHigh: 4000,
                        confidence: 0.72, category: .projected,
                        triggerEvent: "Trigger: Headcount projected to exceed 15 employees"
                    ),
                ],
                submissionPacketUrl: "",
                voiceSummaryUrl: ""
            ),
            sessionId: "preview"
        )
    }
}
