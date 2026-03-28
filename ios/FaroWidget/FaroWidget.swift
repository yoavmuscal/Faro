import WidgetKit
import SwiftUI

private let widgetSuiteName = "group.com.faro.shared"
private let widgetSnapshotKey = "coverage_snapshot"

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
        nextRenewalDays: nil,
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

    var progressFraction: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }
}

enum WidgetCoverageStatus: String, Codable {
    case healthy
    case gapDetected = "gap_detected"
    case renewalSoon = "renewal_soon"
    case unknown

    var icon: String {
        switch self {
        case .healthy:
            return "checkmark.shield.fill"
        case .gapDetected:
            return "exclamationmark.shield.fill"
        case .renewalSoon:
            return "clock.badge.exclamationmark.fill"
        case .unknown:
            return "sparkles.rectangle.stack.fill"
        }
    }

    var label: String {
        switch self {
        case .healthy:
            return "Stable"
        case .gapDetected:
            return "Needs Review"
        case .renewalSoon:
            return "Renewal Soon"
        case .unknown:
            return "Waiting"
        }
    }

    var tint: Color {
        switch self {
        case .healthy:
            return Color(red: 0.16, green: 0.50, blue: 0.33)
        case .gapDetected:
            return Color(red: 0.83, green: 0.42, blue: 0.19)
        case .renewalSoon:
            return Color(red: 0.74, green: 0.23, blue: 0.23)
        case .unknown:
            return Color(red: 0.36, green: 0.34, blue: 0.47)
        }
    }

    var accentBackground: Color {
        switch self {
        case .healthy:
            return Color(red: 0.88, green: 0.96, blue: 0.89)
        case .gapDetected:
            return Color(red: 0.98, green: 0.92, blue: 0.85)
        case .renewalSoon:
            return Color(red: 0.98, green: 0.88, blue: 0.88)
        case .unknown:
            return Color(red: 0.92, green: 0.91, blue: 0.96)
        }
    }
}

enum WidgetDestination: String, Decodable {
    case analyze
    case coverage
    case summary
    case submission
}

enum WidgetCoverageLineCategory: String, Decodable {
    case required
    case recommended
    case projected

    var tint: Color {
        switch self {
        case .required:
            return Color(red: 0.78, green: 0.27, blue: 0.26)
        case .recommended:
            return Color(red: 0.29, green: 0.44, blue: 0.66)
        case .projected:
            return Color(red: 0.62, green: 0.49, blue: 0.24)
        }
    }

    var label: String {
        switch self {
        case .required:
            return "Required"
        case .recommended:
            return "Recommended"
        case .projected:
            return "Projected"
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

struct CoverageProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoverageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CoverageEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoverageEntry>) -> Void) {
        let entry = loadEntry()
        let refreshMinutes = entry.isInProgress ? 5 : 30
        let next = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: .now) ?? .now.addingTimeInterval(Double(refreshMinutes * 60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> CoverageEntry {
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
            message: "Open the app to generate a fresh coverage snapshot",
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

struct FaroWidget: Widget {
    let kind = "FaroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoverageProvider()) { entry in
            FaroWidgetView(entry: entry)
                .widgetURL(entry.widgetURL)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Coverage Pulse")
        .description("Keep Faro's latest coverage readout on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FaroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CoverageEntry

    var body: some View {
        ZStack {
            widgetBackground

            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }

    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.90),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(entry.status.accentBackground)
                    .frame(width: 120, height: 120)
                    .offset(x: -32, y: -42)
            }
            .overlay(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(entry.status.tint.opacity(0.08))
                    .frame(width: 120, height: 86)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 26, y: 28)
            }
    }
}

private struct SmallWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(entry: entry)

            Spacer(minLength: 0)

            Text(entry.businessName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.primaryText)
                .lineLimit(2)

            if entry.isInProgress {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.headline)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.status.tint)
                        .lineLimit(1)
                    ProgressMeter(entry: entry)
                }
            } else {
                Text(entry.headline)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    MetricChip(title: "Policies", value: "\(entry.policyCount)", compact: true)
                    MetricChip(title: "Req", value: "\(entry.requiredCount)", compact: true)
                }
            }
        }
        .padding(16)
    }
}

private struct MediumWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(entry: entry)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.businessName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.primaryText)
                        .lineLimit(2)

                    Text(entry.headline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.status.tint)
                        .lineLimit(2)

                    Text(entry.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(2)

                    if entry.isInProgress {
                        ProgressMeter(entry: entry)
                    } else {
                        ActionPill(title: entry.nextActionTitle, tint: entry.status.tint)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    MetricChip(title: "Policies", value: "\(entry.policyCount)", compact: false)
                    MetricChip(title: "Confidence", value: confidenceText, compact: false)
                }
            }

            HStack(spacing: 8) {
                CoverageCountPill(title: "Required", value: entry.requiredCount, tint: entry.status.tint.opacity(0.92))
                CoverageCountPill(title: "Recommended", value: entry.recommendedCount, tint: Color(red: 0.31, green: 0.45, blue: 0.65))
                CoverageCountPill(title: "Projected", value: entry.projectedCount, tint: Color(red: 0.63, green: 0.50, blue: 0.24))
            }
        }
        .padding(16)
    }

    private var confidenceText: String {
        entry.isInProgress ? "..." : "\(Int(entry.averageConfidence * 100))%"
    }
}

private struct LargeWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeader(entry: entry)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.businessName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetPalette.primaryText)
                    .lineLimit(2)

                Text(entry.headline)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.status.tint)
                    .lineLimit(2)

                Text(entry.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(2)
            }

            if entry.isInProgress {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressMeter(entry: entry)

                    HStack(spacing: 10) {
                        MetricCard(title: "Steps", value: "\(entry.completedSteps)/\(entry.totalSteps)", accent: entry.status.tint)
                        MetricCard(title: "Next", value: "Coverage", accent: Color(red: 0.29, green: 0.40, blue: 0.63))
                        MetricCard(title: "Action", value: "Watch", accent: Color(red: 0.18, green: 0.47, blue: 0.34))
                    }
                }
            } else {
                HStack(spacing: 10) {
                    MetricCard(title: "Policies", value: "\(entry.policyCount)", accent: entry.status.tint)
                    MetricCard(title: "Premium", value: premiumText, accent: Color(red: 0.18, green: 0.47, blue: 0.34))
                    MetricCard(title: "Confidence", value: "\(Int(entry.averageConfidence * 100))%", accent: Color(red: 0.29, green: 0.40, blue: 0.63))
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        CoverageCountPill(title: "Required", value: entry.requiredCount, tint: entry.status.tint.opacity(0.92))
                        CoverageCountPill(title: "Recommended", value: entry.recommendedCount, tint: Color(red: 0.31, green: 0.45, blue: 0.65))
                        CoverageCountPill(title: "Projected", value: entry.projectedCount, tint: Color(red: 0.63, green: 0.50, blue: 0.24))
                    }

                    if !entry.coverageLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(entry.coverageLines.enumerated()), id: \.offset) { _, line in
                                CoverageLineRow(line: line)
                            }
                        }
                    } else if let topCoverageType = entry.topCoverageType {
                        Label(topCoverageType, systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.22, green: 0.21, blue: 0.28))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.7))
                            )
                    }
                }
            }
        }
        .padding(18)
    }

    private var premiumText: String {
        let highValue = max(Int(entry.premiumHigh.rounded()), Int(entry.premiumLow.rounded()))
        if highValue <= 0 {
            return "TBD"
        }
        if highValue > 9999 {
            return "$\(highValue / 1000)k"
        }
        return "$\(highValue)"
    }
}

private struct CoverageLineRow: View {
    let line: WidgetCoverageLine

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(line.category.tint)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(line.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(line.category.label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(line.category.tint)
                }

                if let triggerEvent = line.triggerEvent, !triggerEvent.isEmpty {
                    Text(triggerEvent)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

private struct ProgressMeter: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Pipeline")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetPalette.secondaryText)
                Spacer(minLength: 0)
                Text("\(entry.completedSteps)/\(max(entry.totalSteps, 1))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.status.tint)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.78))
                    Capsule(style: .continuous)
                        .fill(entry.status.tint)
                        .frame(width: max(width * entry.progressFraction, width * 0.12))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct WidgetHeader: View {
    let entry: CoverageEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(entry.isInProgress ? "Working" : entry.status.label, systemImage: entry.status.icon)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(entry.status.accentBackground)
                )

            Spacer(minLength: 0)

            Text(relativeUpdatedAt)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.tertiaryText)
        }
    }

    private var relativeUpdatedAt: String {
        let minutes = max(0, Int(Date().timeIntervalSince(entry.date) / 60))
        if minutes == 0 {
            return "Now"
        }
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h"
    }
}

private struct MetricChip: View {
    let title: String
    let value: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(title.uppercased())
                .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.tertiaryText)
            Text(value)
                .font(.system(size: compact ? 14 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.primaryText)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(accent.opacity(0.9))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
    }
}

private struct ActionPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct CoverageCountPill: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

private enum WidgetPalette {
    static let primaryText = Color(red: 0.16, green: 0.15, blue: 0.20)
    static let secondaryText = Color(red: 0.37, green: 0.35, blue: 0.44)
    static let tertiaryText = Color(red: 0.45, green: 0.42, blue: 0.51)
}

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
