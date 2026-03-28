import SwiftUI

// MARK: - View model

@MainActor
final class VoiceIntakeViewModel: ObservableObject {
    enum Field: Int, CaseIterable {
        case businessName, description, employeeCount, state, annualRevenue
    }

    @Published var businessName = ""
    @Published var description = ""
    @Published var employeeCountText = ""
    @Published var state = ""
    @Published var annualRevenueText = ""
    @Published var currentField: Field = .businessName

    @Published var isStartingConv = true
    @Published var convSessionId: String?
    @Published var convStartError: String?

    @Published var isSubmitting = false
    @Published var sessionId: String?
    @Published var errorMessage: String?

    var progress: Double {
        Double(currentField.rawValue) / Double(Field.allCases.count - 1)
    }

    var canAdvance: Bool {
        switch currentField {
        case .businessName: return !businessName.trimmingCharacters(in: .whitespaces).isEmpty
        case .description: return !description.trimmingCharacters(in: .whitespaces).isEmpty
        case .employeeCount: return Int(employeeCountText) != nil
        case .state: return state.count == 2
        case .annualRevenue: return Double(annualRevenueText.replacingOccurrences(of: ",", with: "")) != nil
        }
    }

    func startConversationPhase() async {
        isStartingConv = true
        convStartError = nil
        do {
            let r = try await APIService.shared.startConversation()
            convSessionId = r.sessionId
        } catch {
            convStartError =
                "Conversational intake isn’t available on the server right now. Use the guided questionnaire instead."
        }
        isStartingConv = false
    }

    func advance() {
        guard canAdvance, convSessionId != nil else { return }
        if currentField == .annualRevenue {
            Task { await submit() }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentField = Field(rawValue: currentField.rawValue + 1)!
            }
        }
    }

    private func submit() async {
        guard let sid = convSessionId else { return }
        isSubmitting = true
        errorMessage = nil
        let revenue = Double(annualRevenueText.replacingOccurrences(of: ",", with: "")) ?? 0
        let intake = IntakeRequest(
            businessName: businessName,
            description: description,
            employeeCount: Int(employeeCountText) ?? 0,
            state: state.uppercased(),
            annualRevenue: revenue
        )
        let transcript = ElevenLabsConvService.transcript(from: intake)
        do {
            let response = try await APIService.shared.completeConversation(sessionId: sid, transcript: transcript)
            sessionId = response.sessionId
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - View

struct VoiceIntakeView: View {
    @EnvironmentObject private var appState: FaroAppState
    @StateObject private var vm = VoiceIntakeViewModel()

    var body: some View {
        Group {
            if vm.isStartingConv {
                VStack(spacing: FaroSpacing.md) {
                    ProgressView()
                        .tint(FaroPalette.purpleDeep)
                    Text("Preparing conversational session…")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.convStartError {
                ContentUnavailableView {
                    Label("Voice intake unavailable", systemImage: "waveform.slash")
                } description: {
                    Text(err)
                        .multilineTextAlignment(.center)
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
                intakeForm
            }
        }
        .faroCanvasBackground()
        .navigationTitle("Voice intake")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await vm.startConversationPhase()
        }
        .navigationDestination(isPresented: Binding(
            get: { vm.sessionId != nil },
            set: { if !$0 { vm.sessionId = nil } }
        )) {
            if let sessionId = vm.sessionId {
                AgentTrackerView(sessionId: sessionId, businessName: vm.businessName)
            }
        }
        .onChange(of: vm.sessionId) { _, newId in
            if let id = newId {
                appState.beginNewAnalysis(sessionId: id, businessName: vm.businessName)
            }
        }
    }

    private var intakeForm: some View {
        VStack(spacing: 0) {
            Text(
                "Answer the same questions as the guided flow. Your answers are sent as a conversation transcript to start the analysis pipeline."
            )
            .font(FaroType.caption())
            .foregroundStyle(FaroPalette.ink.opacity(0.5))
            .multilineTextAlignment(.leading)
            .padding(.horizontal)
            .padding(.top, FaroSpacing.sm)

            ProgressView(value: vm.progress)
                .tint(FaroPalette.purpleDeep)
                .padding(.horizontal)
                .padding(.top, FaroSpacing.lg)

            Spacer()

            Group {
                switch vm.currentField {
                case .businessName:
                    QuestionCard(
                        question: "What's your business called?",
                        placeholder: "e.g. Sunny Days Daycare",
                        text: $vm.businessName
                    )
                case .description:
                    QuestionCard(
                        question: "What does your business do?",
                        placeholder: "Describe it in your own words — the more detail the better",
                        text: $vm.description,
                        isMultiline: true
                    )
                case .employeeCount:
                    QuestionCard(
                        question: "How many employees do you have?",
                        placeholder: "12",
                        text: $vm.employeeCountText,
                        keyboard: .numberPad
                    )
                case .state:
                    QuestionCard(
                        question: "Which state do you operate in?",
                        placeholder: "NJ",
                        text: $vm.state
                    )
                case .annualRevenue:
                    QuestionCard(
                        question: "What's your approximate annual revenue?",
                        placeholder: "800000",
                        text: $vm.annualRevenueText,
                        keyboard: .decimalPad
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            if let error = vm.errorMessage {
                Text(error)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
                    .padding(.horizontal)
            }

            Button(action: vm.advance) {
                Group {
                    if vm.isSubmitting {
                        ProgressView()
                            .tint(FaroPalette.onAccent)
                    } else {
                        Text(vm.currentField == .annualRevenue ? "Analyze my coverage" : "Continue")
                            .font(FaroType.headline())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(vm.canAdvance ? FaroPalette.purpleDeep : FaroPalette.purple.opacity(0.25))
                .foregroundStyle(vm.canAdvance ? FaroPalette.onAccent : FaroPalette.ink.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous))
            }
            .disabled(!vm.canAdvance || vm.isSubmitting)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    NavigationStack {
        VoiceIntakeView()
    }
    .environmentObject(FaroAppState())
}
