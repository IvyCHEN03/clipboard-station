#!/usr/bin/env swift

import AppKit
import AVFoundation
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fatalError("Usage: make-video-contact-sheet.swift INPUT.mp4 OUTPUT.png")
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let isTeaser = CommandLine.arguments.dropFirst(3).contains("teaser")
let isAvatar = CommandLine.arguments.dropFirst(3).contains("avatar")
let times: [Double]
if isAvatar {
    times = [0.8, 7.5, 16.0, 24.0, 31.0, 39.0, 46.0, 49.7, 54.5, 57.0, 65.0, 73.2, 77.0, 82.0, 90.8, 96.0]
} else if isTeaser {
    times = [0.6, 1.8, 3.0, 4.7, 6.5, 8.0, 9.8, 11.8, 13.6, 15.0, 16.8, 18.6, 20.5, 22.0, 23.8, 25.3]
} else {
    times = [0.8, 2.4, 3.6, 5.9, 8.4, 10.8, 12.8, 15.7, 18.5, 19.8, 21.4, 22.4, 23.8, 25.2, 26.5, 29.2]
}
let asset = AVURLAsset(url: input)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let thumb = CGSize(width: 480, height: 270)
let sheet = NSImage(size: CGSize(width: thumb.width * 4, height: thumb.height * 4))
sheet.lockFocusFlipped(true)
NSColor.black.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: sheet.size)).fill()

for (index, seconds) in times.enumerated() {
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    let (image, _) = try await generator.image(at: time)
    let column = index % 4
    let row = index / 4
    let rect = CGRect(x: CGFloat(column) * thumb.width, y: CGFloat(row) * thumb.height, width: thumb.width, height: thumb.height)
    NSImage(cgImage: image, size: thumb).draw(in: rect)
    let title = String(format: "%.1fs", seconds)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white,
        .backgroundColor: NSColor.black.withAlphaComponent(0.72),
    ]
    NSAttributedString(string: " \(title) ", attributes: attributes).draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 8))
}

sheet.unlockFocus()
guard let tiff = sheet.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else { fatalError("Could not encode contact sheet") }
try png.write(to: output)
print(output.path)
