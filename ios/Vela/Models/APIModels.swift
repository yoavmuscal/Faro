import Foundation

// MARK: - Intake

struct IntakeRequest: Codable {
    let businessName: String
    let description: String
    let employeeCount: Int
    let state: String
    let annualRevenue: Double

    enum CodingKeys: String, CodingKey {
        case businessName = "business_name"
        case description
        case employeeCount = "employee_count"
        case state
        case annualRevenue = "annual_revenue"
    }
}

struct IntakeResponse: Codable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

// MARK: - WebSocket Step Updates

enum AgentStep: String, Codable {
    case riskProfiler = "risk_profiler"
    case coverageMapper = "coverage_mapper"
    case submissionBuilder = "submission_builder"
    case explainer
}

enum StepStatus: String, Codable {
    case running, complete, error
}

struct StepUpdate: Codable, Identifiable {
    let step: AgentStep
    let status: StepStatus
    let summary: String

    var id: String { step.rawValue }
}

// MARK: - Results

enum CoverageCategory: String, Codable {
    case required, recommended, projected
}

struct CoverageOption: Codable, Identifiable {
    let type: String
    let description: String
    let estimatedPremiumLow: Double
    let estimatedPremiumHigh: Double
    let confidence: Double
    let required: Bool
    let category: CoverageCategory
    let triggerEvent: String?

    var id: String { type }

    enum CodingKeys: String, CodingKey {
        case type, description, required, category, confidence
        case estimatedPremiumLow = "estimated_premium_low"
        case estimatedPremiumHigh = "estimated_premium_high"
        case triggerEvent = "trigger_event"
    }
}

struct ResultsResponse: Codable {
    let coverageOptions: [CoverageOption]
    let submissionPacketUrl: String
    let voiceSummaryUrl: String

    enum CodingKeys: String, CodingKey {
        case coverageOptions = "coverage_options"
        case submissionPacketUrl = "submission_packet_url"
        case voiceSummaryUrl = "voice_summary_url"
    }
}

// MARK: - Widget Status

enum CoverageStatus: String, Codable {
    case healthy, gapDetected = "gap_detected", renewalSoon = "renewal_soon", unknown
}

struct StatusResponse: Codable {
    let status: CoverageStatus
    let nextRenewalDays: Int?
    let message: String

    enum CodingKeys: String, CodingKey {
        case status, message
        case nextRenewalDays = "next_renewal_days"
    }
}
