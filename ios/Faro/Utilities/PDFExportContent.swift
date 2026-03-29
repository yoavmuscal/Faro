import Foundation

/// Text blocks for the Faro export PDF.
enum PDFExportContent {

    struct Section {
        let title: String
        let paragraphs: [String]
    }

    static func sections(for results: ResultsResponse, businessName: String) -> [Section] {
        var out: [Section] = []

        out.append(Section(title: "Overview", paragraphs: overviewParagraphs(results: results, businessName: businessName)))

        if let summary = results.plainEnglishSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            out.append(Section(title: "Summary", paragraphs: splitIntoParagraphs(summary)))
        }

        if let rp = results.riskProfile {
            let paras = riskProfileParagraphs(rp)
            if !paras.isEmpty {
                out.append(Section(title: "Risk profile", paragraphs: paras))
            }
        }

        if let packet = results.submissionPacket {
            let paras = submissionPacketParagraphs(packet)
            if !paras.isEmpty {
                out.append(Section(title: "Carrier submission packet", paragraphs: paras))
            }
        }

        var linkLines: [String] = []
        if !results.submissionPacketUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linkLines.append("External submission packet URL: \(results.submissionPacketUrl)")
        }
        if !results.voiceSummaryUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linkLines.append("Voice summary (listen in app or download): \(results.voiceSummaryUrl)")
        }
        if !linkLines.isEmpty {
            out.append(Section(title: "Links", paragraphs: linkLines))
        }

        return out
    }

    // MARK: - Overview

    private static func overviewParagraphs(results: ResultsResponse, businessName: String) -> [String] {
        let opts = results.coverageOptions
        let req = opts.filter { $0.category == .required }.count
        let rec = opts.filter { $0.category == .recommended }.count
        let proj = opts.filter { $0.category == .projected }.count
        let totalLow = opts.reduce(0) { $0 + $1.estimatedPremiumLow }
        let totalHigh = opts.reduce(0) { $0 + $1.estimatedPremiumHigh }
        let avgConf: Int = {
            guard !opts.isEmpty else { return 0 }
            return Int(opts.map(\.confidence).reduce(0, +) / Double(opts.count) * 100)
        }()

        return [
            "Business: \(businessName). Policies analyzed: \(opts.count) (\(req) required, \(rec) recommended, \(proj) projected).",
            "Estimated total annual premium (sum of line items): $\(Int(totalLow).formatted()) – $\(Int(totalHigh).formatted()). Average model confidence: \(avgConf)%.",
        ]
    }

    // MARK: - Risk profile

    private static func riskProfileParagraphs(_ rp: RiskProfile) -> [String] {
        var lines: [String] = []

        appendFieldLine(&lines, "Industry", rp.industry)
        appendFieldLine(&lines, "SIC code", rp.sicCode)
        appendFieldLine(&lines, "Risk level", rp.riskLevel)
        appendFieldLine(&lines, "Revenue exposure", rp.revenueExposure)

        if let summary = rp.reasoningSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            lines.append("Reasoning: \(summary)")
        }

        appendBulletBlock(&lines, title: "Primary exposures", items: rp.primaryExposures)
        appendBulletBlock(&lines, title: "State requirements", items: rp.stateRequirements)
        appendBulletBlock(&lines, title: "Employee implications", items: rp.employeeImplications)
        appendBulletBlock(&lines, title: "Unusual risks", items: rp.unusualRisks)

        return lines
    }

    // MARK: - Submission packet

    private static func submissionPacketParagraphs(_ packet: SubmissionPacket) -> [String] {
        var lines: [String] = []

        if let d = packet.submissionDate?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            lines.append("Submission date: \(d)")
        }

        if let a = packet.applicant {
            lines.append("— Applicant —")
            appendFieldLine(&lines, "Legal name", a.legalName)
            appendFieldLine(&lines, "DBA", a.dba)
            appendFieldLine(&lines, "Business type", a.businessType)
            if let y = a.yearsInBusiness { lines.append("Years in business: \(y)") }
            appendFieldLine(&lines, "State of incorporation", a.stateOfIncorporation)
            appendFieldLine(&lines, "Primary state of operations", a.primaryStateOfOperations)
            appendFieldLine(&lines, "Mailing address", a.mailingAddress)
            appendFieldLine(&lines, "Phone", a.phone)
            appendFieldLine(&lines, "Website", a.website)
            appendFieldLine(&lines, "Federal EIN", a.federalEin)
            lines.append("")
        }

        if let ops = packet.operations {
            lines.append("— Operations —")
            if let desc = ops.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                lines.append(desc)
            }
            appendFieldLine(&lines, "SIC", ops.sicCode)
            appendFieldLine(&lines, "NAICS", ops.naicsCode)

            if let e = ops.employees {
                let empStr: String
                if let t = e.total {
                    empStr = "\(t) total (\(e.fullTime ?? 0) FT / \(e.partTime ?? 0) PT)"
                } else {
                    empStr = "\(e.fullTime ?? 0) full-time / \(e.partTime ?? 0) part-time"
                }
                lines.append("Employees: \(empStr)")
            }
            if let rev = ops.revenue?.annual {
                lines.append("Annual revenue: $\(Int(rev).formatted())")
            }
            if let growth = ops.revenue?.projectedGrowth?.trimmingCharacters(in: .whitespacesAndNewlines), !growth.isEmpty {
                lines.append("Projected growth: \(growth)")
            }
            if let pay = ops.payroll?.annual {
                lines.append("Annual payroll: $\(Int(pay).formatted())")
            }
            if let sub = ops.subcontractors {
                if let u = sub.used {
                    lines.append("Uses subcontractors: \(u ? "Yes" : "No")")
                }
                if let d = sub.details?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
                    lines.append("Subcontractors: \(d)")
                }
            }
            lines.append("")
        }

        if let coverages = packet.requestedCoverages, !coverages.isEmpty {
            lines.append("— Requested coverages —")
            for cov in coverages {
                lines.append("• \(cov.type ?? "Coverage")")
                appendFieldLine(&lines, "  Limits", cov.limits)
                appendFieldLine(&lines, "  Deductible", cov.deductible)
                appendFieldLine(&lines, "  Effective", cov.effectiveDate)
                if let n = cov.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                    lines.append("  Notes: \(n)")
                }
            }
            lines.append("")
        }

        if let losses = packet.lossHistory, !losses.isEmpty {
            lines.append("— Loss history —")
            for loss in losses {
                var head: [String] = []
                if let y = loss.year { head.append(String(y)) }
                if let t = loss.type?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { head.append(t) }
                if let amt = loss.amount {
                    head.append("$\(Int(amt).formatted())")
                }
                let prefix = head.isEmpty ? "•" : "• \(head.joined(separator: " · "))"
                if let desc = loss.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                    lines.append("\(prefix): \(desc)")
                } else {
                    lines.append(prefix)
                }
            }
            lines.append("")
        }

        if let notes = packet.underwriterNotes, !notes.isEmpty {
            lines.append("— Underwriter notes —")
            for (i, note) in notes.enumerated() {
                let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    lines.append("\(i + 1). \(t)")
                }
            }
        }

        return lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Helpers

    private static func splitIntoParagraphs(_ text: String) -> [String] {
        let parts = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count > 1 {
            return parts
        }
        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func appendFieldLine(_ lines: inout [String], _ label: String, _ value: String?) {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return }
        lines.append("\(label): \(v)")
    }

    private static func appendBulletBlock(_ lines: inout [String], title: String, items: [String]?) {
        guard let items, !items.isEmpty else { return }
        let cleaned = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        lines.append("\(title):")
        for item in cleaned {
            lines.append("• \(item)")
        }
    }
}
