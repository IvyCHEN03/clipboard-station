#!/usr/bin/env swift

import AppKit
import AVFoundation
import Foundation
import QuartzCore

private let duration = 28.0
private let canvasSize = CGSize(width: 1920, height: 1080)
private let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let language = CommandLine.arguments.dropFirst().contains("en") ? "en" : "cn"
private let sourceURL = repo.appendingPathComponent("docs/assets/social/linggan-x-teaser-\(language)-1080p.mp4")
private let outputURL = repo.appendingPathComponent("docs/assets/social/linggan-x-premium-\(language)-1080p.mp4")
private let coverURL = repo.appendingPathComponent("docs/assets/social/linggan-x-premium-\(language)-1080p-cover.png")

private let white = NSColor(calibratedWhite: 0.98, alpha: 1)
private let coolGray = NSColor(calibratedRed: 0.60, green: 0.66, blue: 0.74, alpha: 1)
private let electricBlue = NSColor(calibratedRed: 0.31, green: 0.70, blue: 1.00, alpha: 1)
private let lightCanvas = NSColor(calibratedRed: 0.95, green: 0.975, blue: 0.995, alpha: 1)
private let deepInk = NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.21, alpha: 1)

private func localized(_ chinese: String, _ english: String) -> String {
    language == "en" ? english : chinese
}

private func normalizedTimes(_ values: [Double]) -> [NSNumber] {
    values.map { NSNumber(value: min(max($0 / duration, 0), 1)) }
}

private func holdAnimation(
    keyPath: String,
    values: [Any],
    times: [Double],
    mode: CAAnimationCalculationMode = .linear
) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    animation.values = values
    animation.keyTimes = normalizedTimes(times)
    animation.duration = duration
    animation.beginTime = AVCoreAnimationBeginTimeAtZero
    animation.calculationMode = mode
    animation.isRemovedOnCompletion = false
    animation.fillMode = .both
    return animation
}

private func show(_ layer: CALayer, from start: Double, to end: Double, fade: Double = 0.20) {
    layer.opacity = 0
    let safeStart = max(0, start)
    let fadeIn = min(end, safeStart + fade)
    let fadeOut = max(fadeIn, end - fade)
    layer.add(
        holdAnimation(
            keyPath: "opacity",
            values: [0, 0, 1, 1, 0, 0],
            times: [0, safeStart, fadeIn, fadeOut, end, duration]
        ),
        forKey: "visibility"
    )
}

private func rise(_ layer: CALayer, at start: Double, distance: CGFloat = 24) {
    let finalY = layer.position.y
    let animation = CAKeyframeAnimation(keyPath: "position.y")
    animation.values = [finalY - distance, finalY, finalY]
    animation.keyTimes = [0, 0.78, 1]
    animation.duration = 0.62
    animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
    animation.timingFunctions = [
        CAMediaTimingFunction(name: .easeOut),
        CAMediaTimingFunction(name: .linear),
    ]
    animation.isRemovedOnCompletion = false
    animation.fillMode = .both
    layer.add(animation, forKey: "rise")
}

private func textLayer(
    _ value: String,
    frame: CGRect,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    kern: CGFloat = 0,
    lineHeight: CGFloat? = nil
) -> CALayer {
    let layer = CALayer()
    layer.frame = frame

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    let attributed = NSAttributedString(
        string: value,
        attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraph,
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

private func bubbleLayer(diameter: CGFloat) -> CALayer {
    let container = CALayer()
    container.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)

    let circle = CAShapeLayer()
    circle.frame = container.bounds
    circle.path = CGPath(ellipseIn: circle.bounds, transform: nil)
    circle.fillColor = electricBlue.cgColor
    circle.shadowColor = electricBlue.cgColor
    circle.shadowOpacity = 0.42
    circle.shadowRadius = diameter * 0.22
    circle.shadowOffset = .zero
    container.addSublayer(circle)

    let center = CGPoint(x: diameter / 2, y: diameter / 2)
    let radius = diameter * 0.24
    let star = CGMutablePath()
    star.move(to: CGPoint(x: center.x, y: center.y - radius))
    star.addCurve(
        to: CGPoint(x: center.x + radius, y: center.y),
        control1: CGPoint(x: center.x + radius * 0.18, y: center.y - radius * 0.18),
        control2: CGPoint(x: center.x + radius * 0.18, y: center.y - radius * 0.18)
    )
    star.addCurve(
        to: CGPoint(x: center.x, y: center.y + radius),
        control1: CGPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.18),
        control2: CGPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.18)
    )
    star.addCurve(
        to: CGPoint(x: center.x - radius, y: center.y),
        control1: CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.18),
        control2: CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.18)
    )
    star.addCurve(
        to: CGPoint(x: center.x, y: center.y - radius),
        control1: CGPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.18),
        control2: CGPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.18)
    )
    let starLayer = CAShapeLayer()
    starLayer.frame = container.bounds
    starLayer.path = star
    starLayer.fillColor = white.cgColor
    container.addSublayer(starLayer)

    let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
    pulse.values = [1.0, 1.06, 1.0]
    pulse.keyTimes = [0, 0.5, 1]
    pulse.duration = 2.4
    pulse.beginTime = AVCoreAnimationBeginTimeAtZero
    pulse.repeatCount = .infinity
    pulse.timingFunctions = [
        CAMediaTimingFunction(name: .easeInEaseOut),
        CAMediaTimingFunction(name: .easeInEaseOut),
    ]
    container.add(pulse, forKey: "pulse")
    return container
}

private func titleCard(
    word: String,
    statement: String,
    detail: String,
    marker: String,
    start: Double,
    end: Double
) -> CALayer {
    let card = CALayer()
    card.frame = CGRect(origin: .zero, size: canvasSize)
    card.backgroundColor = lightCanvas.cgColor

    let hairline = CALayer()
    hairline.frame = CGRect(x: 92, y: 900, width: 116, height: 3)
    hairline.backgroundColor = electricBlue.cgColor
    card.addSublayer(hairline)

    let mark = textLayer(marker, frame: CGRect(x: 92, y: 836, width: 360, height: 42), size: 24, weight: .semibold, color: electricBlue, kern: 4)
    card.addSublayer(mark)

    let ghost = textLayer(word, frame: CGRect(x: 78, y: 60, width: 1780, height: 350), size: 300, weight: .black, color: deepInk.withAlphaComponent(0.045), kern: 4)
    card.addSublayer(ghost)

    let title = textLayer(statement, frame: CGRect(x: 92, y: 470, width: 1540, height: 190), size: 104, weight: .bold, color: deepInk, kern: 0, lineHeight: 122)
    card.addSublayer(title)

    let subtitle = textLayer(detail, frame: CGRect(x: 98, y: 400, width: 1250, height: 52), size: 30, weight: .medium, color: coolGray, kern: 1)
    card.addSublayer(subtitle)

    let bubble = bubbleLayer(diameter: 86)
    bubble.position = CGPoint(x: 1780, y: 90)
    card.addSublayer(bubble)

    show(card, from: start, to: end, fade: start == 0 ? 0.08 : 0.16)
    rise(title, at: start + 0.05, distance: 30)
    rise(subtitle, at: start + 0.14, distance: 18)
    return card
}

private func featureCaption(
    number: String,
    action: String,
    start: Double,
    end: Double
) -> CALayer {
    let group = CALayer()
    group.frame = CGRect(origin: .zero, size: canvasSize)

    let line = CALayer()
    line.frame = CGRect(x: 1538, y: 1007, width: 54, height: 3)
    line.backgroundColor = electricBlue.cgColor
    group.addSublayer(line)

    let eyebrow = textLayer("\(number)  /  \(action)", frame: CGRect(x: 1538, y: 962, width: 310, height: 30), size: 17, weight: .semibold, color: electricBlue, alignment: .right, kern: 2)
    group.addSublayer(eyebrow)

    let brand = textLayer("LINGGAN", frame: CGRect(x: 74, y: 968, width: 230, height: 28), size: 16, weight: .bold, color: deepInk.withAlphaComponent(0.54), kern: 4)
    group.addSublayer(brand)

    show(group, from: start, to: end, fade: 0.24)
    rise(eyebrow, at: start + 0.05, distance: 10)
    return group
}

private func makeOverlay() -> CALayer {
    let overlay = CALayer()
    overlay.frame = CGRect(origin: .zero, size: canvasSize)

    overlay.addSublayer(titleCard(
        word: "CAPTURE",
        statement: localized("灵感，不该散落。", "Ideas shouldn't scatter."),
        detail: "Collect what matters. Keep it within reach.",
        marker: "LINGGAN / 00",
        start: 0,
        end: 2.72
    ))

    overlay.addSublayer(featureCaption(number: "01", action: "CAPTURE + FIND", start: 2.48, end: 7.72))

    overlay.addSublayer(featureCaption(number: "02", action: "COMPOSE", start: 8.28, end: 13.12))

    overlay.addSublayer(featureCaption(number: "03", action: "AI POLISH", start: 13.62, end: 17.48))
    overlay.addSublayer(titleCard(
        word: "DRAG",
        statement: localized("图片，不必绕路。", "Images should take the direct route."),
        detail: "Keep the original. Drag it anywhere.",
        marker: "LINGGAN / 03",
        start: 17.36,
        end: 18.22
    ))

    overlay.addSublayer(featureCaption(number: "04", action: "ORIGINAL IMAGE", start: 18.02, end: 21.16))

    overlay.addSublayer(featureCaption(number: "05", action: "IMAGE COLLECTION", start: 21.72, end: 25.18))

    overlay.addSublayer(titleCard(
        word: "GITHUB",
        statement: localized("灵感悬浮球，已经开源。", "Linggan is open source."),
        detail: "github.com/IvyCHEN03/clipboard-station",
        marker: "OPEN SOURCE / MACOS",
        start: 26.85,
        end: duration
    ))

    let progress = CALayer()
    progress.bounds = CGRect(x: 0, y: 0, width: canvasSize.width, height: 4)
    progress.anchorPoint = CGPoint(x: 0, y: 0.5)
    progress.position = CGPoint(x: 0, y: 3)
    progress.backgroundColor = electricBlue.cgColor
    progress.shadowColor = electricBlue.cgColor
    progress.shadowOpacity = 0.55
    progress.shadowRadius = 8
    let progressAnimation = CAKeyframeAnimation(keyPath: "transform.scale.x")
    progressAnimation.values = [0.0, 1.0]
    progressAnimation.keyTimes = [0, 1]
    progressAnimation.duration = duration
    progressAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
    progressAnimation.isRemovedOnCompletion = false
    progressAnimation.fillMode = .both
    progress.add(progressAnimation, forKey: "progress")
    overlay.addSublayer(progress)

    return overlay
}

private func saveCover(from videoURL: URL) async throws {
    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = canvasSize
    let image = try await generator.image(at: CMTime(seconds: 1.2, preferredTimescale: 600)).image
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LingganPremiumDemo", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not encode cover image"])
    }
    try png.write(to: coverURL)
}

guard FileManager.default.fileExists(atPath: sourceURL.path) else {
    fatalError("Missing source demo at \(sourceURL.path)")
}

let sourceAsset = AVURLAsset(url: sourceURL)
let sourceDuration = try await sourceAsset.load(.duration)
guard let sourceVideo = try await sourceAsset.loadTracks(withMediaType: .video).first else {
    fatalError("Source demo has no video track")
}

let composition = AVMutableComposition()
guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fatalError("Could not create video track")
}
let renderDuration = CMTimeMinimum(sourceDuration, CMTime(seconds: duration, preferredTimescale: 600))
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: renderDuration), of: sourceVideo, at: .zero)
let preferredTransform = try await sourceVideo.load(.preferredTransform)
videoTrack.preferredTransform = preferredTransform

if let sourceAudio = try await sourceAsset.loadTracks(withMediaType: .audio).first,
   let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: renderDuration), of: sourceAudio, at: .zero)
}

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: renderDuration)
let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
layerInstruction.setTransform(preferredTransform, at: .zero)
instruction.layerInstructions = [layerInstruction]

let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = canvasSize
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = [instruction]

let parent = CALayer()
parent.frame = CGRect(origin: .zero, size: canvasSize)
parent.backgroundColor = lightCanvas.cgColor
let videoLayer = CALayer()
videoLayer.frame = parent.frame
parent.addSublayer(videoLayer)
parent.addSublayer(makeOverlay())
videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

try? FileManager.default.removeItem(at: outputURL)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    fatalError("Could not create premium exporter")
}
exporter.videoComposition = videoComposition
try await exporter.export(to: outputURL, as: .mp4)
try await saveCover(from: outputURL)

print("Created \(outputURL.path)")
print("Created \(coverURL.path)")
