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

    var stepLabel: String {
        let total = Field.allCases.count
        let current = currentField.rawValue + 1
        return "\(current) of \(total)"
    }

    var fieldSubtitle: String {
        switch currentField {
        case .businessName: return "We'll use this throughout your coverage report."
        case .description: return "The more detail, the better we can match you."
        case .employeeCount: return "This helps size workers' comp and liability."
        case .state: return "State regulations affect your requirements."
        case .annualRevenue: return "Revenue drives premium estimates."
        }
    }

    func advance() {
        guard canAdvance else { return }
        if currentField == .annualRevenue {
            Task { await submit() }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                currentField = Field(rawValue: currentField.rawValue + 1)!
            }
        }
    }

    func goBack() {
        guard currentField.rawValue > 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentField = Field(rawValue: currentField.rawValue - 1)!
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
    @State private var appeared = false

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, FaroSpacing.lg)

                Spacer(minLength: FaroSpacing.xl)

                questionArea
                    .frame(maxWidth: 480)

                Spacer(minLength: FaroSpacing.xl)

                footer
                    .padding(.bottom, FaroSpacing.xl)
            }
            .padding(.horizontal, FaroSpacing.lg)
        }
        .faroCanvasBackground()
        .navigationTitle("Analyze")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if vm.currentField.rawValue > 0 {
                    Button {
                        vm.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.semibold))
                            Text("Back")
                        }
                        .foregroundStyle(FaroPalette.purpleDeep)
                    }
                }
            }
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.65
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FaroPalette.purple.opacity(0.25),
                                FaroPalette.purpleDeep.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.05,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)
                    .blur(radius: 50)
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1 : 0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FaroPalette.purpleDeep.opacity(0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blur(radius: 30)
                    .offset(x: size * 0.15, y: -size * 0.12)
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        VStack(spacing: FaroSpacing.sm) {
            HStack(spacing: 6) {
                ForEach(OnboardingViewModel.Field.allCases, id: \.rawValue) { field in
                    Capsule(style: .continuous)
                        .fill(field.rawValue <= vm.currentField.rawValue
                              ? FaroPalette.purpleDeep
                              : FaroPalette.ink.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .frame(maxWidth: 200)

            Text("Step \(vm.stepLabel)")
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.4))
        }
    }

    // MARK: - Question area

    private var questionArea: some View {
        VStack(spacing: 0) {
            Group {
                switch vm.currentField {
                case .businessName:
                    OnboardingQuestionCard(
                        icon: "building.2.fill",
                        question: "What's your business called?",
                        subtitle: vm.fieldSubtitle,
                        placeholder: "e.g. Sunny Days Daycare",
                        text: $vm.businessName
                    )
                case .description:
                    OnboardingQuestionCard(
                        icon: "text.alignleft",
                        question: "Describe what you do",
                        subtitle: vm.fieldSubtitle,
                        placeholder: "Tell us about your business…",
                        text: $vm.description,
                        isMultiline: true
                    )
                case .employeeCount:
                    OnboardingQuestionCard(
                        icon: "person.3.fill",
                        question: "How many employees?",
                        subtitle: vm.fieldSubtitle,
                        placeholder: "12",
                        text: $vm.employeeCountText,
                        keyboard: .numberPad
                    )
                case .state:
                    OnboardingQuestionCard(
                        icon: "map.fill",
                        question: "Which state?",
                        subtitle: vm.fieldSubtitle,
                        placeholder: "NJ",
                        text: $vm.state
                    )
                case .annualRevenue:
                    OnboardingQuestionCard(
                        icon: "dollarsign.circle.fill",
                        question: "Annual revenue?",
                        subtitle: vm.fieldSubtitle,
                        placeholder: "800,000",
                        text: $vm.annualRevenueText,
                        keyboard: .decimalPad
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(vm.currentField)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: FaroSpacing.md) {
            if let error = vm.errorMessage {
                Text(error)
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.danger)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(action: vm.advance) {
                ZStack {
                    if vm.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text(vm.currentField == .annualRevenue ? "Analyze my coverage" : "Continue")
                                .font(FaroType.headline())
                            if vm.currentField != .annualRevenue {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                        .fill(
                            vm.canAdvance
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(FaroPalette.ink.opacity(0.08))
                        )
                }
                .overlay {
                    if vm.canAdvance {
                        RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .shadow(color: vm.canAdvance ? FaroPalette.purpleDeep.opacity(0.35) : .clear, radius: 16, y: 6)
            }
            .disabled(!vm.canAdvance || vm.isSubmitting)
            .animation(.easeInOut(duration: 0.25), value: vm.canAdvance)
        }
    }
}

// MARK: - Question Card

private struct OnboardingQuestionCard: View {
    let icon: String
    let question: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String
    var isMultiline = false
    var keyboard: FaroTextKeyboard = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg) {
            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(FaroPalette.purpleDeep)
                    .symbolRenderingMode(.hierarchical)

                Text(question)
                    .font(FaroType.title(.bold))
                    .foregroundStyle(FaroPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isMultiline {
                TextEditor(text: $text)
                    .font(FaroType.body())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110, maxHeight: 170)
                    .padding(FaroSpacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .strokeBorder(
                                isFocused ? FaroPalette.purpleDeep.opacity(0.5) : FaroPalette.glassStroke,
                                lineWidth: isFocused ? 1.5 : 1
                            )
                    }
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .font(FaroType.title3(.medium))
                    .faroKeyboard(keyboard)
                    .padding(.horizontal, FaroSpacing.md)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .strokeBorder(
                                isFocused ? FaroPalette.purpleDeep.opacity(0.5) : FaroPalette.glassStroke,
                                lineWidth: isFocused ? 1.5 : 1
                            )
                    }
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, FaroSpacing.sm)
        .onAppear { isFocused = true }
    }
}

// MARK: - Shared Question Card (used by VoiceIntakeView too)

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
