import Foundation

/// Local sample analysis when **Offline demo** is on — no backend, Gemini, or API keys.
enum FaroDemoData {
    private static let pendingIntakeKey = "faro_demo_pendingIntakePayload"
    private static let latestPendingSessionKey = "faro_demo_latestPendingSessionId"

    /// Session IDs created for demo runs (intake + analysis). WebSocket and results use this prefix.
    static let sessionPrefix = "faro-demo-"

    static func isDemoSessionId(_ id: String) -> Bool {
        id.hasPrefix(sessionPrefix)
    }

    static func makeSessionId() -> String {
        sessionPrefix + UUID().uuidString
    }

    private static func pendingIntakeKey(for sessionId: String) -> String {
        pendingIntakeKey + "_" + sessionId
    }

    static func storePendingIntake(_ intake: IntakeRequest, for sessionId: String) throws {
        let data = try JSONEncoder().encode(intake)
        UserDefaults.standard.set(data, forKey: pendingIntakeKey(for: sessionId))
        // Keep the legacy singleton key in sync so older code paths still have a sensible fallback.
        UserDefaults.standard.set(data, forKey: pendingIntakeKey)
        UserDefaults.standard.set(sessionId, forKey: latestPendingSessionKey)
    }

    static func loadPendingIntake(for sessionId: String) -> IntakeRequest? {
        if let data = UserDefaults.standard.data(forKey: pendingIntakeKey(for: sessionId)) {
            return try? JSONDecoder().decode(IntakeRequest.self, from: data)
        }
        // Fallback for older builds that only stored one demo intake payload.
        return loadPendingIntake()
    }

    static func loadPendingIntake() -> IntakeRequest? {
        guard let data = UserDefaults.standard.data(forKey: pendingIntakeKey) else { return nil }
        return try? JSONDecoder().decode(IntakeRequest.self, from: data)
    }

    static func latestPendingSessionId() -> String? {
        UserDefaults.standard.string(forKey: latestPendingSessionKey)
    }

    /// Same structured content as ``OnboardingViewModel/loadDemoData()`` for voice / fallback.
    static func sampleGuidedIntake() -> IntakeRequest {
        IntakeRequest(
            businessName: "Sunny Days Daycare",
            description:
                "Licensed childcare center serving children ages 6 weeks to 12 years. We provide full-day care, after-school programs, and summer camps across 3 locations in central New Jersey. Our certified staff oversee indoor play areas, outdoor playgrounds, and early learning programs.",
            employeeCount: 28,
            state: "NJ",
            annualRevenue: 1_200_000,
            contactFirstName: "Sarah",
            contactMiddleName: nil,
            contactLastName: "Johnson",
            contactEmail: nil
        )
    }

    static func results(from intake: IntakeRequest) -> ResultsResponse {
        let state = intake.state.uppercased()
        let biz = intake.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayBiz = biz.isEmpty ? "Your business" : biz
        let employees = intake.employeeCount
        let rev = intake.annualRevenue
        let revFormatted = Self.currencyString(rev)

        let risk = RiskProfile(
            industry: "Childcare / Daycare",
            sicCode: "8351",
            riskLevel: employees >= 20 ? "high" : "medium",
            primaryExposures: [
                "Bodily injury to minors and supervision liability",
                "Professional negligence and licensing compliance",
                "Employment practices and staff background requirements",
                "Property damage to facilities and playgrounds",
            ],
            stateRequirements: [
                "Workers’ compensation required for employees in \(state)",
                "General liability is standard; abuse & molestation often required for childcare",
                "State licensing and staff ratios must be maintained for coverage eligibility",
            ],
            employeeImplications: [
                "\(employees) employees — workers’ comp and EPLI thresholds typically apply",
                "Background checks and training records are common underwriting asks",
            ],
            revenueExposure: "\(revFormatted) annual revenue — used to bracket premium estimates",
            unusualRisks: [
                "Care of minors increases severity potential versus general office exposure",
            ],
            reasoningSummary:
                "Demo profile for \(displayBiz) in \(state), sized for \(employees) employees and \(revFormatted) in revenue. This is static sample output for device testing — connect a configured API for live Gemini-backed analysis."
        )

        let options: [CoverageOption] = [
            CoverageOption(
                type: "General Liability",
                description: "Third-party bodily injury, property damage, and many advertising injury claims for your premises and operations.",
                estimatedPremiumLow: max(2_400, rev * 0.0012),
                estimatedPremiumHigh: max(4_800, rev * 0.0022),
                confidence: 0.82,
                category: .required,
                triggerEvent: "Ongoing operations and visitor traffic",
                exampleCarriers: ["Hartford", "Travelers", "CNA"]
            ),
            CoverageOption(
                type: "Workers Compensation",
                description: "Statutory benefits for employees injured on the job — typically mandatory with payroll.",
                estimatedPremiumLow: Double(employees) * 420,
                estimatedPremiumHigh: Double(employees) * 780,
                confidence: 0.78,
                category: .required,
                triggerEvent: "Payrolled employees in \(state)",
                exampleCarriers: ["EMPLOYERS", "AmTrust", "Zurich"]
            ),
            CoverageOption(
                type: "Abuse & Molestation",
                description: "Often required or strongly recommended when caring for minors.",
                estimatedPremiumLow: 900,
                estimatedPremiumHigh: 2_400,
                confidence: 0.7,
                category: .recommended,
                triggerEvent: "Care and custody of children",
                exampleCarriers: ["Philadelphia", "Markel", "Tokio Marine"]
            ),
            CoverageOption(
                type: "Cyber Liability",
                description: "First- and third-party cyber coverage if you store parent or payment data electronically.",
                estimatedPremiumLow: 800,
                estimatedPremiumHigh: 2_200,
                confidence: 0.62,
                category: .recommended,
                triggerEvent: "Digital records and payment processing",
                exampleCarriers: ["Coalition", "Corvus", "Chubb"]
            ),
        ]

        let applicant = SubmissionApplicant(
            legalName: displayBiz,
            dba: displayBiz,
            businessType: "Childcare / early education",
            yearsInBusiness: nil,
            stateOfIncorporation: state,
            primaryStateOfOperations: state,
            mailingAddress: nil,
            phone: nil,
            website: nil,
            federalEin: nil
        )

        let submissionOps = SubmissionOperations(
            description: intake.description,
            sicCode: "8351",
            naicsCode: "624410",
            employees: SubmissionEmployeeInfo(
                fullTime: max(employees - 4, 1),
                partTime: min(4, employees),
                total: employees
            ),
            revenue: SubmissionRevenueInfo(annual: rev, projectedGrowth: nil),
            payroll: nil,
            subcontractors: SubmissionSubcontractorInfo(used: false, details: nil)
        )

        let dateStr: String = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let packet = SubmissionPacket(
            submissionDate: dateStr,
            applicant: applicant,
            operations: submissionOps,
            lossHistory: [
                SubmissionLoss(
                    year: nil,
                    type: "Demo note",
                    amount: nil,
                    description: "No claims entered — offline demo packet."
                ),
            ],
            requestedCoverages: [
                SubmissionRequestedCoverage(
                    type: "General Liability",
                    limits: "$1M per occurrence / $2M aggregate",
                    deductible: "$1,000",
                    effectiveDate: nil,
                    notes: "Illustrative — confirm with a licensed agent."
                ),
                SubmissionRequestedCoverage(
                    type: "Workers Compensation",
                    limits: "Statutory \(state)",
                    deductible: nil,
                    effectiveDate: nil,
                    notes: nil
                ),
            ],
            underwriterNotes: [
                "Offline demo — not for underwriting. Replace with API-backed submission for production.",
            ]
        )

        let summary =
            "\(displayBiz) in \(state): mapped core liability and workers’ comp themes for roughly \(employees) employees and \(revFormatted) in revenue (offline demo)."

        return ResultsResponse(
            coverageOptions: options,
            submissionPacketUrl: "",
            voiceSummaryUrl: "",
            riskProfile: risk,
            submissionPacket: packet,
            plainEnglishSummary: summary,
            nextRenewalDays: 120
        )
    }

    static func demoCoverageChatReply(userMessage: String) -> String {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = trimmed.count > 120 ? String(trimmed.prefix(120)) + "…" : trimmed
        return """
        Offline demo mode is on — there is no live model on the device. Your message was: “\(clip)”

        With the real API, Faro would answer using your mapped coverages and risk profile. Turn off Offline demo in Profile and point the app at a configured backend for full Q&A.
        """
    }

    static func demoStatus() -> StatusResponse {
        StatusResponse(status: .healthy, nextRenewalDays: 120, message: "Offline demo — no server status.")
    }

    /// Step completion copy for the simulated analysis pipeline.
    static func demoPipelineSteps(for intake: IntakeRequest) -> [(AgentStep, String)] {
        let state = intake.state.uppercased()
        return [
            (.riskProfiler, "Profiled industry exposure and \(state) requirements."),
            (.coverageMapper, "Mapped priorities to policy types for your operation size."),
            (.submissionBuilder, "Built a submission-style outline from your intake."),
            (.explainer, "Generated a plain-English summary for review."),
        ]
    }

    /// Voice demo: prefer transcript-derived intake when the user spoke; otherwise guided sample.
    static func intakeForVoiceDemo(transcript: [ConvTranscriptTurn]) -> IntakeRequest {
        let userText = transcript.filter { $0.role == "user" }.map(\.message).joined(separator: " ")
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 40 {
            let base = sampleGuidedIntake()
            return IntakeRequest(
                businessName: base.businessName,
                description: String(trimmed.prefix(2_000)),
                employeeCount: base.employeeCount,
                state: base.state,
                annualRevenue: base.annualRevenue,
                contactFirstName: base.contactFirstName,
                contactMiddleName: base.contactMiddleName,
                contactLastName: base.contactLastName,
                contactEmail: base.contactEmail
            )
        }
        return sampleGuidedIntake()
    }

    private static func currencyString(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
