#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreVideo
import Foundation

private let designSize = CGSize(width: 1280, height: 720)
private let canvasSize = CGSize(width: 1920, height: 1080)
private let fps: Int32 = 30
private let arguments = Set(CommandLine.arguments.dropFirst())
private let isTeaser = arguments.contains("teaser")
private let duration: Double = isTeaser ? 26 : 32
private let frameCount = Int(duration * Double(fps))
private let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let language = arguments.contains("en") ? "en" : "cn"
private let assetKind = isTeaser ? "teaser" : "demo"
private let outputURL = repo.appendingPathComponent("docs/assets/social/linggan-x-\(assetKind)-\(language)-1080p.mp4")
private let coverURL = repo.appendingPathComponent("docs/assets/social/linggan-x-\(assetKind)-\(language)-1080p-cover.png")
private let silentVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("linggan-\(assetKind)-\(language)-silent.mp4")
private let musicURL = FileManager.default.temporaryDirectory.appendingPathComponent("linggan-\(assetKind)-\(language)-music.wav")

private let ink = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)
private let muted = NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.54, alpha: 1)
private let blue = NSColor(calibratedRed: 0.32, green: 0.67, blue: 0.96, alpha: 1)
private let paleBlue = NSColor(calibratedRed: 0.91, green: 0.97, blue: 1, alpha: 1)
private let border = NSColor(calibratedRed: 0.87, green: 0.90, blue: 0.94, alpha: 1)
private let bg = NSColor(calibratedRed: 0.95, green: 0.975, blue: 0.995, alpha: 1)
private let coral = NSColor(calibratedRed: 0.99, green: 0.48, blue: 0.39, alpha: 1)

private func localized(_ chinese: String, _ english: String) -> String {
    language == "en" ? english : chinese
}

private func clamp(_ value: Double, _ low: Double = 0, _ high: Double = 1) -> Double {
    min(max(value, low), high)
}

private func ease(_ value: Double) -> Double {
    let x = clamp(value)
    return x * x * (3 - 2 * x)
}

private func interpolate(_ a: CGPoint, _ b: CGPoint, _ p: Double) -> CGPoint {
    let x = CGFloat(ease(p))
    return CGPoint(x: a.x + (b.x - a.x) * x, y: a.y + (b.y - a.y) * x)
}

private func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func stroke(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat = 1, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

private func text(
    _ value: String,
    rect: CGRect,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    alignment: NSTextAlignment = .left,
    alpha: CGFloat = 1,
    lines: Int = 1
) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color.withAlphaComponent(alpha),
        .paragraphStyle: style,
    ]
    NSAttributedString(string: value, attributes: attributes).draw(in: rect)
}

private func bubble(center: CGPoint, radius: CGFloat, alpha: CGFloat = 1) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.systemBlue.withAlphaComponent(0.18 * alpha)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = CGSize(width: 0, height: 7)
    shadow.set()
    let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    blue.withAlphaComponent(alpha).setFill()
    NSBezierPath(ovalIn: circle).fill()
    NSColor.white.withAlphaComponent(alpha).setFill()
    let star = NSBezierPath()
    star.move(to: CGPoint(x: center.x, y: center.y - radius * 0.48))
    star.curve(to: CGPoint(x: center.x + radius * 0.48, y: center.y), controlPoint1: CGPoint(x: center.x + radius * 0.08, y: center.y - radius * 0.08), controlPoint2: CGPoint(x: center.x + radius * 0.08, y: center.y - radius * 0.08))
    star.curve(to: CGPoint(x: center.x, y: center.y + radius * 0.48), controlPoint1: CGPoint(x: center.x + radius * 0.08, y: center.y + radius * 0.08), controlPoint2: CGPoint(x: center.x + radius * 0.08, y: center.y + radius * 0.08))
    star.curve(to: CGPoint(x: center.x - radius * 0.48, y: center.y), controlPoint1: CGPoint(x: center.x - radius * 0.08, y: center.y + radius * 0.08), controlPoint2: CGPoint(x: center.x - radius * 0.08, y: center.y + radius * 0.08))
    star.curve(to: CGPoint(x: center.x, y: center.y - radius * 0.48), controlPoint1: CGPoint(x: center.x - radius * 0.08, y: center.y - radius * 0.08), controlPoint2: CGPoint(x: center.x - radius * 0.08, y: center.y - radius * 0.08))
    star.fill()
}

private func cursor(at p: CGPoint, down: Bool = false, alpha: CGFloat = 1) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: p.x, yBy: p.y)
    transform.scale(by: down ? 0.86 : 1)
    transform.concat()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24 * alpha)
    shadow.shadowBlurRadius = 5
    shadow.shadowOffset = CGSize(width: 2, height: 3)
    shadow.set()
    let path = NSBezierPath()
    path.move(to: .zero)
    path.line(to: CGPoint(x: 0, y: 29))
    path.line(to: CGPoint(x: 8, y: 22))
    path.line(to: CGPoint(x: 15, y: 36))
    path.line(to: CGPoint(x: 22, y: 33))
    path.line(to: CGPoint(x: 15, y: 20))
    path.line(to: CGPoint(x: 27, y: 19))
    path.close()
    NSColor.white.withAlphaComponent(alpha).setFill()
    path.fill()
    ink.withAlphaComponent(alpha).setStroke()
    path.lineWidth = 2
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

private func clickRing(at p: CGPoint, time: Double, event: Double, color: NSColor = blue) {
    let age = time - event
    guard age >= 0, age < 0.46 else { return }
    let progress = CGFloat(age / 0.46)
    let radius = 10 + 28 * progress
    color.withAlphaComponent(0.7 * (1 - progress)).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 4 - 2 * progress
    ring.stroke()
}

private func windowShadow(_ rect: CGRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = CGSize(width: 0, height: 12)
    shadow.set()
    rounded(rect, radius: radius, color: .white)
    NSGraphicsContext.restoreGraphicsState()
}

private let appRect = CGRect(x: 72, y: 48, width: 454, height: 640)

private func drawStationFrame(_ index: Int, alpha: CGFloat = 1) {
    windowShadow(appRect, radius: 22)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: appRect, xRadius: 22, yRadius: 22).addClip()

    let transform = NSAffineTransform()
    transform.translateX(by: appRect.minX, yBy: appRect.minY)
    transform.scaleX(by: appRect.width / 420, yBy: appRect.height / 592)
    transform.concat()

    func pill(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor, active: Bool = false) {
        rounded(CGRect(x: x, y: y, width: width, height: 27), radius: 8, color: active ? color : color.withAlphaComponent(0.12), alpha: alpha)
        text(value, rect: CGRect(x: x, y: y + 6, width: width, height: 18), size: 11, weight: .semibold, color: active ? .white : color, alignment: .center, alpha: alpha)
    }

    func redactionBars(x: CGFloat, y: CGFloat, widths: [CGFloat]) {
        for (offset, width) in widths.enumerated() {
            rounded(CGRect(x: x, y: y + CGFloat(offset) * 17, width: width, height: 8), radius: 4, color: NSColor(calibratedWhite: 0.76, alpha: 1), alpha: alpha * 0.72)
        }
    }

    func snippetRow(number: String, title: String, y: CGFloat, color: NSColor, tags: [String]) {
        NSColor(calibratedWhite: 0.40, alpha: alpha).setStroke()
        let checkbox = NSBezierPath(roundedRect: CGRect(x: 21, y: y + 5, width: 13, height: 13), xRadius: 2, yRadius: 2)
        checkbox.lineWidth = 1.5
        checkbox.stroke()
        text("⌃", rect: CGRect(x: 48, y: y, width: 24, height: 20), size: 14, color: muted, alignment: .center, alpha: alpha)
        stroke(CGRect(x: 49, y: y + 28, width: 36, height: 27), radius: 7, color: color, width: 1.4, alpha: alpha)
        text(number, rect: CGRect(x: 49, y: y + 34, width: 36, height: 18), size: 12, weight: .bold, color: color, alignment: .center, alpha: alpha)
        text(title, rect: CGRect(x: 92, y: y + 2, width: 240, height: 22), size: 13, weight: .bold, alpha: alpha)
        text("✎   ⧉   ↓   ⌫", rect: CGRect(x: 322, y: y + 2, width: 82, height: 20), size: 12, color: muted, alignment: .right, alpha: alpha)
        redactionBars(x: 92, y: y + 31, widths: [248, 222, 188])
        rounded(CGRect(x: 92, y: y + 84, width: 81, height: 19), radius: 9, color: NSColor(calibratedWhite: 0.94, alpha: 1), alpha: alpha)
        text(localized("内容已脱敏", "REDACTED"), rect: CGRect(x: 92, y: y + 88, width: 81, height: 15), size: 9, weight: .bold, color: muted, alignment: .center, alpha: alpha)
        var tagX: CGFloat = 181
        for tag in tags {
            let width = CGFloat(max(42, tag.count * 9 + 18))
            rounded(CGRect(x: tagX, y: y + 84, width: width, height: 19), radius: 9, color: paleBlue, alpha: alpha)
            text(tag, rect: CGRect(x: tagX, y: y + 88, width: width, height: 14), size: 9, weight: .semibold, color: NSColor.systemBlue, alignment: .center, alpha: alpha)
            tagX += width + 6
        }
        text(localized("文字   刚刚   仅用于演示", "TEXT   JUST NOW   DEMO ONLY"), rect: CGRect(x: 92, y: y + 109, width: 260, height: 17), size: 9, color: NSColor(calibratedWhite: 0.58, alpha: 1), alpha: alpha)
    }

    NSColor.white.withAlphaComponent(alpha).setFill()
    NSBezierPath(rect: CGRect(x: 0, y: 0, width: 420, height: 592)).fill()
    for x in [17, 39, 61] {
        NSColor(calibratedWhite: 0.84, alpha: alpha).setFill()
        NSBezierPath(ovalIn: CGRect(x: x - 6, y: 13, width: 12, height: 12)).fill()
    }
    bubble(center: CGPoint(x: 29, y: 57), radius: 15, alpha: alpha)
    text(localized("灵感悬浮球", "Linggan Floating Ball"), rect: CGRect(x: 51, y: 42, width: 245, height: 25), size: language == "en" ? 16 : 18, weight: .bold, alpha: alpha)
    let count = index == 1 ? "2/3" : index == 2 ? "1/3" : "3/3"
    text("v0.4.0  ·  \(count)  \(localized("个片段", "snippets"))", rect: CGRect(x: 51, y: 67, width: 250, height: 18), size: 10, color: muted, alpha: alpha)
    text("?   ◉   ⚑   ⚙", rect: CGRect(x: 303, y: 49, width: 100, height: 22), size: 14, color: muted, alignment: .right, alpha: alpha)
    NSColor(calibratedWhite: 0.88, alpha: alpha).setStroke()
    NSBezierPath(rect: CGRect(x: 0, y: 90, width: 420, height: 1)).stroke()

    text(localized("时间", "Time"), rect: CGRect(x: 22, y: 105, width: 38, height: 18), size: 10, weight: .semibold, color: muted, alpha: alpha)
    pill(localized("今天  100%", "Today  100%"), x: 55, y: 98, width: 104, color: NSColor.systemBlue)
    pill(localized("3天  0%", "3 days  0%"), x: 168, y: 98, width: 96, color: NSColor.systemGreen)
    pill(localized("鱼的7天  0%", "Fish 7d  0%"), x: 274, y: 98, width: 126, color: NSColor.systemOrange)

    text(localized("分类", "Tags"), rect: CGRect(x: 22, y: 139, width: 38, height: 18), size: 10, weight: .semibold, color: muted, alpha: alpha)
    pill("AI  2", x: 55, y: 132, width: 57, color: NSColor.systemBlue, active: index == 1 || index == 2)
    pill("prompt  1", x: 118, y: 132, width: 78, color: muted)
    pill("research  1", x: 202, y: 132, width: 84, color: muted)
    pill("table  1", x: 292, y: 132, width: 68, color: muted)

    text("⌕", rect: CGRect(x: 21, y: 173, width: 26, height: 24), size: 20, color: muted, alpha: alpha)
    text(index == 2 ? localized("表格", "table") : localized("搜索标题、正文或来源", "Search title, text, or source"), rect: CGRect(x: 48, y: 177, width: 320, height: 22), size: 12, color: index == 2 ? ink : muted, alpha: alpha)
    text(localized("☑  全选    ⊠  取消    ⧉  复制    ◇  Tag    ↤  倒带    ⌫  删除", "☑  All    ⊠  Clear    ⧉  Copy    ◇  Tag    ↤  Rewind    ⌫  Delete"), rect: CGRect(x: 21, y: 213, width: 380, height: 22), size: language == "en" ? 9 : 10, color: muted, alpha: alpha)

    if index == 2 {
        snippetRow(number: "2", title: localized("匿名表格摘录", "Redacted table excerpt"), y: 248, color: NSColor.systemOrange, tags: ["table", "AI"])
    } else {
        snippetRow(number: "1", title: localized("匿名 AI 讨论片段", "Redacted AI discussion"), y: 248, color: coral, tags: ["prompt", "AI"])
        snippetRow(number: "2", title: localized("匿名表格摘录", "Redacted table excerpt"), y: 399, color: NSColor.systemOrange, tags: ["table", "AI"])
    }

    rounded(CGRect(x: 0, y: 503, width: 420, height: 89), radius: 0, color: .white, alpha: alpha)
    NSColor(calibratedWhite: 0.88, alpha: alpha).setStroke()
    NSBezierPath(rect: CGRect(x: 0, y: 503, width: 420, height: 1)).stroke()
    text(localized("▱  组合框", "▱  Composer"), rect: CGRect(x: 18, y: 514, width: 160, height: 22), size: 12, weight: .bold, alpha: alpha)
    text("ⓧ   ⧉", rect: CGRect(x: 356, y: 514, width: 48, height: 22), size: 13, color: muted, alignment: .right, alpha: alpha)
    rounded(CGRect(x: 16, y: 540, width: 388, height: 42), radius: 8, color: NSColor(calibratedWhite: 0.995, alpha: 1), alpha: alpha)
    stroke(CGRect(x: 16, y: 540, width: 388, height: 42), radius: 8, color: border, alpha: alpha)
    if index < 4 {
        text(localized("空", "Empty"), rect: CGRect(x: 28, y: 552, width: 80, height: 20), size: 11, color: muted, alpha: alpha)
    } else {
        rounded(CGRect(x: 48, y: 549, width: 40, height: 25), radius: 6, color: coral.withAlphaComponent(0.17), alpha: alpha)
        text("1 ×", rect: CGRect(x: 48, y: 555, width: 40, height: 16), size: 11, weight: .bold, color: coral, alignment: .center, alpha: alpha)
        if index >= 5 {
            let bridge = index >= 6 ? localized("对比以下内容", "Compare with") : ""
            if !bridge.isEmpty {
                rounded(CGRect(x: 98, y: 549, width: 112, height: 25), radius: 5, color: NSColor(calibratedWhite: 0.96, alpha: 1), alpha: alpha)
                text(bridge, rect: CGRect(x: 98, y: 555, width: 112, height: 16), size: 10, color: ink, alignment: .center, alpha: alpha)
            }
            let secondX: CGFloat = index >= 6 ? 220 : 100
            rounded(CGRect(x: secondX, y: 549, width: 40, height: 25), radius: 6, color: NSColor.systemOrange.withAlphaComponent(0.18), alpha: alpha)
            text("2 ×", rect: CGRect(x: secondX, y: 555, width: 40, height: 16), size: 11, weight: .bold, color: NSColor.systemOrange, alignment: .center, alpha: alpha)
        }
    }
    if index == 7 {
        rounded(CGRect(x: 132, y: 480, width: 156, height: 36), radius: 18, color: ink, alpha: alpha * 0.96)
        text(localized("已复制组合内容", "Composition copied"), rect: CGRect(x: 132, y: 490, width: 156, height: 18), size: 11, weight: .bold, color: .white, alignment: .center, alpha: alpha)
    }
    NSGraphicsContext.restoreGraphicsState()
}

private func stationIndex(at time: Double) -> Int {
    if time < 3.25 { return 0 }
    if time < 5.55 { return 1 }
    if time < 6.8 { return 2 }
    if time < 9.35 { return 3 }
    if time < 11.6 { return 4 }
    if time < 13.65 { return 5 }
    if time < 15.45 { return 6 }
    return 7
}

private func localToCanvas(_ p: CGPoint) -> CGPoint {
    CGPoint(x: appRect.minX + p.x / 420 * appRect.width, y: appRect.minY + p.y / 592 * appRect.height)
}

private func stationCursor(_ t: Double) -> (CGPoint, Bool) {
    let ai = localToCanvas(CGPoint(x: 74, y: 145))
    let search = localToCanvas(CGPoint(x: 105, y: 184))
    let row1 = localToCanvas(CGPoint(x: 155, y: 280))
    let row2 = localToCanvas(CGPoint(x: 155, y: 448))
    let composerA = localToCanvas(CGPoint(x: 86, y: 558))
    let composerB = localToCanvas(CGPoint(x: 220, y: 558))
    let bridge = localToCanvas(CGPoint(x: 142, y: 558))
    let copy = localToCanvas(CGPoint(x: 395, y: 515))
    if t < 2.25 { return (CGPoint(x: 635, y: 128), false) }
    if t < 2.85 { return (interpolate(CGPoint(x: 635, y: 128), ai, (t - 2.25) / 0.6), false) }
    if t < 3.1 { return (ai, true) }
    if t < 4.1 { return (interpolate(ai, search, (t - 3.1) / 1), false) }
    if t < 5.25 { return (search, t < 4.35) }
    if t < 6.6 { return (search, false) }
    if t < 7.5 { return (interpolate(search, row1, (t - 6.6) / 0.9), false) }
    if t < 9.25 { return (interpolate(row1, composerA, (t - 7.5) / 1.75), true) }
    if t < 10.15 { return (interpolate(composerA, row2, (t - 9.25) / 0.9), false) }
    if t < 11.5 { return (interpolate(row2, composerB, (t - 10.15) / 1.35), true) }
    if t < 12.45 { return (interpolate(composerB, bridge, (t - 11.5) / 0.95), false) }
    if t < 13.5 { return (bridge, t < 12.7) }
    if t < 14.8 { return (interpolate(bridge, copy, (t - 13.5) / 1.3), false) }
    return (copy, t < 15.12)
}

private func stageLabel(_ step: String, _ title: String, _ detail: String) {
    rounded(CGRect(x: 580, y: 100, width: 118, height: 34), radius: 17, color: paleBlue)
    text(step, rect: CGRect(x: 580, y: 109, width: 118, height: 22), size: 12, weight: .bold, color: NSColor.systemBlue, alignment: .center)
    text(title, rect: CGRect(x: 580, y: 160, width: 620, height: 110), size: 36, weight: .bold, lines: 2)
    text(detail, rect: CGRect(x: 580, y: 276, width: 570, height: 120), size: 20, weight: .medium, color: muted, lines: 3)
}

private func drawStationScene(_ t: Double) {
    bg.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: designSize)).fill()
    let index = stationIndex(at: t)
    drawStationFrame(index)

    if t < 6.8 {
        stageLabel(
            localized("01  捞回灵光", "01  REEL IT BACK"),
            localized("标签轻轻一捞，\n刚才那点灵光，归队。", "Let tags reel it back in.\nThat little spark is back."),
            localized("想法没丢，只是在等你叫它回来。", "Your idea was never lost. It was waiting to be called back.")
        )
    } else if t < 13.7 {
        stageLabel(
            localized("02  增添灵感", "02  ADD A SPARK"),
            localized("一句、两句，\n再添一点新灵感。", "One fragment. Then another.\nAdd a spark of your own."),
            localized("散落的碎片，开始长成答案。", "Watch scattered fragments start becoming an answer.")
        )
    } else {
        stageLabel(
            localized("03  出发", "03  NEXT STOP"),
            localized("组合完成。\n下一站：AI 对话框。", "Built.\nNext stop: your AI chat."),
            localized("带上刚刚长成的答案，继续出发。", "Take the answer you just built and keep moving.")
        )
    }

    if t >= 7.5 && t < 9.35 {
        let start = localToCanvas(CGPoint(x: 155, y: 280))
        let end = localToCanvas(CGPoint(x: 86, y: 558))
        let p = interpolate(start, end, (t - 7.5) / 1.75)
        rounded(CGRect(x: p.x - 31, y: p.y - 17, width: 62, height: 34), radius: 8, color: coral, alpha: 0.92)
        text("1", rect: CGRect(x: p.x - 31, y: p.y - 9, width: 62, height: 20), size: 14, weight: .bold, color: .white, alignment: .center)
    }
    if t >= 10.15 && t < 11.6 {
        let start = localToCanvas(CGPoint(x: 155, y: 448))
        let end = localToCanvas(CGPoint(x: 220, y: 558))
        let p = interpolate(start, end, (t - 10.15) / 1.35)
        rounded(CGRect(x: p.x - 31, y: p.y - 17, width: 62, height: 34), radius: 8, color: NSColor.systemOrange, alpha: 0.92)
        text("2", rect: CGRect(x: p.x - 31, y: p.y - 9, width: 62, height: 20), size: 14, weight: .bold, color: .white, alignment: .center)
    }

    let (p, down) = stationCursor(t)
    cursor(at: p, down: down)
    for event in [2.9, 4.18, 12.55, 14.95] { clickRing(at: p, time: t, event: event) }
}

private func photo(_ rect: CGRect, variant: Int) {
    let colors: [(NSColor, NSColor)] = [
        (NSColor(calibratedRed: 0.99, green: 0.76, blue: 0.72, alpha: 1), NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.98, alpha: 1)),
        (NSColor(calibratedRed: 0.79, green: 0.92, blue: 0.73, alpha: 1), NSColor(calibratedRed: 0.99, green: 0.87, blue: 0.59, alpha: 1)),
        (NSColor(calibratedRed: 0.76, green: 0.72, blue: 0.98, alpha: 1), NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.85, alpha: 1)),
        (NSColor(calibratedRed: 0.58, green: 0.82, blue: 0.75, alpha: 1), NSColor(calibratedRed: 0.76, green: 0.93, blue: 0.99, alpha: 1)),
    ]
    let pair = colors[variant % colors.count]
    let gradient = NSGradient(starting: pair.0, ending: pair.1)!
    gradient.draw(in: NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10), angle: CGFloat(30 + variant * 24))
    rounded(CGRect(x: rect.minX + 12, y: rect.minY + 12, width: rect.width - 24, height: 12), radius: 6, color: .white, alpha: 0.72)
    rounded(CGRect(x: rect.minX + 12, y: rect.minY + 31, width: rect.width * 0.58, height: 8), radius: 4, color: .white, alpha: 0.56)
    let circle = CGRect(x: rect.midX - 20, y: rect.midY - 4, width: 40, height: 40)
    NSColor.white.withAlphaComponent(0.72).setFill()
    NSBezierPath(ovalIn: circle).fill()
    text(["A", "B", "C", "D"][variant % 4], rect: CGRect(x: circle.minX, y: circle.minY + 8, width: circle.width, height: 24), size: 18, weight: .bold, color: pair.0, alignment: .center)
}

private func browserPage() {
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: designSize)).fill()
    rounded(CGRect(x: 26, y: 20, width: 1228, height: 64), radius: 14, color: .white)
    stroke(CGRect(x: 26, y: 20, width: 1228, height: 64), radius: 14, color: border)
    for x in [53, 78, 103] {
        NSColor(calibratedRed: x == 53 ? 1 : 0.74, green: x == 78 ? 0.73 : 0.38, blue: x == 103 ? 0.40 : 0.34, alpha: 1).setFill()
        NSBezierPath(ovalIn: CGRect(x: x, y: 43, width: 14, height: 14)).fill()
    }
    rounded(CGRect(x: 164, y: 34, width: 760, height: 38), radius: 19, color: NSColor(calibratedWhite: 0.95, alpha: 1))
    text("xiaohongshu.com/explore/inspiration-workflow", rect: CGRect(x: 192, y: 44, width: 700, height: 22), size: 14, color: muted)
    text(localized("遇到多图，\n不想把下载键敲出火星子？", "Too many images to save\none by one?"), rect: CGRect(x: 70, y: 114, width: 690, height: 78), size: 31, weight: .bold, lines: 2)
    text(localized("⌘ 点灵感球，整篇打包带走。", "⌘-click the bubble. Take the whole post with you."), rect: CGRect(x: 72, y: 198, width: 620, height: 28), size: 16, weight: .medium, color: muted)
    photo(CGRect(x: 70, y: 228, width: 310, height: 360), variant: 0)
    photo(CGRect(x: 400, y: 228, width: 310, height: 170), variant: 1)
    photo(CGRect(x: 400, y: 418, width: 310, height: 170), variant: 2)
    text(localized("双击摊开。只留下心动的画面。", "Double-click. Keep only what catches your eye."), rect: CGRect(x: 72, y: 615, width: 638, height: 52), size: 17, weight: .semibold, color: muted, lines: 2)
}

private let panel = CGRect(x: 824, y: 112, width: 380, height: 510)

private func button(_ title: String, rect: CGRect, primary: Bool = false) {
    rounded(rect, radius: 10, color: primary ? ink : NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.97, alpha: 1))
    text(title, rect: CGRect(x: rect.minX, y: rect.minY + 9, width: rect.width, height: 20), size: 12, weight: .bold, color: primary ? .white : NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.33, alpha: 1), alignment: .center)
}

private func stackPreview(_ rect: CGRect) {
    rounded(rect, radius: 12, color: NSColor(calibratedRed: 0.97, green: 0.985, blue: 1, alpha: 1))
    stroke(rect, radius: 12, color: NSColor(calibratedRed: 0.75, green: 0.86, blue: 0.99, alpha: 1), width: 1.3)
    for i in 0..<3 {
        let offset = CGFloat(i * 5)
        photo(CGRect(x: rect.minX + 10 + offset, y: rect.minY + 8 + offset, width: 64, height: 42), variant: i)
        stroke(CGRect(x: rect.minX + 10 + offset, y: rect.minY + 8 + offset, width: 64, height: 42), radius: 8, color: .white, width: 2)
    }
    rounded(CGRect(x: rect.maxX - 28, y: rect.maxY - 25, width: 24, height: 20), radius: 10, color: ink)
    text("4", rect: CGRect(x: rect.maxX - 28, y: rect.maxY - 21, width: 24, height: 16), size: 11, weight: .bold, color: .white, alignment: .center)
}

private func collectorPanel(mode: Int, selected: Set<Int>, toast: Bool) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 48
    shadow.shadowOffset = CGSize(width: 0, height: 18)
    shadow.set()
    rounded(panel, radius: 18, color: NSColor.white.withAlphaComponent(0.97))
    NSGraphicsContext.restoreGraphicsState()
    stroke(panel, radius: 18, color: NSColor(calibratedRed: 0.58, green: 0.64, blue: 0.72, alpha: 0.28))

    text(localized("灵感图片暂存", "Image Stash"), rect: CGRect(x: panel.minX + 14, y: panel.minY + 15, width: 190, height: 25), size: 16, weight: .bold)
    text(localized("每个帖子一行，双击展开", "One post per row. Double-click to expand."), rect: CGRect(x: panel.minX + 14, y: panel.minY + 40, width: 230, height: 20), size: 12, color: muted)
    button(localized("收图", "Collect"), rect: CGRect(x: panel.maxX - 132, y: panel.minY + 14, width: 62, height: 36))
    button(localized("收起", "Hide"), rect: CGRect(x: panel.maxX - 62, y: panel.minY + 14, width: 50, height: 36))

    if mode == 0 {
        text(localized("还没有图片暂存。点“收图”保存当前帖子。", "No saved images yet. Click Collect to capture this post."), rect: CGRect(x: panel.minX + 26, y: panel.minY + 220, width: panel.width - 52, height: 32), size: 13, weight: .semibold, color: NSColor(calibratedRed: 0.58, green: 0.64, blue: 0.72, alpha: 1), alignment: .center, lines: 2)
        return
    }

    let batch = CGRect(x: panel.minX + 14, y: panel.minY + 77, width: panel.width - 28, height: mode == 2 ? 358 : 94)
    rounded(batch, radius: 14, color: mode == 2 ? NSColor(calibratedRed: 0.94, green: 0.975, blue: 1, alpha: 0.96) : NSColor(calibratedRed: 0.97, green: 0.985, blue: 1, alpha: 0.78))
    stroke(batch, radius: 14, color: mode == 2 ? NSColor(calibratedRed: 0.38, green: 0.65, blue: 0.98, alpha: 0.55) : NSColor(calibratedRed: 0.58, green: 0.64, blue: 0.72, alpha: 0.26))
    stackPreview(CGRect(x: batch.minX + 10, y: batch.minY + 10, width: 88, height: 64))
    text(localized("只留下心动的画面", "Keep what catches your eye"), rect: CGRect(x: batch.minX + 108, y: batch.minY + 15, width: 226, height: 22), size: 13, weight: .bold)
    text(localized("4 张 · 已选 \(selected.count) 张", "4 images · \(selected.count) selected"), rect: CGRect(x: batch.minX + 108, y: batch.minY + 43, width: 210, height: 20), size: 12, color: muted)

    if mode == 2 {
        button(localized("全选", "All"), rect: CGRect(x: batch.minX + 10, y: batch.minY + 90, width: 54, height: 36))
        button(localized("移除", "Remove"), rect: CGRect(x: batch.minX + 72, y: batch.minY + 90, width: 62, height: 36))
        button(localized("保存选中", "Save selected"), rect: CGRect(x: batch.minX + 142, y: batch.minY + 90, width: 96, height: 36), primary: true)
        let itemWidth: CGFloat = 76
        for i in 0..<4 {
            let item = CGRect(x: batch.minX + 10 + CGFloat(i) * 84, y: batch.minY + 139, width: itemWidth, height: 143)
            let active = selected.contains(i)
            rounded(item, radius: 14, color: active ? NSColor(calibratedRed: 0.94, green: 0.975, blue: 1, alpha: 1) : .white)
            stroke(item, radius: 14, color: active ? NSColor(calibratedRed: 0.14, green: 0.51, blue: 0.85, alpha: 1) : border, width: active ? 2 : 1)
            photo(CGRect(x: item.minX + 7, y: item.minY + 8, width: 62, height: 101), variant: i)
            text("post_0\(i + 1).png", rect: CGRect(x: item.minX + 7, y: item.maxY - 26, width: 62, height: 18), size: 9, color: NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.41, alpha: 1))
            if active {
                rounded(CGRect(x: item.maxX - 27, y: item.minY + 10, width: 18, height: 18), radius: 5, color: NSColor(calibratedRed: 0.14, green: 0.51, blue: 0.85, alpha: 1))
                text("✓", rect: CGRect(x: item.maxX - 27, y: item.minY + 10, width: 18, height: 16), size: 11, weight: .bold, color: .white, alignment: .center)
            }
        }
    }

    text(localized("已暂存 1 行 / 4 张 · 已选 \(selected.count) 张", "1 post / 4 images · \(selected.count) selected"), rect: CGRect(x: panel.minX + 14, y: panel.maxY - 32, width: panel.width - 28, height: 20), size: 12, color: muted)
    if toast {
        rounded(CGRect(x: panel.minX + 68, y: panel.maxY - 78, width: 244, height: 42), radius: 21, color: ink, alpha: 0.95)
        text(localized("已保存 3 张 PNG", "Saved 3 PNG images"), rect: CGRect(x: panel.minX + 68, y: panel.maxY - 67, width: 244, height: 22), size: 13, weight: .bold, color: .white, alignment: .center)
    }
}

private func collectorCursor(_ t: Double) -> (CGPoint, Bool) {
    let collect = CGPoint(x: panel.maxX - 95, y: panel.minY + 32)
    let row = CGPoint(x: panel.minX + 180, y: panel.minY + 112)
    let item = CGPoint(x: panel.minX + 287, y: panel.minY + 280)
    let save = CGPoint(x: panel.minX + 183, y: panel.minY + 185)
    if t < 18.5 { return (CGPoint(x: 760, y: 180), false) }
    if t < 19.1 { return (interpolate(CGPoint(x: 760, y: 180), collect, (t - 18.5) / 0.6), false) }
    if t < 19.35 { return (collect, true) }
    if t < 20.15 { return (interpolate(collect, row, (t - 19.35) / 0.8), false) }
    if t < 20.55 { return (row, true) }
    if t < 21.6 { return (interpolate(row, item, (t - 20.55) / 1.05), false) }
    if t < 21.9 { return (item, true) }
    if t < 22.7 { return (interpolate(item, row, (t - 21.9) / 0.8), false) }
    if t < 23.05 { return (row, true) }
    if t < 24.15 { return (row, false) }
    if t < 24.55 { return (row, true) }
    if t < 25.6 { return (interpolate(row, save, (t - 24.55) / 1.05), false) }
    return (save, t < 26.1)
}

private func drawCollectorScene(_ t: Double) {
    browserPage()
    let mode: Int
    if t < 19.4 { mode = 0 }
    else if t < 20.65 { mode = 1 }
    else if t < 23.2 { mode = 2 }
    else if t < 24.65 { mode = 1 }
    else { mode = 2 }
    let selected: Set<Int> = t >= 22.0 ? [0, 1, 3] : [0, 1, 2, 3]
    collectorPanel(mode: mode, selected: selected, toast: t >= 26.1)
    bubble(center: CGPoint(x: 1222, y: 360), radius: 31)
    if t < 19.4 {
        rounded(CGRect(x: 1000, y: 645, width: 204, height: 38), radius: 19, color: ink, alpha: 0.9)
        text(localized("⌘ + 点击悬浮球收图", "⌘ + click the bubble to collect"), rect: CGRect(x: 988, y: 655, width: 216, height: 20), size: 12, weight: .bold, color: .white, alignment: .center)
    }
    let (p, down) = collectorCursor(t)
    cursor(at: p, down: down)
    for event in [19.18, 20.35, 20.52, 21.75, 22.88, 23.03, 24.35, 24.52, 25.9] {
        clickRing(at: p, time: t, event: event)
    }
}

private func drawIntro(_ t: Double) {
    bg.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: designSize)).fill()
    bubble(center: CGPoint(x: 640, y: 190), radius: 62)
    text(localized("灵感刚冒头，\n就准备开溜？", "An idea just popped up…\nand it’s already running away?"), rect: CGRect(x: 260, y: 282, width: 760, height: 110), size: 44, weight: .bold, alignment: .center, lines: 2)
    text(localized("别急，灵感悬浮球来接住。", "Don’t worry. Linggan catches it."), rect: CGRect(x: 260, y: 402, width: 760, height: 45), size: 23, weight: .medium, color: muted, alignment: .center)
    rounded(CGRect(x: 500, y: 450, width: 280, height: 42), radius: 21, color: .white)
    stroke(CGRect(x: 500, y: 450, width: 280, height: 42), radius: 21, color: border)
    text(localized("接住 · 捞回 · 组合 · 收图", "CATCH · REEL BACK · BUILD · COLLECT"), rect: CGRect(x: 480, y: 462, width: 320, height: 22), size: 13, weight: .bold, color: NSColor.systemBlue, alignment: .center)
    let opacity = CGFloat(clamp((t - 1.05) / 0.5))
    text("▶", rect: CGRect(x: 620, y: 542, width: 40, height: 36), size: 25, weight: .bold, color: blue, alignment: .center, alpha: opacity)
}

private func drawOutro(_ t: Double) {
    bg.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: designSize)).fill()
    bubble(center: CGPoint(x: 640, y: 176), radius: 54)
    text(localized("灵感悬浮 ing。\n接住散落的灵感。", "Inspiration, floating.\nCatch the scattered sparks."), rect: CGRect(x: 150, y: 264, width: 980, height: 112), size: 40, weight: .bold, alignment: .center, lines: 2)
    text(localized("在鱼的 7 天记忆消失之前，拼出你的下一步。", "Before fish memory fades, build what comes next."), rect: CGRect(x: 230, y: 390, width: 820, height: 44), size: 21, weight: .medium, color: muted, alignment: .center)
    rounded(CGRect(x: 477, y: 465, width: 326, height: 54), radius: 27, color: ink)
    text("github.com/IvyCHEN03/clipboard-station", rect: CGRect(x: 477, y: 482, width: 326, height: 25), size: 13, weight: .bold, color: .white, alignment: .center)
}

private func render(time: Double) -> NSImage {
    let image = NSImage(size: canvasSize)
    image.lockFocusFlipped(true)
    let scale = NSAffineTransform()
    scale.scale(by: canvasSize.width / designSize.width)
    scale.concat()
    if time < 1.8 {
        drawIntro(time)
    } else if time < 17.2 {
        drawStationScene(time)
    } else if time < 27.7 {
        drawCollectorScene(time)
    } else {
        drawOutro(time)
    }
    image.unlockFocus()
    return image
}

private func storyTime(for outputTime: Double) -> Double {
    guard isTeaser else { return outputTime }
    let segments: [(Range<Double>, Range<Double>)] = [
        (0.0..<2.6, 0.0..<1.8),
        (2.6..<7.2, 2.0..<6.5),
        (7.2..<13.2, 7.0..<13.6),
        (13.2..<15.7, 13.8..<16.6),
        (15.7..<22.6, 17.6..<26.8),
        (22.6..<26.0, 28.0..<31.8),
    ]
    guard let segment = segments.first(where: { $0.0.contains(outputTime) }) else {
        return 31.8
    }
    let source = segment.0
    let target = segment.1
    let progress = (outputTime - source.lowerBound) / (source.upperBound - source.lowerBound)
    return target.lowerBound + progress * (target.upperBound - target.lowerBound)
}

private func makeMusic(at url: URL, duration: Double) throws {
    try? FileManager.default.removeItem(at: url)
    let sampleRate = 48_000.0
    let channelCount: AVAudioChannelCount = 2
    let frameTotal = AVAudioFrameCount(duration * sampleRate)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameTotal),
          let channels = buffer.floatChannelData
    else { fatalError("Could not create music buffer") }
    buffer.frameLength = frameTotal

    let tempo = 100.0
    let beatLength = 60.0 / tempo
    let chords: [[Double]] = [
        [261.63, 329.63, 392.00, 493.88],
        [220.00, 261.63, 329.63, 392.00],
        [174.61, 220.00, 261.63, 329.63],
        [196.00, 246.94, 293.66, 440.00],
    ]

    for frame in 0..<Int(frameTotal) {
        let time = Double(frame) / sampleRate
        let beat = time / beatLength
        let chordIndex = Int(beat / 4) % chords.count
        let chord = chords[chordIndex]
        let chordPhase = beat.truncatingRemainder(dividingBy: 4) / 4
        let chordEnvelope = min(1, chordPhase * 8) * min(1, (1 - chordPhase) * 5)

        var left = 0.0
        var right = 0.0
        for (noteIndex, frequency) in chord.enumerated() {
            let pan = Double(noteIndex) / Double(chord.count - 1)
            let pad = sin(2 * Double.pi * frequency * time) * 0.018 * chordEnvelope
            let air = sin(2 * Double.pi * frequency * 2 * time + 0.35) * 0.004 * chordEnvelope
            left += (pad + air) * (1.15 - pan * 0.3)
            right += (pad + air) * (0.85 + pan * 0.3)
        }

        let halfBeat = beat * 2
        let step = Int(floor(halfBeat))
        let stepTime = halfBeat - floor(halfBeat)
        let pluckFrequency = chord[step % chord.count] * (step % 8 == 7 ? 2 : 1)
        let pluckEnvelope = exp(-stepTime * 7.5)
        let pluck = (
            sin(2 * Double.pi * pluckFrequency * time) +
            0.28 * sin(2 * Double.pi * pluckFrequency * 2 * time)
        ) * 0.052 * pluckEnvelope
        left += pluck * (step % 2 == 0 ? 1.0 : 0.72)
        right += pluck * (step % 2 == 0 ? 0.72 : 1.0)

        let twoBeatPhase = (beat.truncatingRemainder(dividingBy: 2)) * beatLength
        if twoBeatPhase < 0.32 {
            let kickEnvelope = exp(-twoBeatPhase * 13)
            let kickFrequency = 72 - 24 * min(twoBeatPhase / 0.32, 1)
            let kick = sin(2 * Double.pi * kickFrequency * time) * 0.075 * kickEnvelope
            left += kick
            right += kick
        }

        let offBeatPhase = (halfBeat + 1).truncatingRemainder(dividingBy: 2)
        if offBeatPhase < 0.22 {
            let shimmerEnvelope = exp(-offBeatPhase * 18)
            let shimmer = sin(time * 12_347) * sin(time * 7_919) * 0.008 * shimmerEnvelope
            left += shimmer
            right -= shimmer * 0.65
        }

        let fadeIn = min(1, time / 0.9)
        let fadeOut = min(1, max(0, duration - time) / 1.5)
        let master = fadeIn * fadeOut * 0.92
        channels[0][frame] = Float(tanh(left) * master)
        channels[1][frame] = Float(tanh(right) * master)
    }

    var fileSettings = format.settings
    fileSettings[AVLinearPCMIsNonInterleaved] = false
    let file = try AVAudioFile(forWriting: url, settings: fileSettings)
    try file.write(from: buffer)
}

private func combine(videoURL: URL, musicURL: URL, outputURL: URL) async throws {
    let videoAsset = AVURLAsset(url: videoURL)
    let musicAsset = AVURLAsset(url: musicURL)
    let videoDuration = try await videoAsset.load(.duration)
    guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
          let sourceMusic = try await musicAsset.loadTracks(withMediaType: .audio).first
    else { fatalError("Could not load generated media tracks") }

    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    else { fatalError("Could not create composition tracks") }

    try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceVideo, at: .zero)
    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceMusic, at: .zero)
    videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)

    try? FileManager.default.removeItem(at: outputURL)
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        fatalError("Could not create final exporter")
    }
    try await exporter.export(to: outputURL, as: .mp4)
}

private func pixelBuffer(from image: NSImage, pool: CVPixelBufferPool) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
        fatalError("Could not create pixel buffer")
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer),
          let context = CGContext(
            data: base,
            width: Int(canvasSize.width),
            height: Int(canvasSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
          ),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { fatalError("Could not draw frame") }
    context.draw(cgImage, in: CGRect(origin: .zero, size: canvasSize))
    return buffer
}

try? FileManager.default.removeItem(at: silentVideoURL)
let writer = try AVAssetWriter(outputURL: silentVideoURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(canvasSize.width),
    AVVideoHeightKey: Int(canvasSize.height),
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 16_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: Int(canvasSize.width),
    kCVPixelBufferHeightKey as String: Int(canvasSize.height),
])
guard writer.canAdd(input) else { fatalError("Cannot add video input") }
writer.add(input)
guard writer.startWriting() else { fatalError(writer.error?.localizedDescription ?? "Writer failed") }
writer.startSession(atSourceTime: .zero)

for frame in 0..<frameCount {
    while !input.isReadyForMoreMediaData {
        try await Task.sleep(for: .milliseconds(2))
    }
    let time = Double(frame) / Double(fps)
    let image = render(time: storyTime(for: time))
    let buffer = pixelBuffer(from: image, pool: adaptor.pixelBufferPool!)
    adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
    if frame % 120 == 0 { print("Rendering \(frame)/\(frameCount)") }
}
input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError(writer.error?.localizedDescription ?? "Export failed") }

try makeMusic(at: musicURL, duration: duration)
try await combine(videoURL: silentVideoURL, musicURL: musicURL, outputURL: outputURL)
try? FileManager.default.removeItem(at: silentVideoURL)
try? FileManager.default.removeItem(at: musicURL)

let cover = render(time: 0.8)
guard let tiff = cover.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not create cover") }
try png.write(to: coverURL)
print("Created \(outputURL.path)")
print("Created \(coverURL.path)")
