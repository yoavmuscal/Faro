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
                            .fill(FaroPalette.purpleDeep.opacity(0.1))
                            .frame(width: 150, height: 150)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: vm.state == .connected)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(FaroPalette.purpleDeep)
                    }
                    .padding(.vertical, FaroSpacing.xl)
                    
                    Text("Listening...")
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
                    Text("Error: \(msg)").font(FaroType.headline())
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Transcript View
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
}
