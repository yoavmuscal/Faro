import SwiftUI

struct SubmissionPacketView: View {
    let packet: SubmissionPacket
    let businessName: String

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                headerSection
                    .faroStaggerIn(appeared: appeared, delay: 0)

                if let applicant = packet.applicant {
                    applicantSection(applicant)
                        .faroStaggerIn(appeared: appeared, delay: 0.06)
                }

                if let ops = packet.operations {
                    operationsSection(ops)
                        .faroStaggerIn(appeared: appeared, delay: 0.12)
                }

                if let coverages = packet.requestedCoverages, !coverages.isEmpty {
                    requestedCoveragesSection(coverages)
                        .faroStaggerIn(appeared: appeared, delay: 0.18)
                }

                if let losses = packet.lossHistory, !losses.isEmpty {
                    lossHistorySection(losses)
                        .faroStaggerIn(appeared: appeared, delay: 0.24)
                }

                if let notes = packet.underwriterNotes, !notes.isEmpty {
                    underwriterNotesSection(notes)
                        .faroStaggerIn(appeared: appeared, delay: 0.3)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Submission Packet")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            Text("Carrier Submission")
                .font(FaroType.title())
                .foregroundStyle(FaroPalette.ink)

            HStack(spacing: FaroSpacing.sm) {
                if let date = packet.submissionDate {
                    TagPill(text: date, icon: "calendar", tint: FaroPalette.info)
                }
                TagPill(text: "Carrier-Ready", icon: "checkmark.seal.fill", tint: FaroPalette.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func applicantSection(_ applicant: SubmissionApplicant) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Applicant Info", icon: "person.crop.rectangle.fill", tint: FaroPalette.purpleDeep)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: FaroSpacing.sm) {
                FieldRow(label: "Legal Name", value: applicant.legalName)
                FieldRow(label: "DBA", value: applicant.dba)
                FieldRow(label: "Business Type", value: applicant.businessType)
                FieldRow(label: "Years in Business", value: applicant.yearsInBusiness.map { "\($0)" })
                FieldRow(label: "State of Ops", value: applicant.primaryStateOfOperations)
                FieldRow(label: "Incorporated In", value: applicant.stateOfIncorporation)
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func operationsSection(_ ops: SubmissionOperations) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Operations", icon: "gearshape.2.fill", tint: FaroPalette.info)

            if let desc = ops.description, !desc.isEmpty {
                Text(desc)
                    .font(FaroType.subheadline())
                    .foregroundStyle(FaroPalette.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: FaroSpacing.sm) {
                if let sic = ops.sicCode { FieldRow(label: "SIC", value: sic) }
                if let naics = ops.naicsCode { FieldRow(label: "NAICS", value: naics) }
                if let emp = ops.employees {
                    FieldRow(label: "Employees", value: emp.total.map { "\($0)" } ?? "\(emp.fullTime ?? 0) FT / \(emp.partTime ?? 0) PT")
                }
                if let rev = ops.revenue {
                    FieldRow(label: "Annual Revenue", value: rev.annual.map { "$\(Int($0).formatted())" })
                }
                if let pay = ops.payroll {
                    FieldRow(label: "Annual Payroll", value: pay.annual.map { "$\(Int($0).formatted())" })
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func requestedCoveragesSection(_ coverages: [SubmissionRequestedCoverage]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Requested Coverages", icon: "shield.checkered", tint: FaroPalette.purpleDeep)

            ForEach(coverages) { cov in
                VStack(alignment: .leading, spacing: FaroSpacing.xs) {
                    Text(cov.type ?? "Coverage")
                        .font(FaroType.subheadline(.semibold))
                        .foregroundStyle(FaroPalette.ink)

                    HStack(spacing: FaroSpacing.md) {
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
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink.opacity(0.55))
                    }
                }
                .padding(FaroSpacing.sm + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .faroGlassCard(cornerRadius: FaroRadius.md, material: .ultraThinMaterial)
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func lossHistorySection(_ losses: [SubmissionLoss]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Loss History", icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", tint: FaroPalette.warning)

            if losses.isEmpty || (losses.count == 1 && losses.first?.type?.lowercased().contains("none") == true) {
                HStack(spacing: FaroSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FaroPalette.success)
                    Text("No prior losses reported")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.7))
                }
            } else {
                ForEach(losses.indices, id: \.self) { i in
                    let loss = losses[i]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loss.type ?? "Loss")
                                .font(FaroType.subheadline(.semibold))
                                .foregroundStyle(FaroPalette.ink)
                            if let desc = loss.description {
                                Text(desc)
                                    .font(FaroType.caption())
                                    .foregroundStyle(FaroPalette.ink.opacity(0.6))
                            }
                        }
                        Spacer()
                        if let amount = loss.amount {
                            Text("$\(Int(amount).formatted())")
                                .font(FaroType.subheadline(.semibold))
                                .foregroundStyle(FaroPalette.danger)
                        }
                    }
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func underwriterNotesSection(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Underwriter Notes", icon: "note.text", tint: FaroPalette.ink.opacity(0.7))

            ForEach(notes, id: \.self) { note in
                HStack(alignment: .top, spacing: FaroSpacing.sm) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(note)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.45))
            Text(value ?? "—")
                .font(FaroType.subheadline(.medium))
                .foregroundStyle(FaroPalette.ink)
        }
    }
}

private struct MiniField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(FaroType.caption2())
                .foregroundStyle(FaroPalette.ink.opacity(0.4))
            Text(value)
                .font(FaroType.caption(.semibold))
                .foregroundStyle(FaroPalette.ink)
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
