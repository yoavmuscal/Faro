import Foundation
#if os(iOS)
import WidgetKit
#endif

/// Writes coverage data to the shared App Group so the FaroWidget can display it (iOS).
enum WidgetDataWriter {
    private static let suiteName = "group.com.faro.shared"
    private static let snapshotKey = "coverage_snapshot"

    private struct WidgetCoverageSnapshot: Codable {
        let businessName: String
        let status: CoverageStatus
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

    static func update(businessName: String, status: CoverageStatus, message: String, nextRenewalDays: Int?, policyCount: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(businessName, forKey: "business_name")
        defaults.set(status.rawValue, forKey: "coverage_status")
        defaults.set(message, forKey: "coverage_message")
        defaults.set(policyCount, forKey: "policy_count")
        if let days = nextRenewalDays {
            defaults.set(days, forKey: "next_renewal_days")
        } else {
            defaults.removeObject(forKey: "next_renewal_days")
        }
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        [
            "business_name",
            "coverage_status",
            "coverage_message",
            "policy_count",
            "next_renewal_days",
            snapshotKey
        ].forEach { defaults.removeObject(forKey: $0) }
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Call after results are loaded to push data to the widget.
    static func update(from results: ResultsResponse, businessName: String) {
        let policyCount = results.coverageOptions.count
        let requiredCount = results.coverageOptions.filter { $0.category == .required }.count
        let recommendedCount = results.coverageOptions.filter { $0.category == .recommended }.count
        let projectedCount = results.coverageOptions.filter { $0.category == .projected }.count

        let status: CoverageStatus
        let headline: String
        let message: String

        if projectedCount > 0 {
            status = .gapDetected
            headline = "New exposures spotted"
            if let projected = results.coverageOptions.first(where: { $0.category == .projected }) {
                message = "Review \(projected.type) as you grow"
            } else {
                message = "\(projectedCount) projected protections to plan for"
            }
        } else if requiredCount > 0 {
            status = .healthy
            headline = "Coverage looks strong"
            message = "\(requiredCount) core protections in place"
        } else if policyCount > 0 {
            status = .unknown
            headline = "Coverage summary ready"
            message = "\(policyCount) policies analyzed"
        } else {
            status = .unknown
            headline = "Open Faro to analyze"
            message = "No coverage snapshot yet"
        }

        let sortedByPriority = results.coverageOptions.sorted {
            categoryPriority($0.category) < categoryPriority($1.category)
        }
        let topCoverageType = sortedByPriority.first?.type
        let premiumLow = results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumLow }
        let premiumHigh = results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumHigh }
        let averageConfidence = results.coverageOptions.isEmpty
            ? 0
            : results.coverageOptions.map(\.confidence).reduce(0, +) / Double(results.coverageOptions.count)

        writeSnapshot(
            WidgetCoverageSnapshot(
                businessName: businessName,
                status: status,
                headline: headline,
                message: message,
                nextRenewalDays: nil,
                policyCount: policyCount,
                requiredCount: requiredCount,
                recommendedCount: recommendedCount,
                projectedCount: projectedCount,
                topCoverageType: topCoverageType,
                premiumLow: premiumLow,
                premiumHigh: premiumHigh,
                averageConfidence: averageConfidence,
                updatedAt: Date().timeIntervalSince1970
            )
        )

        update(
            businessName: businessName,
            status: status,
            message: headline,
            nextRenewalDays: nil,
            policyCount: policyCount
        )
    }

    private static func writeSnapshot(_ snapshot: WidgetCoverageSnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults.set(encoded, forKey: snapshotKey)
    }

    private static func categoryPriority(_ category: CoverageCategory) -> Int {
        switch category {
        case .required:
            return 0
        case .recommended:
            return 1
        case .projected:
            return 2
        }
    }
}
