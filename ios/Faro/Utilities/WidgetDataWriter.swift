import Foundation
import WidgetKit

/// Writes coverage data to the shared App Group so the FaroWidget can display it.
enum WidgetDataWriter {
    private static let suiteName = "group.com.faro.shared"

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
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Call after results are loaded to push data to the widget.
    static func update(from results: ResultsResponse, businessName: String) {
        let requiredCount = results.coverageOptions.filter { $0.category == .required }.count
        let status: CoverageStatus = requiredCount > 0 ? .healthy : .unknown
        let message = "\(results.coverageOptions.count) policies analyzed"
        update(
            businessName: businessName,
            status: status,
            message: message,
            nextRenewalDays: 365,
            policyCount: results.coverageOptions.count
        )
    }
}
