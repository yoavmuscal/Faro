import SwiftUI

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
    @StateObject private var vm = OnboardingViewModel()
    @State private var navigateToTracker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: vm.progress)
                    .tint(.primary)
                    .padding(.horizontal)
                    .padding(.top, 20)

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
                            keyboardType: .numberPad
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
                            keyboardType: .decimalPad
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
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button(action: vm.advance) {
                    Group {
                        if vm.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(vm.currentField == .annualRevenue ? "Analyze my coverage" : "Continue")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(vm.canAdvance ? Color.primary : Color.secondary.opacity(0.3))
                    .foregroundStyle(vm.canAdvance ? Color(uiColor: .systemBackground) : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!vm.canAdvance || vm.isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationDestination(isPresented: Binding(
                get: { vm.sessionId != nil },
                set: { if !$0 { vm.sessionId = nil } }
            )) {
                if let sessionId = vm.sessionId {
                    AgentTrackerView(sessionId: sessionId)
                }
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
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question)
                .font(.title2)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .padding(16)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    OnboardingView()
}
