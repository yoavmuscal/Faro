import Foundation
import UIKit

/// Full export PDF with branded visuals, charts, and section styling.
enum PDFBuilder {

    private enum PDFTheme {
        static let deepPurple = UIColor(red: 0.32, green: 0.14, blue: 0.52, alpha: 1)
        static let accentPurple = UIColor(red: 0.48, green: 0.28, blue: 0.78, alpha: 1)
        static let lightLavender = UIColor(red: 0.94, green: 0.91, blue: 0.98, alpha: 1)
        static let required = UIColor(red: 0.92, green: 0.26, blue: 0.35, alpha: 1)
        static let recommended = UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
        static let projected = UIColor(red: 0.58, green: 0.35, blue: 0.88, alpha: 1)
        static let teal = UIColor(red: 0.12, green: 0.68, blue: 0.62, alpha: 1)
        static let sky = UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1)
        static let bodyText = UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)
        static let muted = UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)
        static let gold = UIColor(red: 1, green: 0.78, blue: 0.25, alpha: 1)
    }

    /// Generates a full export PDF (overview, summary, risk profile, submission packet, coverage lines) and writes it to a temp file.
    static func build(from results: ResultsResponse, businessName: String = "Business") -> URL? {
        renderPDF(from: results, businessName: businessName)
    }

    private static func renderPDF(from results: ResultsResponse, businessName: String) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 0

            drawHeaderBanner(ctx: ctx.cgContext, pageWidth: pageWidth, height: 108)
            y = 118

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: PDFTheme.deepPurple,
            ]
            let title = "Coverage Analysis — \(businessName)"
            let titleRect = CGRect(x: margin, y: y, width: contentWidth, height: 32)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            y += 38

            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: PDFTheme.muted,
            ]
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
            (("Generated \(dateStr) · Faro") as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                withAttributes: subtitleAttrs
            )
            y += 22

            let req = results.coverageOptions.filter { $0.category == .required }.count
            let rec = results.coverageOptions.filter { $0.category == .recommended }.count
            let proj = results.coverageOptions.filter { $0.category == .projected }.count
            y = drawStatCardsRow(
                ctx: ctx.cgContext,
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                required: req,
                recommended: rec,
                projected: proj
            )

            y = drawCategoryMixStackedBar(
                ctx: ctx.cgContext,
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                required: req,
                recommended: rec,
                projected: proj
            )

            y = drawPipelineDiagram(ctx: ctx.cgContext, y: y, margin: margin, contentWidth: contentWidth)
            y += 8

            let totalLow = results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumLow }
            let totalHigh = results.coverageOptions.reduce(0) { $0 + $1.estimatedPremiumHigh }
            y = drawPremiumRangeDiagram(
                ctx: ctx.cgContext,
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                results: results,
                totalLow: totalLow,
                totalHigh: totalHigh
            )

            if let level = results.riskProfile?.riskLevel, !level.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                y = drawRiskLevelMeter(ctx: ctx.cgContext, y: y, margin: margin, contentWidth: contentWidth, label: level)
            }

            y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth, color: PDFTheme.accentPurple.withAlphaComponent(0.35))

            let sectionTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: PDFTheme.deepPurple,
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: PDFTheme.bodyText,
            ]
            let boldBody: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: PDFTheme.bodyText,
            ]
            let captionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: PDFTheme.muted,
            ]

            drawSectionTitleBar(
                ctx: ctx,
                y: &y,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                title: "Report guide",
                sectionTitleAttrs: sectionTitleAttrs
            )
            drawCompactCallout(
                ctx: ctx,
                y: &y,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                text: "The charts above quantify line mix, premiums, workflow, and risk. The sections below add narrative context, structured risk and submission diagrams, then each line with confidence and premium visuals.",
                attrs: captionAttrs
            )

            if let summary = results.plainEnglishSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                drawSectionTitleBar(
                    ctx: ctx,
                    y: &y,
                    margin: margin,
                    contentWidth: contentWidth,
                    pageHeight: pageHeight,
                    title: "Executive summary",
                    sectionTitleAttrs: sectionTitleAttrs
                )
                drawMultilineCallout(ctx: ctx, y: &y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight, text: summary, bodyAttrs: bodyAttrs)
            }

            if let rp = results.riskProfile {
                drawRiskProfileDiagram(
                    ctx: ctx,
                    risk: rp,
                    margin: margin,
                    contentWidth: contentWidth,
                    pageHeight: pageHeight,
                    y: &y,
                    sectionTitleAttrs: sectionTitleAttrs,
                    bodyAttrs: bodyAttrs,
                    captionAttrs: captionAttrs
                )
            }

            if let packet = results.submissionPacket {
                drawSubmissionPacketDiagram(
                    ctx: ctx,
                    packet: packet,
                    margin: margin,
                    contentWidth: contentWidth,
                    pageHeight: pageHeight,
                    y: &y,
                    sectionTitleAttrs: sectionTitleAttrs,
                    bodyAttrs: bodyAttrs,
                    captionAttrs: captionAttrs
                )
            }

            drawLinksDiagram(
                ctx: ctx,
                results: results,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                y: &y,
                sectionTitleAttrs: sectionTitleAttrs,
                bodyAttrs: bodyAttrs
            )

            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 120)
            y = drawDivider(ctx: ctx.cgContext, y: y, margin: margin, width: contentWidth, color: PDFTheme.accentPurple.withAlphaComponent(0.35))

            (("Coverage lines" as NSString)).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 22),
                withAttributes: sectionTitleAttrs
            )
            y += 28

            let order: [CoverageCategory] = [.required, .recommended, .projected]
            let sorted = results.coverageOptions.sorted {
                (order.firstIndex(of: $0.category) ?? 99) < (order.firstIndex(of: $1.category) ?? 99)
            }
            let globalMinPrem = sorted.map(\.estimatedPremiumLow).min() ?? 0
            let globalMaxPrem = max(sorted.map(\.estimatedPremiumHigh).max() ?? 1, globalMinPrem + 1)

            for option in sorted {
                drawCoverageLineCard(
                    ctx: ctx,
                    option: option,
                    margin: margin,
                    contentWidth: contentWidth,
                    pageHeight: pageHeight,
                    y: &y,
                    globalMinPremium: globalMinPrem,
                    globalMaxPremium: globalMaxPrem,
                    sectionTitleAttrs: sectionTitleAttrs,
                    bodyAttrs: bodyAttrs,
                    boldBody: boldBody
                )
            }

            if y > pageHeight - 90 {
                ctx.beginPage()
                y = margin
            }
            y += 10
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: PDFTheme.muted,
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

    // MARK: - Visual header & diagrams

    private static func drawHeaderBanner(ctx: CGContext, pageWidth: CGFloat, height: CGFloat) {
        let c1 = PDFTheme.deepPurple
        let c2 = PDFTheme.accentPurple
        let bandH = height / 3
        ctx.setFillColor(c1.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: bandH))
        ctx.setFillColor(c2.withAlphaComponent(0.92).cgColor)
        ctx.fill(CGRect(x: 0, y: bandH, width: pageWidth, height: bandH))
        ctx.setFillColor(PDFTheme.teal.withAlphaComponent(0.35).cgColor)
        ctx.fill(CGRect(x: 0, y: bandH * 2, width: pageWidth, height: bandH))

        // Decorative circles (diagram feel)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(2)
        for i in 0..<5 {
            let r: CGFloat = 40 + CGFloat(i) * 35
            ctx.strokeEllipse(in: CGRect(x: pageWidth - r * 2 - 20, y: height / 2 - r, width: r * 2, height: r * 2))
        }
    }

    private static func drawStatCardsRow(
        ctx: CGContext,
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        required: Int,
        recommended: Int,
        projected: Int
    ) -> CGFloat {
        let cardW = (contentWidth - 16) / 3
        let cardH: CGFloat = 52
        let labels = [("Required", required, PDFTheme.required), ("Recommended", recommended, PDFTheme.recommended), ("Projected", projected, PDFTheme.projected)]
        for (i, item) in labels.enumerated() {
            let x = margin + CGFloat(i) * (cardW + 8)
            let rect = CGRect(x: x, y: y, width: cardW, height: cardH)
            ctx.setFillColor(item.2.withAlphaComponent(0.12).cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(item.2.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(rect)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: item.2,
            ]
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: PDFTheme.deepPurple,
            ]
            (item.0 as NSString).draw(in: CGRect(x: x + 8, y: y + 8, width: cardW - 16, height: 14), withAttributes: titleAttrs)
            ("\("\(item.1)")" as NSString).draw(in: CGRect(x: x + 8, y: y + 24, width: cardW - 16, height: 28), withAttributes: numAttrs)
        }
        return y + cardH + 14
    }

    /// Horizontal stacked bar showing share of required / recommended / projected lines (by count).
    private static func drawCategoryMixStackedBar(
        ctx: CGContext,
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        required: Int,
        recommended: Int,
        projected: Int
    ) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: PDFTheme.deepPurple,
        ]
        ("Coverage mix (lines by category)" as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
            withAttributes: titleAttrs
        )
        let barY = y + 20
        let barH: CGFloat = 20
        let total = max(required + recommended + projected, 1)
        let wR = contentWidth * CGFloat(required) / CGFloat(total)
        let wRec = contentWidth * CGFloat(recommended) / CGFloat(total)
        let wP = contentWidth * CGFloat(projected) / CGFloat(total)

        let outer = UIBezierPath(roundedRect: CGRect(x: margin, y: barY, width: contentWidth, height: barH), cornerRadius: 6)
        ctx.saveGState()
        ctx.addPath(outer.cgPath)
        ctx.clip()

        var x = margin
        if required > 0 {
            ctx.setFillColor(PDFTheme.required.cgColor)
            ctx.fill(CGRect(x: x, y: barY, width: wR, height: barH))
            x += wR
        }
        if recommended > 0 {
            ctx.setFillColor(PDFTheme.recommended.cgColor)
            ctx.fill(CGRect(x: x, y: barY, width: wRec, height: barH))
            x += wRec
        }
        if projected > 0 {
            ctx.setFillColor(PDFTheme.projected.cgColor)
            ctx.fill(CGRect(x: x, y: barY, width: wP, height: barH))
        }
        ctx.restoreGState()

        ctx.setStrokeColor(PDFTheme.muted.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(outer.cgPath)
        ctx.strokePath()

        let legendY = barY + barH + 8
        let leg: [(String, UIColor)] = [
            ("Req \(required)", PDFTheme.required),
            ("Rec \(recommended)", PDFTheme.recommended),
            ("Proj \(projected)", PDFTheme.projected),
        ]
        var lx = margin
        for item in leg {
            ctx.setFillColor(item.1.cgColor)
            ctx.fill(CGRect(x: lx, y: legendY + 2, width: 8, height: 8))
            let la: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: PDFTheme.muted,
            ]
            (item.0 as NSString).draw(
                in: CGRect(x: lx + 12, y: legendY, width: 72, height: 12),
                withAttributes: la
            )
            lx += 88
        }
        return legendY + 18
    }

    private static func drawPipelineDiagram(ctx: CGContext, y: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let h: CGFloat = 40
        let steps = ["Intake", "Risk", "Coverage", "Submit"]
        let colors = [PDFTheme.sky, PDFTheme.teal, PDFTheme.accentPurple, PDFTheme.deepPurple]
        let gap: CGFloat = 6
        let chevronW: CGFloat = 14
        let totalGaps = chevronW * CGFloat(steps.count - 1)
        let boxW = (contentWidth - totalGaps - gap * CGFloat(steps.count - 1)) / CGFloat(steps.count)

        var x = margin
        var labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let centerParagraph = NSMutableParagraphStyle()
        centerParagraph.alignment = .center
        labelAttrs[.paragraphStyle] = centerParagraph
        for (i, step) in steps.enumerated() {
            let rect = CGRect(x: x, y: y, width: boxW, height: h)
            ctx.setFillColor(colors[i].cgColor)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            let attr = attributedStringWithBoldAsterisks(step, baseAttributes: labelAttrs)
            drawAttributedStringCenteredInRect(attr, rect: rect)
            x += boxW + gap
            if i < steps.count - 1 {
                // Chevron
                ctx.setFillColor(colors[i].withAlphaComponent(0.85).cgColor)
                let cx = x
                let cy = y + h / 2
                ctx.move(to: CGPoint(x: cx, y: cy - 8))
                ctx.addLine(to: CGPoint(x: cx + chevronW * 0.45, y: cy))
                ctx.addLine(to: CGPoint(x: cx, y: cy + 8))
                ctx.closePath()
                ctx.fillPath()
                x += chevronW
            }
        }

        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: PDFTheme.muted,
        ]
        ("Analysis pipeline" as NSString).draw(
            in: CGRect(x: margin, y: y + h + 4, width: contentWidth, height: 12),
            withAttributes: captionAttrs
        )
        return y + h + 22
    }

    private static func drawPremiumRangeDiagram(
        ctx: CGContext,
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        results: ResultsResponse,
        totalLow: Double,
        totalHigh: Double
    ) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: PDFTheme.deepPurple,
        ]
        ("Estimated premium by category (annual)" as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
            withAttributes: titleAttrs
        )
        var yy = y + 20
        let barH: CGFloat = 22
        let maxW = contentWidth - 120

        func sumPremium(_ cat: CoverageCategory) -> Double {
            results.coverageOptions.filter { $0.category == cat }.reduce(0) { $0 + $1.premiumMidpoint }
        }
        let sums: [(CoverageCategory, UIColor, String)] = [
            (.required, PDFTheme.required, "Required"),
            (.recommended, PDFTheme.recommended, "Recommended"),
            (.projected, PDFTheme.projected, "Projected"),
        ]
        let maxVal = max(sums.map { sumPremium($0.0) }.max() ?? 1, 1)

        for item in sums {
            let v = sumPremium(item.0)
            let frac = CGFloat(v / maxVal)
            (item.2 as NSString).draw(
                in: CGRect(x: margin, y: yy, width: 100, height: barH),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: PDFTheme.bodyText,
                ]
            )
            let track = CGRect(x: margin + 108, y: yy + 3, width: maxW, height: barH - 6)
            ctx.setFillColor(UIColor.systemGray5.cgColor)
            ctx.fill(track)
            let fillW = max(4, track.width * frac)
            ctx.setFillColor(item.1.cgColor)
            ctx.fill(CGRect(x: track.minX, y: track.minY, width: fillW, height: track.height))

            let valStr = v > 0 ? "$\(Int(v).formatted())" : "—"
            (valStr as NSString).draw(
                in: CGRect(x: margin + 108 + maxW + 8, y: yy + 4, width: 80, height: barH),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: PDFTheme.muted,
                ]
            )
            yy += barH + 6
        }

        let sumAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: PDFTheme.muted,
        ]
        let line = "Portfolio total (sum of line ranges): $\(Int(totalLow).formatted()) – $\(Int(totalHigh).formatted()) / yr"
        (line as NSString).draw(in: CGRect(x: margin, y: yy + 4, width: contentWidth, height: 14), withAttributes: sumAttrs)
        return yy + 28
    }

    private static func drawRiskLevelMeter(ctx: CGContext, y: CGFloat, margin: CGFloat, contentWidth: CGFloat, label: String) -> CGFloat {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: PDFTheme.deepPurple,
        ]
        ("Risk posture" as NSString).draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 16), withAttributes: titleAttrs)
        var yy = y + 18

        let trackH: CGFloat = 14
        let track = CGRect(x: margin, y: yy, width: contentWidth, height: trackH)
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [PDFTheme.teal.cgColor, PDFTheme.gold.cgColor, PDFTheme.required.cgColor] as CFArray,
            locations: [0, 0.5, 1]
        )!
        ctx.saveGState()
        ctx.addPath(UIBezierPath(roundedRect: track, cornerRadius: 7).cgPath)
        ctx.clip()
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: track.minX, y: track.midY),
            end: CGPoint(x: track.maxX, y: track.midY),
            options: []
        )
        ctx.restoreGState()

        let t = riskLevelT(label)
        let markerX = track.minX + track.width * t
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.setStrokeColor(PDFTheme.deepPurple.cgColor)
        ctx.setLineWidth(2)
        let marker = CGRect(x: markerX - 6, y: yy - 4, width: 12, height: trackH + 8)
        ctx.fillEllipse(in: marker)
        ctx.strokeEllipse(in: marker)

        let lowHighAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: PDFTheme.muted,
        ]
        ("Lower risk" as NSString).draw(at: CGPoint(x: margin, y: yy + trackH + 4), withAttributes: lowHighAttrs)
        ("Higher risk" as NSString).draw(
            at: CGPoint(x: margin + contentWidth - 54, y: yy + trackH + 4),
            withAttributes: lowHighAttrs
        )

        var labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: PDFTheme.bodyText,
        ]
        let lp = NSMutableParagraphStyle()
        lp.alignment = .natural
        labelAttrs[.paragraphStyle] = lp
        let profileAttr = attributedStringWithBoldAsterisks("Profile: \(label)", baseAttributes: labelAttrs)
        let profileH = heightForAttributedString(profileAttr, width: contentWidth)
        profileAttr.draw(in: CGRect(x: margin, y: yy + trackH + 18, width: contentWidth, height: max(profileH, 16)))
        return yy + trackH + 18 + max(profileH, 16) + 12
    }

    private static func riskLevelT(_ raw: String) -> CGFloat {
        let s = raw.lowercased()
        if s.contains("high") || s.contains("elevated") { return 0.88 }
        if s.contains("low") || s.contains("minimal") { return 0.12 }
        if s.contains("moderate") || s.contains("medium") { return 0.5 }
        return 0.55
    }

    // MARK: - Attributed text (`*bold*` → bold)

    /// Pairs of asterisks wrap bold segments: `*emphasis*` → **emphasis** with asterisks removed. Unpaired `*` is kept as literal.
    private static func attributedStringWithBoldAsterisks(_ string: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = baseAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 11)
        var boldAttrs = baseAttributes
        boldAttrs[.font] = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)

        var i = string.startIndex
        while i < string.endIndex {
            if string[i] == "*" {
                let start = string.index(after: i)
                if start < string.endIndex, let end = string[start...].firstIndex(of: "*") {
                    let inner = String(string[start..<end])
                    result.append(NSAttributedString(string: inner, attributes: boldAttrs))
                    i = string.index(after: end)
                    continue
                } else {
                    result.append(NSAttributedString(string: "*", attributes: baseAttributes))
                    i = string.index(after: i)
                    continue
                }
            }
            var j = i
            while j < string.endIndex && string[j] != "*" {
                j = string.index(after: j)
            }
            let plain = String(string[i..<j])
            if !plain.isEmpty {
                result.append(NSAttributedString(string: plain, attributes: baseAttributes))
            }
            i = j
        }
        return result
    }

    private static func heightForAttributedString(_ attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(
            attributed.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
        )
    }

    private static func drawAttributedStringCenteredInRect(_ attributed: NSAttributedString, rect: CGRect) {
        let size = attributed.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        let h = ceil(size.height)
        let drawRect = CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
        attributed.draw(in: drawRect)
    }

    // MARK: - Narrative visuals (callouts, diagrams)

    private static func drawSectionTitleBar(
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        title: String,
        sectionTitleAttrs: [NSAttributedString.Key: Any]
    ) {
        let titleLineHeight: CGFloat = 24
        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: titleLineHeight + 12)
        let headerBg = CGRect(x: margin, y: y, width: contentWidth, height: titleLineHeight + 4)
        ctx.cgContext.setFillColor(PDFTheme.lightLavender.cgColor)
        ctx.cgContext.fill(headerBg)
        ctx.cgContext.setFillColor(PDFTheme.accentPurple.cgColor)
        ctx.cgContext.fill(CGRect(x: margin, y: y, width: 4, height: titleLineHeight + 4))
        var titleAttrs = sectionTitleAttrs
        let ps = NSMutableParagraphStyle()
        ps.alignment = .left
        titleAttrs[.paragraphStyle] = ps
        let titleAttr = attributedStringWithBoldAsterisks(title, baseAttributes: titleAttrs)
        titleAttr.draw(in: CGRect(x: margin + 12, y: y + 2, width: contentWidth - 16, height: titleLineHeight))
        y += titleLineHeight + 12
    }

    private static func drawCompactCallout(
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        text: String,
        attrs: [NSAttributedString.Key: Any]
    ) {
        let pad: CGFloat = 12
        var base = attrs
        if base[.paragraphStyle] == nil {
            let p = NSMutableParagraphStyle()
            p.alignment = .natural
            base[.paragraphStyle] = p
        }
        let attr = attributedStringWithBoldAsterisks(text, baseAttributes: base)
        let innerW = contentWidth - pad * 2
        let h = heightForAttributedString(attr, width: innerW) + pad * 2
        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 18)
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: h)
        ctx.cgContext.setFillColor(PDFTheme.lightLavender.cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        ctx.cgContext.addPath(path.cgPath)
        ctx.cgContext.fillPath()
        ctx.cgContext.setStrokeColor(PDFTheme.accentPurple.withAlphaComponent(0.28).cgColor)
        ctx.cgContext.setLineWidth(1)
        ctx.cgContext.addPath(path.cgPath)
        ctx.cgContext.strokePath()
        attr.draw(in: rect.insetBy(dx: pad, dy: pad))
        y += h + 14
    }

    private static func drawMultilineCallout(
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        text: String,
        bodyAttrs: [NSAttributedString.Key: Any]
    ) {
        let pad: CGFloat = 14
        var base = bodyAttrs
        if base[.paragraphStyle] == nil {
            let p = NSMutableParagraphStyle()
            p.alignment = .natural
            base[.paragraphStyle] = p
        }
        let attr = attributedStringWithBoldAsterisks(text, baseAttributes: base)
        let innerW = contentWidth - pad * 2
        let h = heightForAttributedString(attr, width: innerW) + pad * 2
        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 18)
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: h)
        ctx.cgContext.setFillColor(UIColor(red: 0.97, green: 0.95, blue: 1, alpha: 1).cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        ctx.cgContext.addPath(path.cgPath)
        ctx.cgContext.fillPath()
        ctx.cgContext.setStrokeColor(PDFTheme.accentPurple.withAlphaComponent(0.35).cgColor)
        ctx.cgContext.setLineWidth(1.5)
        ctx.cgContext.addPath(path.cgPath)
        ctx.cgContext.strokePath()
        attr.draw(in: rect.insetBy(dx: pad, dy: pad))
        y += h + 16
    }

    private static func drawRiskProfileDiagram(
        ctx: UIGraphicsPDFRendererContext,
        risk: RiskProfile,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        y: inout CGFloat,
        sectionTitleAttrs: [NSAttributedString.Key: Any],
        bodyAttrs: [NSAttributedString.Key: Any],
        captionAttrs: [NSAttributedString.Key: Any]
    ) {
        drawSectionTitleBar(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Risk profile",
            sectionTitleAttrs: sectionTitleAttrs
        )

        let tileH: CGFloat = 46
        let gap: CGFloat = 8
        let tileW = (contentWidth - gap) / 2
        let tiles: [(String, String)] = [
            ("Industry", risk.industry ?? "—"),
            ("SIC / class", risk.sicCode ?? "—"),
            ("Risk level", risk.riskLevel ?? "—"),
            ("Revenue exposure", risk.revenueExposure ?? "—"),
        ]
        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: tileH * 2 + gap + 24)
        let labelFont = captionAttrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 10)
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: PDFTheme.bodyText,
        ]
        for row in 0..<2 {
            for col in 0..<2 {
                let idx = row * 2 + col
                let x = margin + CGFloat(col) * (tileW + gap)
                let yy = y + CGFloat(row) * (tileH + gap)
                let rect = CGRect(x: x, y: yy, width: tileW, height: tileH)
                ctx.cgContext.setFillColor(PDFTheme.lightLavender.cgColor)
                ctx.cgContext.fill(rect)
                ctx.cgContext.setFillColor(PDFTheme.teal.cgColor)
                ctx.cgContext.fill(CGRect(x: x, y: yy, width: tileW, height: 4))
                let cap: [NSAttributedString.Key: Any] = [
                    .font: labelFont,
                    .foregroundColor: PDFTheme.muted,
                ]
                (tiles[idx].0 as NSString).draw(in: CGRect(x: x + 8, y: yy + 6, width: tileW - 16, height: 12), withAttributes: cap)
                var valBase = valueAttrs
                if valBase[.paragraphStyle] == nil {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .natural
                    valBase[.paragraphStyle] = p
                }
                let valAttr = attributedStringWithBoldAsterisks(tiles[idx].1, baseAttributes: valBase)
                valAttr.draw(in: CGRect(x: x + 8, y: yy + 20, width: tileW - 16, height: 24))
            }
        }
        y += CGFloat(2) * (tileH + gap) + 10

        let smallTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: PDFTheme.deepPurple,
        ]
        ("Exposure & requirements (diagram)" as NSString).draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
            withAttributes: smallTitle
        )
        y += 18

        drawTimelineBulletBlock(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Primary exposures",
            items: risk.primaryExposures,
            accent: PDFTheme.required,
            bodyAttrs: bodyAttrs
        )
        drawTimelineBulletBlock(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "State requirements",
            items: risk.stateRequirements,
            accent: PDFTheme.sky,
            bodyAttrs: bodyAttrs
        )
        drawTimelineBulletBlock(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Employee implications",
            items: risk.employeeImplications,
            accent: PDFTheme.teal,
            bodyAttrs: bodyAttrs
        )
        drawTimelineBulletBlock(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Unusual risks",
            items: risk.unusualRisks,
            accent: PDFTheme.projected,
            bodyAttrs: bodyAttrs
        )

        if let reasoning = risk.reasoningSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !reasoning.isEmpty {
            ("Underwriter reasoning" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                withAttributes: smallTitle
            )
            y += 16
            drawMultilineCallout(ctx: ctx, y: &y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight, text: reasoning, bodyAttrs: bodyAttrs)
        }
        y += 6
    }

    private static func drawTimelineBulletBlock(
        ctx: UIGraphicsPDFRendererContext,
        y: inout CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        title: String,
        items: [String]?,
        accent: UIColor,
        bodyAttrs: [NSAttributedString.Key: Any]
    ) {
        let cleaned = (items ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: accent,
        ]
        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 20)
        (title as NSString).draw(in: CGRect(x: margin + 14, y: y, width: contentWidth - 14, height: 12), withAttributes: titleAttrs)
        y += 14

        let lineX = margin + 6
        for item in cleaned {
            var body = bodyAttrs
            if body[.paragraphStyle] == nil {
                let p = NSMutableParagraphStyle()
                p.alignment = .natural
                body[.paragraphStyle] = p
            }
            let attr = attributedStringWithBoldAsterisks(item, baseAttributes: body)
            let h = heightForAttributedString(attr, width: contentWidth - 28)
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 14)
            ctx.cgContext.setFillColor(accent.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: lineX, y: y + 4, width: 8, height: 8))
            attr.draw(in: CGRect(x: margin + 22, y: y, width: contentWidth - 22, height: h + 4))
            y += h + 6
        }
        y += 12
    }

    private static func drawSubmissionPacketDiagram(
        ctx: UIGraphicsPDFRendererContext,
        packet: SubmissionPacket,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        y: inout CGFloat,
        sectionTitleAttrs: [NSAttributedString.Key: Any],
        bodyAttrs: [NSAttributedString.Key: Any],
        captionAttrs: [NSAttributedString.Key: Any]
    ) {
        drawSectionTitleBar(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Carrier submission packet",
            sectionTitleAttrs: sectionTitleAttrs
        )

        if let d = packet.submissionDate?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            drawCompactCallout(
                ctx: ctx,
                y: &y,
                margin: margin,
                contentWidth: contentWidth,
                pageHeight: pageHeight,
                text: "Submission date · \(d)",
                attrs: captionAttrs
            )
        }

        if let a = packet.applicant {
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 100)
            ("Applicant snapshot" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: PDFTheme.deepPurple,
                ]
            )
            y += 18
            let tw = (contentWidth - 16) / 3
            let th: CGFloat = 52
            let snap: [(String, String)] = [
                ("Legal name", a.legalName ?? "—"),
                ("Ops state", a.primaryStateOfOperations ?? a.stateOfIncorporation ?? "—"),
                ("Years in business", a.yearsInBusiness.map { String($0) } ?? "—"),
            ]
            for (i, pair) in snap.enumerated() {
                let x = margin + CGFloat(i) * (tw + 8)
                let rect = CGRect(x: x, y: y, width: tw, height: th)
                ctx.cgContext.setFillColor(PDFTheme.sky.withAlphaComponent(0.15).cgColor)
                ctx.cgContext.fill(rect)
                ctx.cgContext.setStrokeColor(PDFTheme.sky.withAlphaComponent(0.5).cgColor)
                ctx.cgContext.setLineWidth(1)
                ctx.cgContext.stroke(rect)
                (pair.0 as NSString).draw(
                    in: CGRect(x: x + 8, y: y + 6, width: tw - 16, height: 12),
                    withAttributes: captionAttrs
                )
                var valAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: PDFTheme.bodyText,
                ]
                let vp = NSMutableParagraphStyle()
                vp.alignment = .natural
                valAttrs[.paragraphStyle] = vp
                let valAttr = attributedStringWithBoldAsterisks(pair.1, baseAttributes: valAttrs)
                valAttr.draw(in: CGRect(x: x + 8, y: y + 22, width: tw - 16, height: 28))
            }
            y += th + 14
        }

        if let ops = packet.operations {
            if let emp = ops.employees {
                let ft = CGFloat(emp.fullTime ?? 0)
                let pt = CGFloat(emp.partTime ?? 0)
                let total = max(ft + pt, 1)
                ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 52)
                ("Workforce mix" as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: PDFTheme.deepPurple,
                    ]
                )
                y += 18
                let track = CGRect(x: margin, y: y, width: contentWidth, height: 18)
                ctx.cgContext.setFillColor(UIColor.systemGray5.cgColor)
                ctx.cgContext.fill(track)
                let fw = track.width * ft / total
                ctx.cgContext.setFillColor(PDFTheme.teal.cgColor)
                ctx.cgContext.fill(CGRect(x: track.minX, y: track.minY, width: fw, height: track.height))
                ctx.cgContext.setFillColor(PDFTheme.gold.cgColor)
                ctx.cgContext.fill(CGRect(x: track.minX + fw, y: track.minY, width: track.width - fw, height: track.height))
                let legend = "FT \(Int(ft))   ·   PT \(Int(pt))"
                (legend as NSString).draw(
                    in: CGRect(x: margin, y: y + 22, width: contentWidth, height: 12),
                    withAttributes: captionAttrs
                )
                y += 40
            }

            let rev = ops.revenue?.annual
            let pay = ops.payroll?.annual
            if rev != nil || pay != nil {
                ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 110)
                ("Revenue vs payroll" as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: PDFTheme.deepPurple,
                    ]
                )
                y += 18
                let maxVal = max(rev ?? 0, pay ?? 0, 1)
                let chartLeft = margin + 100
                let chartW = contentWidth - 100
                func drawBar(label: String, value: Double?, color: UIColor, offset: CGFloat) {
                    let v = value ?? 0
                    let frac = CGFloat(v / maxVal)
                    (label as NSString).draw(
                        in: CGRect(x: margin, y: y + offset, width: 90, height: 14),
                        withAttributes: captionAttrs
                    )
                    let track = CGRect(x: chartLeft, y: y + offset + 2, width: chartW, height: 16)
                    ctx.cgContext.setFillColor(UIColor.systemGray5.cgColor)
                    ctx.cgContext.fill(track)
                    ctx.cgContext.setFillColor(color.cgColor)
                    ctx.cgContext.fill(CGRect(x: track.minX, y: track.minY, width: max(4, track.width * frac), height: track.height))
                    let vs = v > 0 ? "$\(Int(v).formatted())" : "—"
                    (vs as NSString).draw(
                        in: CGRect(x: chartLeft + chartW + 8, y: y + offset, width: 80, height: 16),
                        withAttributes: bodyAttrs
                    )
                }
                drawBar(label: "Annual revenue", value: rev, color: PDFTheme.accentPurple, offset: 0)
                drawBar(label: "Annual payroll", value: pay, color: PDFTheme.teal, offset: 28)
                y += 64
            }

            if let desc = ops.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                drawMultilineCallout(ctx: ctx, y: &y, margin: margin, contentWidth: contentWidth, pageHeight: pageHeight, text: "Operations: \(desc)", bodyAttrs: bodyAttrs)
            }
        }

        if let cov = packet.requestedCoverages, !cov.isEmpty {
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 40)
            ("Requested coverages" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: PDFTheme.deepPurple,
                ]
            )
            y += 18
            for c in cov {
                let title = c.type ?? "Coverage"
                let sub = [c.limits, c.deductible, c.effectiveDate].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " · ")
                ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 44)
                let row = CGRect(x: margin, y: y, width: contentWidth, height: 40)
                ctx.cgContext.setFillColor(PDFTheme.lightLavender.cgColor)
                ctx.cgContext.fill(row)
                ctx.cgContext.setFillColor(PDFTheme.accentPurple.cgColor)
                ctx.cgContext.fill(CGRect(x: margin, y: y, width: 4, height: 40))
                var titleBase: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: PDFTheme.bodyText,
                ]
                let tp = NSMutableParagraphStyle()
                tp.alignment = .natural
                titleBase[.paragraphStyle] = tp
                let titleAttr = attributedStringWithBoldAsterisks(title, baseAttributes: titleBase)
                titleAttr.draw(in: CGRect(x: margin + 12, y: y + 6, width: contentWidth - 16, height: 16))
                if !sub.isEmpty {
                    var cap = captionAttrs
                    if cap[.paragraphStyle] == nil {
                        let p = NSMutableParagraphStyle()
                        p.alignment = .natural
                        cap[.paragraphStyle] = p
                    }
                    let subAttr = attributedStringWithBoldAsterisks(sub, baseAttributes: cap)
                    subAttr.draw(in: CGRect(x: margin + 12, y: y + 22, width: contentWidth - 16, height: 14))
                }
                y += 46
            }
        }

        if let losses = packet.lossHistory, !losses.isEmpty {
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: 36)
            ("Loss history (timeline)" as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 14),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: PDFTheme.deepPurple,
                ]
            )
            y += 18
            for loss in losses {
                var parts: [String] = []
                if let yr = loss.year { parts.append(String(yr)) }
                if let t = loss.type?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { parts.append(t) }
                if let amt = loss.amount { parts.append("$\(Int(amt).formatted())") }
                let head = parts.joined(separator: " · ")
                let line = loss.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let text = line.isEmpty ? head : "\(head)\n\(line)"
                var b = bodyAttrs
                if b[.paragraphStyle] == nil {
                    let p = NSMutableParagraphStyle()
                    p.alignment = .natural
                    b[.paragraphStyle] = p
                }
                let lossAttr = attributedStringWithBoldAsterisks(text, baseAttributes: b)
                let h = heightForAttributedString(lossAttr, width: contentWidth - 20)
                ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 12)
                ctx.cgContext.setFillColor(PDFTheme.required.withAlphaComponent(0.85).cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(x: margin + 4, y: y + 4, width: 8, height: 8))
                lossAttr.draw(in: CGRect(x: margin + 20, y: y, width: contentWidth - 20, height: h + 4))
                y += h + 10
            }
        }

        if let notes = packet.underwriterNotes {
            let cleaned = notes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !cleaned.isEmpty {
                drawSectionTitleBar(
                    ctx: ctx,
                    y: &y,
                    margin: margin,
                    contentWidth: contentWidth,
                    pageHeight: pageHeight,
                    title: "Underwriter notes",
                    sectionTitleAttrs: sectionTitleAttrs
                )
                for (i, note) in cleaned.enumerated() {
                    drawCompactCallout(
                        ctx: ctx,
                        y: &y,
                        margin: margin,
                        contentWidth: contentWidth,
                        pageHeight: pageHeight,
                        text: "\(i + 1). \(note)",
                        attrs: bodyAttrs
                    )
                }
            }
        }
        y += 4
    }

    private static func drawLinksDiagram(
        ctx: UIGraphicsPDFRendererContext,
        results: ResultsResponse,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        y: inout CGFloat,
        sectionTitleAttrs: [NSAttributedString.Key: Any],
        bodyAttrs: [NSAttributedString.Key: Any]
    ) {
        var lines: [String] = []
        let su = results.submissionPacketUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let vu = results.voiceSummaryUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !su.isEmpty { lines.append(su) }
        if !vu.isEmpty { lines.append(vu) }
        guard !lines.isEmpty else { return }

        drawSectionTitleBar(
            ctx: ctx,
            y: &y,
            margin: margin,
            contentWidth: contentWidth,
            pageHeight: pageHeight,
            title: "Links & assets",
            sectionTitleAttrs: sectionTitleAttrs
        )

        for url in lines {
            let h: CGFloat = 36
            ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: h + 8)
            let row = CGRect(x: margin, y: y, width: contentWidth, height: h)
            ctx.cgContext.setFillColor(PDFTheme.sky.withAlphaComponent(0.12).cgColor)
            ctx.cgContext.fill(row)
            drawChainLinkIcon(ctx: ctx.cgContext, in: CGRect(x: margin + 10, y: y + 8, width: 18, height: 18), color: PDFTheme.sky)
            let display = url.count > 70 ? String(url.prefix(67)) + "…" : url
            var linkBase = bodyAttrs
            if linkBase[.paragraphStyle] == nil {
                let p = NSMutableParagraphStyle()
                p.alignment = .natural
                linkBase[.paragraphStyle] = p
            }
            let linkAttr = attributedStringWithBoldAsterisks(display, baseAttributes: linkBase)
            linkAttr.draw(in: CGRect(x: margin + 34, y: y + 10, width: contentWidth - 40, height: 22))
            y += h + 6
        }
        y += 8
    }

    private static func drawChainLinkIcon(ctx: CGContext, in rect: CGRect, color: UIColor) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2)
        let w = rect.width
        let h = rect.height
        let cy = rect.midY
        ctx.addEllipse(in: CGRect(x: rect.minX + w * 0.05, y: cy - h * 0.25, width: w * 0.45, height: h * 0.5))
        ctx.addEllipse(in: CGRect(x: rect.minX + w * 0.5, y: cy - h * 0.25, width: w * 0.45, height: h * 0.5))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawCoverageLineCard(
        ctx: UIGraphicsPDFRendererContext,
        option: CoverageOption,
        margin: CGFloat,
        contentWidth: CGFloat,
        pageHeight: CGFloat,
        y: inout CGFloat,
        globalMinPremium: Double,
        globalMaxPremium: Double,
        sectionTitleAttrs: [NSAttributedString.Key: Any],
        bodyAttrs: [NSAttributedString.Key: Any],
        boldBody: [NSAttributedString.Key: Any]
    ) {
        let innerPad: CGFloat = 12
        let stripeColor = categoryUIColor(option.category)
        let diagRowH: CGFloat = 40
        let textW = contentWidth - innerPad * 2 - 8
        var bodyPara = bodyAttrs
        if bodyPara[.paragraphStyle] == nil {
            let p = NSMutableParagraphStyle()
            p.alignment = .natural
            bodyPara[.paragraphStyle] = p
        }
        let descAttr = attributedStringWithBoldAsterisks(option.description, baseAttributes: bodyPara)
        let descHeight = heightForAttributedString(descAttr, width: textW)

        var titlePara = sectionTitleAttrs
        if titlePara[.paragraphStyle] == nil {
            let p = NSMutableParagraphStyle()
            p.alignment = .natural
            titlePara[.paragraphStyle] = p
        }
        let typeAttr = attributedStringWithBoldAsterisks(option.type, baseAttributes: titlePara)
        let typeH = heightForAttributedString(typeAttr, width: textW)

        var triggerAttr: NSAttributedString?
        if let trigger = option.triggerEvent {
            var triggerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: PDFTheme.accentPurple,
            ]
            let p = NSMutableParagraphStyle()
            p.alignment = .natural
            triggerAttrs[.paragraphStyle] = p
            triggerAttr = attributedStringWithBoldAsterisks(trigger, baseAttributes: triggerAttrs)
        }
        let triggerExtra: CGFloat = {
            guard let t = triggerAttr else { return 0 }
            return heightForAttributedString(t, width: textW) + 8
        }()

        var blockH: CGFloat = innerPad + 16 + typeH + 6 + diagRowH + 8 + descHeight + 8 + 16 + triggerExtra + innerPad * 0.5

        ensureSpace(ctx: ctx, y: &y, margin: margin, pageHeight: pageHeight, needed: blockH + 16)

        let cardRect = CGRect(x: margin, y: y, width: contentWidth, height: blockH)
        ctx.cgContext.setFillColor(PDFTheme.lightLavender.withAlphaComponent(0.65).cgColor)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 12)
        ctx.cgContext.addPath(cardPath.cgPath)
        ctx.cgContext.fillPath()
        ctx.cgContext.setStrokeColor(stripeColor.withAlphaComponent(0.5).cgColor)
        ctx.cgContext.setLineWidth(2)
        ctx.cgContext.addPath(cardPath.cgPath)
        ctx.cgContext.strokePath()

        ctx.cgContext.setFillColor(stripeColor.cgColor)
        ctx.cgContext.fill(CGRect(x: margin, y: y, width: 5, height: blockH))

        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: stripeColor,
        ]
        var cy = y + innerPad
        (categoryLabel(option.category).uppercased() as NSString).draw(at: CGPoint(x: margin + 12, y: cy), withAttributes: badgeAttrs)
        cy += 16
        typeAttr.draw(in: CGRect(x: margin + 12, y: cy, width: textW, height: typeH))
        cy += typeH + 6

        let colW = (contentWidth - 24) / 2
        drawConfidenceMiniDiagram(
            ctx: ctx.cgContext,
            frame: CGRect(x: margin + 12, y: cy, width: colW - 6, height: diagRowH),
            confidence: option.confidence
        )
        drawPremiumSpanMiniDiagram(
            ctx: ctx.cgContext,
            frame: CGRect(x: margin + 12 + colW, y: cy, width: colW - 6, height: diagRowH),
            low: option.estimatedPremiumLow,
            high: option.estimatedPremiumHigh,
            globalMin: globalMinPremium,
            globalMax: globalMaxPremium,
            tint: stripeColor
        )
        cy += diagRowH + 8

        descAttr.draw(in: CGRect(x: margin + 12, y: cy, width: textW, height: descHeight + 4))
        cy += descHeight + 8

        let premiumLine = "$\(Int(option.estimatedPremiumLow).formatted()) – $\(Int(option.estimatedPremiumHigh).formatted()) / yr (annual band)"
        (premiumLine as NSString).draw(
            in: CGRect(x: margin + 12, y: cy, width: textW, height: 16),
            withAttributes: boldBody
        )
        cy += 18

        if let trigAttr = triggerAttr {
            let th = heightForAttributedString(trigAttr, width: textW)
            trigAttr.draw(in: CGRect(x: margin + 12, y: cy, width: textW, height: max(th, 14)))
        }

        y += blockH + 12
    }

    private static func drawConfidenceMiniDiagram(ctx: CGContext, frame: CGRect, confidence: Double) {
        let label: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: PDFTheme.muted,
        ]
        ("Model confidence" as NSString).draw(in: CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 10), withAttributes: label)
        let track = CGRect(x: frame.minX, y: frame.minY + 14, width: frame.width, height: 12)
        ctx.setFillColor(UIColor.systemGray5.cgColor)
        ctx.fill(track)
        ctx.setFillColor(PDFTheme.teal.cgColor)
        ctx.fill(CGRect(x: track.minX, y: track.minY, width: max(4, track.width * CGFloat(confidence)), height: track.height))
        let pct = "\(Int(confidence * 100))%"
        (pct as NSString).draw(
            in: CGRect(x: frame.minX, y: frame.minY + 28, width: frame.width, height: 12),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: PDFTheme.deepPurple,
            ]
        )
    }

    private static func drawPremiumSpanMiniDiagram(
        ctx: CGContext,
        frame: CGRect,
        low: Double,
        high: Double,
        globalMin: Double,
        globalMax: Double,
        tint: UIColor
    ) {
        let label: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: PDFTheme.muted,
        ]
        ("Premium vs portfolio" as NSString).draw(in: CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 10), withAttributes: label)
        let track = CGRect(x: frame.minX, y: frame.minY + 14, width: frame.width, height: 12)
        ctx.setFillColor(UIColor.systemGray5.cgColor)
        ctx.fill(track)
        let span = max(globalMax - globalMin, 1)
        let x1 = track.minX + CGFloat((low - globalMin) / span) * track.width
        let x2 = track.minX + CGFloat((high - globalMin) / span) * track.width
        let left = min(x1, x2)
        let right = max(x1, x2)
        ctx.setFillColor(tint.withAlphaComponent(0.35).cgColor)
        ctx.fill(CGRect(x: left, y: track.minY, width: max(4, right - left), height: track.height))
        ctx.setStrokeColor(tint.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: left, y: track.minY - 2))
        ctx.addLine(to: CGPoint(x: left, y: track.maxY + 2))
        ctx.move(to: CGPoint(x: right, y: track.minY - 2))
        ctx.addLine(to: CGPoint(x: right, y: track.maxY + 2))
        ctx.strokePath()
    }

    // MARK: - Sections & layout

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

    private static func drawDivider(ctx: CGContext, y: CGFloat, margin: CGFloat, width: CGFloat, color: UIColor = UIColor.separator) -> CGFloat {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: margin, y: y))
        ctx.addLine(to: CGPoint(x: margin + width, y: y))
        ctx.strokePath()
        return y + 14
    }

    private static func categoryUIColor(_ cat: CoverageCategory) -> UIColor {
        switch cat {
        case .required: return PDFTheme.required
        case .recommended: return PDFTheme.recommended
        case .projected: return PDFTheme.projected
        }
    }

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
