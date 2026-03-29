import Foundation
import UIKit

enum PDFBuilder {

    /// Generates a full export PDF (overview, summary, risk profile, submission packet, coverage lines) and writes it to a temp file.
    static func build(from results: ResultsResponse, businessName: String = "Business") -> URL? {
        renderPDF(from: results, businessName: businessName)
    }

    private static func renderPDF(from results: ResultsResponse, businessName: String) -> URL? {
        let pageWidth: CGFloat  = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat     = 50
        let contentWidth        = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

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

            y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)

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

            let exportSections = PDFExportContent.sections(for: results, businessName: businessName)
            drawExportSections(
                ctx: ctx,
                sections: exportSections,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                sectionAttrs: sectionAttrs,
                bodyAttrs: bodyAttrs,
                y: &y
            )

            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 36)
            ("Coverage analysis" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 22),
                withAttributes: sectionAttrs
            )
            y += 28
            y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)

            let order: [CoverageCategory] = [.required, .recommended, .projected]
            let sorted = results.coverageOptions.sorted {
                (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
            }

            for option in sorted {
                if y > pageHeight - 140 {
                    ctx.beginPage()
                    y = margin
                }

                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: categoryUIColor(option.category),
                ]
                (categoryLabel(option.category).uppercased() as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: badgeAttrs
                )
                y += 16

                (option.type as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 20),
                    withAttributes: sectionAttrs
                )
                y += 22

                let descHeight = heightForString(option.description, width: contentWidth, attributes: bodyAttrs)
                (option.description as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: descHeight),
                    withAttributes: bodyAttrs
                )
                y += descHeight + 6

                let premiumLine = "Est. premium: $\(Int(option.estimatedPremiumLow).formatted()) – $\(Int(option.estimatedPremiumHigh).formatted())/yr  |  Confidence: \(Int(option.confidence * 100))%"
                (premiumLine as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                    withAttributes: boldBody
                )
                y += 20

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

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Faro_Export_\(businessName.replacingOccurrences(of: " ", with: "_")).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func ensureSpace(
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        margin: CGFloat,
        pageHeight: CGFloat,
        needed: CGFloat,
        bottomReserve: CGFloat = 80
    ) {
        if y + needed <= pageHeight - bottomReserve { return }
        ctx.beginPage()
        y = margin
    }

    private static func drawExportSections(
        ctx: UIGraphicsPDFRendererContext,
        sections: [PDFExportContent.Section],
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        sectionAttrs: [NSAttributedString.Key: Any],
        bodyAttrs: [NSAttributedString.Key: Any],
        y: inout CGFloat
    ) {
        let titleLineHeight: CGFloat = 22
        let spacingAfterTitle: CGFloat = 6
        for section in sections {
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: titleLineHeight + spacingAfterTitle)
            (section.title as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: titleLineHeight),
                withAttributes: sectionAttrs
            )
            y += titleLineHeight + spacingAfterTitle

            for paragraph in section.paragraphs {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                let h = heightForString(trimmed, width: contentWidth, attributes: bodyAttrs)
                ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 8)
                (trimmed as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: h),
                    withAttributes: bodyAttrs
                )
                y += h + 8
            }
            y += 12
        }
    }

    private static func drawDivider(ctx: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        return y + 12
    }

    private static func categoryUIColor(_ cat: CoverageCategory) -> UIColor {
        switch cat {
        case .required: return .systemRed
        case .recommended: return .systemOrange
        case .projected: return .systemPurple
        }
    }

    // MARK: - Shared helpers

    private static func categoryLabel(_ cat: CoverageCategory) -> String {
        switch cat {
        case .required: return "Required"
        case .recommended: return "Recommended"
        case .projected: return "Projected"
        }
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
}
