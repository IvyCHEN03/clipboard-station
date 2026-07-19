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
    .init(start: 0.35, end: 3.0, spokenText: "灵感一复制就消失？这谁受得了。", caption: "灵感一复制就消失？\n这谁受得了。", side: .right),
    .init(start: 3.15, end: 7.7, spokenText: "标签一筛，刚才那句话自己回来了。", caption: "标签一筛，\n刚才那句话自己回来了。", side: .right),
    .init(start: 7.85, end: 13.05, spokenText: "拖进组合框，想法开始拼成一段。", caption: "拖进组合框，\n想法开始拼成一段。", side: .right),
    .init(start: 13.15, end: 17.65, spokenText: "重点来了。点一下 Polish，AI 自动补逻辑，生成全文。", caption: "重点来了：点一下 Polish。\nAI 自动补逻辑，生成全文。", side: .right),
    .init(start: 17.8, end: 24.25, spokenText: "多图帖子也别一张张存。点球，一次收齐。", caption: "多图帖子也别一张张存。\n点球，一次收齐。", side: .left),
    .init(start: 24.4, end: 27.85, spokenText: "灵感悬浮球。把散落的灵感，捞回来。", caption: "灵感悬浮球。\n把散落的灵感，捞回来。", side: .right),
]

private func makeNarrationFiles() throws -> [URL] {
    try? FileManager.default.removeItem(at: tempDirectory)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    return try segments.enumerated().map { index, segment in
        let url = tempDirectory.appendingPathComponent("voice-\(index).aiff")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "Tingting", "-r", "225", "-o", url.path, segment.spokenText]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "LingganAvatarDemo", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to synthesize narration segment \(index)",
            ])
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

private func avatarCameraLayer(image: CGImage) -> CALayer {
    let size: CGFloat = 318
    let camera = CALayer()
    camera.bounds = CGRect(x: 0, y: 0, width: size, height: size)
    camera.position = CGPoint(x: 1690, y: 170)
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

    let mouth = CAShapeLayer()
    mouth.path = CGPath(ellipseIn: CGRect(x: 137, y: 137, width: 31, height: 9), transform: nil)
    mouth.fillColor = NSColor(calibratedRed: 0.55, green: 0.18, blue: 0.20, alpha: 0.82).cgColor
    mouth.strokeColor = NSColor(calibratedRed: 0.98, green: 0.52, blue: 0.54, alpha: 0.85).cgColor
    mouth.lineWidth = 2
    avatar.addSublayer(mouth)

    let talking = CAKeyframeAnimation(keyPath: "transform.scale.y")
    talking.values = [0.55, 1.15, 0.72, 1.0, 0.55]
    talking.keyTimes = [0, 0.22, 0.47, 0.74, 1]
    talking.duration = 0.42
    talking.beginTime = AVCoreAnimationBeginTimeAtZero
    talking.repeatCount = .infinity
    mouth.add(talking, forKey: "talking")

    let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
    bob.values = [0, 4, 0, -3, 0]
    bob.duration = 2.4
    bob.beginTime = AVCoreAnimationBeginTimeAtZero
    bob.repeatCount = .infinity
    camera.add(bob, forKey: "host-bob")

    camera.add(
        holdAnimation(
            keyPath: "position",
            values: [
                NSValue(point: CGPoint(x: 1690, y: 170)),
                NSValue(point: CGPoint(x: 1690, y: 170)),
                NSValue(point: CGPoint(x: 230, y: 172)),
                NSValue(point: CGPoint(x: 230, y: 172)),
                NSValue(point: CGPoint(x: 1690, y: 170)),
                NSValue(point: CGPoint(x: 1690, y: 170)),
            ],
            times: [0, 17.45, 17.85, 24.1, 24.5, duration],
            calculationMode: .discrete
        ),
        forKey: "side-switch"
    )
    camera.add(
        holdAnimation(
            keyPath: "transform.scale",
            values: [1.08, 1.08, 1.0, 1.0, 1.16, 1.16, 1.0, 1.0, 1.12, 1.0],
            times: [0, 2.55, 2.9, 12.95, 13.18, 14.05, 17.55, 24.25, 24.45, duration],
            calculationMode: .cubic
        ),
        forKey: "reaction-cuts"
    )

    let cameraBadge = CALayer()
    cameraBadge.frame = CGRect(x: 18, y: size - 48, width: 98, height: 30)
    cameraBadge.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.20, alpha: 0.90).cgColor
    cameraBadge.cornerRadius = 15
    let dot = CALayer()
    dot.frame = CGRect(x: 11, y: 10, width: 10, height: 10)
    dot.cornerRadius = 5
    dot.backgroundColor = NSColor.systemRed.cgColor
    cameraBadge.addSublayer(dot)
    cameraBadge.addSublayer(textLayer("CAM 2", frame: CGRect(x: 28, y: 5, width: 62, height: 20), size: 14, color: .white))
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
    addTimedOpacity(to: badge, start: 13.15, end: 17.65)
    return badge
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
    parent.addSublayer(avatarCameraLayer(image: avatar))
    for segment in segments {
        parent.addSublayer(captionLayer(for: segment))
    }
    parent.addSublayer(polishBadge())
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
