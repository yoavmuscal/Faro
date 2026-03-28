import SwiftUI
import Charts

struct RiskProfileView: View {
    let riskProfile: RiskProfile
    let businessName: String

    private var riskLevelNormalized: Double {
        switch riskProfile.riskLevel?.lowercased() {
        case "low": return 0.25
        case "medium": return 0.55
        case "high": return 0.85
        default: return 0.5
        }
    }

    private var riskLevelColor: Color {
        switch riskProfile.riskLevel?.lowercased() {
        case "low": return FaroPalette.success
        case "medium": return FaroPalette.warning
        case "high": return FaroPalette.danger
        default: return FaroPalette.info
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FaroSpacing.lg) {
                headerSection
                riskGaugeSection
                if let exposures = riskProfile.primaryExposures, !exposures.isEmpty {
                    exposuresSection(exposures)
                }
                if let stateReqs = riskProfile.stateRequirements, !stateReqs.isEmpty {
                    stateRequirementsSection(stateReqs)
                }
                if let empImplications = riskProfile.employeeImplications, !empImplications.isEmpty {
                    employeeSection(empImplications)
                }
                if let unusualRisks = riskProfile.unusualRisks, !unusualRisks.isEmpty {
                    unusualRisksSection(unusualRisks)
                }
                if let summary = riskProfile.reasoningSummary, !summary.isEmpty {
                    summarySection(summary)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, FaroSpacing.md)
        }
        .faroCanvasBackground()
        .navigationTitle("Risk Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FaroSpacing.xs) {
            Text("Risk Assessment")
                .font(FaroType.title())
                .foregroundStyle(FaroPalette.ink)

            HStack(spacing: FaroSpacing.sm) {
                if let industry = riskProfile.industry {
                    TagPill(text: industry, icon: "building.2.fill", tint: FaroPalette.purpleDeep)
                }
                if let sic = riskProfile.sicCode {
                    TagPill(text: "SIC \(sic)", icon: "number", tint: FaroPalette.info)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FaroSpacing.md)
    }

    private var riskGaugeSection: some View {
        VStack(spacing: FaroSpacing.md) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(FaroPalette.ink.opacity(0.08), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * riskLevelNormalized)
                    .stroke(
                        riskLevelColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))

                VStack(spacing: 4) {
                    Text(riskProfile.riskLevel?.capitalized ?? "Unknown")
                        .font(FaroType.title2())
                        .foregroundStyle(riskLevelColor)
                    Text("Risk Level")
                        .font(FaroType.caption())
                        .foregroundStyle(FaroPalette.ink.opacity(0.5))
                }
            }
            .frame(width: 160, height: 160)

            if let revenue = riskProfile.revenueExposure, !revenue.isEmpty {
                HStack(spacing: FaroSpacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(FaroPalette.warning)
                    Text(revenue)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(FaroSpacing.lg)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func exposuresSection(_ exposures: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Primary Exposures", icon: "exclamationmark.triangle.fill", tint: FaroPalette.warning)

            FlowLayout(spacing: FaroSpacing.sm) {
                ForEach(exposures, id: \.self) { exposure in
                    HStack(spacing: 6) {
                        Image(systemName: "shield.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(FaroPalette.warning)
                        Text(exposure)
                            .font(FaroType.caption())
                            .foregroundStyle(FaroPalette.ink)
                    }
                    .padding(.horizontal, FaroSpacing.sm + 2)
                    .padding(.vertical, FaroSpacing.xs + 2)
                    .faroGlassCard(cornerRadius: FaroRadius.md, material: .ultraThinMaterial)
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func stateRequirementsSection(_ reqs: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "State Requirements", icon: "building.columns.fill", tint: FaroPalette.info)

            ForEach(reqs, id: \.self) { req in
                HStack(alignment: .top, spacing: FaroSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(FaroPalette.info)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(req)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.8))
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func employeeSection(_ implications: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Employee Implications", icon: "person.3.fill", tint: FaroPalette.purpleDeep)

            ForEach(implications, id: \.self) { item in
                HStack(alignment: .top, spacing: FaroSpacing.sm) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundStyle(FaroPalette.purpleDeep)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(item)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.8))
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func unusualRisksSection(_ risks: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "Unusual Risks", icon: "bolt.trianglebadge.exclamationmark.fill", tint: FaroPalette.danger)

            ForEach(risks, id: \.self) { risk in
                HStack(alignment: .top, spacing: FaroSpacing.sm) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(FaroPalette.danger)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(risk)
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.8))
                }
            }
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.sm) {
            SectionHeader(title: "AI Reasoning", icon: "brain.fill", tint: FaroPalette.purpleDeep)

            Text(summary)
                .font(FaroType.body())
                .foregroundStyle(FaroPalette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FaroSpacing.md)
        .faroGlassCard(cornerRadius: FaroRadius.xl)
        .padding(.horizontal, FaroSpacing.md)
    }
}

// MARK: - Helpers

struct SectionHeader: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: FaroSpacing.xs + 2) {
            Image(systemName: icon)
                .font(FaroType.subheadline(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(FaroType.headline())
                .foregroundStyle(FaroPalette.ink)
        }
    }
}

struct TagPill: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(FaroType.caption(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, FaroSpacing.sm)
        .padding(.vertical, FaroSpacing.xs)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + rowHeight), origins)
    }
}

#Preview {
    NavigationStack {
        RiskProfileView(
            riskProfile: RiskProfile(
                industry: "Childcare / Daycare",
                sicCode: "8351",
                riskLevel: "high",
                primaryExposures: ["Bodily injury to minors", "Professional negligence", "Employment practices", "Property damage"],
                stateRequirements: [
                    "Workers Compensation required for all employees in NJ",
                    "General Liability minimum $1M per occurrence",
                    "Abuse & Molestation coverage required for childcare"
                ],
                employeeImplications: [
                    "12 employees triggers full workers comp requirements",
                    "Background check compliance for all childcare staff"
                ],
                revenueExposure: "$800K revenue — mid-range exposure bracket",
                unusualRisks: ["Supervision of minors creates elevated liability exposure"],
                reasoningSummary: "A 12-employee New Jersey daycare with $800K in annual revenue faces significant risk exposure primarily due to the supervision of minors. NJ mandates workers comp, and the childcare industry has elevated professional liability requirements including abuse & molestation coverage."
            ),
            businessName: "Sunny Days Daycare"
        )
    }
}
