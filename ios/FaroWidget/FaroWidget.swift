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
    let nextRenewalDays: Int?
    let policyCount: Int
    let requiredCount: Int
    let recommendedCount: Int
    let projectedCount: Int
    let topCoverageType: String?
    let premiumLow: Double
    let premiumHigh: Double
    let averageConfidence: Double

    static let placeholder = CoverageEntry(
        date: .now,
        status: .healthy,
        businessName: "Northwind Studio",
        headline: "Coverage looks strong",
        message: "3 core protections in place",
        nextRenewalDays: nil,
        policyCount: 4,
        requiredCount: 3,
        recommendedCount: 1,
        projectedCount: 0,
        topCoverageType: "General Liability",
        premiumLow: 3200,
        premiumHigh: 4700,
        averageConfidence: 0.89
    )

    static let gapPreview = CoverageEntry(
        date: .now,
        status: .gapDetected,
        businessName: "Harbor Electric",
        headline: "New exposures spotted",
        message: "Review Cyber Liability as you grow",
        nextRenewalDays: nil,
        policyCount: 5,
        requiredCount: 2,
        recommendedCount: 1,
        projectedCount: 2,
        topCoverageType: "Cyber Liability",
        premiumLow: 5400,
        premiumHigh: 7600,
        averageConfidence: 0.82
    )
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

private struct WidgetSnapshot: Decodable {
    let businessName: String
    let status: WidgetCoverageStatus
    let headline: String
    let message: String
    let nextRenewalDays: Int?
    let policyCount: Int
    let requiredCount: Int
    let recommendedCount: Int
    let projectedCount: Int
    let topCoverageType: String?
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
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
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
                nextRenewalDays: snapshot.nextRenewalDays,
                policyCount: snapshot.policyCount,
                requiredCount: snapshot.requiredCount,
                recommendedCount: snapshot.recommendedCount,
                projectedCount: snapshot.projectedCount,
                topCoverageType: snapshot.topCoverageType,
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
            nextRenewalDays: defaults.object(forKey: "next_renewal_days") as? Int,
            policyCount: defaults.integer(forKey: "policy_count"),
            requiredCount: 0,
            recommendedCount: 0,
            projectedCount: 0,
            topCoverageType: nil,
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
                .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.20))
                .lineLimit(2)

            Text(entry.headline)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.31, green: 0.29, blue: 0.38))
                .lineLimit(2)

            HStack(spacing: 8) {
                MetricChip(title: "Policies", value: "\(entry.policyCount)", compact: true)
                MetricChip(title: "Req", value: "\(entry.requiredCount)", compact: true)
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
                        .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.20))
                        .lineLimit(2)

                    Text(entry.headline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(entry.status.tint)
                        .lineLimit(2)

                    Text(entry.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.37, green: 0.35, blue: 0.44))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    MetricChip(title: "Policies", value: "\(entry.policyCount)", compact: false)
                    MetricChip(title: "Confidence", value: "\(Int(entry.averageConfidence * 100))%", compact: false)
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
}

private struct LargeWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeader(entry: entry)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.businessName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.20))
                    .lineLimit(2)

                Text(entry.headline)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.status.tint)
                    .lineLimit(2)

                Text(entry.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.37, green: 0.35, blue: 0.44))
                    .lineLimit(2)
            }

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

                if let topCoverageType = entry.topCoverageType {
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
        .padding(18)
    }

    private var premiumText: String {
        let highValue = max(Int(entry.premiumHigh.rounded()), Int(entry.premiumLow.rounded()))
        if highValue <= 0 {
            return "TBD"
        }
        if entry.premiumHigh > 9999 {
            return "$\(highValue / 1000)k"
        }
        return "$\(highValue)"
    }
}

private struct WidgetHeader: View {
    let entry: CoverageEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(entry.status.label, systemImage: entry.status.icon)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(entry.status.accentBackground)
                )

            Spacer(minLength: 0)

            Text("FARO")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(Color(red: 0.39, green: 0.37, blue: 0.46))
        }
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
                .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.51))
            Text(value)
                .font(.system(size: compact ? 14 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.20))
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
                .foregroundStyle(Color(red: 0.16, green: 0.15, blue: 0.20))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
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

#Preview("Small", as: .systemSmall) {
    FaroWidget()
} timeline: {
    CoverageEntry.placeholder
    CoverageEntry.gapPreview
}

#Preview("Medium", as: .systemMedium) {
    FaroWidget()
} timeline: {
    CoverageEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    FaroWidget()
} timeline: {
    CoverageEntry.gapPreview
}
