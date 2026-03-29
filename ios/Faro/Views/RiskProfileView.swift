import SwiftUI

struct RiskProfileView: View {
    let riskProfile: RiskProfile
    let businessName: String

    @State private var gaugeProgress: Double = 0
    @State private var pageAppeared = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    private var isWideLayout: Bool { horizontalSizeClass == .regular }
    private var horizontalPagePadding: CGFloat { FaroSpacing.dashboardPageHorizontal(isWideLayout: isWideLayout) }
    private var insightGridColumns: [GridItem] {
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

    private var displayTitle: String {
        let n = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your risk profile" : n
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

                riskGaugeSection
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08), value: pageAppeared)

                insightGallery
                    .opacity(pageAppeared ? 1 : 0)
                    .offset(y: pageAppeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1), value: pageAppeared)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isWideLayout ? FaroSpacing.lg : FaroSpacing.md)
            .padding(.bottom, FaroSpacing.xl)
            .padding(.horizontal, horizontalPagePadding)
        }
        .faroCanvasBackground()
        .navigationTitle("Risk Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            gaugeProgress = riskLevelNormalized
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
                Text("Assessment")
                    .font(FaroType.caption(.semibold))
                    .foregroundStyle(FaroPalette.purpleDeep.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(displayTitle)
                .font(isWideLayout ? FaroType.largeTitle() : FaroType.title())
                .foregroundStyle(FaroPalette.ink)
                .multilineTextAlignment(.leading)

            Text("See where loss can show up, what your state expects, and how staffing and operations affect exposure—all in plain language.")
                .font(isWideLayout ? FaroType.body() : FaroType.subheadline())
                .foregroundStyle(FaroPalette.ink.opacity(0.52))
                .frame(maxWidth: isWideLayout ? 640 : .infinity, alignment: .leading)
                .lineSpacing(3)

            tagBadgesRow
                .padding(.top, FaroSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tagBadgesRow: some View {
        if riskProfile.industry == nil && riskProfile.sicCode == nil {
            EmptyView()
        } else {
            Group {
                if isWideLayout {
                    HStack(spacing: FaroSpacing.sm) {
                        if let industry = riskProfile.industry {
                            TagPill(
                                text: industry,
                                icon: "building.2.fill",
                                tint: FaroPalette.purpleDeep,
                                expandToFillWidth: true
                            )
                        }
                        if let sic = riskProfile.sicCode {
                            TagPill(text: "SIC \(sic)", icon: "number", tint: FaroPalette.info, expandToFillWidth: true)
                        }
                    }
                } else {
                    FlowLayout(spacing: FaroSpacing.sm) {
                        if let industry = riskProfile.industry {
                            TagPill(text: industry, icon: "building.2.fill", tint: FaroPalette.purpleDeep)
                        }
                        if let sic = riskProfile.sicCode {
                            TagPill(text: "SIC \(sic)", icon: "number", tint: FaroPalette.info)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metricStrip: some View {
        metricTiles
            .frame(maxWidth: .infinity)
    }

    private var metricTiles: some View {
        let tileMinHeight = FaroSpacing.dashboardMetricTileMinHeight(isWideLayout: isWideLayout)
        let level = riskProfile.riskLevel?.capitalized ?? "—"
        let contextValue: String = {
            if let ind = riskProfile.industry, !ind.isEmpty { return ind }
            if let sic = riskProfile.sicCode { return "SIC \(sic)" }
            return "—"
        }()
        return HStack(alignment: .top, spacing: FaroSpacing.md) {
            FaroDashboardMetricTile(
                title: "Risk level",
                value: level,
                subtitle: "How we’re sizing overall risk",
                icon: "chart.bar.fill",
                tint: riskLevelColor
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: tileMinHeight, alignment: .topLeading)

            FaroDashboardMetricTile(
                title: "Business context",
                value: contextValue,
                subtitle: "Industry & classification",
                icon: "building.columns.fill",
                tint: FaroPalette.purpleDeep
            )
            .frame(maxWidth: .infinity, minHeight: tileMinHeight, maxHeight: tileMinHeight, alignment: .topLeading)
        }
    }

    private var riskGaugeSection: some View {
        let gaugeSize: CGFloat = isWideLayout ? 196 : 180
        return VStack(spacing: FaroSpacing.lg) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(FaroPalette.ink.opacity(0.06), style: StrokeStyle(lineWidth: isWideLayout ? 18 : 16, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * gaugeProgress)
                    .stroke(
                        riskLevelColor.gradient,
                        style: StrokeStyle(lineWidth: isWideLayout ? 18 : 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .shadow(color: riskLevelColor.opacity(0.3), radius: 8, y: 0)

                VStack(spacing: 6) {
                    Text(riskProfile.riskLevel?.capitalized ?? "Unknown")
                        .font(isWideLayout ? FaroType.title() : FaroType.title2())
                        .foregroundStyle(riskLevelColor)
                    Text("Overall risk band")
                        .font(FaroType.subheadline())
                        .foregroundStyle(FaroPalette.ink.opacity(0.48))
                }
            }
            .frame(width: gaugeSize, height: gaugeSize)

            if let revenue = riskProfile.revenueExposure, !revenue.isEmpty {
                FaroDashboardSnapshotRow(
                    title: "Revenue & exposure",
                    value: revenue,
                    detail: "",
                    comfortable: true
                )
            }
        }
        .frame(maxWidth: .infinity)
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
        .overlay { FaroDashboardCardOutline() }
    }

    // MARK: - Insight gallery

    private var insightGallery: some View {
        LazyVGrid(columns: insightGridColumns, alignment: .leading, spacing: FaroSpacing.lg) {
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
                    .gridCellColumns(isWideLayout ? 2 : 1)
            }
        }
    }

    // MARK: - Sections

    private func exposuresSection(_ exposures: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "exclamationmark.triangle.fill",
                iconTint: FaroPalette.warning,
                title: "Primary exposures",
                subtitle: "Where claims tend to come from for businesses like yours",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                ForEach(Array(exposures.enumerated()), id: \.offset) { _, exposure in
                    FaroDashboardStripeBulletRow(text: exposure, stripe: FaroPalette.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func stateRequirementsSection(_ reqs: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "building.columns.fill",
                iconTint: FaroPalette.info,
                title: "State requirements",
                subtitle: "Licensing, insurance, and rules that often apply",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                ForEach(Array(reqs.enumerated()), id: \.offset) { _, req in
                    FaroDashboardStripeBulletRow(text: req, stripe: FaroPalette.info)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func employeeSection(_ implications: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "person.3.fill",
                iconTint: FaroPalette.purpleDeep,
                title: "Employee implications",
                subtitle: "Workers’ comp, training, and staffing considerations",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                ForEach(Array(implications.enumerated()), id: \.offset) { _, item in
                    FaroDashboardStripeBulletRow(text: item, stripe: FaroPalette.purpleDeep)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func unusualRisksSection(_ risks: [String]) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "bolt.trianglebadge.exclamationmark.fill",
                iconTint: FaroPalette.danger,
                title: "Unusual risks",
                subtitle: "Factors that stand out from a typical peer",
                style: .emphasized
            )

            VStack(alignment: .leading, spacing: FaroSpacing.md + 2) {
                ForEach(Array(risks.enumerated()), id: \.offset) { _, risk in
                    FaroDashboardStripeBulletRow(text: risk, stripe: FaroPalette.danger)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: FaroSpacing.lg + 4) {
            FaroDashboardInsightSectionHeader(
                icon: "brain.fill",
                iconTint: FaroPalette.purpleDeep,
                title: "How we put this together",
                subtitle: "Short explanation of the model’s reasoning",
                style: .emphasized
            )

            Text(summary)
                .font(FaroType.body())
                .foregroundStyle(FaroPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(6)
        }
        .faroDashboardCardSurface(innerPadding: cardInnerPadding)
    }
}

// MARK: - Helpers (shared with Settings & Submission)

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
    /// When true (e.g. dashboard priority row), pills share width evenly.
    var expandToFillWidth: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(FaroType.caption(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: expandToFillWidth ? .infinity : nil, alignment: .center)
        .padding(.horizontal, FaroSpacing.sm + 2)
        .padding(.vertical, FaroSpacing.xs + 1)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
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
