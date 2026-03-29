import SwiftUI
import AVFoundation

private final class SummarySpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish?() }
    }
}

struct SummaryPlayerView: View {
    let summary: String
    let voiceURL: String
    let businessName: String

    @StateObject private var player = SummaryAudioPlayer()

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                    Text(businessName.isEmpty ? "Coverage Summary" : "\(businessName) Summary")
                        .font(FaroType.title())
                        .foregroundStyle(FaroPalette.ink)
                    Text("Plain-English explanation of your coverage recommendations")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FaroSpacing.md)

                if showVoiceCard {
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

    private var showVoiceCard: Bool {
        let u = voiceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return !u.isEmpty || !s.isEmpty
    }

    private var audioPlayerCard: some View {
        VStack(spacing: FaroSpacing.md) {
            HStack(spacing: FaroSpacing.md) {
                Button {
                    if player.isPlaying {
                        player.stop()
                    } else {
                        Task {
                            await player.play(voiceURLPath: voiceURL, fallbackText: summary)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: FaroPalette.purpleDeep.opacity(0.3), radius: 10, y: 3)

                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
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
                .lineSpacing(5)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
    }
}

@MainActor
final class SummaryAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private var avPlayer: AVPlayer?
    private var voiceTempFileURL: URL?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var speechSynth: AVSpeechSynthesizer?
    private var speechDelegate: SummarySpeechDelegate?

    func play(voiceURLPath: String, fallbackText: String) async {
        let trimmedURL = voiceURLPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = fallbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty || !trimmedText.isEmpty else { return }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        stop()
        isPlaying = true

        if !trimmedURL.isEmpty {
            do {
                let data = try await APIService.shared.fetchVoiceSummaryData(from: trimmedURL)
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent("faro-summary-\(UUID().uuidString).mp3")
                try data.write(to: temp)
                voiceTempFileURL = temp
                let item = AVPlayerItem(url: temp)
                avPlayer = AVPlayer(playerItem: item)
                attachPlayerObservers(item: item, fallbackText: trimmedText)
                avPlayer?.play()
                return
            } catch {
                // Fall through to speech.
            }
        }

        if !trimmedText.isEmpty {
            startSpeech(trimmedText)
            return
        }

        isPlaying = false
    }

    private func attachPlayerObservers(item: AVPlayerItem, fallbackText: String) {
        removeObservers()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.teardownTemp()
            }
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.removeObservers()
                self?.avPlayer = nil
                self?.teardownTemp()
                if !fallbackText.isEmpty {
                    self?.isPlaying = true
                    self?.startSpeech(fallbackText)
                } else {
                    self?.isPlaying = false
                }
            }
        }
    }

    private func startSpeech(_ text: String) {
        let synth = AVSpeechSynthesizer()
        let del = SummarySpeechDelegate()
        del.onFinish = { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.speechSynth = nil
            self.speechDelegate = nil
        }
        synth.delegate = del
        speechSynth = synth
        speechDelegate = del
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }

    private func removeObservers() {
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
            endObserver = nil
        }
        if let o = failObserver {
            NotificationCenter.default.removeObserver(o)
            failObserver = nil
        }
    }

    private func teardownTemp() {
        if let u = voiceTempFileURL {
            try? FileManager.default.removeItem(at: u)
            voiceTempFileURL = nil
        }
    }

    func stop() {
        removeObservers()
        avPlayer?.pause()
        avPlayer = nil
        teardownTemp()
        speechSynth?.stopSpeaking(at: .immediate)
        speechSynth = nil
        speechDelegate = nil
        isPlaying = false
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
