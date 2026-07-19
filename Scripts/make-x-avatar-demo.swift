#!/usr/bin/env swift

import AppKit
import AVFoundation
import Foundation
import QuartzCore

private struct NarrationSegment {
    let start: Double
    let end: Double
    let spokenText: String
    let caption: String
    let side: Side

    enum Side {
        case left
        case right
    }
}

private let duration = 98.0
private let canvasSize = CGSize(width: 1920, height: 1080)
private let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceURL = repo.appendingPathComponent("docs/assets/social/linggan-x-teaser-cn-1080p.mp4")
private let avatarURL = repo.appendingPathComponent("docs/assets/social/avatar/linggan-host.png")
private let outputURL = repo.appendingPathComponent("docs/assets/social/linggan-x-avatar-cn-1080p.mp4")
private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("linggan-avatar-demo", isDirectory: true)

private enum Timeline {
    static let polishStart = 38.6
    static let polishEnd = 45.55
    static let imageStart = 45.6
    static let imageEnd = 56.08
    static let archiveStart = 72.8
    static let archiveEnd = 80.8
    static let memoryStart = 81.0
    static let memoryEnd = 90.4
}

private let segments: [NarrationSegment] = [
    .init(start: 0.4, end: 6.8, spokenText: "我最近总在好几个 AI 之间来回跑。灵感很多，剪贴板只有一个，多少有点不讲武德。", caption: "灵感很多，剪贴板只有一个。\n多少有点不讲武德。", side: .right),
    .init(start: 7.0, end: 15.6, spokenText: "所以我做了灵感悬浮球。文字、截图、表格，按下 Command C，它就顺手接住；同一句复制三次，也会老老实实留下三条。", caption: "文字、截图、表格，⌘C 就接住。\n重复复制，也不偷偷合并。", side: .right),
    .init(start: 15.8, end: 23.4, spokenText: "东西多了也不怕。搜一句话，点几个标签，再选今天、三天或者鱼的七天记忆，想找的那条很快就浮上来。", caption: "搜索 + 多标签 + 时间。\n想找的那条，自己浮上来。", side: .right),
    .init(start: 23.6, end: 29.9, spokenText: "筛完以后，全选、复制、删除和倒带都只管眼前这些，不会隔着筛选条件误伤后面的内容。", caption: "批量操作只作用于当前筛选结果。\n倒带一下，顺序也能反过来看。", side: .right),
    .init(start: 30.1, end: 38.4, spokenText: "看到顺眼的句子，就拖进组合框。积木中间可以直接补字，先写一句过渡，再塞下一块，顺序完全按你的脑回路来。", caption: "把句子拖成积木。\n中间想补什么，直接写。", side: .right),
    .init(start: 38.6, end: 45.55, spokenText: "懒得自己捋逻辑，就点 Polish。它只拿当前组合的内容去润色，补上衔接，原来的积木和顺序都还在。", caption: "点一下 Polish。\n碎片变全文，原积木不动。", side: .right),
    .init(start: 45.6, end: 56.08, spokenText: "图片这里我重新做了一遍。Command C 复制一张图，它会直接变成灵感球里的一栏，不是文件路径。抓住这张图片往文档里一拖，放进去的就是图片本身。", caption: "⌘C 复制图片 → 变成图片栏。\n直接拖进文档，带走图片本身。", side: .left),
    .init(start: 56.1, end: 64.62, spokenText: "碰到小红书或者公众号这种多图帖子，也不用右键二十次。Command 点一下悬浮球，当前帖子自己的图片会一起叠进暂存栏。", caption: "多图帖子不用右键二十次。\n⌘ 点悬浮球，一次收进暂存栏。", side: .left),
    .init(start: 64.7, end: 72.72, spokenText: "双击这一行摊开，哪张心动就勾哪张，再保存成真正的 PNG。头像、表情包和重复图，会尽量替你挡在外面。", caption: "双击摊开，单张勾选。\n只保存心动的 PNG。", side: .left),
    .init(start: 72.8, end: 80.8, spokenText: "这次还在更新一个很实用的小按钮：存网页。点一下，同时留下可搜索的 HTML 和从头到底的完整网页截图。", caption: "新功能：存网页。\nHTML + 从头到底的完整 PNG。", side: .left),
    .init(start: 81.0, end: 90.4, spokenText: "鱼的七天记忆会提醒你什么时候快忘了；删错的内容先去回忆浅滩，不会立刻消失。固定位置、快捷键和开机启动，也都能按自己的习惯调。", caption: "7 天记忆提醒 + 回忆浅滩。\n位置、快捷键、开机启动都能调。", side: .right),
    .init(start: 90.6, end: 97.6, spokenText: "内容默认留在本地，AI 也是你点了才用。它不替你想，只负责把那些差点跑掉的灵感，先稳稳接住。", caption: "默认本地保存，AI 按需才用。\n把差点跑掉的灵感，稳稳接住。", side: .right),
]

private func makeNarrationFiles() throws -> [URL] {
    try? FileManager.default.removeItem(at: tempDirectory)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    return try segments.enumerated().map { index, segment in
        let url = tempDirectory.appendingPathComponent("voice-\(index).aiff")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "Shelley (中文（中国大陆）)", "-r", "245", "-o", url.path, segment.spokenText]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "LingganAvatarDemo", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to synthesize narration segment \(index)",
            ])
        }
        let audioFile = try AVAudioFile(forReading: url)
        let spokenDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let availableDuration = segment.end - segment.start
        if spokenDuration > availableDuration {
            print(String(format: "Warning: narration %d is %.2fs but only %.2fs is available", index, spokenDuration, availableDuration))
        }
        return url
    }
}

private func cgImage(at url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let result = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        throw NSError(domain: "LingganAvatarDemo", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not load avatar image at \(url.path)",
        ])
    }
    return result
}

private func normalizedTimes(_ absoluteTimes: [Double]) -> [NSNumber] {
    absoluteTimes.map { NSNumber(value: min(max($0 / duration, 0), 1)) }
}

private func holdAnimation(
    keyPath: String,
    values: [Any],
    times: [Double],
    calculationMode: CAAnimationCalculationMode = .linear
) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = normalizedTimes(times)
    animation.duration = duration
    animation.beginTime = AVCoreAnimationBeginTimeAtZero
    animation.calculationMode = calculationMode
    animation.isRemovedOnCompletion = false
    animation.fillMode = .both
    return animation
}

private func addTimedOpacity(to layer: CALayer, start: Double, end: Double) {
    let fade = 0.18
    layer.opacity = 0
    layer.add(
        holdAnimation(
            keyPath: "opacity",
            values: [0, 0, 1, 1, 0, 0],
            times: [0, max(0, start - fade), start, end, min(duration, end + fade), duration]
        ),
        forKey: "visibility"
    )
}

private func textLayer(_ value: String, frame: CGRect, size: CGFloat, color: NSColor, weight: NSFont.Weight = .bold) -> CATextLayer {
    let layer = CATextLayer()
    layer.frame = frame
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    style.lineSpacing = 4
    let attributed = NSAttributedString(
        string: value,
        attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
    )
    let image = NSImage(size: frame.size)
    image.lockFocusFlipped(true)
    attributed.draw(in: CGRect(origin: .zero, size: frame.size))
    image.unlockFocus()
    layer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    layer.contentsGravity = .resizeAspect
    layer.contentsScale = 2
    return layer
}

private func captionLayer(for segment: NarrationSegment) -> CALayer {
    let width: CGFloat = segment.side == .right ? 500 : 520
    let originX: CGFloat = segment.side == .right ? 1328 : 78
    let container = CALayer()
    container.frame = CGRect(x: originX, y: 338, width: width, height: 118)
    container.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
    container.cornerRadius = 24
    container.borderWidth = 2
    container.borderColor = NSColor(calibratedRed: 0.63, green: 0.83, blue: 0.98, alpha: 0.86).cgColor
    container.shadowColor = NSColor.black.cgColor
    container.shadowOpacity = 0.16
    container.shadowRadius = 18
    container.shadowOffset = CGSize(width: 0, height: -6)

    let accent = CALayer()
    accent.frame = CGRect(x: 18, y: 22, width: 7, height: 74)
    accent.backgroundColor = NSColor(calibratedRed: 0.32, green: 0.67, blue: 0.96, alpha: 1).cgColor
    accent.cornerRadius = 3.5
    container.addSublayer(accent)
    container.addSublayer(textLayer(segment.caption, frame: CGRect(x: 42, y: 18, width: width - 62, height: 84), size: 26, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    addTimedOpacity(to: container, start: segment.start, end: segment.end)
    return container
}

private func cameraVisibilityAnimation(for side: NarrationSegment.Side) -> CAKeyframeAnimation {
    var values: [Any] = [0.0]
    var times: [Double] = [0.0]
    let fade = 0.12
    for segment in segments where segment.side == side {
        let fadeIn = max(0, segment.start - fade)
        if fadeIn > times.last! {
            values.append(0.0)
            times.append(fadeIn)
        }
        values.append(1.0)
        times.append(segment.start)
        values.append(1.0)
        times.append(segment.end)
        values.append(0.0)
        times.append(min(duration, segment.end + fade))
    }
    if times.last! < duration {
        values.append(0.0)
        times.append(duration)
    }
    return holdAnimation(keyPath: "opacity", values: values, times: times)
}

private func avatarCameraLayer(image: CGImage, side: NarrationSegment.Side) -> CALayer {
    let size: CGFloat = 318
    let camera = CALayer()
    camera.bounds = CGRect(x: 0, y: 0, width: size, height: size)
    camera.position = side == .right ? CGPoint(x: 1690, y: 170) : CGPoint(x: 230, y: 172)
    camera.backgroundColor = NSColor.white.cgColor
    camera.cornerRadius = size / 2
    camera.borderWidth = 7
    camera.borderColor = NSColor(calibratedRed: 0.58, green: 0.81, blue: 0.99, alpha: 1).cgColor
    camera.shadowColor = NSColor.systemBlue.cgColor
    camera.shadowOpacity = 0.22
    camera.shadowRadius = 28
    camera.shadowOffset = CGSize(width: 0, height: -8)
    camera.masksToBounds = false

    let avatar = CALayer()
    avatar.frame = CGRect(x: 7, y: 7, width: size - 14, height: size - 14)
    avatar.contents = image
    avatar.contentsGravity = .resizeAspectFill
    avatar.cornerRadius = (size - 14) / 2
    avatar.masksToBounds = true
    camera.addSublayer(avatar)

    // A still portrait looks more natural with a gentle camera breath than a synthetic mouth overlay.
    let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
    bob.values = [0, 1.5, 0, -1, 0]
    bob.duration = 5.2
    bob.beginTime = AVCoreAnimationBeginTimeAtZero
    bob.repeatCount = .infinity
    camera.add(bob, forKey: "host-bob")

    camera.add(cameraVisibilityAnimation(for: side), forKey: "camera-cut")
    camera.add(
        holdAnimation(
            keyPath: "transform.scale",
            values: [1.0, 1.012, 1.0, 0.996, 1.0],
            times: [0, 15, 30, 45, duration],
            calculationMode: .cubic
        ),
        forKey: "camera-breath"
    )

    let cameraBadge = CALayer()
    cameraBadge.frame = CGRect(x: 18, y: size - 48, width: 82, height: 30)
    cameraBadge.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 0.90).cgColor
    cameraBadge.cornerRadius = 15
    let dot = CALayer()
    dot.frame = CGRect(x: 11, y: 10, width: 10, height: 10)
    dot.cornerRadius = 5
    dot.backgroundColor = NSColor.systemRed.cgColor
    cameraBadge.addSublayer(dot)
    cameraBadge.addSublayer(textLayer("LIVE", frame: CGRect(x: 28, y: 5, width: 46, height: 20), size: 14, color: .white))
    camera.addSublayer(cameraBadge)

    return camera
}

private func polishBadge() -> CALayer {
    let badge = CALayer()
    badge.frame = CGRect(x: 1290, y: 866, width: 480, height: 94)
    badge.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 0.95).cgColor
    badge.cornerRadius = 24
    badge.shadowColor = NSColor.systemBlue.cgColor
    badge.shadowOpacity = 0.22
    badge.shadowRadius = 18
    badge.addSublayer(textLayer("AI POLISH  ·  碎片 → 完整全文", frame: CGRect(x: 28, y: 27, width: 424, height: 44), size: 27, color: .white))
    addTimedOpacity(to: badge, start: Timeline.polishStart, end: Timeline.polishEnd)
    return badge
}

private func imageDragDemoLayer() -> CALayer {
    let panel = CALayer()
    panel.frame = CGRect(x: 585, y: 430, width: 1240, height: 480)
    panel.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
    panel.cornerRadius = 28
    panel.borderWidth = 2
    panel.borderColor = NSColor(calibratedRed: 0.60, green: 0.82, blue: 0.99, alpha: 0.88).cgColor
    panel.shadowColor = NSColor.black.cgColor
    panel.shadowOpacity = 0.18
    panel.shadowRadius = 30
    panel.shadowOffset = CGSize(width: 0, height: -10)
    addTimedOpacity(to: panel, start: Timeline.imageStart, end: Timeline.imageEnd)

    panel.addSublayer(textLayer("⌘C 复制图片，它会直接变成灵感球里的一栏", frame: CGRect(x: 34, y: 414, width: 800, height: 42), size: 29, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    panel.addSublayer(textLayer("不是文件地址。抓住图片，直接拖进文档。", frame: CGRect(x: 34, y: 378, width: 760, height: 30), size: 18, color: NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.54, alpha: 1), weight: .medium))

    let command = CALayer()
    command.frame = CGRect(x: 930, y: 392, width: 270, height: 54)
    command.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 0.96).cgColor
    command.cornerRadius = 18
    command.addSublayer(textLayer("⌘ C   复制图片", frame: CGRect(x: 28, y: 14, width: 218, height: 28), size: 20, color: .white))
    command.add(holdAnimation(keyPath: "transform.scale", values: [1, 1, 1.07, 1, 1], times: [0, Timeline.imageStart + 0.3, Timeline.imageStart + 0.8, Timeline.imageStart + 1.2, duration], calculationMode: .cubic), forKey: "command-press")
    panel.addSublayer(command)

    let station = CALayer()
    station.frame = CGRect(x: 34, y: 46, width: 520, height: 310)
    station.backgroundColor = NSColor(calibratedRed: 0.965, green: 0.982, blue: 1, alpha: 1).cgColor
    station.cornerRadius = 22
    station.borderWidth = 1.5
    station.borderColor = NSColor(calibratedRed: 0.73, green: 0.85, blue: 0.98, alpha: 1).cgColor
    panel.addSublayer(station)

    let bubble = CALayer()
    bubble.frame = CGRect(x: 22, y: 242, width: 48, height: 48)
    bubble.backgroundColor = NSColor(calibratedRed: 0.47, green: 0.76, blue: 0.98, alpha: 1).cgColor
    bubble.cornerRadius = 24
    bubble.addSublayer(textLayer("✦", frame: CGRect(x: 8, y: 7, width: 32, height: 34), size: 24, color: .white))
    station.addSublayer(bubble)
    station.addSublayer(textLayer("灵感悬浮球", frame: CGRect(x: 84, y: 251, width: 230, height: 32), size: 22, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    station.addSublayer(textLayer("图片刚复制，就在这里落脚", frame: CGRect(x: 84, y: 221, width: 310, height: 25), size: 16, color: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.56, alpha: 1), weight: .medium))

    let empty = textLayer("还没有图片片段", frame: CGRect(x: 120, y: 102, width: 280, height: 32), size: 20, color: NSColor(calibratedRed: 0.58, green: 0.64, blue: 0.72, alpha: 1), weight: .medium)
    addTimedOpacity(to: empty, start: Timeline.imageStart, end: Timeline.imageStart + 1.5)
    station.addSublayer(empty)

    let row = CALayer()
    row.frame = CGRect(x: 20, y: 28, width: 480, height: 170)
    row.backgroundColor = NSColor.white.cgColor
    row.cornerRadius = 18
    row.borderWidth = 2
    row.borderColor = NSColor.systemBlue.withAlphaComponent(0.60).cgColor
    row.shadowColor = NSColor.black.cgColor
    row.shadowOpacity = 0.10
    row.shadowRadius = 12
    row.shadowOffset = CGSize(width: 0, height: -4)
    addTimedOpacity(to: row, start: Timeline.imageStart + 1.5, end: Timeline.imageEnd)
    station.addSublayer(row)

    func imagePreview(frame: CGRect) -> CALayer {
        let preview = CAGradientLayer()
        preview.frame = frame
        preview.cornerRadius = 14
        preview.colors = [
            NSColor(calibratedRed: 0.54, green: 0.84, blue: 0.98, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.77, green: 0.72, blue: 0.98, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.99, green: 0.72, blue: 0.81, alpha: 1).cgColor,
        ]
        preview.startPoint = CGPoint(x: 0, y: 1)
        preview.endPoint = CGPoint(x: 1, y: 0)
        preview.addSublayer(textLayer("✦", frame: CGRect(x: frame.width / 2 - 32, y: frame.height / 2 - 33, width: 64, height: 66), size: 46, color: .white))
        return preview
    }

    row.addSublayer(imagePreview(frame: CGRect(x: 14, y: 14, width: 190, height: 142)))
    row.addSublayer(textLayer("图片片段", frame: CGRect(x: 224, y: 102, width: 180, height: 30), size: 22, color: NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.26, alpha: 1)))
    row.addSublayer(textLayer("刚刚通过 ⌘C 收进来", frame: CGRect(x: 224, y: 68, width: 220, height: 24), size: 16, color: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.56, alpha: 1), weight: .medium))
    row.addSublayer(textLayer("可复制 · 可拖拽", frame: CGRect(x: 224, y: 34, width: 210, height: 24), size: 16, color: NSColor.systemBlue, weight: .semibold))

    let target = CALayer()
    target.frame = CGRect(x: 590, y: 46, width: 610, height: 310)
    target.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.985, blue: 1, alpha: 1).cgColor
    target.cornerRadius = 20
    let targetBorder = CAShapeLayer()
    targetBorder.frame = target.bounds
    targetBorder.path = CGPath(roundedRect: target.bounds.insetBy(dx: 2, dy: 2), cornerWidth: 18, cornerHeight: 18, transform: nil)
    targetBorder.fillColor = NSColor.clear.cgColor
    targetBorder.strokeColor = NSColor.systemBlue.withAlphaComponent(0.62).cgColor
    targetBorder.lineWidth = 3
    targetBorder.lineDashPattern = [10, 8]
    target.addSublayer(targetBorder)
    target.addSublayer(textLayer("文档正文", frame: CGRect(x: 28, y: 246, width: 180, height: 34), size: 23, color: NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.35, alpha: 1)))
    target.addSublayer(textLayer("这一段在整理研究记录。\n把刚才的图片直接放在下面：", frame: CGRect(x: 28, y: 166, width: 520, height: 62), size: 18, color: NSColor(calibratedRed: 0.38, green: 0.44, blue: 0.52, alpha: 1), weight: .medium))
    target.addSublayer(textLayer("拖到这里", frame: CGRect(x: 28, y: 98, width: 250, height: 30), size: 18, color: NSColor(calibratedRed: 0.46, green: 0.52, blue: 0.60, alpha: 1), weight: .medium))
    panel.addSublayer(target)

    let dragCard = imagePreview(frame: CGRect(x: 0, y: 0, width: 190, height: 142))
    dragCard.position = CGPoint(x: 149, y: 159)
    dragCard.shadowColor = NSColor.black.cgColor
    dragCard.shadowOpacity = 0.20
    dragCard.shadowRadius = 16
    dragCard.shadowOffset = CGSize(width: 0, height: -8)
    addTimedOpacity(to: dragCard, start: Timeline.imageStart + 4.0, end: Timeline.imageEnd - 0.2)
    dragCard.add(holdAnimation(
        keyPath: "position",
        values: [NSValue(point: CGPoint(x: 149, y: 159)), NSValue(point: CGPoint(x: 149, y: 159)), NSValue(point: CGPoint(x: 902, y: 152)), NSValue(point: CGPoint(x: 902, y: 152))],
        times: [0, Timeline.imageStart + 4.0, Timeline.imageStart + 8.6, duration],
        calculationMode: .cubic
    ), forKey: "drag-image")
    dragCard.add(holdAnimation(keyPath: "transform.scale", values: [1, 1, 0.82, 0.82], times: [0, Timeline.imageStart + 4.0, Timeline.imageStart + 8.6, duration], calculationMode: .cubic), forKey: "drop-scale")
    panel.addSublayer(dragCard)

    let pointer = textLayer("↖", frame: CGRect(x: 0, y: 0, width: 48, height: 48), size: 34, color: NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.20, alpha: 1))
    pointer.position = CGPoint(x: 232, y: 104)
    addTimedOpacity(to: pointer, start: Timeline.imageStart + 3.9, end: Timeline.imageStart + 9.0)
    pointer.add(holdAnimation(
        keyPath: "position",
        values: [NSValue(point: CGPoint(x: 232, y: 104)), NSValue(point: CGPoint(x: 232, y: 104)), NSValue(point: CGPoint(x: 985, y: 99)), NSValue(point: CGPoint(x: 985, y: 99))],
        times: [0, Timeline.imageStart + 4.0, Timeline.imageStart + 8.6, duration],
        calculationMode: .cubic
    ), forKey: "drag-pointer")
    panel.addSublayer(pointer)

    let success = CALayer()
    success.frame = CGRect(x: 755, y: 66, width: 320, height: 50)
    success.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.57, blue: 0.34, alpha: 0.96).cgColor
    success.cornerRadius = 24
    success.addSublayer(textLayer("✓  文档里放入的是图片本身", frame: CGRect(x: 24, y: 12, width: 280, height: 26), size: 18, color: .white))
    addTimedOpacity(to: success, start: Timeline.imageStart + 8.4, end: Timeline.imageEnd)
    panel.addSublayer(success)

    return panel
}

private func webpageArchiveDemoLayer() -> CALayer {
    let panel = CALayer()
    panel.frame = CGRect(x: 585, y: 430, width: 1240, height: 480)
    panel.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
    panel.cornerRadius = 28
    panel.borderWidth = 2
    panel.borderColor = NSColor(calibratedRed: 0.60, green: 0.82, blue: 0.99, alpha: 0.88).cgColor
    panel.shadowColor = NSColor.black.cgColor
    panel.shadowOpacity = 0.18
    panel.shadowRadius = 30
    panel.shadowOffset = CGSize(width: 0, height: -10)
    addTimedOpacity(to: panel, start: Timeline.archiveStart, end: Timeline.archiveEnd)

    panel.addSublayer(textLayer("网页太长，也不用截图再拼图", frame: CGRect(x: 34, y: 414, width: 720, height: 42), size: 29, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    panel.addSublayer(textLayer("点一次“存网页”，同时留下可搜索的 HTML 和完整网页 PNG。", frame: CGRect(x: 34, y: 378, width: 860, height: 30), size: 18, color: NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.54, alpha: 1), weight: .medium))

    let browser = CALayer()
    browser.frame = CGRect(x: 34, y: 42, width: 720, height: 314)
    browser.backgroundColor = NSColor(calibratedRed: 0.965, green: 0.978, blue: 0.99, alpha: 1).cgColor
    browser.cornerRadius = 20
    browser.borderWidth = 1.5
    browser.borderColor = NSColor(calibratedRed: 0.83, green: 0.87, blue: 0.92, alpha: 1).cgColor
    panel.addSublayer(browser)
    for (index, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
        let dot = CALayer()
        dot.frame = CGRect(x: 18 + CGFloat(index) * 24, y: 278, width: 12, height: 12)
        dot.backgroundColor = color.cgColor
        dot.cornerRadius = 6
        browser.addSublayer(dot)
    }
    let address = CALayer()
    address.frame = CGRect(x: 110, y: 267, width: 450, height: 34)
    address.backgroundColor = NSColor.white.cgColor
    address.cornerRadius = 17
    address.addSublayer(textLayer("article.example.com/long-page", frame: CGRect(x: 22, y: 8, width: 390, height: 20), size: 14, color: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.56, alpha: 1), weight: .medium))
    browser.addSublayer(address)
    let sectionColors = [
        NSColor(calibratedRed: 0.85, green: 0.94, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.86, green: 0.96, blue: 0.91, alpha: 1),
        NSColor(calibratedRed: 0.97, green: 0.91, blue: 0.96, alpha: 1),
    ]
    for index in 0..<3 {
        let pageSection = CALayer()
        pageSection.frame = CGRect(x: 24, y: 25 + CGFloat(index) * 78, width: 672, height: 66)
        pageSection.backgroundColor = sectionColors[index].cgColor
        pageSection.cornerRadius = 14
        pageSection.addSublayer(textLayer(["开头：研究背景", "中段：关键证据", "结尾：下一步"][index], frame: CGRect(x: 18, y: 22, width: 260, height: 24), size: 16, color: NSColor(calibratedRed: 0.17, green: 0.23, blue: 0.31, alpha: 1), weight: .semibold))
        browser.addSublayer(pageSection)
    }

    let collector = CALayer()
    collector.frame = CGRect(x: 786, y: 42, width: 420, height: 314)
    collector.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.985, blue: 1, alpha: 1).cgColor
    collector.cornerRadius = 20
    collector.borderWidth = 1.5
    collector.borderColor = NSColor(calibratedRed: 0.72, green: 0.85, blue: 0.98, alpha: 1).cgColor
    panel.addSublayer(collector)
    collector.addSublayer(textLayer("灵感图片暂存", frame: CGRect(x: 20, y: 266, width: 190, height: 28), size: 20, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))

    let archiveButton = CALayer()
    archiveButton.frame = CGRect(x: 205, y: 254, width: 82, height: 42)
    archiveButton.backgroundColor = NSColor.systemBlue.cgColor
    archiveButton.cornerRadius = 12
    archiveButton.addSublayer(textLayer("存网页", frame: CGRect(x: 12, y: 10, width: 58, height: 24), size: 16, color: .white))
    archiveButton.add(holdAnimation(keyPath: "transform.scale", values: [1, 1, 0.88, 1, 1], times: [0, Timeline.archiveStart + 0.5, Timeline.archiveStart + 0.85, Timeline.archiveStart + 1.15, duration], calculationMode: .cubic), forKey: "archive-click")
    collector.addSublayer(archiveButton)
    let collectButton = CALayer()
    collectButton.frame = CGRect(x: 295, y: 254, width: 54, height: 42)
    collectButton.backgroundColor = NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.98, alpha: 1).cgColor
    collectButton.cornerRadius = 12
    collectButton.addSublayer(textLayer("收图", frame: CGRect(x: 10, y: 10, width: 36, height: 24), size: 15, color: NSColor(calibratedRed: 0.25, green: 0.31, blue: 0.40, alpha: 1)))
    collector.addSublayer(collectButton)

    let progress = textLayer("正在唤醒懒加载图片，并保存整页…", frame: CGRect(x: 24, y: 206, width: 360, height: 28), size: 16, color: NSColor.systemBlue, weight: .semibold)
    addTimedOpacity(to: progress, start: Timeline.archiveStart + 0.7, end: Timeline.archiveStart + 3.0)
    collector.addSublayer(progress)

    func fileCard(title: String, detail: String, x: CGFloat, color: NSColor) -> CALayer {
        let card = CALayer()
        card.frame = CGRect(x: x, y: 72, width: 174, height: 116)
        card.backgroundColor = NSColor.white.cgColor
        card.cornerRadius = 16
        card.borderWidth = 2
        card.borderColor = color.withAlphaComponent(0.75).cgColor
        card.addSublayer(textLayer(title, frame: CGRect(x: 14, y: 65, width: 146, height: 28), size: 18, color: color))
        card.addSublayer(textLayer(detail, frame: CGRect(x: 14, y: 28, width: 146, height: 38), size: 13, color: NSColor(calibratedRed: 0.43, green: 0.49, blue: 0.57, alpha: 1), weight: .medium))
        addTimedOpacity(to: card, start: Timeline.archiveStart + 3.0, end: Timeline.archiveEnd)
        return card
    }
    collector.addSublayer(fileCard(title: "页面.html", detail: "可搜索\n保留来源链接", x: 22, color: NSColor.systemBlue))
    collector.addSublayer(fileCard(title: "完整页面.png", detail: "从页面顶部\n一直截到底部", x: 218, color: NSColor(calibratedRed: 0.12, green: 0.57, blue: 0.34, alpha: 1)))
    let saved = CALayer()
    saved.frame = CGRect(x: 78, y: 18, width: 264, height: 42)
    saved.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 0.96).cgColor
    saved.cornerRadius = 21
    saved.addSublayer(textLayer("已保存 HTML + 完整 PNG", frame: CGRect(x: 24, y: 10, width: 220, height: 24), size: 16, color: .white))
    addTimedOpacity(to: saved, start: Timeline.archiveStart + 4.0, end: Timeline.archiveEnd)
    collector.addSublayer(saved)
    return panel
}

private func memorySafetyLayer() -> CALayer {
    let panel = CALayer()
    panel.frame = CGRect(x: 570, y: 505, width: 1050, height: 360)
    panel.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
    panel.cornerRadius = 28
    panel.borderWidth = 2
    panel.borderColor = NSColor(calibratedRed: 0.60, green: 0.82, blue: 0.99, alpha: 0.88).cgColor
    panel.shadowColor = NSColor.black.cgColor
    panel.shadowOpacity = 0.16
    panel.shadowRadius = 28
    panel.shadowOffset = CGSize(width: 0, height: -8)
    addTimedOpacity(to: panel, start: Timeline.memoryStart, end: Timeline.memoryEnd)

    panel.addSublayer(textLayer("给灵感一点缓冲，不要一删就永别", frame: CGRect(x: 32, y: 296, width: 720, height: 42), size: 29, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    panel.addSublayer(textLayer("鱼的 7 天记忆", frame: CGRect(x: 34, y: 244, width: 220, height: 30), size: 20, color: NSColor.systemBlue))
    let progressTrack = CALayer()
    progressTrack.frame = CGRect(x: 250, y: 248, width: 550, height: 22)
    progressTrack.backgroundColor = NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.96, alpha: 1).cgColor
    progressTrack.cornerRadius = 11
    panel.addSublayer(progressTrack)
    let today = CALayer()
    today.frame = CGRect(x: 0, y: 0, width: 150, height: 22)
    today.backgroundColor = NSColor(calibratedRed: 0.32, green: 0.67, blue: 0.96, alpha: 1).cgColor
    today.cornerRadius = 11
    progressTrack.addSublayer(today)
    let threeDays = CALayer()
    threeDays.frame = CGRect(x: 150, y: 0, width: 210, height: 22)
    threeDays.backgroundColor = NSColor(calibratedRed: 0.26, green: 0.75, blue: 0.56, alpha: 1).cgColor
    progressTrack.addSublayer(threeDays)
    let sevenDays = CALayer()
    sevenDays.frame = CGRect(x: 360, y: 0, width: 126, height: 22)
    sevenDays.backgroundColor = NSColor(calibratedRed: 0.99, green: 0.62, blue: 0.35, alpha: 1).cgColor
    sevenDays.cornerRadius = 11
    progressTrack.addSublayer(sevenDays)
    panel.addSublayer(textLayer("今天 27%      3 天 38%      快到 7 天 23%", frame: CGRect(x: 250, y: 216, width: 570, height: 24), size: 15, color: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.56, alpha: 1), weight: .semibold))

    let shallow = CALayer()
    shallow.frame = CGRect(x: 32, y: 48, width: 450, height: 138)
    shallow.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.975, blue: 1, alpha: 1).cgColor
    shallow.cornerRadius = 20
    shallow.addSublayer(textLayer("回忆浅滩", frame: CGRect(x: 24, y: 86, width: 190, height: 30), size: 22, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    shallow.addSublayer(textLayer("删错的内容先在这里停一停", frame: CGRect(x: 24, y: 54, width: 320, height: 24), size: 16, color: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.56, alpha: 1), weight: .medium))
    let restore = CALayer()
    restore.frame = CGRect(x: 326, y: 49, width: 96, height: 42)
    restore.backgroundColor = NSColor.systemBlue.cgColor
    restore.cornerRadius = 13
    restore.addSublayer(textLayer("恢复", frame: CGRect(x: 26, y: 10, width: 48, height: 24), size: 16, color: .white))
    shallow.addSublayer(restore)
    panel.addSublayer(shallow)

    let settings = CALayer()
    settings.frame = CGRect(x: 510, y: 48, width: 508, height: 138)
    settings.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.985, blue: 1, alpha: 1).cgColor
    settings.cornerRadius = 20
    settings.addSublayer(textLayer("按你的习惯待着", frame: CGRect(x: 24, y: 88, width: 220, height: 28), size: 21, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    let labels = ["固定位置", "自定义快捷键", "开机启动"]
    for (index, label) in labels.enumerated() {
        let chip = CALayer()
        chip.frame = CGRect(x: 22 + CGFloat(index) * 154, y: 34, width: 140, height: 42)
        chip.backgroundColor = index == 0 ? NSColor(calibratedRed: 0.86, green: 0.94, blue: 1, alpha: 1).cgColor : NSColor.white.cgColor
        chip.cornerRadius = 13
        chip.borderWidth = 1
        chip.borderColor = NSColor(calibratedRed: 0.79, green: 0.86, blue: 0.94, alpha: 1).cgColor
        chip.addSublayer(textLayer(label, frame: CGRect(x: 12, y: 10, width: 116, height: 24), size: 15, color: NSColor(calibratedRed: 0.24, green: 0.30, blue: 0.39, alpha: 1), weight: .semibold))
        settings.addSublayer(chip)
    }
    panel.addSublayer(settings)
    return panel
}

private func makeComposition(narrationURLs: [URL]) async throws -> (AVMutableComposition, AVMutableVideoComposition, AVMutableAudioMix) {
    let sourceAsset = AVURLAsset(url: sourceURL)
    let sourceDuration = try await sourceAsset.load(.duration)
    guard let sourceVideo = try await sourceAsset.loadTracks(withMediaType: .video).first else {
        throw NSError(domain: "LingganAvatarDemo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Source video has no video track"])
    }

    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw NSError(domain: "LingganAvatarDemo", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create video track"])
    }
    try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: sourceDuration), of: sourceVideo, at: .zero)
    let finalDuration = CMTime(seconds: duration, preferredTimescale: 600)
    videoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: sourceDuration), toDuration: finalDuration)
    let preferredTransform = try await sourceVideo.load(.preferredTransform)
    videoTrack.preferredTransform = preferredTransform

    var audioParameters: [AVMutableAudioMixInputParameters] = []
    if let sourceAudio = try await sourceAsset.loadTracks(withMediaType: .audio).first,
       let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        var insertionTime = CMTime.zero
        while insertionTime < finalDuration {
            let remaining = CMTimeSubtract(finalDuration, insertionTime)
            let chunk = CMTimeMinimum(sourceDuration, remaining)
            try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: chunk), of: sourceAudio, at: insertionTime)
            insertionTime = CMTimeAdd(insertionTime, chunk)
        }
        let musicParameters = AVMutableAudioMixInputParameters(track: musicTrack)
        musicParameters.setVolume(0.12, at: .zero)
        audioParameters.append(musicParameters)
    }

    for (index, url) in narrationURLs.enumerated() {
        let asset = AVURLAsset(url: url)
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first,
              let narrationTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { continue }
        let available = try await asset.load(.duration)
        let segment = segments[index]
        let maxLength = CMTime(seconds: max(0.1, segment.end - segment.start), preferredTimescale: 600)
        let insertionDuration = CMTimeMinimum(available, maxLength)
        try narrationTrack.insertTimeRange(CMTimeRange(start: .zero, duration: insertionDuration), of: sourceTrack, at: CMTime(seconds: segment.start, preferredTimescale: 600))
        let narrationParameters = AVMutableAudioMixInputParameters(track: narrationTrack)
        narrationParameters.setVolume(1.0, at: .zero)
        audioParameters.append(narrationParameters)
    }

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: finalDuration)
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    layerInstruction.setTransform(preferredTransform, at: .zero)
    instruction.layerInstructions = [layerInstruction]

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = canvasSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = [instruction]

    let parent = CALayer()
    parent.frame = CGRect(origin: .zero, size: canvasSize)
    let video = CALayer()
    video.frame = parent.frame
    parent.addSublayer(video)

    let avatar = try cgImage(at: avatarURL)
    parent.addSublayer(avatarCameraLayer(image: avatar, side: .right))
    parent.addSublayer(avatarCameraLayer(image: avatar, side: .left))
    for segment in segments {
        parent.addSublayer(captionLayer(for: segment))
    }
    parent.addSublayer(polishBadge())
    parent.addSublayer(imageDragDemoLayer())
    parent.addSublayer(webpageArchiveDemoLayer())
    parent.addSublayer(memorySafetyLayer())
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video, in: parent)

    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = audioParameters
    return (composition, videoComposition, audioMix)
}

guard FileManager.default.fileExists(atPath: sourceURL.path) else {
    fatalError("Generate the Chinese teaser first: swift Scripts/make-x-real-style-demo.swift teaser")
}
guard FileManager.default.fileExists(atPath: avatarURL.path) else {
    fatalError("Missing avatar asset at \(avatarURL.path)")
}

let narrationURLs = try makeNarrationFiles()
let (composition, videoComposition, audioMix) = try await makeComposition(narrationURLs: narrationURLs)
try? FileManager.default.removeItem(at: outputURL)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    fatalError("Could not create avatar demo exporter")
}
exporter.videoComposition = videoComposition
exporter.audioMix = audioMix
try await exporter.export(to: outputURL, as: .mp4)
try? FileManager.default.removeItem(at: tempDirectory)
print("Created \(outputURL.path)")
