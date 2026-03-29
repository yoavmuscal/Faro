import AppIntents
import SwiftUI
import WidgetKit

private let widgetSuiteName = "group.com.faro.shared"
private let widgetSnapshotKey = "coverage_snapshot"

// MARK: - Entry

struct CoverageEntry: TimelineEntry {
    let date: Date
    let status: WidgetCoverageStatus
    let businessName: String
    let headline: String
    let message: String
    let isInProgress: Bool
    let completedSteps: Int
    let totalSteps: Int
    let nextRenewalDays: Int?
    let policyCount: Int
    let requiredCount: Int
    let recommendedCount: Int
    let projectedCount: Int
    let topCoverageType: String?
    let nextActionTitle: String
    let destination: WidgetDestination
    let coverageLines: [WidgetCoverageLine]
    let premiumLow: Double
    let premiumHigh: Double
    let averageConfidence: Double

    static let placeholder = CoverageEntry(
        date: .now,
        status: .healthy,
        businessName: "Northwind Studio",
        headline: "Coverage looks strong",
        message: "3 core protections in place",
        isInProgress: false,
        completedSteps: 4,
        totalSteps: 4,
        nextRenewalDays: nil,
        policyCount: 4,
        requiredCount: 3,
        recommendedCount: 1,
        projectedCount: 0,
        topCoverageType: "General Liability",
        nextActionTitle: "Open dashboard",
        destination: .coverage,
        coverageLines: [
            WidgetCoverageLine(title: "General Liability", category: .required, triggerEvent: nil),
            WidgetCoverageLine(title: "Workers' Compensation", category: .required, triggerEvent: nil),
            WidgetCoverageLine(title: "Cyber Liability", category: .recommended, triggerEvent: nil)
        ],
        premiumLow: 3200,
        premiumHigh: 4700,
        averageConfidence: 0.89
    )

    static let inProgressPreview = CoverageEntry(
        date: .now,
        status: .unknown,
        businessName: "Harbor Electric",
        headline: "Analysis in progress",
        message: "Faro is reasoning through coverage options",
        isInProgress: true,
        completedSteps: 2,
        totalSteps: 4,
        nextRenewalDays: nil,
        policyCount: 0,
        requiredCount: 0,
        recommendedCount: 0,
        projectedCount: 0,
        topCoverageType: nil,
        nextActionTitle: "Open analysis",
        destination: .analyze,
        coverageLines: [],
        premiumLow: 0,
        premiumHigh: 0,
        averageConfidence: 0
    )

    static let gapPreview = CoverageEntry(
        date: .now,
        status: .gapDetected,
        businessName: "Harbor Electric",
        headline: "New exposures spotted",
        message: "Review Cyber Liability as you grow",
        isInProgress: false,
        completedSteps: 4,
        totalSteps: 4,
        nextRenewalDays: 45,
        policyCount: 5,
        requiredCount: 2,
        recommendedCount: 1,
        projectedCount: 2,
        topCoverageType: "Cyber Liability",
        nextActionTitle: "Review gaps",
        destination: .coverage,
        coverageLines: [
            WidgetCoverageLine(title: "General Liability", category: .required, triggerEvent: nil),
            WidgetCoverageLine(title: "Umbrella", category: .recommended, triggerEvent: nil),
            WidgetCoverageLine(title: "Cyber Liability", category: .projected, triggerEvent: "As staff and customer records scale")
        ],
        premiumLow: 5400,
        premiumHigh: 7600,
        averageConfidence: 0.82
    )

    var widgetURL: URL? {
        URL(string: "faro://\(destination.rawValue)")
    }

    func replacingDestination(_ dest: WidgetDestination) -> CoverageEntry {
        CoverageEntry(
            date: date,
            status: status,
            businessName: businessName,
            headline: headline,
            message: message,
            isInProgress: isInProgress,
            completedSteps: completedSteps,
            totalSteps: totalSteps,
            nextRenewalDays: nextRenewalDays,
            policyCount: policyCount,
            requiredCount: requiredCount,
            recommendedCount: recommendedCount,
            projectedCount: projectedCount,
            topCoverageType: topCoverageType,
            nextActionTitle: nextActionTitle,
            destination: dest,
            coverageLines: coverageLines,
            premiumLow: premiumLow,
            premiumHigh: premiumHigh,
            averageConfidence: averageConfidence
        )
    }

    var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }

    var hasPremiumEstimate: Bool {
        max(premiumLow, premiumHigh) > 0
    }
}

// MARK: - Models

enum WidgetCoverageStatus: String, Codable {
    case healthy
    case gapDetected = "gap_detected"
    case renewalSoon = "renewal_soon"
    case unknown

    var icon: String {
        switch self {
        case .healthy: return "checkmark.shield.fill"
        case .gapDetected: return "exclamationmark.shield.fill"
        case .renewalSoon: return "clock.badge.exclamationmark.fill"
        case .unknown: return "sparkles.rectangle.stack.fill"
        }
    }

    var label: String {
        switch self {
        case .healthy: return "Stable"
        case .gapDetected: return "Review"
        case .renewalSoon: return "Renewal"
        case .unknown: return "Working"
        }
    }

    func accentColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .healthy:
            return scheme == .dark ? Color(red: 0.45, green: 0.85, blue: 0.62) : Color(red: 0.12, green: 0.52, blue: 0.35)
        case .gapDetected:
            return scheme == .dark ? Color(red: 1.0, green: 0.65, blue: 0.35) : Color(red: 0.78, green: 0.35, blue: 0.12)
        case .renewalSoon:
            return scheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : Color(red: 0.72, green: 0.18, blue: 0.22)
        case .unknown:
            return scheme == .dark ? Color(red: 0.72, green: 0.68, blue: 1.0) : Color(red: 0.38, green: 0.34, blue: 0.55)
        }
    }

    func badgeBackground(for scheme: ColorScheme) -> Color {
        accentColor(for: scheme).opacity(scheme == .dark ? 0.22 : 0.14)
    }
}

enum WidgetDestination: String, Decodable {
    case analyze
    case coverage
    case submission

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        if raw == "summary" {
            self = .coverage
        } else if let v = WidgetDestination(rawValue: raw) {
            self = v
        } else {
            self = .analyze
        }
    }
}

enum WidgetCoverageLineCategory: String, Decodable {
    case required
    case recommended
    case projected

    func tint(for scheme: ColorScheme) -> Color {
        switch self {
        case .required:
            return scheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.42) : Color(red: 0.78, green: 0.27, blue: 0.26)
        case .recommended:
            return scheme == .dark ? Color(red: 0.55, green: 0.72, blue: 1.0) : Color(red: 0.29, green: 0.44, blue: 0.66)
        case .projected:
            return scheme == .dark ? Color(red: 1.0, green: 0.82, blue: 0.45) : Color(red: 0.62, green: 0.49, blue: 0.24)
        }
    }

    var label: String {
        switch self {
        case .required: return "Req"
        case .recommended: return "Rec"
        case .projected: return "Later"
        }
    }
}

struct WidgetCoverageLine: Decodable {
    let title: String
    let category: WidgetCoverageLineCategory
    let triggerEvent: String?
}

private struct WidgetSnapshot: Decodable {
    let businessName: String
    let status: WidgetCoverageStatus
    let headline: String
    let message: String
    let isInProgress: Bool
    let completedSteps: Int
    let totalSteps: Int
    let nextRenewalDays: Int?
    let policyCount: Int
    let requiredCount: Int
    let recommendedCount: Int
    let projectedCount: Int
    let topCoverageType: String?
    let nextActionTitle: String
    let destination: WidgetDestination
    let coverageLines: [WidgetCoverageLine]
    let premiumLow: Double
    let premiumHigh: Double
    let averageConfidence: Double
    let updatedAt: TimeInterval
}

// MARK: - Provider

struct CoverageProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CoverageEntry {
        .placeholder
    }

    func snapshot(for configuration: FaroWidgetConfigurationIntent, in context: Context) async -> CoverageEntry {
        resolvedEntry(configuration: configuration)
    }

    func timeline(for configuration: FaroWidgetConfigurationIntent, in context: Context) async -> Timeline<CoverageEntry> {
        let entry = resolvedEntry(configuration: configuration)
        let refreshMinutes = entry.isInProgress ? 5 : 30
        let next = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: .now) ?? .now.addingTimeInterval(Double(refreshMinutes * 60))
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func resolvedEntry(configuration: FaroWidgetConfigurationIntent) -> CoverageEntry {
        let base = loadBaseEntry()
        switch configuration.tapDestination ?? .matchSnapshot {
        case .matchSnapshot:
            return base
        case .analyze:
            return base.replacingDestination(.analyze)
        case .coverage:
            return base.replacingDestination(.coverage)
        case .submission:
            return base.replacingDestination(.submission)
        }
    }

    private func loadBaseEntry() -> CoverageEntry {
        guard let defaults = UserDefaults(suiteName: widgetSuiteName) else {
            return .placeholder
        }

        if let data = defaults.data(forKey: widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            return CoverageEntry(
                date: Date(timeIntervalSince1970: snapshot.updatedAt),
                status: snapshot.status,
                businessName: snapshot.businessName,
                headline: snapshot.headline,
                message: snapshot.message,
                isInProgress: snapshot.isInProgress,
                completedSteps: snapshot.completedSteps,
                totalSteps: snapshot.totalSteps,
                nextRenewalDays: snapshot.nextRenewalDays,
                policyCount: snapshot.policyCount,
                requiredCount: snapshot.requiredCount,
                recommendedCount: snapshot.recommendedCount,
                projectedCount: snapshot.projectedCount,
                topCoverageType: snapshot.topCoverageType,
                nextActionTitle: snapshot.nextActionTitle,
                destination: snapshot.destination,
                coverageLines: snapshot.coverageLines,
                premiumLow: snapshot.premiumLow,
                premiumHigh: snapshot.premiumHigh,
                averageConfidence: snapshot.averageConfidence
            )
        }

        guard let statusRaw = defaults.string(forKey: "coverage_status") else {
            return .placeholder
        }

        return CoverageEntry(
            date: .now,
            status: WidgetCoverageStatus(rawValue: statusRaw) ?? .unknown,
            businessName: defaults.string(forKey: "business_name") ?? "Your Business",
            headline: defaults.string(forKey: "coverage_message") ?? "Open Faro to analyze",
            message: "Open the app to refresh your snapshot.",
            isInProgress: false,
            completedSteps: 0,
            totalSteps: 4,
            nextRenewalDays: defaults.object(forKey: "next_renewal_days") as? Int,
            policyCount: defaults.integer(forKey: "policy_count"),
            requiredCount: 0,
            recommendedCount: 0,
            projectedCount: 0,
            topCoverageType: nil,
            nextActionTitle: "Open Faro",
            destination: .analyze,
            coverageLines: [],
            premiumLow: 0,
            premiumHigh: 0,
            averageConfidence: 0
        )
    }
}

// MARK: - Widget

struct FaroWidget: Widget {
    let kind = "FaroWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FaroWidgetConfigurationIntent.self, provider: CoverageProvider()) { entry in
            FaroWidgetView(entry: entry)
                .widgetURL(entry.widgetURL)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Faro Coverage")
        .description("Business name, premium range, and top coverages at a glance. Tap to jump into the app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

// MARK: - Root view

struct FaroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: CoverageEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemExtraLarge:
                ExtraLargeWidgetView(entry: entry)
            case .accessoryInline:
                AccessoryInlineWidgetView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularWidgetView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if family == .systemSmall || family == .systemMedium || family == .systemLarge || family == .systemExtraLarge {
                WidgetCanvasBackground(status: entry.status, colorScheme: colorScheme)
            }
        }
    }
}

// MARK: - Adaptive background

private struct WidgetCanvasBackground: View {
    let status: WidgetCoverageStatus
    let colorScheme: ColorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [
                            Color(red: 0.07, green: 0.07, blue: 0.10),
                            Color(red: 0.11, green: 0.10, blue: 0.16)
                        ]
                        : [
                            Color(red: 0.98, green: 0.97, blue: 0.95),
                            Color(red: 1.0, green: 0.99, blue: 1.0)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                status.accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 140, height: 140)
                    .offset(x: -40, y: -50)
            }
            .overlay(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(status.accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(width: 140, height: 100)
                    .rotationEffect(.degrees(-18))
                    .offset(x: 36, y: 32)
            }
    }
}

// MARK: - Formatting

private enum WidgetFormat {
    static func premiumAnnual(low: Double, high: Double) -> String {
        let lo = Int(low.rounded())
        let hi = Int(high.rounded())
        if lo <= 0 && hi <= 0 { return "—" }
        if lo == hi { return "$\(formatNumber(lo))/yr" }
        return "$\(formatNumber(lo))–$\(formatNumber(hi))/yr"
    }

    static func premiumCompact(low: Double, high: Double) -> String {
        let lo = Int(low.rounded())
        let hi = Int(high.rounded())
        if lo <= 0 && hi <= 0 { return "—" }
        return "$\(shortK(lo))–$\(shortK(hi))"
    }

    private static func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static func shortK(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.0fk", Double(n) / 1000) }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    static func renewalText(days: Int?) -> String? {
        guard let d = days, d > 0 else { return nil }
        if d == 1 { return "Renewal in 1 day" }
        if d < 14 { return "Renewal in \(d) days" }
        if d < 60 { return "Renewal in \(d / 7) wk" }
        return "Renewal ~\(d / 30) mo"
    }
}

// MARK: - Small

private struct SmallWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry, colorScheme: colorScheme)

            Spacer(minLength: 6)

            Text(entry.businessName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.ink(colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if entry.isInProgress {
                Text(entry.headline)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.status.accentColor(for: colorScheme))
                    .lineLimit(2)
                    .padding(.top, 4)

                ProgressMeter(entry: entry, colorScheme: colorScheme)
                    .padding(.top, 8)

                Text(pipelineMicroLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.faint(colorScheme))
                    .lineLimit(1)
                    .padding(.top, 4)
            } else {
                Text(entry.headline)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.muted(colorScheme))
                    .lineLimit(2)
                    .padding(.top, 4)

                if entry.hasPremiumEstimate {
                    Text(WidgetFormat.premiumCompact(low: entry.premiumLow, high: entry.premiumHigh))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(entry.status.accentColor(for: colorScheme))
                        .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    MiniStat(icon: "doc.text.fill", value: "\(entry.policyCount)", scheme: colorScheme)
                    MiniStat(icon: "exclamationmark.circle.fill", value: "\(entry.requiredCount)", scheme: colorScheme)
                    if entry.averageConfidence > 0 {
                        MiniStat(icon: "chart.bar.fill", value: "\(Int(entry.averageConfidence * 100))%", scheme: colorScheme)
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            Text("Tap to open")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.faint(colorScheme))
        }
        .padding(14)
    }

    private var pipelineMicroLabel: String {
        "Risk · Map · Packet · Summary"
    }
}

private struct MiniStat: View {
    let icon: String
    let value: String
    let scheme: ColorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(FaroWidgetColors.ink(scheme))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(FaroWidgetColors.cardFill(scheme))
        )
    }
}

// MARK: - Medium

private struct MediumWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(entry: entry, colorScheme: colorScheme)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.businessName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(FaroWidgetColors.ink(colorScheme))
                        .lineLimit(2)

                    Text(entry.headline)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.status.accentColor(for: colorScheme))
                        .lineLimit(2)

                    Text(entry.message)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(FaroWidgetColors.muted(colorScheme))
                        .lineLimit(2)

                    if let renewal = WidgetFormat.renewalText(days: entry.nextRenewalDays) {
                        Label(renewal, systemImage: "calendar")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(FaroWidgetColors.muted(colorScheme))
                    }

                    if entry.isInProgress {
                        ProgressMeter(entry: entry, colorScheme: colorScheme)
                            .padding(.top, 4)
                        Text("Pipeline: Risk → Coverage → Submission → Summary")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(FaroWidgetColors.faint(colorScheme))
                    } else {
                        ActionPill(title: entry.nextActionTitle, status: entry.status, colorScheme: colorScheme)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    MetricChip(title: "Policies", value: "\(entry.policyCount)", scheme: colorScheme)
                    if !entry.isInProgress && entry.hasPremiumEstimate {
                        MetricChip(title: "Est. annual", value: WidgetFormat.premiumCompact(low: entry.premiumLow, high: entry.premiumHigh), scheme: colorScheme, emphasize: true)
                    }
                    MetricChip(
                        title: "Confidence",
                        value: entry.isInProgress ? "…" : "\(Int(entry.averageConfidence * 100))%",
                        scheme: colorScheme
                    )
                }
            }

            HStack(spacing: 6) {
                CategoryCountChip(title: "Req", count: entry.requiredCount, color: WidgetCoverageLineCategory.required.tint(for: colorScheme), scheme: colorScheme)
                CategoryCountChip(title: "Rec", count: entry.recommendedCount, color: WidgetCoverageLineCategory.recommended.tint(for: colorScheme), scheme: colorScheme)
                CategoryCountChip(title: "Later", count: entry.projectedCount, color: WidgetCoverageLineCategory.projected.tint(for: colorScheme), scheme: colorScheme)
            }
        }
        .padding(14)
    }
}

// MARK: - Large

private struct LargeWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(entry: entry, colorScheme: colorScheme)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.businessName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.ink(colorScheme))
                    .lineLimit(2)

                Text(entry.headline)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.status.accentColor(for: colorScheme))
                    .lineLimit(2)

                Text(entry.message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.muted(colorScheme))
                    .lineLimit(3)
            }

            if let renewal = WidgetFormat.renewalText(days: entry.nextRenewalDays) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 14))
                    Text(renewal)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(FaroWidgetColors.muted(colorScheme))
            }

            if entry.isInProgress {
                ProgressMeter(entry: entry, colorScheme: colorScheme)
                PipelineStepRow(completed: entry.completedSteps, total: entry.totalSteps, colorScheme: colorScheme)
                HStack(spacing: 8) {
                    LargeMetricTile(title: "Step", value: "\(entry.completedSteps)/\(entry.totalSteps)", scheme: colorScheme)
                    LargeMetricTile(title: "Next", value: nextPipelineStepName, scheme: colorScheme)
                }
            } else {
                HStack(spacing: 8) {
                    LargeMetricTile(title: "Policies", value: "\(entry.policyCount)", scheme: colorScheme)
                    LargeMetricTile(title: "Est. premium", value: entry.hasPremiumEstimate ? WidgetFormat.premiumAnnual(low: entry.premiumLow, high: entry.premiumHigh) : "—", scheme: colorScheme, valueSize: 13)
                    LargeMetricTile(title: "Confidence", value: "\(Int(entry.averageConfidence * 100))%", scheme: colorScheme)
                }

                HStack(spacing: 6) {
                    CategoryCountChip(title: "Required", count: entry.requiredCount, color: WidgetCoverageLineCategory.required.tint(for: colorScheme), scheme: colorScheme)
                    CategoryCountChip(title: "Recommended", count: entry.recommendedCount, color: WidgetCoverageLineCategory.recommended.tint(for: colorScheme), scheme: colorScheme)
                    CategoryCountChip(title: "Projected", count: entry.projectedCount, color: WidgetCoverageLineCategory.projected.tint(for: colorScheme), scheme: colorScheme)
                }

                if !entry.coverageLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top coverages")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(FaroWidgetColors.faint(colorScheme))

                        ForEach(Array(entry.coverageLines.enumerated()), id: \.offset) { _, line in
                            CoverageLineRow(line: line, colorScheme: colorScheme)
                        }
                    }
                } else if let top = entry.topCoverageType {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(entry.status.accentColor(for: colorScheme))
                        Text("Focus: \(top)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(FaroWidgetColors.ink(colorScheme))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(FaroWidgetColors.cardFill(colorScheme))
                    )
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("Tap for \(destinationLabel)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.faint(colorScheme))
            }
        }
        .padding(16)
    }

    private var nextPipelineStepName: String {
        let names = ["Risk", "Coverage", "Packet", "Summary"]
        let idx = min(entry.completedSteps, max(0, names.count - 1))
        return names[idx]
    }

    private var destinationLabel: String {
        switch entry.destination {
        case .analyze: return "Analyze"
        case .coverage: return "Coverage"
        case .submission: return "Submission"
        }
    }
}

private struct PipelineStepRow: View {
    let completed: Int
    let total: Int
    let colorScheme: ColorScheme

    private let labels = ["Risk", "Coverage", "Packet", "Summary"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<min(total, labels.count), id: \.self) { i in
                Text(labels[i])
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(i < completed ? FaroWidgetColors.ink(colorScheme) : FaroWidgetColors.faint(colorScheme))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct LargeMetricTile: View {
    let title: String
    let value: String
    let scheme: ColorScheme
    var valueSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.faint(scheme))
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.ink(scheme))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FaroWidgetColors.cardFill(scheme))
        )
    }
}

// MARK: - Extra large (iPad)

private struct ExtraLargeWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        LargeWidgetView(entry: entry)
            .padding(6)
    }
}

// MARK: - Lock Screen accessories

private struct AccessoryCircularWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        Gauge(value: circularProgress) {
            Image(systemName: entry.status.icon)
                .widgetAccentable()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var circularProgress: Double {
        if entry.isInProgress {
            return min(1, max(0.1, entry.progressFraction))
        }
        return 1
    }
}

private struct AccessoryInlineWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        ViewThatFits {
            Text("\(entry.businessName) · \(entry.headline)")
            Text(entry.headline)
        }
        .lineLimit(1)
    }
}

private struct AccessoryRectangularWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: CoverageEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: entry.status.icon)
                .font(.system(size: 16, weight: .semibold))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.businessName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.85)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitle: String {
        if entry.isInProgress {
            return "\(entry.completedSteps)/\(entry.totalSteps) · \(entry.headline)"
        }
        if entry.hasPremiumEstimate {
            return "\(entry.headline) · \(WidgetFormat.premiumCompact(low: entry.premiumLow, high: entry.premiumHigh))"
        }
        return entry.headline
    }
}

// MARK: - Shared subviews

private struct CoverageLineRow: View {
    let line: WidgetCoverageLine
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(line.category.tint(for: colorScheme))
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(line.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(FaroWidgetColors.ink(colorScheme))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(line.category.label)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(line.category.tint(for: colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(line.category.tint(for: colorScheme).opacity(0.15)))
                }

                if let triggerEvent = line.triggerEvent, !triggerEvent.isEmpty {
                    Text(triggerEvent)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(FaroWidgetColors.muted(colorScheme))
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FaroWidgetColors.cardFill(colorScheme))
        )
    }
}

private struct ProgressMeter: View {
    let entry: CoverageEntry
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Agent pipeline")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(FaroWidgetColors.faint(colorScheme))
                Spacer(minLength: 0)
                Text("\(entry.completedSteps)/\(max(entry.totalSteps, 1))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.status.accentColor(for: colorScheme))
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(FaroWidgetColors.cardFill(colorScheme))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    entry.status.accentColor(for: colorScheme),
                                    entry.status.accentColor(for: colorScheme).opacity(0.75)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(width * entry.progressFraction, width * 0.1))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct WidgetHeader: View {
    let entry: CoverageEntry
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 11, weight: .bold))
                Text("Faro")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(FaroWidgetColors.ink(colorScheme))

            Spacer(minLength: 0)

            Text(entry.isInProgress ? "In progress" : entry.status.label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status.accentColor(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(entry.status.badgeBackground(for: colorScheme))
                )

            Text(relativeUpdatedAt)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.faint(colorScheme))
                .monospacedDigit()
        }
    }

    private var relativeUpdatedAt: String {
        let minutes = max(0, Int(Date().timeIntervalSince(entry.date) / 60))
        if minutes >= 10_080 { return "stale" }
        if minutes == 0 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }
}

private struct MetricChip: View {
    let title: String
    let value: String
    let scheme: ColorScheme
    var emphasize: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.faint(scheme))
            Text(value)
                .font(.system(size: emphasize ? 15 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(FaroWidgetColors.ink(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FaroWidgetColors.cardFill(scheme))
        )
    }
}

private struct CategoryCountChip: View {
    let title: String
    let count: Int
    let color: Color
    let scheme: ColorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Text("\(count)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(scheme == .dark ? 0.18 : 0.12))
        )
    }
}

private struct ActionPill: View {
    let title: String
    let status: WidgetCoverageStatus
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 11))
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(status.accentColor(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(status.accentColor(for: colorScheme).opacity(0.14))
        )
    }
}

// MARK: - Colors (avoid names that collide with SwiftUI ShapeStyle.primary / .secondary / .tertiary)

private enum FaroWidgetColors {
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.96, green: 0.96, blue: 0.98) : Color(red: 0.12, green: 0.11, blue: 0.15)
    }

    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.72, green: 0.70, blue: 0.78) : Color(red: 0.38, green: 0.36, blue: 0.44)
    }

    static func faint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.52, green: 0.50, blue: 0.58) : Color(red: 0.48, green: 0.45, blue: 0.54)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.white.opacity(0.82)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FaroWidget()
} timeline: {
    CoverageEntry.placeholder
    CoverageEntry.inProgressPreview
}

#Preview("Medium", as: .systemMedium) {
    FaroWidget()
} timeline: {
    CoverageEntry.gapPreview
}

#Preview("Large", as: .systemLarge) {
    FaroWidget()
} timeline: {
    CoverageEntry.gapPreview
}

#Preview("Accessory Rect", as: .accessoryRectangular) {
    FaroWidget()
} timeline: {
    CoverageEntry.gapPreview
}

#Preview("Accessory Circle", as: .accessoryCircular) {
    FaroWidget()
} timeline: {
    CoverageEntry.inProgressPreview
}

#Preview("Extra Large", as: .systemExtraLarge) {
    FaroWidget()
} timeline: {
    CoverageEntry.gapPreview
}
