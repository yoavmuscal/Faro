import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Keyboard (number pads)

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

// MARK: - US states (50 + DC, alphabetical by name)

private struct USStateRow: Identifiable {
    var id: String { code }
    let code: String
    let name: String
}

/// All US states and D.C. for the onboarding state step (two-letter codes).
private let usStateRows: [USStateRow] = [
    .init(code: "AL", name: "Alabama"),
    .init(code: "AK", name: "Alaska"),
    .init(code: "AZ", name: "Arizona"),
    .init(code: "AR", name: "Arkansas"),
    .init(code: "CA", name: "California"),
    .init(code: "CO", name: "Colorado"),
    .init(code: "CT", name: "Connecticut"),
    .init(code: "DE", name: "Delaware"),
    .init(code: "DC", name: "District of Columbia"),
    .init(code: "FL", name: "Florida"),
    .init(code: "GA", name: "Georgia"),
    .init(code: "HI", name: "Hawaii"),
    .init(code: "ID", name: "Idaho"),
    .init(code: "IL", name: "Illinois"),
    .init(code: "IN", name: "Indiana"),
    .init(code: "IA", name: "Iowa"),
    .init(code: "KS", name: "Kansas"),
    .init(code: "KY", name: "Kentucky"),
    .init(code: "LA", name: "Louisiana"),
    .init(code: "ME", name: "Maine"),
    .init(code: "MD", name: "Maryland"),
    .init(code: "MA", name: "Massachusetts"),
    .init(code: "MI", name: "Michigan"),
    .init(code: "MN", name: "Minnesota"),
    .init(code: "MS", name: "Mississippi"),
    .init(code: "MO", name: "Missouri"),
    .init(code: "MT", name: "Montana"),
    .init(code: "NE", name: "Nebraska"),
    .init(code: "NV", name: "Nevada"),
    .init(code: "NH", name: "New Hampshire"),
    .init(code: "NJ", name: "New Jersey"),
    .init(code: "NM", name: "New Mexico"),
    .init(code: "NY", name: "New York"),
    .init(code: "NC", name: "North Carolina"),
    .init(code: "ND", name: "North Dakota"),
    .init(code: "OH", name: "Ohio"),
    .init(code: "OK", name: "Oklahoma"),
    .init(code: "OR", name: "Oregon"),
    .init(code: "PA", name: "Pennsylvania"),
    .init(code: "RI", name: "Rhode Island"),
    .init(code: "SC", name: "South Carolina"),
    .init(code: "SD", name: "South Dakota"),
    .init(code: "TN", name: "Tennessee"),
    .init(code: "TX", name: "Texas"),
    .init(code: "UT", name: "Utah"),
    .init(code: "VT", name: "Vermont"),
    .init(code: "VA", name: "Virginia"),
    .init(code: "WA", name: "Washington"),
    .init(code: "WV", name: "West Virginia"),
    .init(code: "WI", name: "Wisconsin"),
    .init(code: "WY", name: "Wyoming"),
]

// MARK: - Onboarding state

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Field: Int, CaseIterable {
        case businessName, contactInfo, description, employeeCount, state, annualRevenue
    }

    @Published var businessName = ""
    @Published var contactFirstName = ""
    @Published var contactMiddleName = ""
    @Published var contactLastName = ""
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
        case .contactInfo:
            return !contactFirstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !contactLastName.trimmingCharacters(in: .whitespaces).isEmpty
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
        case .contactInfo: return "We'll personalize your reports with their details."
        case .description: return "The more detail, the better we can match you."
        case .employeeCount: return "This helps size workers' comp and liability."
        case .state: return "Pick from the list — rules and filings depend on where you operate."
        case .annualRevenue: return "Revenue drives premium estimates."
        }
    }

    var fieldQuestion: String {
        switch currentField {
        case .businessName: return "What's your business called?"
        case .contactInfo: return "Who's the point of contact?"
        case .description: return "Tell us what you do"
        case .employeeCount: return "How big is the team?"
        case .state: return "Where are you based?"
        case .annualRevenue: return "What's the annual revenue?"
        }
    }

    var fieldIcon: String {
        switch currentField {
        case .businessName: return "building.2.fill"
        case .contactInfo: return "person.crop.circle.fill"
        case .description: return "text.alignleft"
        case .employeeCount: return "person.3.fill"
        case .state: return "map.fill"
        case .annualRevenue: return "dollarsign.circle.fill"
        }
    }

    func advance() {
        guard canAdvance else { return }
        if currentField == .annualRevenue {
            Task { await submit() }
        } else {
            currentField = Field(rawValue: currentField.rawValue + 1)!
        }
    }

    func goBack() {
        guard currentField.rawValue > 0 else { return }
        currentField = Field(rawValue: currentField.rawValue - 1)!
    }

    func loadDemoData() {
        businessName = "Sunny Days Daycare"
        contactFirstName = "Sarah"
        contactMiddleName = ""
        contactLastName = "Johnson"
        description = "Licensed childcare center serving children ages 6 weeks to 12 years. We provide full-day care, after-school programs, and summer camps across 3 locations in central New Jersey. Our certified staff oversee indoor play areas, outdoor playgrounds, and early learning programs."
        employeeCountText = "28"
        state = "NJ"
        annualRevenueText = "1,200,000"
        currentField = .annualRevenue
    }

    func prefillContact(firstName: String, lastName: String) {
        if contactFirstName.isEmpty { contactFirstName = firstName }
        if contactLastName.isEmpty { contactLastName = lastName }
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
            annualRevenue: revenue,
            contactFirstName: contactFirstName.isEmpty ? nil : contactFirstName,
            contactMiddleName: contactMiddleName.isEmpty ? nil : contactMiddleName,
            contactLastName: contactLastName.isEmpty ? nil : contactLastName,
            contactEmail: nil
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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = OnboardingViewModel()
    @State private var appeared = false
    /// Lifts the state step above the footer while the autocomplete panel is open.
    @State private var stateSuggestionPopupOpen = false
    var isDemo: Bool = false

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, FaroSpacing.lg)

                Spacer(minLength: FaroSpacing.xl)

                questionArea
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    .zIndex(stateSuggestionPopupOpen ? 5 : 0)

                Spacer(minLength: FaroSpacing.xl)

                footer
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
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
        .navigationDestination(item: $vm.sessionId) { sessionId in
            AgentTrackerView(sessionId: sessionId, businessName: vm.businessName) {
                vm.sessionId = nil
                dismiss()
            }
        }
        .onChange(of: vm.sessionId) { _, newId in
            if let id = newId {
                appState.contactFirstName = vm.contactFirstName
                appState.contactMiddleName = vm.contactMiddleName
                appState.contactLastName = vm.contactLastName
                appState.beginNewAnalysis(sessionId: id, businessName: vm.businessName)
            }
        }
        .onChange(of: vm.currentField) { _, _ in
            stateSuggestionPopupOpen = false
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
            vm.prefillContact(firstName: appState.userFirstName, lastName: appState.userLastName)
            if isDemo {
                vm.loadDemoData()
            }
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
            .frame(maxWidth: 240)

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
                        icon: vm.fieldIcon,
                        question: vm.fieldQuestion,
                        subtitle: vm.fieldSubtitle,
                        placeholder: "e.g. Sunny Days Daycare",
                        text: $vm.businessName,
                        onSubmit: vm.advance
                    )
                case .contactInfo:
                    ContactInfoCard(
                        firstName: $vm.contactFirstName,
                        middleName: $vm.contactMiddleName,
                        lastName: $vm.contactLastName,
                        onSubmit: vm.advance
                    )
                case .description:
                    OnboardingQuestionCard(
                        icon: vm.fieldIcon,
                        question: vm.fieldQuestion,
                        subtitle: vm.fieldSubtitle,
                        placeholder: "Tell us about your business…",
                        text: $vm.description,
                        isMultiline: true,
                        onSubmit: vm.advance
                    )
                case .employeeCount:
                    OnboardingQuestionCard(
                        icon: vm.fieldIcon,
                        question: vm.fieldQuestion,
                        subtitle: vm.fieldSubtitle,
                        placeholder: "12",
                        text: $vm.employeeCountText,
                        keyboard: .numberPad,
                        onSubmit: vm.advance
                    )
                case .state:
                    OnboardingStatePickerCard(
                        icon: vm.fieldIcon,
                        question: vm.fieldQuestion,
                        subtitle: vm.fieldSubtitle,
                        selectedCode: $vm.state,
                        onSuggestionPopupChange: { stateSuggestionPopupOpen = $0 }
                    )
                case .annualRevenue:
                    OnboardingQuestionCard(
                        icon: vm.fieldIcon,
                        question: vm.fieldQuestion,
                        subtitle: vm.fieldSubtitle,
                        placeholder: "800,000",
                        text: $vm.annualRevenueText,
                        keyboard: .decimalPad,
                        onSubmit: vm.advance
                    )
                }
            }
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

// MARK: - State picker (search + filtered list + browse menu)

private struct OnboardingStatePickerCard: View {
    let icon: String
    let question: String
    let subtitle: String
    @Binding var selectedCode: String
    var onSuggestionPopupChange: ((Bool) -> Void)? = nil

    @State private var query: String = ""
    @State private var isProgrammaticQuery = false
    @FocusState private var fieldFocused: Bool

    private var filteredRows: [USStateRow] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return usStateRows }
        return usStateRows.filter { row in
            row.name.localizedCaseInsensitiveContains(q)
                || row.code.localizedCaseInsensitiveContains(q)
        }
    }

    /// Floating suggestions only while typing (not the empty “browse all” panel).
    private var showSuggestionPopup: Bool {
        guard fieldFocused else { return false }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if queryMatchesCommittedSelection { return false }
        return true
    }

    private var queryMatchesCommittedSelection: Bool {
        guard let row = usStateRows.first(where: { $0.code == selectedCode }) else { return false }
        return query == "\(row.name) (\(row.code))"
    }

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

            HStack(spacing: FaroSpacing.sm) {
                TextField("Search state or abbreviation…", text: $query)
                    .font(FaroType.title3(.medium))
                    .focused($fieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { commitIfSingleMatchOrExactCode() }
                    .onChange(of: query) { _, newValue in
                        if isProgrammaticQuery { return }
                        if !selectedCode.isEmpty {
                            if let row = usStateRows.first(where: { $0.code == selectedCode }) {
                                let label = "\(row.name) (\(row.code))"
                                if newValue != label { selectedCode = "" }
                            }
                        }
                    }
                    .padding(.horizontal, FaroSpacing.md)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .fill(FaroPalette.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .strokeBorder(
                                fieldFocused ? FaroPalette.purpleDeep.opacity(0.5) : FaroPalette.glassStroke,
                                lineWidth: fieldFocused ? 1.5 : 1
                            )
                    }

                Menu {
                    ForEach(usStateRows) { row in
                        Button {
                            applySelection(row)
                        } label: {
                            Text("\(row.name) (\(row.code))")
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .frame(width: 44, height: 54)
                        .background {
                            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                                .fill(FaroPalette.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                                .strokeBorder(FaroPalette.glassStroke, lineWidth: 1)
                        }
                }
                .accessibilityLabel("Browse all states")
            }
            .zIndex(1)
            .overlay(alignment: .topLeading) {
                if showSuggestionPopup {
                    suggestionPopupContent
                        .offset(y: 54 + FaroSpacing.sm)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSuggestionPopup)
        }
        .padding(.horizontal, FaroSpacing.sm)
        .onAppear {
            syncQueryFromSelectedCode()
            onSuggestionPopupChange?(showSuggestionPopup)
        }
        .onChange(of: selectedCode) { _, _ in syncQueryFromSelectedCode() }
        .onChange(of: showSuggestionPopup) { _, newValue in
            onSuggestionPopupChange?(newValue)
        }
    }

    private var suggestionPopupContent: some View {
        Group {
            if filteredRows.isEmpty {
                Text("No matches — try a different spelling or use the list button.")
                    .font(FaroType.caption())
                    .foregroundStyle(FaroPalette.ink.opacity(0.55))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, FaroSpacing.md)
                    .padding(.vertical, FaroSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredRows) { row in
                            Button {
                                applySelection(row)
                                fieldFocused = false
                            } label: {
                                HStack {
                                    Text(row.name)
                                        .font(FaroType.body(.medium))
                                        .foregroundStyle(FaroPalette.ink)
                                    Spacer()
                                    Text(row.code)
                                        .font(FaroType.caption(.semibold))
                                        .foregroundStyle(FaroPalette.ink.opacity(0.45))
                                }
                                .padding(.horizontal, FaroSpacing.md)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    row.code == selectedCode
                                        ? FaroPalette.purpleDeep.opacity(0.08)
                                        : Color.clear
                                )
                            }
                            .buttonStyle(.plain)
                            if row.id != filteredRows.last?.id {
                                Divider().padding(.leading, FaroSpacing.md)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .fill(FaroPalette.surface)
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke, lineWidth: 1)
        }
    }

    private func syncQueryFromSelectedCode() {
        guard let row = usStateRows.first(where: { $0.code == selectedCode }) else {
            if selectedCode.isEmpty { query = "" }
            return
        }
        isProgrammaticQuery = true
        query = "\(row.name) (\(row.code))"
        DispatchQueue.main.async {
            isProgrammaticQuery = false
        }
    }

    private func applySelection(_ row: USStateRow) {
        selectedCode = row.code
        isProgrammaticQuery = true
        query = "\(row.name) (\(row.code))"
        DispatchQueue.main.async {
            isProgrammaticQuery = false
        }
    }

    /// If only one row matches the filter, or the query is a valid two-letter code, commit selection.
    private func commitIfSingleMatchOrExactCode() {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return }
        let rows = filteredRows
        if rows.count == 1, let only = rows.first {
            applySelection(only)
            return
        }
        let upper = q.uppercased()
        if upper.count == 2, let row = usStateRows.first(where: { $0.code == upper }) {
            applySelection(row)
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
    var onSubmit: () -> Void = {}
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
                            .fill(FaroPalette.surface)
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
                    .onSubmit { onSubmit() }
                    .padding(.horizontal, FaroSpacing.md)
                    .frame(height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                            .fill(FaroPalette.surface)
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

// MARK: - Contact Info Card (multi-field step)

private struct ContactInfoCard: View {
    @Binding var firstName: String
    @Binding var middleName: String
    @Binding var lastName: String
    var onSubmit: () -> Void = {}
    @FocusState private var focusedField: ContactField?

    private enum ContactField: Hashable {
        case first, middle, last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg) {
            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(FaroPalette.purpleDeep)
                    .symbolRenderingMode(.hierarchical)

                Text("Who's the point of contact?")
                    .font(FaroType.title(.bold))
                    .foregroundStyle(FaroPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("We'll personalize your reports with their details.")
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: FaroSpacing.sm) {
                contactField("First name", text: $firstName, field: .first) {
                    focusedField = .middle
                }
                contactField("Middle name (optional)", text: $middleName, field: .middle) {
                    focusedField = .last
                }
                contactField("Last name", text: $lastName, field: .last) {
                    onSubmit()
                }
            }
        }
        .padding(.horizontal, FaroSpacing.sm)
        .onAppear { focusedField = .first }
    }

    private func contactField(
        _ placeholder: String,
        text: Binding<String>,
        field: ContactField,
        onFieldSubmit: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: text)
            .font(FaroType.title3(.medium))
            .focused($focusedField, equals: field)
            .onSubmit(onFieldSubmit)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif
            .padding(.horizontal, FaroSpacing.md)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .fill(FaroPalette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FaroRadius.md, style: .continuous)
                    .strokeBorder(
                        focusedField == field
                        ? FaroPalette.purpleDeep.opacity(0.5)
                        : FaroPalette.glassStroke,
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
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
                    .faroGlassCard(cornerRadius: FaroRadius.md)
            } else {
                TextField(placeholder, text: $text)
                    .font(FaroType.body())
                    .faroKeyboard(keyboard)
                    .padding(FaroSpacing.md)
                    .faroGlassCard(cornerRadius: FaroRadius.md)
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
