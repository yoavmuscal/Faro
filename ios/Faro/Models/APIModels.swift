import Foundation

// MARK: - Intake

struct IntakeRequest: Codable {
    let businessName: String
    let description: String
    let employeeCount: Int
    let state: String
    let annualRevenue: Double
    var contactFirstName: String? = nil
    var contactMiddleName: String? = nil
    var contactLastName: String? = nil
    var contactEmail: String? = nil

    enum CodingKeys: String, CodingKey {
        case businessName = "business_name"
        case description
        case employeeCount = "employee_count"
        case state
        case annualRevenue = "annual_revenue"
        case contactFirstName = "contact_first_name"
        case contactMiddleName = "contact_middle_name"
        case contactLastName = "contact_last_name"
        case contactEmail = "contact_email"
    }
}

struct IntakeResponse: Codable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

// MARK: - Conversational AI Intake

struct ConvStartResponse: Codable {
    let sessionId: String
    let signedUrl: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case signedUrl = "signed_url"
    }
}

struct ConvTranscriptTurn: Codable {
    let role: String
    let message: String
}

struct ConvCompleteRequest: Codable {
    let sessionId: String
    let transcript: [ConvTranscriptTurn]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcript
    }
}

struct ConvCompleteResponse: Codable {
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
    let category: CoverageCategory
    let triggerEvent: String?

    var id: String { type }

    var isRequired: Bool { category == .required }

    var premiumMidpoint: Double { (estimatedPremiumLow + estimatedPremiumHigh) / 2 }

    enum CodingKeys: String, CodingKey {
        case type, description, category, confidence
        case estimatedPremiumLow = "estimated_premium_low"
        case estimatedPremiumHigh = "estimated_premium_high"
        case triggerEvent = "trigger_event"
    }
}

struct ResultsResponse: Codable {
    let coverageOptions: [CoverageOption]
    let submissionPacketUrl: String
    let voiceSummaryUrl: String
    let riskProfile: RiskProfile?
    let submissionPacket: SubmissionPacket?
    let plainEnglishSummary: String?

    enum CodingKeys: String, CodingKey {
        case coverageOptions = "coverage_options"
        case submissionPacketUrl = "submission_packet_url"
        case voiceSummaryUrl = "voice_summary_url"
        case riskProfile = "risk_profile"
        case submissionPacket = "submission_packet"
        case plainEnglishSummary = "plain_english_summary"
    }
}

// MARK: - Risk Profile

struct RiskProfile: Codable {
    let industry: String?
    let sicCode: String?
    let riskLevel: String?
    let primaryExposures: [String]?
    let stateRequirements: [String]?
    let employeeImplications: [String]?
    let revenueExposure: String?
    let unusualRisks: [String]?
    let reasoningSummary: String?

    enum CodingKeys: String, CodingKey {
        case industry
        case sicCode = "sic_code"
        case riskLevel = "risk_level"
        case primaryExposures = "primary_exposures"
        case stateRequirements = "state_requirements"
        case employeeImplications = "employee_implications"
        case revenueExposure = "revenue_exposure"
        case unusualRisks = "unusual_risks"
        case reasoningSummary = "reasoning_summary"
    }
}

// MARK: - Submission Packet

struct SubmissionPacket: Codable {
    let submissionDate: String?
    let applicant: SubmissionApplicant?
    let operations: SubmissionOperations?
    let lossHistory: [SubmissionLoss]?
    let requestedCoverages: [SubmissionRequestedCoverage]?
    let underwriterNotes: [String]?

    enum CodingKeys: String, CodingKey {
        case submissionDate = "submission_date"
        case applicant, operations
        case lossHistory = "loss_history"
        case requestedCoverages = "requested_coverages"
        case underwriterNotes = "underwriter_notes"
    }
}

struct SubmissionApplicant: Codable {
    let legalName: String?
    let dba: String?
    let businessType: String?
    let yearsInBusiness: Int?
    let stateOfIncorporation: String?
    let primaryStateOfOperations: String?
    let mailingAddress: String?
    let phone: String?
    let website: String?
    let federalEin: String?

    enum CodingKeys: String, CodingKey {
        case legalName = "legal_name"
        case dba
        case businessType = "business_type"
        case yearsInBusiness = "years_in_business"
        case stateOfIncorporation = "state_of_incorporation"
        case primaryStateOfOperations = "primary_state_of_operations"
        case mailingAddress = "mailing_address"
        case phone, website
        case federalEin = "federal_ein"
    }
}

struct SubmissionOperations: Codable {
    let description: String?
    let sicCode: String?
    let naicsCode: String?
    let employees: SubmissionEmployeeInfo?
    let revenue: SubmissionRevenueInfo?
    let payroll: SubmissionPayrollInfo?
    let subcontractors: SubmissionSubcontractorInfo?

    enum CodingKeys: String, CodingKey {
        case description
        case sicCode = "sic_code"
        case naicsCode = "naics_code"
        case employees, revenue, payroll, subcontractors
    }
}

struct SubmissionEmployeeInfo: Codable {
    let fullTime: Int?
    let partTime: Int?
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case fullTime = "full_time"
        case partTime = "part_time"
        case total
    }
}

struct SubmissionRevenueInfo: Codable {
    let annual: Double?
    let projectedGrowth: String?

    enum CodingKeys: String, CodingKey {
        case annual
        case projectedGrowth = "projected_growth"
    }
}

struct SubmissionPayrollInfo: Codable {
    let annual: Double?

    enum CodingKeys: String, CodingKey {
        case annual
    }
}

struct SubmissionSubcontractorInfo: Codable {
    let used: Bool?
    let details: String?

    enum CodingKeys: String, CodingKey {
        case used, details
    }
}

struct SubmissionLoss: Codable {
    let year: Int?
    let type: String?
    let amount: Double?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case year, type, amount, description
    }
}

struct SubmissionRequestedCoverage: Codable, Identifiable {
    let type: String?
    let policyName: String?
    let applicationForms: [String]?
    let companyTypes: [String]?
    let limits: String?
    let deductible: String?
    let effectiveDate: String?
    let notes: String?

    var id: String { type ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case type, limits, deductible, notes
        case policyName = "policy_name"
        case applicationForms = "application_forms"
        case companyTypes = "company_types"
        case effectiveDate = "effective_date"
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

// MARK: - Flexible Decoding Helpers

private struct SubmissionLossHistorySnapshot: Decodable {
    let yearsReviewed: Int?
    let priorLosses: String?
    let currentlyInsured: String?

    enum CodingKeys: String, CodingKey {
        case yearsReviewed = "years_reviewed"
        case priorLosses = "prior_losses"
        case currentlyInsured = "currently_insured"
    }
}

private extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value.trimmedOrNil
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value ? "Yes" : "No"
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }

    func decodeStringArrayOrWrappedStringIfPresent(forKey key: Key) -> [String]? {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        if let value = decodeFlexibleStringIfPresent(forKey: key) {
            return [value]
        }
        return nil
    }
}

// MARK: - Flexible Result Decoding

extension ResultsResponse {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coverageOptions = try container.decode([CoverageOption].self, forKey: .coverageOptions)
        submissionPacketUrl = container.decodeFlexibleStringIfPresent(forKey: .submissionPacketUrl) ?? ""
        voiceSummaryUrl = container.decodeFlexibleStringIfPresent(forKey: .voiceSummaryUrl) ?? ""
        riskProfile = try? container.decodeIfPresent(RiskProfile.self, forKey: .riskProfile)
        submissionPacket = try? container.decodeIfPresent(SubmissionPacket.self, forKey: .submissionPacket)
        plainEnglishSummary = container.decodeFlexibleStringIfPresent(forKey: .plainEnglishSummary)
    }
}

extension SubmissionPacket {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        submissionDate = container.decodeFlexibleStringIfPresent(forKey: .submissionDate)
        applicant = try? container.decodeIfPresent(SubmissionApplicant.self, forKey: .applicant)
        operations = try? container.decodeIfPresent(SubmissionOperations.self, forKey: .operations)
        requestedCoverages = try? container.decodeIfPresent([SubmissionRequestedCoverage].self, forKey: .requestedCoverages)
        underwriterNotes = container.decodeStringArrayOrWrappedStringIfPresent(forKey: .underwriterNotes)

        if let losses = try? container.decodeIfPresent([SubmissionLoss].self, forKey: .lossHistory) {
            lossHistory = losses
        } else if let snapshot = try? container.decodeIfPresent(SubmissionLossHistorySnapshot.self, forKey: .lossHistory) {
            var normalized: [SubmissionLoss] = []

            if let priorLosses = snapshot.priorLosses?.trimmedOrNil {
                normalized.append(
                    SubmissionLoss(
                        year: nil,
                        type: "Prior Losses",
                        amount: nil,
                        description: priorLosses
                    )
                )
            }

            if let currentlyInsured = snapshot.currentlyInsured?.trimmedOrNil {
                let description: String
                if let yearsReviewed = snapshot.yearsReviewed {
                    description = "\(currentlyInsured) • \(yearsReviewed)-year review"
                } else {
                    description = currentlyInsured
                }

                normalized.append(
                    SubmissionLoss(
                        year: nil,
                        type: "Current Insurance",
                        amount: nil,
                        description: description
                    )
                )
            }

            lossHistory = normalized.isEmpty ? nil : normalized
        } else {
            lossHistory = nil
        }
    }
}

extension SubmissionOperations {
    private enum FlexibleCodingKeys: String, CodingKey {
        case description
        case sicCode = "sic_code"
        case naicsCode = "naics_code"
        case employees
        case revenue
        case payroll
        case subcontractors
        case fullTimeEmployees = "full_time_employees"
        case partTimeEmployees = "part_time_employees"
        case annualRevenue = "annual_revenue"
        case annualPayroll = "annual_payroll"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKeys.self)

        description = container.decodeFlexibleStringIfPresent(forKey: .description)
        sicCode = container.decodeFlexibleStringIfPresent(forKey: .sicCode)
        naicsCode = container.decodeFlexibleStringIfPresent(forKey: .naicsCode)

        if let nestedEmployees = try? container.decodeIfPresent(SubmissionEmployeeInfo.self, forKey: .employees) {
            employees = nestedEmployees
        } else {
            let fullTime = container.decodeFlexibleIntIfPresent(forKey: .fullTimeEmployees)
            let partTime = container.decodeFlexibleIntIfPresent(forKey: .partTimeEmployees)
            if fullTime != nil || partTime != nil {
                employees = SubmissionEmployeeInfo(
                    fullTime: fullTime,
                    partTime: partTime,
                    total: (fullTime ?? 0) + (partTime ?? 0)
                )
            } else {
                employees = nil
            }
        }

        if let nestedRevenue = try? container.decodeIfPresent(SubmissionRevenueInfo.self, forKey: .revenue) {
            revenue = nestedRevenue
        } else if let annualRevenue = container.decodeFlexibleDoubleIfPresent(forKey: .annualRevenue) {
            revenue = SubmissionRevenueInfo(annual: annualRevenue, projectedGrowth: nil)
        } else {
            revenue = nil
        }

        if let nestedPayroll = try? container.decodeIfPresent(SubmissionPayrollInfo.self, forKey: .payroll) {
            payroll = nestedPayroll
        } else if let annualPayroll = container.decodeFlexibleDoubleIfPresent(forKey: .annualPayroll) {
            payroll = SubmissionPayrollInfo(annual: annualPayroll)
        } else {
            payroll = nil
        }

        if let nestedSubcontractors = try? container.decodeIfPresent(SubmissionSubcontractorInfo.self, forKey: .subcontractors) {
            subcontractors = nestedSubcontractors
        } else if let usesSubcontractors = try? container.decodeIfPresent(Bool.self, forKey: .subcontractors) {
            subcontractors = SubmissionSubcontractorInfo(used: usesSubcontractors, details: nil)
        } else if let subcontractorNote = container.decodeFlexibleStringIfPresent(forKey: .subcontractors) {
            subcontractors = SubmissionSubcontractorInfo(used: nil, details: subcontractorNote)
        } else {
            subcontractors = nil
        }
    }
}
