import SwiftUI
import AVFoundation

struct SummaryPlayerView: View {
    let summary: String
    let voiceURL: String
    let businessName: String

    @StateObject private var player = SummaryAudioPlayer()

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                    Text("Coverage Summary")
                        .font(FaroType.title())
                        .foregroundStyle(FaroPalette.ink)
                    Text("Plain-English explanation of your coverage recommendations")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FaroSpacing.md)

                if !voiceURL.isEmpty {
                    audioPlayerCard
                        .padding(.horizontal, FaroSpacing.md)
                }

                summaryTextCard
                    .padding(.horizontal, FaroSpacing.md)

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Summary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var audioPlayerCard: some View {
        VStack(spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.md) {
                Button {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        let urlString: String
                        if voiceURL.hasPrefix("/") {
                            urlString = APIConfig.httpBaseURL + voiceURL
                        } else {
                            urlString = voiceURL
                        }
                        player.play(url: urlString)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(FaroPalette.purpleDeep)
                            .frame(width: 56, height: 56)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(FaroPalette.onAccent)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Summary")
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.ink)
                    Text(player.isPlaying ? "Playing..." : "Tap to listen")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }

                Spacer()

                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(player.isPlaying ? FaroPalette.purpleDeep : FaroPalette.ink.opacity(0.2))
                    .symbolEffect(.variableColor, isActive: player.isPlaying)
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }

    private var summaryTextCard: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            SectionHeader(title: "Written Summary", icon: "text.alignleft", tint: FaroPalette.purpleDeep)

            Text(summary)
                .font(FaroType.body())
                .foregroundStyle(FaroPalette.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

@MainActor
final class SummaryAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private var avPlayer: AVPlayer?
    /// Held for teardown from `deinit` (nonisolated); avoids Swift 6 isolation warnings on `Any?`.
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?

    func play(url: String) {
        guard let audioURL = URL(string: url) else { return }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        let item = AVPlayerItem(url: audioURL)
        avPlayer = AVPlayer(playerItem: item)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }

        avPlayer?.play()
        isPlaying = true
    }

    func pause() {
        avPlayer?.pause()
        isPlaying = false
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

#Preview {
    NavigationStack {
        SummaryPlayerView(
            summary: "Based on our analysis of Sunny Days Daycare, a 12-employee childcare facility in New Jersey with $800,000 in annual revenue, we recommend three categories of insurance coverage.\n\nFirst, you are required by New Jersey law to carry Workers Compensation insurance for all your employees. This is non-negotiable and estimated to cost between $2,000 and $4,000 per year. You also need General Liability insurance, which protects you from third-party injury claims — critical in a daycare setting.\n\nWe strongly recommend Cyber Liability coverage given that you likely store parent and child personal information digitally. A data breach could be devastating.\n\nFinally, as your business grows beyond 15 employees, you should plan for Employment Practices Liability Insurance (EPLI) to protect against workplace discrimination and wrongful termination claims.",
            voiceURL: "/audio/test-session",
            businessName: "Sunny Days Daycare"
        )
    }
}
