import SwiftUI
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
        if let url = URL(string: results.voiceSummaryUrl) {
            audioPlayer = AVPlayer(url: url)
            audioPlayer?.play()
            // TODO: observe playerItem to reset isPlayingAudio when done
        }
    }

    func stopAudio() {
        audioPlayer?.pause()
        isPlayingAudio = false
    }

    // PDF generation lives in PDFBuilder — see ios/Faro/Utilities/PDFBuilder.swift
}

// MARK: - View

struct CoverageDashboardView: View {
    let results: ResultsResponse
    let sessionId: String

    @StateObject private var vm: CoverageDashboardViewModel
    @State private var selectedIndex = 0
    @State private var showShareSheet = false
    @State private var pdfURL: URL?

    init(results: ResultsResponse, sessionId: String) {
        self.results = results
        self.sessionId = sessionId
        _vm = StateObject(wrappedValue: CoverageDashboardViewModel(results: results))
    }

    private var sortedCoverage: [CoverageOption] {
        let order: [CoverageCategory] = [.required, .recommended, .projected]
        return results.coverageOptions.sorted {
            (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your coverage")
                        .font(.title).fontWeight(.bold)
                    Text("\(sortedCoverage.filter { $0.category == .required }.count) required · \(sortedCoverage.filter { $0.category == .recommended }.count) recommended · \(sortedCoverage.filter { $0.category == .projected }.count) projected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Coverage cards (swipeable TabView)
                TabView(selection: $selectedIndex) {
                    ForEach(sortedCoverage.indices, id: \.self) { i in
                        CoverageCard(option: sortedCoverage[i])
                            .tag(i)
                            .padding(.horizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 320)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        if vm.isPlayingAudio { vm.stopAudio() } else { vm.playVoiceSummary() }
                    } label: {
                        Label(
                            vm.isPlayingAudio ? "Stop" : "Hear your summary",
                            systemImage: vm.isPlayingAudio ? "stop.fill" : "speaker.wave.2.fill"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primary)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(results.voiceSummaryUrl.isEmpty)

                    Button {
                        Task { await exportPDF() }
                    } label: {
                        Label("Export submission packet", systemImage: "arrow.up.doc.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("Coverage Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportPDF() async {
        // TODO: build PDF from results using PDFBuilder, then share
        // pdfURL = PDFBuilder.build(from: results)
        // showShareSheet = true
    }
}

// MARK: - Coverage Card

struct CoverageCard: View {
    let option: CoverageOption

    var categoryColor: Color {
        switch option.category {
        case .required: return .red
        case .recommended: return .orange
        case .projected: return .purple
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
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(categoryLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(option.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(option.type)
                .font(.title3)
                .fontWeight(.bold)

            Text(option.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let trigger = option.triggerEvent {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text(trigger)
                        .font(.caption)
                }
                .foregroundStyle(.purple)
                .padding(10)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Text("Est. premium")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$\(Int(option.estimatedPremiumLow).formatted()) – $\(Int(option.estimatedPremiumHigh).formatted())/yr")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
