#!/usr/bin/env swift

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let inputPath = arguments.count > 1
    ? arguments[1]
    : "docs/assets/social/linggan-x-teaser-en-1080p.mp4"
let outputPath = arguments.count > 2
    ? arguments[2]
    : "docs/assets/social/linggan-readme-demo.gif"
let targetWidth: CGFloat = 960
let framesPerSecond = 10.0

let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)
let asset = AVURLAsset(url: inputURL)
let assetDuration = try await asset.load(.duration)
let duration = CMTimeGetSeconds(assetDuration)

guard duration.isFinite, duration > 0 else {
    fputs("Unable to read video duration.\n", stderr)
    exit(1)
}

let frameCount = max(1, Int((duration * framesPerSecond).rounded(.down)))
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.gif.identifier as CFString,
    frameCount,
    nil
) else {
    fputs("Unable to create GIF destination.\n", stderr)
    exit(1)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: targetWidth, height: targetWidth)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let fileProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFLoopCount: 0
    ]
]
CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

let frameProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: 1.0 / framesPerSecond,
        kCGImagePropertyGIFUnclampedDelayTime: 1.0 / framesPerSecond
    ]
]

for index in 0..<frameCount {
    let seconds = Double(index) / framesPerSecond
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    do {
        let (frame, _) = try await generator.image(at: time)
        CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
    } catch {
        fputs("Unable to render frame \(index): \(error)\n", stderr)
        exit(1)
    }
}

guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to finalize GIF.\n", stderr)
    exit(1)
}

let size = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? NSNumber)?.intValue ?? 0
print("Created \(outputPath) (\(frameCount) frames, \(size) bytes)")
