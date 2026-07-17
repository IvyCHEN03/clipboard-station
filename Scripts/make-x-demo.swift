#!/usr/bin/env swift

import AppKit
import AVFoundation
import CoreVideo
import Foundation

private let canvasSize = CGSize(width: 1280, height: 720)
private let fps: Int32 = 30
private let duration: Double = 15
private let frameCount = Int(duration * Double(fps))

private let ink = NSColor(calibratedRed: 0.075, green: 0.125, blue: 0.20, alpha: 1)
private let muted = NSColor(calibratedRed: 0.36, green: 0.43, blue: 0.52, alpha: 1)
private let blue = NSColor(calibratedRed: 0.43, green: 0.76, blue: 0.98, alpha: 1)
private let paleBlue = NSColor(calibratedRed: 0.94, green: 0.98, blue: 1.0, alpha: 1)
private let line = NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.96, alpha: 1)

private func clamp(_ value: Double, _ lower: Double = 0, _ upper: Double = 1) -> Double {
    min(max(value, lower), upper)
}

private func ease(_ value: Double) -> Double {
    let x = clamp(value)
    return x * x * (3 - 2 * x)
}

private func interpolate(_ start: CGPoint, _ end: CGPoint, progress: Double) -> CGPoint {
    let amount = CGFloat(ease(progress))
    return CGPoint(
        x: start.x + (end.x - start.x) * amount,
        y: start.y + (end.y - start.y) * amount
    )
}

private func sceneAlpha(time: Double, start: Double, end: Double, fade: Double = 0.45) -> CGFloat {
    let entering = ease((time - start) / fade)
    let leaving = ease((end - time) / fade)
    return CGFloat(min(entering, leaving))
}

private func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

private func text(
    _ value: String,
    at point: CGPoint,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    alpha: CGFloat = 1,
    alignment: NSTextAlignment = .left,
    width: CGFloat? = nil
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: color.withAlphaComponent(alpha),
        .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: value, attributes: attributes)
    if let width {
        attributed.draw(in: CGRect(x: point.x, y: point.y, width: width, height: size * 2.6))
    } else {
        attributed.draw(at: point)
    }
}

private func roundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func strokeRoundedRect(_ rect: CGRect, radius: CGFloat, color: NSColor, width: CGFloat, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = width
    path.stroke()
}

private func drawBubble(center: CGPoint, radius: CGFloat, alpha: CGFloat = 1, pulse: CGFloat = 0) {
    if pulse > 0 {
        strokeRoundedRect(
            CGRect(x: center.x - radius - pulse, y: center.y - radius - pulse, width: (radius + pulse) * 2, height: (radius + pulse) * 2),
            radius: radius + pulse,
            color: blue,
            width: 3,
            alpha: alpha * max(0, 0.5 - pulse / 80)
        )
    }
    blue.withAlphaComponent(alpha).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()

    NSColor.white.withAlphaComponent(alpha).setFill()
    let star = NSBezierPath()
    star.move(to: CGPoint(x: center.x, y: center.y - radius * 0.48))
    star.line(to: CGPoint(x: center.x + radius * 0.17, y: center.y - radius * 0.16))
    star.line(to: CGPoint(x: center.x + radius * 0.50, y: center.y))
    star.line(to: CGPoint(x: center.x + radius * 0.17, y: center.y + radius * 0.16))
    star.line(to: CGPoint(x: center.x, y: center.y + radius * 0.50))
    star.line(to: CGPoint(x: center.x - radius * 0.17, y: center.y + radius * 0.16))
    star.line(to: CGPoint(x: center.x - radius * 0.50, y: center.y))
    star.line(to: CGPoint(x: center.x - radius * 0.17, y: center.y - radius * 0.16))
    star.close()
    star.fill()
}

private func drawCursor(at point: CGPoint, alpha: CGFloat, pressing: Bool = false) {
    let scale: CGFloat = pressing ? 0.88 : 1
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: point.x, yBy: point.y)
    transform.scale(by: scale)
    transform.concat()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha * 0.22)
    shadow.shadowBlurRadius = 7
    shadow.shadowOffset = CGSize(width: 2, height: 3)
    shadow.set()

    let cursor = NSBezierPath()
    cursor.move(to: CGPoint(x: 0, y: 0))
    cursor.line(to: CGPoint(x: 0, y: 31))
    cursor.line(to: CGPoint(x: 8, y: 23))
    cursor.line(to: CGPoint(x: 15, y: 38))
    cursor.line(to: CGPoint(x: 22, y: 35))
    cursor.line(to: CGPoint(x: 15, y: 21))
    cursor.line(to: CGPoint(x: 27, y: 20))
    cursor.close()
    NSColor.white.withAlphaComponent(alpha).setFill()
    cursor.fill()
    ink.withAlphaComponent(alpha).setStroke()
    cursor.lineWidth = 2.2
    cursor.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

private func drawClick(at point: CGPoint, time: Double, clickTime: Double, color: NSColor = blue, alpha: CGFloat = 1) {
    let age = time - clickTime
    guard age >= 0, age <= 0.55 else { return }
    let progress = CGFloat(age / 0.55)
    let radius = 14 + progress * 32
    color.withAlphaComponent(alpha * (1 - progress) * 0.72).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    ring.lineWidth = 4 - progress * 2
    ring.stroke()
}

private func drawCommandBadge(at point: CGPoint, alpha: CGFloat) {
    roundedRect(CGRect(x: point.x, y: point.y, width: 82, height: 34), radius: 10, color: ink, alpha: alpha)
    text("⌘ held", at: CGPoint(x: point.x, y: point.y + 8), size: 14, weight: .bold, color: .white, alpha: alpha, alignment: .center, width: 82)
}

private func drawDragGhost(at point: CGPoint, alpha: CGFloat) {
    roundedRect(CGRect(x: point.x - 82, y: point.y - 23, width: 164, height: 46), radius: 14, color: blue, alpha: alpha * 0.92)
    text("1  model answer", at: CGPoint(x: point.x - 82, y: point.y - 13), size: 14, weight: .semibold, color: .white, alpha: alpha, alignment: .center, width: 164)
}

private func chip(_ value: String, x: CGFloat, y: CGFloat, color: NSColor, alpha: CGFloat) -> CGFloat {
    let width = max(104, CGFloat(value.count) * 13 + 38)
    roundedRect(CGRect(x: x, y: y, width: width, height: 42), radius: 21, color: color, alpha: alpha * 0.17)
    text(value, at: CGPoint(x: x, y: y + 10), size: 15, weight: .semibold, color: color, alpha: alpha, alignment: .center, width: width)
    return width
}

private func drawImage(_ image: NSImage, in rect: CGRect, alpha: CGFloat, scale: CGFloat = 1, offset: CGPoint = .zero) {
    let target = CGRect(
        x: rect.midX - rect.width * scale / 2 + offset.x,
        y: rect.midY - rect.height * scale / 2 + offset.y,
        width: rect.width * scale,
        height: rect.height * scale
    )
    image.draw(in: target, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
}

private func renderFrame(time: Double, hero: NSImage, collector: NSImage) -> NSImage {
    let image = NSImage(size: canvasSize)
    image.lockFocusFlipped(true)
    defer { image.unlockFocus() }

    NSColor.white.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

    // Brand opener: 0.0-2.5s
    let opener = sceneAlpha(time: time, start: 0, end: 2.6, fade: 0.55)
    if opener > 0 {
        let rise = CGFloat(18 * (1 - ease(time / 0.8)))
        drawBubble(center: CGPoint(x: 640, y: 214 + rise), radius: 55, alpha: opener, pulse: CGFloat((time * 34).truncatingRemainder(dividingBy: 42)))
        text("LINGGAN FLOATING BALL", at: CGPoint(x: 240, y: 304 + rise), size: 47, weight: .bold, color: ink, alpha: opener, alignment: .center, width: 800)
        text("Your AI clipboard, finally visible.", at: CGPoint(x: 290, y: 376 + rise), size: 25, weight: .medium, color: muted, alpha: opener, alignment: .center, width: 700)
        roundedRect(CGRect(x: 525, y: 438 + rise, width: 230, height: 42), radius: 21, color: paleBlue, alpha: opener)
        text("macOS  •  local-first", at: CGPoint(x: 525, y: 449 + rise), size: 15, weight: .semibold, color: NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.72, alpha: 1), alpha: opener, alignment: .center, width: 230)
    }

    // Clipboard station: 2.1-7.4s
    let station = sceneAlpha(time: time, start: 2.1, end: 7.5, fade: 0.6)
    if station > 0 {
        roundedRect(CGRect(x: 0, y: 0, width: 1280, height: 720), radius: 0, color: paleBlue, alpha: station)
        text("Collect everything worth keeping.", at: CGPoint(x: 70, y: 44), size: 34, weight: .bold, color: ink, alpha: station)
        text("Text, screenshots and tables become reusable blocks.", at: CGPoint(x: 70, y: 91), size: 19, weight: .medium, color: muted, alpha: station)

        var chipX: CGFloat = 824
        chipX += chip("TEXT", x: chipX, y: 54, color: NSColor.systemBlue, alpha: station) + 12
        chipX += chip("IMAGES", x: chipX, y: 54, color: NSColor.systemGreen, alpha: station) + 12
        _ = chip("TABLES", x: chipX, y: 54, color: NSColor.systemOrange, alpha: station)

        let progress = CGFloat(ease((time - 2.1) / 5.4))
        let card = CGRect(x: 112, y: 146, width: 1056, height: 527)
        roundedRect(card.offsetBy(dx: 0, dy: 8), radius: 26, color: NSColor.black, alpha: station * 0.09)
        drawImage(hero, in: card, alpha: station, scale: 1.02 + progress * 0.025, offset: CGPoint(x: -progress * 9, y: -progress * 4))
        strokeRoundedRect(card, radius: 26, color: line, width: 2, alpha: station)

        // Demonstrate selecting a snippet, dragging it into the composer, then copying.
        let snippetPoint = CGPoint(x: 682, y: 402)
        let composerPoint = CGPoint(x: 646, y: 565)
        let copyPoint = CGPoint(x: 866, y: 565)
        var cursorPoint = snippetPoint
        var cursorAlpha = station
        var pressing = false

        if time < 3.1 {
            cursorAlpha = 0
        } else if time < 3.65 {
            cursorPoint = interpolate(CGPoint(x: 1030, y: 330), snippetPoint, progress: (time - 3.1) / 0.55)
        } else if time < 5.35 {
            cursorPoint = interpolate(snippetPoint, composerPoint, progress: (time - 3.65) / 1.7)
            pressing = true
            drawDragGhost(at: CGPoint(x: cursorPoint.x - 18, y: cursorPoint.y - 32), alpha: station)
        } else if time < 6.25 {
            cursorPoint = interpolate(composerPoint, copyPoint, progress: (time - 5.35) / 0.9)
        } else {
            cursorPoint = copyPoint
            pressing = time < 6.5
        }

        drawClick(at: snippetPoint, time: time, clickTime: 3.62, alpha: station)
        drawClick(at: composerPoint, time: time, clickTime: 5.32, color: NSColor.systemGreen, alpha: station)
        drawClick(at: copyPoint, time: time, clickTime: 6.35, alpha: station)
        drawCursor(at: cursorPoint, alpha: cursorAlpha, pressing: pressing)

        if time >= 6.45, time <= 7.25 {
            let copiedAlpha = station * CGFloat(sceneAlpha(time: time, start: 6.4, end: 7.3, fade: 0.18))
            roundedRect(CGRect(x: 970, y: 545, width: 126, height: 42), radius: 12, color: NSColor.systemGreen, alpha: copiedAlpha)
            text("Copied ✓", at: CGPoint(x: 970, y: 555), size: 15, weight: .bold, color: .white, alpha: copiedAlpha, alignment: .center, width: 126)
        }
    }

    // Whole-post image collector: 7.0-12.6s
    let collect = sceneAlpha(time: time, start: 7.0, end: 12.7, fade: 0.65)
    if collect > 0 {
        NSColor.white.withAlphaComponent(collect).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()
        text("One bubble. The whole post.", at: CGPoint(x: 70, y: 42), size: 38, weight: .bold, color: ink, alpha: collect)
        text("Cmd-click  •  pick the keepers  •  export real PNGs", at: CGPoint(x: 70, y: 94), size: 19, weight: .medium, color: muted, alpha: collect)

        let progress = CGFloat(ease((time - 7.0) / 5.7))
        let card = CGRect(x: 58, y: 142, width: 1164, height: 532)
        roundedRect(card.offsetBy(dx: 0, dy: 8), radius: 22, color: NSColor.black, alpha: collect * 0.08)
        drawImage(collector, in: card, alpha: collect, scale: 1.015 + progress * 0.025, offset: CGPoint(x: progress * 8, y: 0))
        strokeRoundedRect(card, radius: 22, color: line, width: 2, alpha: collect)

        // Demonstrate Cmd-clicking the existing bubble, selecting cards, and saving.
        let bubblePoint = CGPoint(x: 586, y: 424)
        let firstImagePoint = CGPoint(x: 755, y: 535)
        let secondImagePoint = CGPoint(x: 910, y: 535)
        let savePoint = CGPoint(x: 835, y: 435)
        var cursorPoint = CGPoint(x: 500, y: 350)
        var pressing = false

        if time < 8.45 {
            cursorPoint = interpolate(CGPoint(x: 470, y: 310), bubblePoint, progress: (time - 7.45) / 1.0)
        } else if time < 9.6 {
            cursorPoint = interpolate(bubblePoint, firstImagePoint, progress: (time - 8.45) / 1.15)
        } else if time < 10.45 {
            cursorPoint = interpolate(firstImagePoint, secondImagePoint, progress: (time - 9.6) / 0.85)
        } else {
            cursorPoint = interpolate(secondImagePoint, savePoint, progress: (time - 10.45) / 0.95)
        }

        pressing = abs(time - 8.42) < 0.14 || abs(time - 9.62) < 0.14 || abs(time - 10.47) < 0.14 || abs(time - 11.48) < 0.14
        let badgeAlpha = collect * CGFloat(clamp((9.0 - time) / 0.35)) * CGFloat(clamp((time - 7.65) / 0.25))
        if badgeAlpha > 0 { drawCommandBadge(at: CGPoint(x: 620, y: 360), alpha: badgeAlpha) }

        drawClick(at: bubblePoint, time: time, clickTime: 8.42, alpha: collect)
        drawClick(at: firstImagePoint, time: time, clickTime: 9.62, color: NSColor.systemBlue, alpha: collect)
        drawClick(at: secondImagePoint, time: time, clickTime: 10.47, color: NSColor.systemOrange, alpha: collect)
        drawClick(at: savePoint, time: time, clickTime: 11.48, color: NSColor.systemGreen, alpha: collect)
        drawCursor(at: cursorPoint, alpha: collect, pressing: pressing)

        if time >= 11.58, time <= 12.45 {
            let savedAlpha = collect * CGFloat(sceneAlpha(time: time, start: 11.5, end: 12.55, fade: 0.18))
            roundedRect(CGRect(x: 982, y: 86, width: 212, height: 42), radius: 12, color: NSColor.systemGreen, alpha: savedAlpha)
            text("PNG pack saved ✓", at: CGPoint(x: 982, y: 96), size: 15, weight: .bold, color: .white, alpha: savedAlpha, alignment: .center, width: 212)
        }
    }

    // Final CTA: 12.2-15.0s
    let cta = sceneAlpha(time: time, start: 12.2, end: 15.25, fade: 0.55)
    if cta > 0 {
        roundedRect(CGRect(origin: .zero, size: canvasSize), radius: 0, color: ink, alpha: cta)
        drawBubble(center: CGPoint(x: 640, y: 168), radius: 47, alpha: cta)
        text("COPY CHAOS IN.", at: CGPoint(x: 240, y: 255), size: 44, weight: .bold, color: NSColor.white, alpha: cta, alignment: .center, width: 800)
        text("A reusable prompt or clean PNG pack out.", at: CGPoint(x: 230, y: 320), size: 27, weight: .semibold, color: blue, alpha: cta, alignment: .center, width: 820)
        text("Open source for macOS", at: CGPoint(x: 390, y: 402), size: 20, weight: .medium, color: NSColor.white, alpha: cta * 0.82, alignment: .center, width: 500)
        roundedRect(CGRect(x: 322, y: 463, width: 636, height: 62), radius: 16, color: NSColor.white, alpha: cta)
        text("github.com/IvyCHEN03/clipboard-station", at: CGPoint(x: 322, y: 481), size: 20, weight: .semibold, color: ink, alpha: cta, alignment: .center, width: 636)
    }

    return image
}

private func pixelBuffer(from image: NSImage, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var optionalBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
          let buffer = optionalBuffer else { return nil }

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
          ), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: [.interpolation: NSImageInterpolation.high]) else {
        return nil
    }

    context.draw(cgImage, in: CGRect(origin: .zero, size: canvasSize))
    return buffer
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "LingganVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let heroURL = root.appendingPathComponent("docs/assets/hero-preview.svg")
let collectorURL = root.appendingPathComponent("docs/assets/image-collector-demo.svg")
let outputDirectory = root.appendingPathComponent("docs/assets/social", isDirectory: true)
let outputURL = outputDirectory.appendingPathComponent("linggan-x-demo.mp4")
let coverURL = outputDirectory.appendingPathComponent("linggan-x-cover.png")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: outputURL)

guard let hero = NSImage(contentsOf: heroURL), let collector = NSImage(contentsOf: collectorURL) else {
    fatalError("Missing demo SVG assets")
}

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(canvasSize.width),
    AVVideoHeightKey: Int(canvasSize.height),
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 5_500_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
    ],
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: Int(canvasSize.width),
        kCVPixelBufferHeightKey as String: Int(canvasSize.height),
    ]
)

guard writer.canAdd(input) else { fatalError("Cannot add video input") }
writer.add(input)
guard writer.startWriting() else { fatalError(writer.error?.localizedDescription ?? "Could not start writer") }
writer.startSession(atSourceTime: .zero)

guard let pool = adaptor.pixelBufferPool else { fatalError("Missing pixel buffer pool") }

for frame in 0..<frameCount {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    let time = Double(frame) / Double(fps)
    let rendered = renderFrame(time: time, hero: hero, collector: collector)
    guard let buffer = pixelBuffer(from: rendered, pool: pool) else { fatalError("Could not render frame \(frame)") }
    let presentationTime = CMTime(value: CMTimeValue(frame), timescale: fps)
    guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
        fatalError(writer.error?.localizedDescription ?? "Could not append frame \(frame)")
    }
}

input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError(writer.error?.localizedDescription ?? "Video export failed") }

let cover = renderFrame(time: 8.3, hero: hero, collector: collector)
try writePNG(cover, to: coverURL)

print("Created \(outputURL.path)")
print("Created \(coverURL.path)")
