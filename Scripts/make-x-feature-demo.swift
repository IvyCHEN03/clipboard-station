#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreVideo
import Foundation

private let size = CGSize(width: 1280, height: 720)
private let fps: Int32 = 30
private let duration: Double = 44
private let totalFrames = Int(duration * Double(fps))

private let ink = NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.19, alpha: 1)
private let muted = NSColor(calibratedRed: 0.37, green: 0.44, blue: 0.53, alpha: 1)
private let blue = NSColor(calibratedRed: 0.40, green: 0.75, blue: 0.98, alpha: 1)
private let blueDark = NSColor(calibratedRed: 0.08, green: 0.43, blue: 0.72, alpha: 1)
private let canvas = NSColor(calibratedRed: 0.96, green: 0.985, blue: 1, alpha: 1)
private let border = NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.96, alpha: 1)
private let green = NSColor(calibratedRed: 0.17, green: 0.69, blue: 0.40, alpha: 1)
private let orange = NSColor(calibratedRed: 0.94, green: 0.55, blue: 0.13, alpha: 1)

private func clamp(_ value: Double, _ low: Double = 0, _ high: Double = 1) -> Double {
    min(max(value, low), high)
}

private func ease(_ value: Double) -> Double {
    let x = clamp(value)
    return x * x * (3 - 2 * x)
}

private func point(_ start: CGPoint, _ end: CGPoint, _ progress: Double) -> CGPoint {
    let p = CGFloat(ease(progress))
    return CGPoint(x: start.x + (end.x - start.x) * p, y: start.y + (end.y - start.y) * p)
}

private func alpha(time: Double, start: Double, end: Double, fade: Double = 0.45) -> CGFloat {
    CGFloat(min(ease((time - start) / fade), ease((end - time) / fade)))
}

private func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func outline(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat = 1.5, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

private func label(
    _ value: String,
    x: CGFloat,
    y: CGFloat,
    width: CGFloat? = nil,
    size fontSize: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    alpha: CGFloat = 1,
    alignment: NSTextAlignment = .left
) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color.withAlphaComponent(alpha),
        .paragraphStyle: style,
    ]
    let string = NSAttributedString(string: value, attributes: attributes)
    if let width {
        string.draw(in: CGRect(x: x, y: y, width: width, height: fontSize * 1.8))
    } else {
        string.draw(at: CGPoint(x: x, y: y))
    }
}

private func bubble(center: CGPoint, radius: CGFloat, alpha: CGFloat = 1) {
    blue.withAlphaComponent(alpha).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    NSColor.white.withAlphaComponent(alpha).setFill()
    let star = NSBezierPath()
    star.move(to: CGPoint(x: center.x, y: center.y - radius * 0.48))
    star.line(to: CGPoint(x: center.x + radius * 0.16, y: center.y - radius * 0.16))
    star.line(to: CGPoint(x: center.x + radius * 0.50, y: center.y))
    star.line(to: CGPoint(x: center.x + radius * 0.16, y: center.y + radius * 0.16))
    star.line(to: CGPoint(x: center.x, y: center.y + radius * 0.50))
    star.line(to: CGPoint(x: center.x - radius * 0.16, y: center.y + radius * 0.16))
    star.line(to: CGPoint(x: center.x - radius * 0.50, y: center.y))
    star.line(to: CGPoint(x: center.x - radius * 0.16, y: center.y - radius * 0.16))
    star.close()
    star.fill()
}

private func cursor(at location: CGPoint, alpha: CGFloat = 1, down: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: location.x, yBy: location.y)
    transform.scale(by: down ? 0.88 : 1)
    transform.concat()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha * 0.22)
    shadow.shadowBlurRadius = 6
    shadow.shadowOffset = CGSize(width: 2, height: 3)
    shadow.set()

    let shape = NSBezierPath()
    shape.move(to: .zero)
    shape.line(to: CGPoint(x: 0, y: 31))
    shape.line(to: CGPoint(x: 8, y: 23))
    shape.line(to: CGPoint(x: 15, y: 38))
    shape.line(to: CGPoint(x: 22, y: 35))
    shape.line(to: CGPoint(x: 15, y: 21))
    shape.line(to: CGPoint(x: 27, y: 20))
    shape.close()
    NSColor.white.withAlphaComponent(alpha).setFill()
    shape.fill()
    ink.withAlphaComponent(alpha).setStroke()
    shape.lineWidth = 2.2
    shape.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

private func clickRing(at location: CGPoint, time: Double, event: Double, color: NSColor = blue, alpha: CGFloat = 1) {
    let age = time - event
    guard age >= 0, age <= 0.5 else { return }
    let p = CGFloat(age / 0.5)
    let radius = 12 + p * 28
    color.withAlphaComponent(alpha * (1 - p) * 0.8).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: location.x - radius, y: location.y - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 4 - p * 2
    ring.stroke()
}

private func sectionPill(_ value: String, x: CGFloat, y: CGFloat, color: NSColor, alpha: CGFloat) {
    rounded(CGRect(x: x, y: y, width: 178, height: 36), radius: 18, color: color, alpha: alpha * 0.14)
    label(value, x: x, y: y + 9, width: 178, size: 13, weight: .bold, color: color, alpha: alpha, alignment: .center)
}

private func filterChip(_ value: String, rect: CGRect, active: Bool, color: NSColor, alpha: CGFloat) {
    rounded(rect, radius: rect.height / 2, color: active ? color : NSColor.white, alpha: alpha)
    outline(rect, radius: rect.height / 2, color: active ? color : border, width: 1.5, alpha: alpha)
    label(value, x: rect.minX, y: rect.minY + 9, width: rect.width, size: 14, weight: .semibold, color: active ? NSColor.white : muted, alpha: alpha, alignment: .center)
}

private struct SnippetStyle {
    let number: String
    let title: String
    let detail: String
    let color: NSColor
    let tag: String
}

private let snippets = [
    SnippetStyle(number: "1", title: "Compare model answers", detail: "Captured from ChatGPT and Claude", color: blue, tag: "AI"),
    SnippetStyle(number: "2", title: "Spreadsheet evidence", detail: "Three rows copied as table text", color: NSColor(calibratedRed: 0.42, green: 0.84, blue: 0.66, alpha: 1), tag: "TABLE"),
    SnippetStyle(number: "3", title: "Pricing insight", detail: "Screenshot note with a useful quote", color: NSColor(calibratedRed: 1, green: 0.67, blue: 0.44, alpha: 1), tag: "AI"),
]

private func snippetCard(_ snippet: SnippetStyle, rect: CGRect, alpha: CGFloat, selected: Bool = false) {
    rounded(rect, radius: 12, color: selected ? NSColor(calibratedRed: 0.93, green: 0.98, blue: 1, alpha: 1) : .white, alpha: alpha)
    outline(rect, radius: 12, color: selected ? blue : border, width: selected ? 2.4 : 1.3, alpha: alpha)
    rounded(CGRect(x: rect.minX + 14, y: rect.minY + 13, width: 38, height: 38), radius: 11, color: snippet.color, alpha: alpha)
    label(snippet.number, x: rect.minX + 14, y: rect.minY + 22, width: 38, size: 15, weight: .bold, color: .white, alpha: alpha, alignment: .center)
    label(snippet.title, x: rect.minX + 66, y: rect.minY + 11, width: rect.width - 180, size: 16, weight: .bold, color: ink, alpha: alpha)
    label(snippet.detail, x: rect.minX + 66, y: rect.minY + 34, width: rect.width - 180, size: 12, weight: .medium, color: muted, alpha: alpha)
    rounded(CGRect(x: rect.maxX - 92, y: rect.minY + 19, width: 70, height: 28), radius: 14, color: snippet.color, alpha: alpha * 0.18)
    label(snippet.tag, x: rect.maxX - 92, y: rect.minY + 26, width: 70, size: 11, weight: .bold, color: snippet.color, alpha: alpha, alignment: .center)
    if snippet.number == "1" {
        label("★", x: rect.maxX - 122, y: rect.minY + 20, width: 24, size: 18, weight: .bold, color: orange, alpha: alpha, alignment: .center)
    }
}

private func dragBlock(_ snippet: SnippetStyle, center: CGPoint, alpha: CGFloat) {
    rounded(CGRect(x: center.x - 104, y: center.y - 25, width: 208, height: 50), radius: 13, color: snippet.color, alpha: alpha * 0.94)
    label("\(snippet.number)  \(snippet.title)", x: center.x - 104, y: center.y - 15, width: 208, size: 13, weight: .bold, color: .white, alpha: alpha, alignment: .center)
}

private func drawIntro(time: Double) {
    let a = alpha(time: time, start: 0, end: 2.0, fade: 0.5)
    guard a > 0 else { return }
    bubble(center: CGPoint(x: 640, y: 185), radius: 50, alpha: a)
    label("灵感不该被下一次复制覆盖。", x: 180, y: 276, width: 920, size: 43, weight: .bold, color: ink, alpha: a, alignment: .center)
    label("收集、找回、组合，再把它变成真正可用的表达。", x: 190, y: 340, width: 900, size: 24, weight: .medium, color: muted, alpha: a, alignment: .center)
    sectionPill("完整工作流", x: 551, y: 410, color: blueDark, alpha: a)
}

private func stationCursor(time: Double) -> (CGPoint, Bool, CGFloat) {
    let ai = CGPoint(x: 980, y: 188)
    let search = CGPoint(x: 460, y: 188)
    let clear = CGPoint(x: 787, y: 188)
    let card1 = CGPoint(x: 470, y: 279)
    let card2 = CGPoint(x: 470, y: 354)
    let composer1 = CGPoint(x: 992, y: 342)
    let composer2 = CGPoint(x: 992, y: 462)
    let gap = CGPoint(x: 992, y: 402)
    let copy = CGPoint(x: 992, y: 526)

    if time < 2.3 { return (CGPoint(x: 1160, y: 110), false, 0) }
    if time < 3.15 { return (point(CGPoint(x: 1160, y: 110), ai, (time - 2.3) / 0.85), false, 1) }
    if time < 3.45 { return (ai, true, 1) }
    if time < 4.6 { return (point(ai, search, (time - 3.45) / 1.15), false, 1) }
    if time < 6.75 { return (search, time < 4.9, 1) }
    if time < 7.15 { return (point(search, clear, (time - 6.75) / 0.4), false, 1) }
    if time < 7.45 { return (clear, true, 1) }
    if time < 7.95 { return (point(clear, ai, (time - 7.45) / 0.5), false, 1) }
    if time < 8.25 { return (ai, true, 1) }
    if time < 8.7 { return (point(ai, card1, (time - 8.25) / 0.45), false, 1) }
    if time < 10.15 { return (point(card1, composer1, (time - 8.7) / 1.45), true, 1) }
    if time < 10.65 { return (point(composer1, card2, (time - 10.15) / 0.5), false, 1) }
    if time < 12.15 { return (point(card2, composer2, (time - 10.65) / 1.5), true, 1) }
    if time < 12.8 { return (point(composer2, gap, (time - 12.15) / 0.65), false, 1) }
    if time < 14.45 { return (gap, time < 13.05, 1) }
    if time < 15.2 { return (point(gap, copy, (time - 14.45) / 0.75), false, 1) }
    return (copy, time < 15.5, 1)
}

private func drawStation(time: Double) {
    let a = alpha(time: time, start: 1.35, end: 17.25, fade: 0.6)
    guard a > 0 else { return }

    rounded(CGRect(origin: .zero, size: size), radius: 0, color: canvas, alpha: a)
    let phase = time < 8.45 ? "1 / 4   收藏 + 搜索" : "2 / 4   组合 + POLISH"
    sectionPill(phase, x: 64, y: 24, color: time < 8.45 ? blueDark : green, alpha: a)
    label(time < 8.45 ? "重要的留下，想找的立刻回来。" : "把零散积木变成一段连贯文字。", x: 266, y: 30, width: 780, size: 21, weight: .bold, color: ink, alpha: a)

    let panel = CGRect(x: 64, y: 76, width: 1152, height: 606)
    rounded(panel.offsetBy(dx: 0, dy: 7), radius: 24, color: .black, alpha: a * 0.08)
    rounded(panel, radius: 24, color: .white, alpha: a)
    outline(panel, radius: 24, color: border, width: 2, alpha: a)

    bubble(center: CGPoint(x: 112, y: 116), radius: 25, alpha: a)
    label("灵感悬浮球", x: 153, y: 95, width: 430, size: 24, weight: .bold, color: ink, alpha: a)
    label("本地优先的灵感工作记忆", x: 153, y: 125, width: 360, size: 13, weight: .medium, color: muted, alpha: a)
    label("3 个片段", x: 1052, y: 108, width: 104, size: 13, weight: .semibold, color: muted, alpha: a, alignment: .right)

    let searchRect = CGRect(x: 96, y: 162, width: 710, height: 50)
    rounded(searchRect, radius: 14, color: NSColor(calibratedWhite: 0.98, alpha: 1), alpha: a)
    outline(searchRect, radius: 14, color: border, width: 1.4, alpha: a)
    let searchOn = time >= 4.75 && time < 7.28
    let letters = Array("pricing")
    let count = Int(clamp((time - 4.95) / 0.19, 0, Double(letters.count)))
    let query = searchOn ? String(letters.prefix(count)) : ""
    label(query.isEmpty ? "搜索标题、正文、来源或标签" : query, x: 134, y: 176, width: 610, size: 16, weight: query.isEmpty ? .regular : .semibold, color: query.isEmpty ? NSColor(calibratedWhite: 0.62, alpha: 1) : ink, alpha: a)
    NSColor(calibratedWhite: 0.55, alpha: a).setStroke()
    let magnifier = NSBezierPath(ovalIn: CGRect(x: 111, y: 176, width: 17, height: 17))
    magnifier.lineWidth = 2
    magnifier.stroke()
    if !query.isEmpty {
        label("×", x: 765, y: 169, width: 28, size: 24, weight: .medium, color: muted, alpha: a, alignment: .center)
    }

    let filterOn = time >= 3.25 && time < 8.1
    filterChip("今天", rect: CGRect(x: 834, y: 169, width: 92, height: 38), active: false, color: blueDark, alpha: a)
    filterChip("收藏", rect: CGRect(x: 938, y: 169, width: 82, height: 38), active: filterOn, color: orange, alpha: a)
    filterChip("日期", rect: CGRect(x: 1032, y: 169, width: 118, height: 38), active: false, color: blueDark, alpha: a)

    let listTop: CGFloat = 235
    let cardRect = CGRect(x: 96, y: listTop, width: 710, height: 64)
    if !query.isEmpty {
        let result = SnippetStyle(number: "3", title: "Pricing insight", detail: "Matched “pricing” in screenshot text", color: NSColor(calibratedRed: 1, green: 0.67, blue: 0.44, alpha: 1), tag: "MATCH")
        snippetCard(result, rect: cardRect, alpha: a, selected: true)
        label("找到 1 条 “\(query)”", x: 96, y: 318, width: 300, size: 13, weight: .semibold, color: blueDark, alpha: a)
    } else if filterOn {
        snippetCard(snippets[0], rect: cardRect, alpha: a)
        snippetCard(snippets[2], rect: cardRect.offsetBy(dx: 0, dy: 75), alpha: a)
        label("已收藏的重要片段", x: 96, y: 393, width: 220, size: 13, weight: .semibold, color: orange, alpha: a)
    } else {
        snippetCard(snippets[0], rect: cardRect, alpha: a)
        snippetCard(snippets[1], rect: cardRect.offsetBy(dx: 0, dy: 75), alpha: a)
        snippetCard(snippets[2], rect: cardRect.offsetBy(dx: 0, dy: 150), alpha: a)
    }

    let composer = CGRect(x: 834, y: 235, width: 316, height: 330)
    rounded(composer, radius: 16, color: NSColor(calibratedWhite: 0.985, alpha: 1), alpha: a)
    outline(composer, radius: 16, color: border, width: 1.5, alpha: a)
    label("积木组合框", x: 856, y: 255, width: 210, size: 17, weight: .bold, color: ink, alpha: a)
    label("拖进来，在积木之间补充文字", x: 856, y: 282, width: 250, size: 12, weight: .medium, color: muted, alpha: a)

    let firstDropped = time >= 10.05
    let secondDropped = time >= 12.05
    let bridgeProgress = Int(clamp((time - 13.0) / 0.09, 0, 17))
    let bridge = String(Array("Compare this with").prefix(bridgeProgress))

    if !firstDropped {
        rounded(CGRect(x: 856, y: 320, width: 272, height: 136), radius: 13, color: canvas, alpha: a)
        outline(CGRect(x: 856, y: 320, width: 272, height: 136), radius: 13, color: blue, width: 1.5, alpha: a * 0.55)
        label("空", x: 856, y: 356, width: 272, size: 23, weight: .bold, color: muted, alpha: a * 0.55, alignment: .center)
        label("拖入第一块灵感", x: 856, y: 392, width: 272, size: 13, weight: .medium, color: muted, alpha: a * 0.7, alignment: .center)
    } else {
        rounded(CGRect(x: 856, y: 318, width: 272, height: 48), radius: 12, color: snippets[0].color, alpha: a)
        label("1  Compare model answers", x: 856, y: 332, width: 272, size: 13, weight: .bold, color: .white, alpha: a, alignment: .center)
        if secondDropped {
            rounded(CGRect(x: 856, y: 380, width: 272, height: 44), radius: 10, color: .white, alpha: a)
            outline(CGRect(x: 856, y: 380, width: 272, height: 44), radius: 10, color: border, width: 1.3, alpha: a)
            label(bridge.isEmpty ? "点击积木之间输入" : bridge, x: 868, y: 393, width: 248, size: 13, weight: bridge.isEmpty ? .regular : .semibold, color: bridge.isEmpty ? muted : ink, alpha: a)
            rounded(CGRect(x: 856, y: 438, width: 272, height: 48), radius: 12, color: snippets[1].color, alpha: a)
            label("2  Spreadsheet evidence", x: 856, y: 452, width: 272, size: 13, weight: .bold, color: .white, alpha: a, alignment: .center)
        }
    }

    let canPolish = secondDropped && bridgeProgress == 17
    let polished = time >= 15.35
    if polished {
        rounded(CGRect(x: 856, y: 318, width: 272, height: 168), radius: 13, color: blue, alpha: a * 0.11)
        outline(CGRect(x: 856, y: 318, width: 272, height: 168), radius: 13, color: blue, width: 1.6, alpha: a)
        label("AI 已整理为连贯全文", x: 874, y: 336, width: 236, size: 14, weight: .bold, color: blueDark, alpha: a, alignment: .center)
        label("综合模型回答与表格证据，先保留共同结论，再核对关键差异，形成可继续使用的完整提示词。", x: 878, y: 374, width: 228, size: 13, weight: .medium, color: ink, alpha: a, alignment: .left)
    }
    rounded(CGRect(x: 856, y: 505, width: 272, height: 42), radius: 12, color: canPolish ? ink : NSColor(calibratedWhite: 0.86, alpha: 1), alpha: a)
    label(polished ? "复制全文" : "Polish 生成全文", x: 856, y: 517, width: 272, size: 14, weight: .bold, color: canPolish ? .white : muted, alpha: a, alignment: .center)

    if time >= 15.35 {
        let toastAlpha = a * alpha(time: time, start: 15.3, end: 17.1, fade: 0.18)
        rounded(CGRect(x: 308, y: 608, width: 664, height: 50), radius: 14, color: green, alpha: toastAlpha)
        label("Polish 完成：零散积木已经变成一段可直接使用的全文", x: 328, y: 623, width: 624, size: 14, weight: .bold, color: .white, alpha: toastAlpha, alignment: .center)
    }

    let cursorState = stationCursor(time: time)
    if time >= 8.7 && time < 10.15 {
        dragBlock(snippets[0], center: CGPoint(x: cursorState.0.x - 15, y: cursorState.0.y - 28), alpha: a)
    }
    if time >= 10.65 && time < 12.15 {
        dragBlock(snippets[1], center: CGPoint(x: cursorState.0.x - 15, y: cursorState.0.y - 28), alpha: a)
    }
    clickRing(at: CGPoint(x: 980, y: 188), time: time, event: 3.2, alpha: a)
    clickRing(at: CGPoint(x: 460, y: 188), time: time, event: 4.75, alpha: a)
    clickRing(at: CGPoint(x: 787, y: 188), time: time, event: 7.18, alpha: a)
    clickRing(at: CGPoint(x: 980, y: 188), time: time, event: 7.98, alpha: a)
    clickRing(at: CGPoint(x: 992, y: 342), time: time, event: 10.1, color: green, alpha: a)
    clickRing(at: CGPoint(x: 992, y: 462), time: time, event: 12.1, color: green, alpha: a)
    clickRing(at: CGPoint(x: 992, y: 402), time: time, event: 12.85, alpha: a)
    clickRing(at: CGPoint(x: 992, y: 526), time: time, event: 15.25, color: green, alpha: a)
    cursor(at: cursorState.0, alpha: a * cursorState.2, down: cursorState.1)
}

private func memoryCursor(local t: Double) -> (CGPoint, Bool) {
    let calendar = CGPoint(x: 434, y: 394)
    let reminder = CGPoint(x: 434, y: 453)
    let restore = CGPoint(x: 978, y: 222)
    if t < 0.8 { return (CGPoint(x: 250, y: 320), false) }
    if t < 1.5 { return (point(CGPoint(x: 250, y: 320), calendar, (t - 0.8) / 0.7), false) }
    if t < 1.8 { return (calendar, true) }
    if t < 2.6 { return (point(calendar, reminder, (t - 1.8) / 0.8), false) }
    if t < 2.9 { return (reminder, true) }
    if t < 3.8 { return (point(reminder, restore, (t - 2.9) / 0.9), false) }
    return (restore, t < 4.15)
}

private func drawMemoryAndDates(time: Double) {
    let start = 16.7
    let end = 24.2
    let t = time - start
    let a = alpha(time: time, start: start, end: end, fade: 0.65)
    guard a > 0 else { return }

    rounded(CGRect(origin: .zero, size: size), radius: 0, color: canvas, alpha: a)
    sectionPill("3 / 4   日期 + 找回", x: 64, y: 24, color: orange, alpha: a)
    label("记住时间，也给差点错过的灵感一次返回键。", x: 266, y: 30, width: 850, size: 21, weight: .bold, color: ink, alpha: a)

    let datePanel = CGRect(x: 64, y: 94, width: 530, height: 548)
    rounded(datePanel.offsetBy(dx: 0, dy: 7), radius: 22, color: .black, alpha: a * 0.07)
    rounded(datePanel, radius: 22, color: .white, alpha: a)
    outline(datePanel, radius: 22, color: border, width: 1.8, alpha: a)
    label("复制日期，直接变成行动", x: 98, y: 126, width: 430, size: 23, weight: .bold, color: ink, alpha: a)
    label("不再重新输入日期、时间和提醒内容", x: 98, y: 164, width: 410, size: 14, weight: .medium, color: muted, alpha: a)

    let dateCard = CGRect(x: 98, y: 220, width: 462, height: 108)
    rounded(dateCard, radius: 15, color: canvas, alpha: a)
    outline(dateCard, radius: 15, color: blue, width: 1.6, alpha: a)
    rounded(CGRect(x: 116, y: 240, width: 54, height: 54), radius: 13, color: blue, alpha: a)
    label("27", x: 116, y: 253, width: 54, size: 19, weight: .bold, color: .white, alpha: a, alignment: .center)
    label("周五 14:30  项目复盘", x: 190, y: 242, width: 332, size: 18, weight: .bold, color: ink, alpha: a)
    label("已识别：2026/7/31 14:30", x: 190, y: 276, width: 320, size: 13, weight: .medium, color: muted, alpha: a)

    let calendarRect = CGRect(x: 116, y: 370, width: 390, height: 48)
    let reminderRect = CGRect(x: 116, y: 430, width: 390, height: 48)
    rounded(calendarRect, radius: 13, color: blue, alpha: a * 0.14)
    outline(calendarRect, radius: 13, color: blue, width: 1.4, alpha: a)
    label("加入日历", x: 116, y: 384, width: 390, size: 15, weight: .bold, color: blueDark, alpha: a, alignment: .center)
    rounded(reminderRect, radius: 13, color: orange, alpha: a * 0.14)
    outline(reminderRect, radius: 13, color: orange, width: 1.4, alpha: a)
    label("设置提醒", x: 116, y: 444, width: 390, size: 15, weight: .bold, color: orange, alpha: a, alignment: .center)
    label("复制的不只是文字，也可以是下一步。", x: 98, y: 536, width: 462, size: 15, weight: .semibold, color: muted, alpha: a, alignment: .center)

    let shorePanel = CGRect(x: 626, y: 94, width: 590, height: 548)
    rounded(shorePanel.offsetBy(dx: 0, dy: 7), radius: 22, color: .black, alpha: a * 0.07)
    rounded(shorePanel, radius: 22, color: .white, alpha: a)
    outline(shorePanel, radius: 22, color: border, width: 1.8, alpha: a)
    label("回忆浅滩", x: 660, y: 126, width: 280, size: 23, weight: .bold, color: ink, alpha: a)
    label("满 7 天或手动删除的内容，先在这里等你", x: 660, y: 164, width: 430, size: 14, weight: .medium, color: muted, alpha: a)

    let recovered = t >= 4.1
    rounded(CGRect(x: 960, y: 190, width: 216, height: 48), radius: 13, color: recovered ? green : ink, alpha: a)
    label(recovered ? "已全部找回 ✓" : "全部找回", x: 960, y: 204, width: 216, size: 15, weight: .bold, color: .white, alpha: a, alignment: .center)

    if recovered {
        bubble(center: CGPoint(x: 921, y: 356), radius: 38, alpha: a * 0.55)
        label("3 条历史资料已回到列表", x: 694, y: 424, width: 454, size: 22, weight: .bold, color: ink, alpha: a, alignment: .center)
        label("并自动收藏，不会再次被 7 天规则带走", x: 694, y: 466, width: 454, size: 14, weight: .semibold, color: green, alpha: a, alignment: .center)
    } else {
        let memoryTitles = ["上周的模型对比", "被删掉的截图笔记", "还没整理的灵感"]
        for index in memoryTitles.indices {
            let rect = CGRect(x: 660, y: 272 + CGFloat(index) * 82, width: 516, height: 64)
            rounded(rect, radius: 13, color: canvas, alpha: a)
            outline(rect, radius: 13, color: border, width: 1.2, alpha: a)
            label(memoryTitles[index], x: 684, y: rect.minY + 13, width: 340, size: 15, weight: .bold, color: ink, alpha: a)
            label(index == 0 ? "7 天记忆" : "回忆浅滩", x: 684, y: rect.minY + 37, width: 220, size: 11, weight: .semibold, color: muted, alpha: a)
            label("☆", x: 1118, y: rect.minY + 18, width: 30, size: 20, weight: .bold, color: orange, alpha: a, alignment: .center)
        }
    }

    if t >= 2.75 && t < 4.1 {
        let toast = a * alpha(time: t, start: 2.7, end: 4.05, fade: 0.2)
        rounded(CGRect(x: 296, y: 584, width: 688, height: 42), radius: 13, color: orange, alpha: toast)
        label("日期已加入日历，并创建提醒", x: 296, y: 596, width: 688, size: 14, weight: .bold, color: .white, alpha: toast, alignment: .center)
    }

    let state = memoryCursor(local: t)
    clickRing(at: CGPoint(x: 434, y: 394), time: t, event: 1.5, alpha: a)
    clickRing(at: CGPoint(x: 434, y: 453), time: t, event: 2.6, color: orange, alpha: a)
    clickRing(at: CGPoint(x: 978, y: 222), time: t, event: 3.82, color: green, alpha: a)
    cursor(at: state.0, alpha: a, down: state.1)
}

private func imageTile(rect: CGRect, color: NSColor, symbol: Int, selected: Bool, alpha: CGFloat) {
    rounded(rect, radius: 10, color: color.withAlphaComponent(0.15), alpha: alpha)
    outline(rect, radius: 10, color: selected ? color : border, width: selected ? 3 : 1.3, alpha: alpha)
    if symbol == 0 {
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: CGRect(x: rect.midX - 24, y: rect.midY - 24, width: 48, height: 48)).fill()
    } else if symbol == 1 {
        rounded(CGRect(x: rect.midX - 28, y: rect.midY - 28, width: 56, height: 56), radius: 8, color: color, alpha: alpha)
    } else if symbol == 2 {
        color.withAlphaComponent(alpha).setFill()
        let triangle = NSBezierPath()
        triangle.move(to: CGPoint(x: rect.midX, y: rect.minY + 24))
        triangle.line(to: CGPoint(x: rect.minX + 26, y: rect.maxY - 22))
        triangle.line(to: CGPoint(x: rect.maxX - 26, y: rect.maxY - 22))
        triangle.close()
        triangle.fill()
    } else {
        color.withAlphaComponent(alpha).setFill()
        let diamond = NSBezierPath()
        diamond.move(to: CGPoint(x: rect.midX, y: rect.minY + 20))
        diamond.line(to: CGPoint(x: rect.maxX - 22, y: rect.midY))
        diamond.line(to: CGPoint(x: rect.midX, y: rect.maxY - 20))
        diamond.line(to: CGPoint(x: rect.minX + 22, y: rect.midY))
        diamond.close()
        diamond.fill()
    }
    if selected {
        rounded(CGRect(x: rect.maxX - 29, y: rect.minY + 8, width: 21, height: 21), radius: 6, color: color, alpha: alpha)
        label("✓", x: rect.maxX - 29, y: rect.minY + 10, width: 21, size: 13, weight: .bold, color: .white, alpha: alpha, alignment: .center)
    }
}

private func collectorCursor(local t: Double) -> (CGPoint, Bool) {
    let bubblePoint = CGPoint(x: 576, y: 395)
    let rowPoint = CGPoint(x: 885, y: 252)
    let image2 = CGPoint(x: 844, y: 442)
    let image4 = CGPoint(x: 1080, y: 442)
    let save = CGPoint(x: 1082, y: 316)
    if t < 1.3 { return (CGPoint(x: 430, y: 310), false) }
    if t < 2.0 { return (point(CGPoint(x: 430, y: 310), bubblePoint, (t - 1.3) / 0.7), false) }
    if t < 2.25 { return (bubblePoint, true) }
    if t < 4.0 { return (point(bubblePoint, rowPoint, (t - 2.25) / 1.75), false) }
    if t < 4.45 { return (rowPoint, true) }
    if t < 6.1 { return (point(rowPoint, image2, (t - 4.45) / 1.65), false) }
    if t < 6.4 { return (image2, true) }
    if t < 7.0 { return (point(image2, image4, (t - 6.4) / 0.6), false) }
    if t < 7.3 { return (image4, true) }
    if t < 8.4 { return (point(image4, rowPoint, (t - 7.3) / 1.1), false) }
    if t < 8.85 { return (rowPoint, true) }
    if t < 10.0 { return (rowPoint, false) }
    if t < 10.45 { return (rowPoint, true) }
    if t < 11.35 { return (point(rowPoint, save, (t - 10.45) / 0.9), false) }
    return (save, t < 11.65)
}

private func drawCollector(time: Double) {
    let start = 23.6
    let t = time - start
    let a = alpha(time: time, start: start, end: 37.0, fade: 0.65)
    guard a > 0 else { return }
    rounded(CGRect(origin: .zero, size: size), radius: 0, color: .white, alpha: a)
    sectionPill("4 / 4   整帖收图 + OCR", x: 64, y: 24, color: blueDark, alpha: a)
    label("整帖图片一次收齐，原图与文字都能带走。", x: 266, y: 30, width: 820, size: 21, weight: .bold, color: ink, alpha: a)

    let browser = CGRect(x: 58, y: 92, width: 490, height: 562)
    rounded(browser.offsetBy(dx: 0, dy: 7), radius: 18, color: .black, alpha: a * 0.08)
    rounded(browser, radius: 18, color: NSColor(calibratedWhite: 0.985, alpha: 1), alpha: a)
    outline(browser, radius: 18, color: border, width: 1.5, alpha: a)
    rounded(CGRect(x: 58, y: 92, width: 490, height: 48), radius: 18, color: NSColor(calibratedWhite: 0.93, alpha: 1), alpha: a)
    NSColor.systemRed.withAlphaComponent(a).setFill(); NSBezierPath(ovalIn: CGRect(x: 78, y: 110, width: 12, height: 12)).fill()
    NSColor.systemYellow.withAlphaComponent(a).setFill(); NSBezierPath(ovalIn: CGRect(x: 98, y: 110, width: 12, height: 12)).fill()
    NSColor.systemGreen.withAlphaComponent(a).setFill(); NSBezierPath(ovalIn: CGRect(x: 118, y: 110, width: 12, height: 12)).fill()
    rounded(CGRect(x: 154, y: 105, width: 360, height: 24), radius: 8, color: .white, alpha: a)
    label("linggan.local/post/four-ideas", x: 176, y: 111, width: 300, size: 11, weight: .medium, color: muted, alpha: a)
    label("值得留下的四个画面", x: 86, y: 164, width: 380, size: 25, weight: .bold, color: ink, alpha: a)
    label("当前帖子  •  4 张图片", x: 86, y: 201, width: 300, size: 13, weight: .medium, color: muted, alpha: a)
    imageTile(rect: CGRect(x: 86, y: 238, width: 205, height: 150), color: blueDark, symbol: 0, selected: false, alpha: a)
    imageTile(rect: CGRect(x: 315, y: 238, width: 205, height: 150), color: orange, symbol: 1, selected: false, alpha: a)
    imageTile(rect: CGRect(x: 86, y: 410, width: 205, height: 150), color: green, symbol: 2, selected: false, alpha: a)
    imageTile(rect: CGRect(x: 315, y: 410, width: 205, height: 150), color: NSColor.systemPink, symbol: 3, selected: false, alpha: a)

    bubble(center: CGPoint(x: 576, y: 395), radius: 35, alpha: a)
    label("⌘ + click", x: 534, y: 440, width: 84, size: 12, weight: .bold, color: blueDark, alpha: a, alignment: .center)

    let station = CGRect(x: 608, y: 92, width: 614, height: 562)
    rounded(station.offsetBy(dx: 0, dy: 7), radius: 18, color: .black, alpha: a * 0.08)
    rounded(station, radius: 18, color: canvas, alpha: a)
    outline(station, radius: 18, color: blue, width: 1.8, alpha: a)
    label("灵感图片暂存", x: 638, y: 118, width: 340, size: 22, weight: .bold, color: ink, alpha: a)

    let captured = t >= 2.15
    let collapsedWindow = t >= 8.75 && t < 10.35
    let expanded = captured && t >= 4.3 && !collapsedWindow

    if !captured {
        rounded(CGRect(x: 642, y: 190, width: 546, height: 360), radius: 16, color: .white, alpha: a)
        outline(CGRect(x: 642, y: 190, width: 546, height: 360), radius: 16, color: border, width: 1.5, alpha: a)
        bubble(center: CGPoint(x: 915, y: 310), radius: 32, alpha: a * 0.45)
        label("还没有收图", x: 740, y: 370, width: 350, size: 24, weight: .bold, color: muted, alpha: a * 0.65, alignment: .center)
        label("在支持的帖子上 Cmd + 点击灵感球", x: 722, y: 410, width: 386, size: 14, weight: .medium, color: muted, alpha: a * 0.75, alignment: .center)
    } else {
        let row = CGRect(x: 638, y: 176, width: 554, height: 104)
        rounded(row, radius: 14, color: .white, alpha: a)
        outline(row, radius: 14, color: expanded ? blue : border, width: expanded ? 2.3 : 1.4, alpha: a)
        rounded(CGRect(x: 656, y: 194, width: 86, height: 68), radius: 10, color: canvas, alpha: a)
        rounded(CGRect(x: 666, y: 202, width: 72, height: 54), radius: 8, color: blue, alpha: a * 0.32)
        label("4", x: 704, y: 224, width: 28, size: 16, weight: .bold, color: blueDark, alpha: a, alignment: .center)
        label("值得留下的四个画面", x: 762, y: 196, width: 350, size: 17, weight: .bold, color: ink, alpha: a)
        label(expanded ? "4 张  •  已选 3 张  •  双击收起" : "4 张  •  双击展开", x: 762, y: 228, width: 390, size: 12, weight: .medium, color: muted, alpha: a)

        if expanded {
            rounded(CGRect(x: 638, y: 300, width: 112, height: 40), radius: 11, color: .white, alpha: a)
            outline(CGRect(x: 638, y: 300, width: 112, height: 40), radius: 11, color: border, width: 1.2, alpha: a)
            label("全选", x: 638, y: 312, width: 112, size: 13, weight: .semibold, color: muted, alpha: a, alignment: .center)
            rounded(CGRect(x: 766, y: 300, width: 130, height: 40), radius: 11, color: blue, alpha: a * 0.14)
            label("OCR 存文字", x: 766, y: 312, width: 130, size: 13, weight: .bold, color: blueDark, alpha: a, alignment: .center)
            rounded(CGRect(x: 1010, y: 300, width: 182, height: 40), radius: 11, color: ink, alpha: a)
            label("保存 / 拖出原图", x: 1010, y: 312, width: 182, size: 13, weight: .bold, color: .white, alpha: a, alignment: .center)

            let secondSelected = t < 6.25
            let fourthSelected = t >= 7.1
            imageTile(rect: CGRect(x: 638, y: 364, width: 124, height: 150), color: blueDark, symbol: 0, selected: true, alpha: a)
            imageTile(rect: CGRect(x: 778, y: 364, width: 124, height: 150), color: orange, symbol: 1, selected: secondSelected, alpha: a)
            imageTile(rect: CGRect(x: 918, y: 364, width: 124, height: 150), color: green, symbol: 2, selected: true, alpha: a)
            imageTile(rect: CGRect(x: 1058, y: 364, width: 124, height: 150), color: NSColor.systemPink, symbol: 3, selected: fourthSelected, alpha: a)
            label("单独勾选，双击看大图，也可直接拖进文档", x: 638, y: 536, width: 554, size: 13, weight: .semibold, color: blueDark, alpha: a, alignment: .center)
        } else {
            rounded(CGRect(x: 638, y: 306, width: 554, height: 218), radius: 14, color: .white, alpha: a)
            label("图片已收起", x: 638, y: 376, width: 554, size: 23, weight: .bold, color: muted, alpha: a * 0.72, alignment: .center)
            label("双击这一行即可再次展开", x: 638, y: 414, width: 554, size: 14, weight: .medium, color: muted, alpha: a, alignment: .center)
        }
    }

    if t >= 11.55 {
        let toast = a * alpha(time: t, start: 11.5, end: 13.0, fade: 0.18)
        rounded(CGRect(x: 820, y: 588, width: 380, height: 44), radius: 13, color: green, alpha: toast)
        label("已保存 3 张原图，也可一键 OCR 为文字 ✓", x: 800, y: 601, width: 420, size: 14, weight: .bold, color: .white, alpha: toast, alignment: .center)
    }

    let state = collectorCursor(local: t)
    clickRing(at: CGPoint(x: 576, y: 395), time: t, event: 2.0, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 4.03, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 4.28, alpha: a)
    clickRing(at: CGPoint(x: 844, y: 442), time: t, event: 6.15, color: orange, alpha: a)
    clickRing(at: CGPoint(x: 1080, y: 442), time: t, event: 7.05, color: NSColor.systemPink, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 8.43, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 8.68, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 10.03, alpha: a)
    clickRing(at: CGPoint(x: 885, y: 252), time: t, event: 10.28, alpha: a)
    clickRing(at: CGPoint(x: 1082, y: 316), time: t, event: 11.42, color: green, alpha: a)
    cursor(at: state.0, alpha: a, down: state.1)
}

private func drawCTA(time: Double) {
    let a = alpha(time: time, start: 36.4, end: 43.7, fade: 0.55)
    guard a > 0 else { return }
    rounded(CGRect(origin: .zero, size: size), radius: 0, color: canvas, alpha: a)
    bubble(center: CGPoint(x: 640, y: 150), radius: 44, alpha: a)
    label("一个灵感球，把散落的想法接回来。", x: 160, y: 236, width: 960, size: 40, weight: .bold, color: ink, alpha: a, alignment: .center)
    label("收藏 • 日期与提醒 • 历史找回 • 组合 • Polish • 整帖收图", x: 160, y: 300, width: 960, size: 22, weight: .semibold, color: blueDark, alpha: a, alignment: .center)
    label("本地优先、开源，为 macOS 上的 AI 工作流而做", x: 280, y: 366, width: 720, size: 18, weight: .medium, color: muted, alpha: a, alignment: .center)
    rounded(CGRect(x: 302, y: 430, width: 676, height: 64), radius: 16, color: .white, alpha: a)
    outline(CGRect(x: 302, y: 430, width: 676, height: 64), radius: 16, color: border, width: 1.5, alpha: a)
    label("github.com/IvyCHEN03/clipboard-station", x: 302, y: 449, width: 676, size: 20, weight: .bold, color: ink, alpha: a, alignment: .center)
}

private func render(time: Double) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocusFlipped(true)
    NSColor.white.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    drawIntro(time: time)
    drawStation(time: time)
    drawMemoryAndDates(time: time)
    drawCollector(time: time)
    drawCTA(time: time)
    image.unlockFocus()
    return image
}

private func pixelBuffer(from image: NSImage, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var optional: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optional) == kCVReturnSuccess,
          let buffer = optional else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
              data: base,
              width: Int(size.width),
              height: Int(size.height),
              bitsPerComponent: 8,
              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
          ),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: [.interpolation: NSImageInterpolation.high]) else { return nil }
    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    return buffer
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LingganFeatureDemo", code: 1)
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root.appendingPathComponent("docs/assets/social", isDirectory: true)
let outputURL = outputDirectory.appendingPathComponent("linggan-core-workflow.mp4")
let coverURL = outputDirectory.appendingPathComponent("linggan-core-workflow-cover.png")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: outputURL)

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(size.width),
    AVVideoHeightKey: Int(size.height),
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 5_800_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps),
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: Int(size.width),
    kCVPixelBufferHeightKey as String: Int(size.height),
])
guard writer.canAdd(input) else { fatalError("Cannot add video input") }
writer.add(input)
guard writer.startWriting() else { fatalError(writer.error?.localizedDescription ?? "Cannot start video writer") }
writer.startSession(atSourceTime: .zero)
guard let pool = adaptor.pixelBufferPool else { fatalError("No pixel buffer pool") }

for frame in 0..<totalFrames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    let time = Double(frame) / Double(fps)
    guard let buffer = pixelBuffer(from: render(time: time), pool: pool) else { fatalError("Frame \(frame) failed") }
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps)) else {
        fatalError(writer.error?.localizedDescription ?? "Frame append failed")
    }
}

input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError(writer.error?.localizedDescription ?? "Video export failed") }
try writePNG(render(time: 29.0), to: coverURL)
print("Created \(outputURL.path)")
print("Created \(coverURL.path)")
