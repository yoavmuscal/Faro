import WidgetKit
import SwiftUI

// MARK: - Shared data (written by the main app, read by the widget)

struct CoverageEntry: TimelineEntry {
    let date: Date
    let status: WidgetCoverageStatus
    let businessName: String
    let message: String
    let nextRenewalDays: Int?
    let policyCount: Int

    static let placeholder = CoverageEntry(
        date: .now,
        status: .unknown,
        businessName: "Your Business",
        message: "Open Faro to analyze coverage",
        nextRenewalDays: nil,
        policyCount: 0
    )
}

enum WidgetCoverageStatus: String {
    case healthy, gapDetected = "gap_detected", renewalSoon = "renewal_soon", unknown

    var color: Color {
        switch self {
        case .healthy:     return .green
        case .gapDetected: return .orange
        case .renewalSoon: return .red
        case .unknown:     return .secondary
        }
    }

    var icon: String {
        switch self {
        case .healthy:     return "checkmark.shield.fill"
        case .gapDetected: return "exclamationmark.triangle.fill"
        case .renewalSoon: return "clock.fill"
        case .unknown:     return "questionmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .healthy:     return "Covered"
        case .gapDetected: return "Gap Detected"
        case .renewalSoon: return "Renewal Soon"
        case .unknown:     return "No Data"
        }
    }
}

// MARK: - Provider

struct CoverageProvider: TimelineProvider {
    // App Group suite name — must match the main app's App Group
    private let suiteName = "group.com.faro.shared"

    func placeholder(in context: Context) -> CoverageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CoverageEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoverageEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 15 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> CoverageEntry {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let statusRaw = defaults.string(forKey: "coverage_status") else {
            return .placeholder
        }

        return CoverageEntry(
            date: .now,
            status: WidgetCoverageStatus(rawValue: statusRaw) ?? .unknown,
            businessName: defaults.string(forKey: "business_name") ?? "Your Business",
            message: defaults.string(forKey: "coverage_message") ?? "Open Faro to analyze coverage",
            nextRenewalDays: defaults.object(forKey: "next_renewal_days") as? Int,
            policyCount: defaults.integer(forKey: "policy_count")
        )
    }
}

// MARK: - Widget definition

struct FaroWidget: Widget {
    let kind = "FaroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoverageProvider()) { entry in
            FaroWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Coverage Status")
        .description("See your insurance coverage health at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct FaroWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoverageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: Small

struct SmallWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.status.icon)
                    .foregroundStyle(entry.status.color)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("FARO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.businessName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(entry.status.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(entry.status.color)
        }
        .padding(2)
    }
}

// MARK: Medium

struct MediumWidgetView: View {
    let entry: CoverageEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: status indicator
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: entry.status.icon)
                    .foregroundStyle(entry.status.color)
                    .font(.system(size: 28, weight: .semibold))

                Spacer()

                Text(entry.businessName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(entry.status.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(entry.status.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: details
            VStack(alignment: .trailing, spacing: 6) {
                Text("FARO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                if let days = entry.nextRenewalDays {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(days)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("days to renewal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if entry.policyCount > 0 {
                    Text("\(entry.policyCount) policies")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    FaroWidget()
} timeline: {
    CoverageEntry(date: .now, status: .healthy, businessName: "Sunny Days Daycare", message: "All coverage active", nextRenewalDays: 280, policyCount: 4)
    CoverageEntry(date: .now, status: .gapDetected, businessName: "Sunny Days Daycare", message: "Gap in cyber liability", nextRenewalDays: 280, policyCount: 3)
}

#Preview("Medium", as: .systemMedium) {
    FaroWidget()
} timeline: {
    CoverageEntry(date: .now, status: .healthy, businessName: "Sunny Days Daycare", message: "All coverage active", nextRenewalDays: 280, policyCount: 4)
}
