import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum PDFBuilder {

    /// Generates a full export PDF (overview, summary, risk profile, submission packet, coverage lines) and writes it to a temp file.
    static func build(from results: ResultsResponse, businessName: String = "Business") -> URL? {
        #if os(iOS)
        return buildIOS(from: results, businessName: businessName)
        #elseif os(macOS)
        return buildMac(from: results, businessName: businessName)
        #else
        return nil
        #endif
    }

    #if os(iOS)
    private static func buildIOS(from results: ResultsResponse, businessName: String) -> URL? {
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

            y = drawDividerIOS(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)

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
            drawExportSectionsIOS(
                ctx: ctx,
                sections: exportSections,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                sectionAttrs: sectionAttrs,
                bodyAttrs: bodyAttrs,
                y: &y
            )

            ensureSpaceIOS(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 36)
            ("Coverage analysis" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 22),
                withAttributes: sectionAttrs
            )
            y += 28
            y = drawDividerIOS(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)

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
                y = drawDividerIOS(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth)
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

    private static func ensureSpaceIOS(
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

    private static func drawExportSectionsIOS(
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
            ensureSpaceIOS(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: titleLineHeight + spacingAfterTitle)
            (section.title as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: titleLineHeight),
                withAttributes: sectionAttrs
            )
            y += titleLineHeight + spacingAfterTitle

            for paragraph in section.paragraphs {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                let h = heightForString(trimmed, width: contentWidth, attributes: bodyAttrs)
                ensureSpaceIOS(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 8)
                (trimmed as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: h),
                    withAttributes: bodyAttrs
                )
                y += h + 8
            }
            y += 12
        }
    }

    private static func drawDividerIOS(ctx: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
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
    #endif

    #if os(macOS)
    private static func buildMac(from results: ResultsResponse, businessName: String) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)

        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        var y: CGFloat = margin

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.black,
        ]
        let title = "Coverage Analysis — \(businessName)"
        (title as NSString).draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 30), withAttributes: titleAttrs)
        y += 36

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.darkGray,
        ]
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        (("Generated \(dateStr) by Faro") as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
            withAttributes: subtitleAttrs
        )
        y += 24

        y = drawDividerMac(ctx: ctx, y: y, margin: margin, width: contentWidth)

        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.darkGray,
        ]
        let boldBody: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        ]

        let exportSections = PDFExportContent.sections(for: results, businessName: businessName)
        drawExportSectionsMac(
            ctx: ctx,
            sections: exportSections,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            sectionAttrs: sectionAttrs,
            bodyAttrs: bodyAttrs,
            y: &y
        )

        ensureSpaceMac(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 36)
        ("Coverage analysis" as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 22),
            withAttributes: sectionAttrs
        )
        y += 28
        y = drawDividerMac(ctx: ctx, y: y, margin: margin, width: contentWidth)

        let order: [CoverageCategory] = [.required, .recommended, .projected]
        let sorted = results.coverageOptions.sorted {
            (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
        }

        for option in sorted {
            if y > pageHeight - 140 {
                macBeginNewPage(ctx: ctx, pageHeight: pageHeight, y: &y, margin: margin)
            }

            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: categoryNSColor(option.category),
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
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.systemPurple,
                    .obliqueness: 0.2,
                ]
                (trigger as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                    withAttributes: triggerAttrs
                )
                y += 18
            }

            y += 12
            y = drawDividerMac(ctx: ctx, y: y, margin: margin, width: contentWidth)
        }

        if y > pageHeight - 80 {
            macBeginNewPage(ctx: ctx, pageHeight: pageHeight, y: &y, margin: margin)
        }
        y += 10
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.gray,
        ]
        let footer = "This document is a preliminary coverage analysis generated by AI. It is not a binding insurance quote. Please consult a licensed broker for final underwriting."
        let fh = heightForString(footer, width: contentWidth, attributes: footerAttrs)
        (footer as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: fh),
            withAttributes: footerAttrs
        )

        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
        ctx.endPDFPage()
        ctx.closePDF()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Faro_Export_\(businessName.replacingOccurrences(of: " ", with: "_")).pdf")
        do {
            try (data as Data).write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func macBeginNewPage(ctx: CGContext, pageHeight: CGFloat, y: inout CGFloat, margin: CGFloat) {
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
        ctx.endPDFPage()
        ctx.beginPDFPage(nil)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        y = margin
    }

    private static func ensureSpaceMac(
        ctx: CGContext,
        y: inout CGFloat,
        margin: CGFloat,
        pageHeight: CGFloat,
        needed: CGFloat,
        bottomReserve: CGFloat = 80
    ) {
        if y + needed <= pageHeight - bottomReserve { return }
        macBeginNewPage(ctx: ctx, pageHeight: pageHeight, y: &y, margin: margin)
    }

    private static func drawExportSectionsMac(
        ctx: CGContext,
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
            ensureSpaceMac(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: titleLineHeight + spacingAfterTitle)
            (section.title as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: titleLineHeight),
                withAttributes: sectionAttrs
            )
            y += titleLineHeight + spacingAfterTitle

            for paragraph in section.paragraphs {
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                let h = heightForString(trimmed, width: contentWidth, attributes: bodyAttrs)
                ensureSpaceMac(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 8)
                (trimmed as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: h),
                    withAttributes: bodyAttrs
                )
                y += h + 8
            }
            y += 12
        }
    }

    private static func drawDividerMac(ctx: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        return y + 12
    }

    private static func categoryNSColor(_ cat: CoverageCategory) -> NSColor {
        switch cat {
        case .required: return .systemRed
        case .recommended: return .systemOrange
        case .projected: return .systemPurple
        }
    }
    #endif

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
