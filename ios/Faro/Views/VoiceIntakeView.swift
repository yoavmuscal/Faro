import SwiftUI
import Combine

@MainActor
final class VoiceIntakeViewModel: ObservableObject {
    @Published var isStartingConv = true
    @Published var convSessionId: String?
    @Published var convStartError: String?

    @Published var isSubmitting = false
    @Published var analysisSessionId: String? // Final Session ID from /conv/complete
    @Published var errorMessage: String?

    let liveService = ElevenLabsLiveConversationService()
    private var bag = Set<AnyCancellable>()

    var state: ElevenLabsLiveConversationService.ConnectionState {
        liveService.state
    }

    var transcript: [ConvTranscriptTurn] {
        liveService.transcript
    }

    var isAgentSpeaking: Bool {
        liveService.isAgentSpeaking
    }

    var isUserSpeaking: Bool {
        liveService.isUserSpeaking
    }

    var userSpeechLevel: Double {
        liveService.userSpeechLevel
    }

    var transcriptScrollToken: String {
        guard let lastTurn = transcript.last else { return "empty" }
        return "\(transcript.count)|\(lastTurn.role)|\(lastTurn.message)"
    }

    /// True once the user has spoken at least one turn — required before submitting.
    var hasUserTurns: Bool {
        transcript.contains { $0.role == "user" }
    }

    init() {
        // Propagate liveService's @Published changes into this ViewModel so SwiftUI re-renders.
        liveService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    func startConversationPhase() async {
        isStartingConv = true
        convStartError = nil
        do {
            let r = try await APIService.shared.startConversation()
            convSessionId = r.sessionId
            try await liveService.connect(signedUrl: r.signedUrl)
        } catch {
            convStartError = "Conversational intake isn’t available on the server right now. \(error.localizedDescription)"
        }
        isStartingConv = false
    }

    func disconnectAndSubmit() {
        liveService.disconnect()
        Task { await submit() }
    }
    
    func abortConversation() {
        liveService.disconnect()
    }

    private func submit() async {
        guard let sid = convSessionId else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.completeConversation(sessionId: sid, transcript: liveService.transcript)
            analysisSessionId = response.sessionId
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

struct VoiceIntakeView: View {
    @EnvironmentObject private var appState: FaroAppState
    @StateObject private var vm = VoiceIntakeViewModel()
    @Environment(\.dismiss) private var dismiss
    private let transcriptBottomID = "voice-transcript-bottom"

    var body: some View {
        Group {
            if vm.isStartingConv {
                VStack(spacing: FaroSpacing.md) {
                    ProgressView().tint(FaroPalette.purpleDeep)
                    Text("Preparing conversational session…")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.convStartError {
                ContentUnavailableView {
                    Label("Voice intake unavailable", systemImage: "waveform.slash")
                } description: {
                    Text(err).multilineTextAlignment(.center)
                } actions: {
                    NavigationLink {
                        OnboardingView()
                    } label: {
                        Text("Open guided questionnaire")
                            .font(FaroType.headline())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(FaroPalette.purpleDeep)
                            .foregroundStyle(FaroPalette.onAccent)
                            .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
                    }
                    .padding(.horizontal)
                }
            } else {
                liveConversationUI
            }
        }
        .faroCanvasBackground()
        .navigationTitle("Voice intake")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(vm.isSubmitting)
        .task {
            await vm.startConversationPhase()
        }
        .onDisappear {
            vm.abortConversation()
        }
        .navigationDestination(item: $vm.analysisSessionId) { sessionId in
            AgentTrackerView(sessionId: sessionId, businessName: "Your Business")
        }
        .onChange(of: vm.analysisSessionId) { _, newId in
            if let id = newId {
                appState.beginNewAnalysis(sessionId: id, businessName: "Your Business")
            }
        }
    }

    private var liveConversationUI: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Conversation UI
            VStack(spacing: FaroSpacing.lg) {
                switch vm.state {
                case .connecting:
                    ProgressView().tint(FaroPalette.purpleDeep)
                    Text("Connecting to Faro...").font(FaroType.headline())
                case .connected:
                    ZStack {
                        Circle()
                            .fill(FaroPalette.purpleDeep.opacity(vm.isUserSpeaking ? 0.18 : 0.08))
                            .frame(width: 168, height: 168)
                            .scaleEffect(1.05 + (vm.isUserSpeaking ? (vm.userSpeechLevel * 0.3) : 0.05))
                            .animation(.easeInOut(duration: 0.18), value: vm.userSpeechLevel)

                        Circle()
                            .stroke(FaroPalette.purple.opacity(vm.isUserSpeaking ? 0.5 : 0.22), lineWidth: 10)
                            .frame(width: 132, height: 132)
                            .scaleEffect(vm.isUserSpeaking ? 1.0 + (vm.userSpeechLevel * 0.14) : 1)
                            .animation(.easeInOut(duration: 0.16), value: vm.userSpeechLevel)

                        VStack(spacing: FaroSpacing.md) {
                            Image(systemName: vm.isAgentSpeaking ? "speaker.wave.2.fill" : "mic.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(FaroPalette.purpleDeep)

                            HStack(alignment: .center, spacing: 8) {
                                ForEach(0..<4, id: \.self) { index in
                                    Capsule(style: .continuous)
                                        .fill(FaroPalette.purple.gradient)
                                        .frame(width: 8, height: speechBarHeight(index: index))
                                        .animation(.easeInOut(duration: 0.18), value: vm.userSpeechLevel)
                                }
                            }
                        }
                    }
                    .padding(.vertical, FaroSpacing.xl)
                    
                    Text(connectionStatusLabel)
                        .font(FaroType.headline())
                        .foregroundStyle(FaroPalette.purpleDeep)
                case .disconnected:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(FaroPalette.purple)
                        .padding(.vertical, FaroSpacing.xl)
                    Text("Conversation Ended").font(FaroType.headline())
                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(FaroPalette.danger)
                        .padding(.vertical, FaroSpacing.xl)
                    Text(msg)
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await vm.startConversationPhase() }
                    }
                    .padding(.top, FaroSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Transcript View
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: FaroSpacing.sm) {
                        ForEach(Array(vm.transcript.enumerated()), id: \.offset) { _, turn in
                            HStack {
                                if turn.role == "user" {
                                    Spacer()
                                    Text(turn.message)
                                        .padding(12)
                                        .background(FaroPalette.purpleDeep)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    Text(turn.message)
                                        .padding(12)
                                        .background(Color.gray.opacity(0.15))
                                        .foregroundColor(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(transcriptBottomID)
                    }
                }
                .onAppear {
                    scrollTranscriptToBottom(using: proxy, animated: false)
                }
                .onChange(of: vm.transcriptScrollToken) { _, _ in
                    scrollTranscriptToBottom(using: proxy)
                }
            }
            .frame(maxHeight: 250)
            
            if let error = vm.errorMessage {
                Text(error)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
                    .padding()
            }

            let canFinish = vm.state == .connected && vm.hasUserTurns && !vm.isSubmitting

            if vm.state == .connected && !vm.hasUserTurns {
                Text("Speak to Faro — the button unlocks once you've responded.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: vm.disconnectAndSubmit) {
                Group {
                    if vm.isSubmitting {
                        ProgressView().tint(FaroPalette.onAccent)
                    } else {
                        Text("Finish Conversation")
                            .font(FaroType.headline())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canFinish ? FaroPalette.purpleDeep : FaroPalette.purple.opacity(0.25))
                .foregroundStyle(canFinish ? FaroPalette.onAccent : FaroPalette.ink.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
            }
            .disabled(!canFinish)
            .padding(.horizontal)
            .padding(.bottom, 40)
            .padding(.top, FaroSpacing.lg)
        }
    }

    private var connectionStatusLabel: String {
        if vm.isAgentSpeaking {
            return "Faro is speaking..."
        }
        if vm.isUserSpeaking {
            return "You're speaking..."
        }
        return "Listening..."
    }

    private func speechBarHeight(index: Int) -> CGFloat {
        let multipliers: [CGFloat] = [0.55, 1.0, 0.82, 0.68]
        let activeLevel = CGFloat(max(vm.userSpeechLevel, vm.isAgentSpeaking ? 0.18 : 0.04))
        return 10 + (activeLevel * 34 * multipliers[index])
    }

    private func scrollTranscriptToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(transcriptBottomID, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), action)
        } else {
            action()
        }
    }
}
