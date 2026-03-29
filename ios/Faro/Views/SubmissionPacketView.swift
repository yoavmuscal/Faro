import SwiftUI

struct SubmissionPacketView: View {
    let packet: SubmissionPacket
    let businessName: String

    @State private var pageAppeared = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    private var isWideLayout: Bool { horizontalSizeClass == .regular }
    private var horizontalPagePadding: CGFloat { isWideLayout ? FaroSpacing.xl + 8 : FaroSpacing.md + 4 }

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

    var body: some View {
        ScrollView {
            VStack(spacing: isWideLayout ? FaroSpacing.xl : FaroSpacing.lg) {
                dashboardHero
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 14)

                metricStrip
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 18)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.04), value: pageAppeared)

                submissionGallery
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08), value: pageAppeared)

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

    // MARK: - Hero & metrics

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            Text(timeBasedGreeting)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink.opacity(0.45))

            HStack(alignment: .firstTextBaseline, spacing: FaroSpacing.sm) {
                Capsule()
                    .fill(
                        colorScheme == .dark
                            ? AnyShapeStyle(FaroPalette.purpleDeep.opacity(0.85))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [FaroPalette.purpleDeep, FaroPalette.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .frame(width: 36, height: 5)
                Text("Packet")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.purpleDeep.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(displayTitle)
                .font(isWideLayout ? FaroType.largeTitle() : FaroType.title())
                .foregroundStyle(FaroPalette.ink)
                .multilineTextAlignment(.leading)

            Text("A clear snapshot for underwriters: who you are, how you operate, what you’re asking to place, and any notes that help tell the story.")
                .font(isWideLayout ? FaroType.body() : FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.52))
                .frame(maxWidth: isWideLayout ? 640 : .infinity, alignment: .leading)
                .lineSpacing(3)

            tagBadgesRow
                .padding(.top, FaroSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tagBadgesRow: some View {
        Group {
            if isWideLayout {
                HStack(spacing: FaroSpacing.sm) {
                    if let date = packet.submissionDate {
                        TagPill(text: date, icon: "calendar", tint: FaroPalette.info, expandToFillWidth: true)
                    }
                    TagPill(text: "Carrier-ready", icon: "checkmark.seal.fill", tint: FaroPalette.success, expandToFillWidth: true)
                }
            } else {
                FlowLayout(spacing: FaroSpacing.sm) {
                    if let date = packet.submissionDate {
                        TagPill(text: date, icon: "calendar", tint: FaroPalette.info)
                    }
                    TagPill(text: "Carrier-ready", icon: "checkmark.seal.fill", tint: FaroPalette.success)
                }
            }
        }
    }

    private var metricStrip: some View {
        Group {
            if isWideLayout {
                metricTiles
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    metricTiles
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var metricTiles: some View {
        let tileMinHeight: CGFloat = isWideLayout ? 136 : 0
        let dateDisplay: String = {
            guard let raw = packet.submissionDate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return "—"
            }
            return raw
        }()
        return HStack(alignment: .top, spacing: FaroSpacing.md) {
            FaroDashboardMetricTile(
                title: "Submission date",
                value: dateDisplay,
                subtitle: "Shown on this packet",
                icon: "calendar.circle.fill",
                tint: FaroPalette.info
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: isWideLayout ? tileMinHeight : nil, alignment: .topLeading)
            .frame(minWidth: isWideLayout ? 0 : 160)

            FaroDashboardMetricTile(
                title: "Status",
                value: "Ready to share",
                subtitle: "Formatted for carriers",
                icon: "doc.text.fill",
                tint: FaroPalette.success
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: isWideLayout ? tileMinHeight : nil, alignment: .topLeading)
            .frame(minWidth: isWideLayout ? 0 : 176)
        }
    }

    // MARK: - Section gallery

    private var submissionGallery: some View {
        LazyVGrid(columns: sectionGridColumns, alignment: .leading, spacing: FaroSpacing.lg) {
            if let applicant = packet.applicant {
                applicantSection(applicant)
            }
            if let ops = packet.operations {
                operationsSection(ops)
            }
            if let coverages = packet.requestedCoverages, !coverages.isEmpty {
                requestedCoveragesSection(coverages)
                    .gridCellColumns(isWideLayout ? 2 : 1)
            }
            lossHistoryCleanSection
            if let notes = packet.underwriterNotes, !notes.isEmpty {
                underwriterNotesSection(notes)
            }
        }
    }

    // MARK: - Sections

    private func applicantSection(_ applicant: SubmissionApplicant) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "person.crop.rectangle.fill",
                iconTint: FaroPalette.purpleDeep,
                title: "Applicant",
                subtitle: "Legal entity, structure, and where you operate",
                style: .emphasized
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: FaroSpacing.md) {
                FieldRow(label: "Legal name", value: applicant.legalName)
                FieldRow(label: "DBA", value: applicant.dba)
                FieldRow(label: "Business type", value: applicant.businessType)
                FieldRow(label: "Years in business", value: applicant.yearsInBusiness.map { "\($0)" })
                FieldRow(label: "State of operations", value: applicant.primaryStateOfOperations)
                FieldRow(label: "Incorporated in", value: applicant.stateOfIncorporation)
            }
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
        .overlay { FaroDashboardCardOutline() }
    }

    private func operationsSection(_ ops: SubmissionOperations) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "gearshape.2.fill",
                iconTint: FaroPalette.info,
                title: "Operations",
                subtitle: "Industry codes, headcount, and financial snapshot",
                style: .emphasized
            )

            if let desc = ops.description, !desc.isEmpty {
                Text(desc)
                    .font(FaroType.body())
                    .foregroundStyle(FaroPalette.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            }

            Divider().opacity(0.3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: FaroSpacing.md) {
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
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func requestedCoveragesSection(_ coverages: [SubmissionRequestedCoverage]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "shield.checkered",
                iconTint: FaroPalette.purpleDeep,
                title: "Requested coverages",
                subtitle: "Lines you’re asking to place, with limits and dates",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.lg) {
                ForEach(coverages) { cov in
                    VStack(alignment: .leading, spacing: FaroSpacing.sm) {
                        Text(cov.type ?? "Coverage")
                            .font(FaroType.title3(.semibold))
                            .foregroundStyle(FaroPalette.ink)

                        HStack(alignment: .top, spacing: FaroSpacing.lg) {
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
                                .lineSpacing(4)
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
            }
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private var lossHistoryCleanSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                iconTint: FaroPalette.warning,
                title: "Loss history",
                subtitle: "Claims and incidents you’ve told us about",
                style: .emphasized
            )

            HStack(alignment: .center, spacing: FaroSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(FaroPalette.success)
                Text("No prior losses reported on this submission.")
                    .font(FaroType.body())
                    .foregroundStyle(FaroPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func underwriterNotesSection(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "note.text",
                iconTint: FaroPalette.ink.opacity(0.7),
                title: "Underwriter notes",
                subtitle: "Highlights worth mentioning in a conversation",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(FaroPalette.purpleDeep)
                            .frame(width: 4)
                            .frame(minHeight: 22)
                            .padding(.top, 5)

                        Text(note)
                            .font(FaroType.body())
                            .foregroundStyle(FaroPalette.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, FaroSpacing.xs)
                }
            }
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FaroType.caption())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
            Text(value)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(FaroPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
