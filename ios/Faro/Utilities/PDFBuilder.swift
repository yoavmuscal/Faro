import UIKit
import PDFKit

enum PDFBuilder {

    /// Generates a carrier-ready submission packet PDF and writes it to a temp file.
    /// Returns the file URL on success.
    static func build(from results: ResultsResponse, businessName: String = "Business") -> URL? {
        let pageWidth: CGFloat  = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat     = 50
        let contentWidth        = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // ── Header ──────────────────────────────────────────────────────
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let title = "Coverage Analysis — \(businessName)"
            let titleRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            y += 36

            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            (("Generated \(dateStr) by Faro") as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                withAttributes: subtitleAttrs
            )
            y += 24

            // Divider
            y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)

            // ── Coverage table ───────────────────────────────────────────────
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray,
            ]
            let boldBody: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            ]

            let order: [CoverageCategory] = [.required, .recommended, .projected]
            let sorted = results.coverageOptions.sorted {
                (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
            }

            for option in sorted {
                // Check if we need a new page
                if y > pageHeight - 140 {
                    ctx.beginPage()
                    y = margin
                }

                // Category badge
                let badge = categoryLabel(option.category).uppercased()
                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: categoryUIColor(option.category),
                ]
                (badge as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: badgeAttrs
                )
                y += 16

                // Policy name
                (option.type as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 20),
                    withAttributes: sectionAttrs
                )
                y += 22

                // Description
                let descHeight = heightForString(option.description, width: contentWidth, attributes: bodyAttrs)
                (option.description as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: descHeight),
                    withAttributes: bodyAttrs
                )
                y += descHeight + 6

                // Premium range + confidence
                let premiumLine = "Est. premium: $\(Int(option.estimatedPremiumLow).formatted()) – $\(Int(option.estimatedPremiumHigh).formatted())/yr  |  Confidence: \(Int(option.confidence * 100))%"
                (premiumLine as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                    withAttributes: boldBody
                )
                y += 20

                // Trigger event (projected only)
                if let trigger = option.triggerEvent {
                    let triggerAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 10),
                        .foregroundColor: UIColor.purple,
                    ]
                    (trigger as NSString).draw(
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                        withAttributes: triggerAttrs
                    )
                    y += 18
                }

                y += 12
                y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)
            }

            // ── Footer ──────────────────────────────────────────────────────
            if y > pageHeight - 80 {
                ctx.beginPage()
                y = margin
            }
            y += 10
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.gray,
            ]
            let footer = "This document is a preliminary coverage analysis generated by AI. It is not a binding insurance quote. Please consult a licensed broker for final underwriting."
            let fh = heightForString(footer, width: contentWidth, attributes: footerAttrs)
            (footer as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: fh),
                withAttributes: footerAttrs
            )
        }

        // Write to temp file
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Faro_Submission_\(businessName.replacingOccurrences(of: " ", with: "_")).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func drawDivider(ctx: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        return y + 12
    }

    private static func heightForString(_ string: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let boundingRect = (string as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(boundingRect.height)
    }

    private static func categoryLabel(_ cat: CoverageCategory) -> String {
        switch cat {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
    }

    private static func categoryUIColor(_ cat: CoverageCategory) -> UIColor {
        switch cat {
        case .required: return .systemRed
        case .recommended: return .systemOrange
        case .projected: return .systemPurple
        }
    }
}
