import SwiftUI

struct SubmissionPacketView: View {
    let packet: SubmissionPacket
    let businessName: String

    @State private var pageAppeared = false
    /// Collapsible sections — start with the essentials open; details and notes on demand.
    @State private var applicantOpen = true
    @State private var operationsOpen = false
    @State private var coveragesOpen = true
    @State private var lossOpen = true
    @State private var notesOpen = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { horizontalSizeClass == .regular }
    private var horizontalPagePadding: CGFloat { FaroSpacing.dashboardPageHorizontal(isWideLayout: isWideLayout) }

    private var sectionGridColumns: [GridItem] {
        if isWideLayout {
            [
                GridItem(.flexible(), spacing: FaroSpacing.lg, alignment: .topLeading),
                GridItem(.flexible(), spacing: FaroSpacing.lg, alignment: .topLeading),
            ]
        } else {
            [GridItem(.flexible(), alignment: .topLeading)]
        }
    }

    private var fieldGridColumns: [GridItem] {
        isWideLayout
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
    }

    private var cardInnerPadding: CGFloat { FaroSpacing.xl }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var displayTitle: String {
        let n = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Carrier submission" : n
    }

    private var coverageCount: Int {
        packet.requestedCoverages?.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isWideLayout ? FaroSpacing.xl : FaroSpacing.lg) {
                packetHeader
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 14)

                submissionSections
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.06), value: pageAppeared)

                Spacer(minLength: 40)
            }
            .padding(.top, isWideLayout ? FaroSpacing.lg : FaroSpacing.md)
            .padding(.bottom, FaroSpacing.xl)
            .padding(.horizontal, horizontalPagePadding)
        }
        .faroCanvasBackground()
        .navigationTitle("Submission Packet")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                pageAppeared = true
            }
        }
    }

    // MARK: - Header (single glance, no duplicate metrics below)

    private var packetHeader: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text(timeBasedGreeting)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.45))

            Text(displayTitle)
                .font(isWideLayout ? FaroType.largeTitle() : FaroType.title())
                .foregroundStyle(FaroPalette.ink)
                .multilineTextAlignment(.leading)

            Text("Underwriter-ready summary: who you are, how you operate, what to place, and anything carriers should know.")
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.52))
                .frame(maxWidth: isWideLayout ? 560 : .infinity, alignment: .leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            headerChipsRow
                .padding(.top, FaroSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerChipsRow: some View {
        let dateDisplay: String = {
            guard let raw = packet.submissionDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return "Date TBD"
            }
            return raw
        }()

        return FlowLayout(spacing: FaroSpacing.sm) {
            TagPill(text: dateDisplay, icon: "calendar", tint: FaroPalette.info, expandToFillWidth: false)
            TagPill(text: "Ready to share", icon: "checkmark.seal.fill", tint: FaroPalette.success, expandToFillWidth: false)
            if coverageCount > 0 {
                TagPill(
                    text: coverageCount == 1 ? "1 coverage" : "\(coverageCount) coverages",
                    icon: "shield.checkered",
                    tint: FaroPalette.purpleDeep,
                    expandToFillWidth: false
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sections

    private var submissionSections: some View {
        LazyVGrid(columns: sectionGridColumns, alignment: .leading, spacing: FaroSpacing.lg) {
            if let applicant = packet.applicant {
                collapsibleApplicant(applicant)
            }
            if let ops = packet.operations {
                collapsibleOperations(ops)
            }
            if let coverages = packet.requestedCoverages, !coverages.isEmpty {
                collapsibleCoverages(coverages)
                    .gridCellColumns(isWideLayout ? 2 : 1)
            }
            collapsibleLossHistory
            if let notes = packet.underwriterNotes, !notes.isEmpty {
                collapsibleNotes(notes)
            }
        }
    }

    private func collapsibleApplicant(_ applicant: SubmissionApplicant) -> some View {
        PacketCollapsibleCard(
            title: "Applicant",
            subtitle: "Legal name, structure, and where you operate",
            icon: "person.crop.rectangle.fill",
            iconTint: FaroPalette.purpleDeep,
            isExpanded: $applicantOpen,
            innerPadding: cardInnerPadding
        ) {
            LazyVGrid(columns: fieldGridColumns, alignment: .leading, spacing: FaroSpacing.md) {
                FieldRow(label: "Legal name", value: applicant.legalName)
                FieldRow(label: "DBA", value: applicant.dba)
                FieldRow(label: "Business type", value: applicant.businessType)
                FieldRow(label: "Years in business", value: applicant.yearsInBusiness.map { "\($0)" })
                FieldRow(label: "State of operations", value: applicant.primaryStateOfOperations)
                FieldRow(label: "Incorporated in", value: applicant.stateOfIncorporation)
            }
        }
    }

    private func collapsibleOperations(_ ops: SubmissionOperations) -> some View {
        PacketCollapsibleCard(
            title: "Operations",
            subtitle: "What you do, size, and financial snapshot",
            icon: "gearshape.2.fill",
            iconTint: FaroPalette.info,
            isExpanded: $operationsOpen,
            innerPadding: cardInnerPadding
        ) {
            VStack(alignment: .leading, spacing: FaroSpacing.md) {
                if let desc = ops.description, !desc.isEmpty {
                    Text(desc)
                        .font(FaroType.body())
                        .foregroundStyle(FaroPalette.ink.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }

                Divider().opacity(0.3)

                LazyVGrid(columns: fieldGridColumns, alignment: .leading, spacing: FaroSpacing.md) {
                    if let sic = ops.sicCode { FieldRow(label: "SIC", value: sic) }
                    if let naics = ops.naicsCode { FieldRow(label: "NAICS", value: naics) }
                    if let emp = ops.employees {
                        FieldRow(label: "Employees", value: emp.total.map { "\($0)" } ?? "\(emp.fullTime ?? 0) FT / \(emp.partTime ?? 0) PT")
                    }
                    if let rev = ops.revenue {
                        FieldRow(label: "Annual revenue", value: rev.annual.map { "$\(Int($0).formatted())" })
                    }
                    if let pay = ops.payroll {
                        FieldRow(label: "Annual payroll", value: pay.annual.map { "$\(Int($0).formatted())" })
                    }
                }
            }
        }
    }

    private func collapsibleCoverages(_ coverages: [SubmissionRequestedCoverage]) -> some View {
        PacketCollapsibleCard(
            title: "Requested coverages",
            subtitle: "Lines, limits, and effective dates",
            icon: "shield.checkered",
            iconTint: FaroPalette.purpleDeep,
            isExpanded: $coveragesOpen,
            innerPadding: cardInnerPadding
        ) {
            VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                ForEach(Array(coverages.enumerated()), id: \.offset) { index, cov in
                    coverageItemCard(cov, index: index, total: coverages.count)
                }
            }
        }
    }

    private func coverageItemCard(_ cov: SubmissionRequestedCoverage, index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            HStack {
                Text(cov.type ?? "Coverage")
                    .font(FaroType.headline(.semibold))
                    .foregroundStyle(FaroPalette.ink)
                Spacer(minLength: 0)
                if total > 1 {
                    Text("\(index + 1)/\(total)")
                        .font(FaroType.caption(.medium))
                        .foregroundStyle(FaroPalette.ink.opacity(0.38))
                }
            }

            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                if let limits = cov.limits {
                    MiniField(label: "Limits", value: limits)
                }
                if let deductible = cov.deductible {
                    MiniField(label: "Deductible", value: deductible)
                }
                if let date = cov.effectiveDate {
                    MiniField(label: "Effective", value: date)
                }
            }

            if let notes = cov.notes, !notes.isEmpty {
                Text(notes)
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                    .padding(.top, FaroSpacing.xs)
            }
        }
        .padding(FaroSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                .fill(FaroPalette.surface.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FaroRadius.lg, style: .continuous)
                .strokeBorder(FaroPalette.glassStroke.opacity(0.2), lineWidth: 0.5)
        }
    }

    private var collapsibleLossHistory: some View {
        PacketCollapsibleCard(
            title: "Loss history",
            subtitle: "Claims reported on this submission",
            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            iconTint: FaroPalette.warning,
            isExpanded: $lossOpen,
            innerPadding: cardInnerPadding
        ) {
            HStack(alignment: .center, spacing: FaroSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(FaroPalette.success)
                Text("No prior losses reported.")
                    .font(FaroType.body())
                    .foregroundStyle(FaroPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func collapsibleNotes(_ notes: [String]) -> some View {
        PacketCollapsibleCard(
            title: "Underwriter notes",
            subtitle: "Talking points for carriers",
            icon: "note.text",
            iconTint: FaroPalette.ink.opacity(0.7),
            isExpanded: $notesOpen,
            innerPadding: cardInnerPadding
        ) {
            VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    FaroDashboardStripeBulletRow(text: note, stripe: FaroPalette.purpleDeep, textOpacity: 0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Collapsible card chrome

private struct PacketCollapsibleCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconTint: Color
    @Binding var isExpanded: Bool
    var innerPadding: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: FaroSpacing.md) {
                    FaroDashboardInsightSectionHeader(
                        icon: icon,
                        iconTint: iconTint,
                        title: title,
                        subtitle: subtitle,
                        style: .emphasized
                    )
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(FaroPalette.ink.opacity(0.35))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, FaroSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(innerPadding)
        .faroDashboardCardSurface(innerPadding: 0)
        .overlay { FaroDashboardCardOutline() }
    }
}

// MARK: - Field helpers

private struct FieldRow: View {
    let label: String
    let value: String?

    init(label: String, value: String?) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.48))
            Text(value ?? "—")
                .font(FaroType.body(.medium))
                .foregroundStyle(FaroPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MiniField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FaroSpacing.sm) {
            Text(label)
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        SubmissionPacketView(
            packet: SubmissionPacket(
                submissionDate: "2026-03-28",
                applicant: SubmissionApplicant(
                    legalName: "Sunny Days Daycare LLC",
                    dba: "Sunny Days Daycare",
                    businessType: "LLC",
                    yearsInBusiness: 5,
                    stateOfIncorporation: "NJ",
                    primaryStateOfOperations: "NJ",
                    mailingAddress: "123 Main St, Newark, NJ",
                    phone: nil,
                    website: nil,
                    federalEin: nil
                ),
                operations: SubmissionOperations(
                    description: "Licensed daycare facility serving children ages 2-12",
                    sicCode: "8351",
                    naicsCode: "624410",
                    employees: SubmissionEmployeeInfo(fullTime: 10, partTime: 2, total: 12),
                    revenue: SubmissionRevenueInfo(annual: 800000, projectedGrowth: "10%"),
                    payroll: SubmissionPayrollInfo(annual: 480000),
                    subcontractors: nil
                ),
                lossHistory: [],
                requestedCoverages: [
                    SubmissionRequestedCoverage(type: "General Liability", limits: "$1M / $2M", deductible: "$1,000", effectiveDate: "2026-04-01", notes: nil),
                    SubmissionRequestedCoverage(type: "Workers Compensation", limits: "Statutory", deductible: "N/A", effectiveDate: "2026-04-01", notes: "12 employees — NJ statutory requirement"),
                ],
                underwriterNotes: [
                    "Daycare operations require enhanced abuse & molestation coverage",
                    "Background check compliance should be verified for all staff",
                ]
            ),
            businessName: "Sunny Days Daycare"
        )
    }
}
