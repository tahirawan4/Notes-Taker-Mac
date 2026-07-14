import AppKit
import Foundation

enum PDFExportKind {
    case notes
    case transcript
}

enum PDFExporter {
    @MainActor
    static func export(meeting: Meeting, kind: PDFExportKind) throws -> URL {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(meeting.title) - \(kind == .notes ? "Notes" : "Transcript").pdf"

        guard panel.runModal() == .OK, let url = panel.url else {
            throw CancellationError()
        }

        try render(meeting: meeting, kind: kind, to: url)
        return url
    }

    static func render(meeting: Meeting, kind: PDFExportKind, to url: URL) throws {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var cursor = PDFCursor(context: context, page: page)
        cursor.beginPage()
        drawHeader(meeting: meeting, kind: kind, cursor: &cursor)

        switch kind {
        case .notes:
            drawNotes(meeting: meeting, cursor: &cursor)
        case .transcript:
            drawTranscript(meeting: meeting, cursor: &cursor)
        }

        cursor.endDocument()
    }

    private static func drawHeader(meeting: Meeting, kind: PDFExportKind, cursor: inout PDFCursor) {
        cursor.fillPageBackground()
        cursor.drawPill(kind == .notes ? "MEETING NOTES" : "FULL TRANSCRIPT", color: .indigo)
        cursor.drawText(meeting.title, size: 28, weight: .bold, color: .navy, spacingAfter: 8)
        let subtitle = "\(meeting.source.rawValue) | \(meeting.startedAt.formatted(date: .abbreviated, time: .shortened)) | \(formatDuration(meeting.duration))"
        cursor.drawText(subtitle, size: 11, weight: .medium, color: .muted, spacingAfter: 22)
        cursor.drawRule(color: .teal)
    }

    private static func drawNotes(meeting: Meeting, cursor: inout PDFCursor) {
        cursor.drawSection("Executive Summary", items: meeting.summary, accent: .teal)
        cursor.drawSection("Decisions", items: meeting.decisions, accent: .indigo)
        cursor.drawSection("Risks & Blockers", items: meeting.risks, accent: .coral)
        cursor.drawSection("Open Questions", items: meeting.openQuestions, accent: .amber)
        cursor.drawActionItems(meeting.actionItems)
    }

    private static func drawTranscript(meeting: Meeting, cursor: inout PDFCursor) {
        cursor.drawText("Transcript", size: 18, weight: .bold, color: .navy, spacingAfter: 12)
        for segment in meeting.transcript {
            cursor.ensureSpace(78)
            cursor.drawTranscriptSegment(segment)
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        let hours = minutes / 60
        let remaining = minutes % 60
        return hours > 0 ? "\(hours)h \(remaining)m" : "\(minutes)m"
    }
}

private struct PDFCursor {
    let context: CGContext
    let page: CGRect
    var y: CGFloat = 0

    mutating func beginPage() {
        context.beginPDFPage(nil)
        y = page.height - 54
        fillPageBackground()
    }

    mutating func endPage() {
        context.endPDFPage()
    }

    mutating func endDocument() {
        endPage()
        context.closePDF()
    }

    mutating func newPage() {
        endPage()
        beginPage()
    }

    func fillPageBackground() {
        NSColor.paper.setFill()
        context.fill(page)
    }

    mutating func ensureSpace(_ height: CGFloat) {
        if y - height < 54 {
            newPage()
        }
    }

    mutating func drawPill(_ text: String, color: NSColor) {
        let attributes = textAttributes(size: 8, weight: .bold, color: .white)
        let textSize = text.size(withAttributes: attributes)
        let rect = CGRect(x: 54, y: y - 18, width: textSize.width + 20, height: 20)
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        text.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5), withAttributes: attributes)
        y -= 34
    }

    mutating func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, spacingAfter: CGFloat) {
        let rect = CGRect(x: 54, y: 0, width: page.width - 108, height: 10_000)
        let attributes = paragraphAttributes(size: size, weight: weight, color: color, lineSpacing: 4)
        let height = text.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).height
        ensureSpace(height + spacingAfter)
        text.draw(in: CGRect(x: rect.minX, y: y - height, width: rect.width, height: height), withAttributes: attributes)
        y -= height + spacingAfter
    }

    mutating func drawRule(color: NSColor) {
        color.setFill()
        context.fill(CGRect(x: 54, y: y - 2, width: page.width - 108, height: 2))
        y -= 26
    }

    mutating func drawSection(_ title: String, items: [String], accent: NSColor) {
        guard !items.isEmpty else { return }
        ensureSpace(110)
        drawText(title, size: 16, weight: .bold, color: .navy, spacingAfter: 10)
        for item in items {
            drawCard(text: item, accent: accent)
        }
        y -= 10
    }

    mutating func drawCard(text: String, accent: NSColor) {
        let attributes = paragraphAttributes(size: 10.5, weight: .regular, color: .navy, lineSpacing: 3)
        let width = page.width - 108
        let textHeight = text.boundingRect(with: CGSize(width: width - 34, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).height
        let height = max(44, textHeight + 24)
        ensureSpace(height + 8)

        let rect = CGRect(x: 54, y: y - height, width: width, height: height)
        NSColor.white.withAlphaComponent(0.86).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        accent.setFill()
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: 4, height: rect.height))
        text.draw(in: CGRect(x: rect.minX + 18, y: rect.minY + 12, width: rect.width - 34, height: textHeight), withAttributes: attributes)
        y -= height + 8
    }

    mutating func drawActionItems(_ items: [MeetingActionItem]) {
        guard !items.isEmpty else { return }
        ensureSpace(140)
        drawText("Action Items", size: 16, weight: .bold, color: .navy, spacingAfter: 12)

        let header = CGRect(x: 54, y: y - 28, width: page.width - 108, height: 28)
        NSColor.navy.setFill()
        NSBezierPath(roundedRect: header, xRadius: 7, yRadius: 7).fill()
        drawTableRow(["Owner", "Action", "Priority", "Status"], in: header, color: .white, bold: true)
        y -= 28

        for item in items {
            ensureSpace(52)
            let rect = CGRect(x: 54, y: y - 48, width: page.width - 108, height: 48)
            NSColor.white.withAlphaComponent(0.9).setFill()
            NSBezierPath(rect: rect).fill()
            drawTableRow([item.owner, item.task, item.priority.rawValue, item.status.rawValue], in: rect, color: .navy, bold: false)
            y -= 48
        }
        y -= 12
    }

    mutating func drawTranscriptSegment(_ segment: TranscriptSegment) {
        let rect = CGRect(x: 54, y: y - 68, width: page.width - 108, height: 68)
        NSColor.white.withAlphaComponent(0.86).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

        let time = formatTimestamp(segment.startTime)
        time.draw(in: CGRect(x: rect.minX + 14, y: rect.minY + 36, width: 58, height: 16), withAttributes: textAttributes(size: 9, weight: .bold, color: .teal))
        segment.speaker.draw(in: CGRect(x: rect.minX + 84, y: rect.minY + 38, width: rect.width - 98, height: 16), withAttributes: textAttributes(size: 10, weight: .bold, color: .navy))
        segment.text.draw(in: CGRect(x: rect.minX + 84, y: rect.minY + 14, width: rect.width - 98, height: 32), withAttributes: paragraphAttributes(size: 9.5, weight: .regular, color: .navy, lineSpacing: 2))
        y -= 76
    }

    private func drawTableRow(_ values: [String], in rect: CGRect, color: NSColor, bold: Bool) {
        let widths: [CGFloat] = [90, rect.width - 260, 78, 78]
        var x = rect.minX + 12
        for (index, value) in values.enumerated() {
            let columnWidth = widths[index]
            let drawRect = CGRect(x: x, y: rect.minY + 11, width: columnWidth - 10, height: rect.height - 16)
            value.draw(in: drawRect, withAttributes: paragraphAttributes(size: 9, weight: bold ? .bold : .regular, color: color, lineSpacing: 2))
            x += columnWidth
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func textAttributes(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
    }

    private func paragraphAttributes(size: CGFloat, weight: NSFont.Weight, color: NSColor, lineSpacing: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        return [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }
}

private extension NSColor {
    static let paper = NSColor(calibratedRed: 0.965, green: 0.957, blue: 0.933, alpha: 1)
    static let navy = NSColor(calibratedRed: 0.055, green: 0.098, blue: 0.176, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.376, green: 0.427, blue: 0.506, alpha: 1)
    static let teal = NSColor(calibratedRed: 0.055, green: 0.58, blue: 0.55, alpha: 1)
    static let indigo = NSColor(calibratedRed: 0.306, green: 0.275, blue: 0.776, alpha: 1)
    static let coral = NSColor(calibratedRed: 0.875, green: 0.302, blue: 0.267, alpha: 1)
    static let amber = NSColor(calibratedRed: 0.82, green: 0.529, blue: 0.075, alpha: 1)
}
