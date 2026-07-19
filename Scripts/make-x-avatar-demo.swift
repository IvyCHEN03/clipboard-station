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

private let duration = 28.0
private let canvasSize = CGSize(width: 1920, height: 1080)
private let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceURL = repo.appendingPathComponent("docs/assets/social/linggan-x-teaser-cn-1080p.mp4")
private let avatarURL = repo.appendingPathComponent("docs/assets/social/avatar/linggan-host.png")
private let outputURL = repo.appendingPathComponent("docs/assets/social/linggan-x-avatar-cn-1080p.mp4")
private let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("linggan-avatar-demo", isDirectory: true)

private let segments: [NarrationSegment] = [
    .init(start: 0.35, end: 3.0, spokenText: "灵感一闪就不见？先接住。", caption: "灵感刚闪一下？\n先把它轻轻接住。", side: .right),
    .init(start: 3.15, end: 7.7, spokenText: "搜索、标签和时间筛选一点，想找的内容马上回来。", caption: "搜索、标签、时间一起筛。\n想找的内容马上回来。", side: .right),
    .init(start: 7.85, end: 13.05, spokenText: "喜欢的句子拖进组合框，像拼积木一样，慢慢长成一段话。", caption: "把喜欢的句子拖进组合框。\n像拼积木一样，慢慢长成一段话。", side: .right),
    .init(start: 13.15, end: 17.45, spokenText: "再点一下 Polish，AI 帮你补好衔接，整段读起来更顺。", caption: "点一下 Polish。\nAI 补好衔接，整段读起来更顺。", side: .right),
    .init(start: 17.55, end: 21.0, spokenText: "图片直接拖进文档，放进去的就是原图。", caption: "抓住图片，直接拖进文档。\n放进去的，就是图片本身。", side: .left),
    .init(start: 21.1, end: 25.35, spokenText: "遇到多图帖子，点一下悬浮球，整组图片都收好。", caption: "遇到多图帖子，点一下悬浮球。\n整组图片，一起收好。", side: .left),
    .init(start: 25.5, end: 27.9, spokenText: "灵感悬浮球，接住每个灵感。", caption: "灵感悬浮球。\n把散落的灵感，轻轻接回来。", side: .right),
]

private func makeNarrationFiles() throws -> [URL] {
    try? FileManager.default.removeItem(at: tempDirectory)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    return try segments.enumerated().map { index, segment in
        let url = tempDirectory.appendingPathComponent("voice-\(index).aiff")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "Tingting", "-r", "232", "-o", url.path, segment.spokenText]
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

    let avatarSize = size - 14
    let lipRegion = CGRect(x: 136.5, y: 136.5, width: 32, height: 12)
    let lips = CALayer()
    lips.bounds = CGRect(origin: .zero, size: lipRegion.size)
    lips.position = CGPoint(x: lipRegion.midX, y: lipRegion.midY)
    lips.contents = image
    lips.contentsGravity = .resize
    lips.contentsRect = CGRect(
        x: lipRegion.minX / avatarSize,
        y: lipRegion.minY / avatarSize,
        width: lipRegion.width / avatarSize,
        height: lipRegion.height / avatarSize
    )
    lips.cornerRadius = lipRegion.height / 2
    lips.masksToBounds = true
    avatar.addSublayer(lips)

    for (index, segment) in segments.enumerated() where segment.side == side {
        let talking = CAKeyframeAnimation(keyPath: "transform.scale.y")
        talking.values = [1.0, 1.035, 1.015, 1.075, 1.02, 1.045, 1.0]
        talking.keyTimes = [0, 0.16, 0.34, 0.50, 0.68, 0.84, 1]
        talking.duration = 1.02 + Double(index % 3) * 0.08
        talking.calculationMode = .cubic
        talking.beginTime = AVCoreAnimationBeginTimeAtZero + segment.start
        talking.repeatDuration = segment.end - segment.start
        talking.isRemovedOnCompletion = true
        lips.add(talking, forKey: "talking-\(index)")
    }

    let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
    bob.values = [0, 1.5, 0, -1, 0]
    bob.duration = 4.8
    bob.beginTime = AVCoreAnimationBeginTimeAtZero
    bob.repeatCount = .infinity
    camera.add(bob, forKey: "host-bob")

    let rightValues: [Any] = [1, 1, 0, 0, 1, 1]
    let leftValues: [Any] = [0, 0, 1, 1, 0, 0]
    camera.add(
        holdAnimation(
            keyPath: "opacity",
            values: side == .right ? rightValues : leftValues,
            times: [0, 17.45, 17.55, 25.35, 25.5, duration],
            calculationMode: .discrete
        ),
        forKey: "camera-cut"
    )
    camera.add(
        holdAnimation(
            keyPath: "transform.scale",
            values: [1.08, 1.08, 1.0, 1.0, 1.16, 1.16, 1.0, 1.0, 1.12, 1.0],
            times: [0, 2.55, 2.9, 12.95, 13.18, 14.05, 17.4, 25.3, 25.5, duration],
            calculationMode: .cubic
        ),
        forKey: "reaction-cuts"
    )

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
    addTimedOpacity(to: badge, start: 13.15, end: 17.45)
    return badge
}

private func imageDragDemoLayer() -> CALayer {
    let panel = CALayer()
    panel.frame = CGRect(x: 690, y: 472, width: 1100, height: 382)
    panel.backgroundColor = NSColor.white.withAlphaComponent(0.98).cgColor
    panel.cornerRadius = 28
    panel.borderWidth = 2
    panel.borderColor = NSColor(calibratedRed: 0.60, green: 0.82, blue: 0.99, alpha: 0.88).cgColor
    panel.shadowColor = NSColor.black.cgColor
    panel.shadowOpacity = 0.18
    panel.shadowRadius = 30
    panel.shadowOffset = CGSize(width: 0, height: -10)
    addTimedOpacity(to: panel, start: 17.55, end: 21.0)

    panel.addSublayer(textLayer("抓住图片，就这样拖进文档", frame: CGRect(x: 34, y: 318, width: 690, height: 42), size: 29, color: NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 1)))
    panel.addSublayer(textLayer("不用绕路，放进去的就是图片本身", frame: CGRect(x: 34, y: 282, width: 690, height: 30), size: 18, color: NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.54, alpha: 1), weight: .medium))

    let target = CALayer()
    target.frame = CGRect(x: 638, y: 52, width: 420, height: 212)
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
    target.addSublayer(textLayer("文档正文", frame: CGRect(x: 28, y: 142, width: 180, height: 34), size: 23, color: NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.35, alpha: 1)))
    target.addSublayer(textLayer("把图片拖到这里", frame: CGRect(x: 28, y: 104, width: 250, height: 30), size: 18, color: NSColor(calibratedRed: 0.46, green: 0.52, blue: 0.60, alpha: 1), weight: .medium))
    panel.addSublayer(target)

    let card = CALayer()
    card.bounds = CGRect(x: 0, y: 0, width: 250, height: 220)
    card.position = CGPoint(x: 178, y: 151)
    card.backgroundColor = NSColor.white.cgColor
    card.cornerRadius = 18
    card.borderWidth = 3
    card.borderColor = NSColor.systemBlue.withAlphaComponent(0.72).cgColor
    card.shadowColor = NSColor.black.cgColor
    card.shadowOpacity = 0.17
    card.shadowRadius = 16
    card.shadowOffset = CGSize(width: 0, height: -7)

    let preview = CAGradientLayer()
    preview.frame = CGRect(x: 14, y: 66, width: 222, height: 138)
    preview.cornerRadius = 12
    preview.colors = [
        NSColor(calibratedRed: 0.54, green: 0.84, blue: 0.98, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.77, green: 0.72, blue: 0.98, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.99, green: 0.72, blue: 0.81, alpha: 1).cgColor,
    ]
    preview.startPoint = CGPoint(x: 0, y: 1)
    preview.endPoint = CGPoint(x: 1, y: 0)
    let star = textLayer("✦", frame: CGRect(x: 78, y: 30, width: 68, height: 70), size: 50, color: .white)
    preview.addSublayer(star)
    card.addSublayer(preview)
    card.addSublayer(textLayer("图片片段.png", frame: CGRect(x: 16, y: 31, width: 180, height: 25), size: 16, color: NSColor(calibratedRed: 0.24, green: 0.30, blue: 0.39, alpha: 1), weight: .medium))
    panel.addSublayer(card)

    card.add(
        holdAnimation(
            keyPath: "position",
            values: [
                NSValue(point: CGPoint(x: 178, y: 151)),
                NSValue(point: CGPoint(x: 178, y: 151)),
                NSValue(point: CGPoint(x: 846, y: 147)),
                NSValue(point: CGPoint(x: 846, y: 147)),
            ],
            times: [0, 18.0, 20.15, duration],
            calculationMode: .cubic
        ),
        forKey: "drag-card"
    )
    card.add(
        holdAnimation(
            keyPath: "transform.scale",
            values: [1, 1, 0.72, 0.72],
            times: [0, 18.0, 20.15, duration],
            calculationMode: .cubic
        ),
        forKey: "drop-scale"
    )

    let success = CALayer()
    success.frame = CGRect(x: 760, y: 70, width: 260, height: 48)
    success.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.57, blue: 0.34, alpha: 0.96).cgColor
    success.cornerRadius = 24
    success.addSublayer(textLayer("✓  图片本身已放入", frame: CGRect(x: 24, y: 12, width: 220, height: 26), size: 18, color: .white))
    addTimedOpacity(to: success, start: 20.12, end: 21.0)
    panel.addSublayer(success)

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
    let preferredTransform = try await sourceVideo.load(.preferredTransform)
    videoTrack.preferredTransform = preferredTransform

    var audioParameters: [AVMutableAudioMixInputParameters] = []
    if let sourceAudio = try await sourceAsset.loadTracks(withMediaType: .audio).first,
       let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: sourceDuration), of: sourceAudio, at: .zero)
        let musicParameters = AVMutableAudioMixInputParameters(track: musicTrack)
        musicParameters.setVolume(0.22, at: .zero)
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
    instruction.timeRange = CMTimeRange(start: .zero, duration: sourceDuration)
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
