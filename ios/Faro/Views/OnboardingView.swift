import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Keyboard (iOS number pads; macOS uses default field behavior)

enum FaroTextKeyboard {
    case `default`
    case numberPad
    case decimalPad
}

#if os(iOS)
extension FaroTextKeyboard {
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: return .default
        case .numberPad: return .numberPad
        case .decimalPad: return .decimalPad
        }
    }
}
#endif

private extension View {
    @ViewBuilder
    func faroKeyboard(_ keyboard: FaroTextKeyboard) -> some View {
        #if os(iOS)
        self.keyboardType(keyboard.uiKeyboardType)
        #else
        self
        #endif
    }
}

// MARK: - Onboarding state

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Field: Int, CaseIterable {
        case businessName, description, employeeCount, state, annualRevenue
    }

    @Published var businessName = ""
    @Published var description = ""
    @Published var employeeCountText = ""
    @Published var state = ""
    @Published var annualRevenueText = ""
    @Published var currentField: Field = .businessName
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

    func advance() {
        guard canAdvance else { return }
        if currentField == .annualRevenue {
            Task { await submit() }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentField = Field(rawValue: currentField.rawValue + 1)!
            }
        }
    }

    private func submit() async {
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
        do {
            let response = try await APIService.shared.submitIntake(intake)
            sessionId = response.sessionId
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - View

struct OnboardingView: View {
    @EnvironmentObject private var appState: FaroAppState
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
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
        .faroCanvasBackground()
        .navigationTitle("Analyze")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
}

// MARK: - Subviews

struct QuestionCard: View {
    let question: String
    let placeholder: String
    @Binding var text: String
    var isMultiline = false
    var keyboard: FaroTextKeyboard = .default

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.md) {
            Text(question)
                .font(FaroType.title2())
                .foregroundStyle(FaroPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isMultiline {
                TextEditor(text: $text)
                    .font(FaroType.body())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(FaroSpacing.sm + 2)
                    .faroGlassCard(cornerRadius: FaroRadius.md, material: .thinMaterial)
            } else {
                TextField(placeholder, text: $text)
                    .font(FaroType.body())
                    .faroKeyboard(keyboard)
                    .padding(FaroSpacing.md)
                    .faroGlassCard(cornerRadius: FaroRadius.md, material: .thinMaterial)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
    .environmentObject(FaroAppState())
}
