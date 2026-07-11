import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("BundleResources", isDirectory: true)
let iconset = resources.appendingPathComponent("InspirationBubble.iconset", isDirectory: true)
let icns = resources.appendingPathComponent("InspirationBubble.icns")

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let scale = size / 1024
    let rect = NSRect(x: 112 * scale, y: 134 * scale, width: 800 * scale, height: 706 * scale)
    let bubble = NSBezierPath(roundedRect: rect, xRadius: 250 * scale, yRadius: 250 * scale)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.76, green: 0.93, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 0.34, green: 0.72, blue: 1.0, alpha: 1)
    ])!
    gradient.draw(in: bubble, angle: 135)

    NSColor.white.withAlphaComponent(0.42).setStroke()
    bubble.lineWidth = 34 * scale
    bubble.stroke()

    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 346 * scale, y: 188 * scale))
    tail.curve(
        to: NSPoint(x: 224 * scale, y: 82 * scale),
        controlPoint1: NSPoint(x: 316 * scale, y: 126 * scale),
        controlPoint2: NSPoint(x: 266 * scale, y: 94 * scale)
    )
    tail.curve(
        to: NSPoint(x: 404 * scale, y: 136 * scale),
        controlPoint1: NSPoint(x: 288 * scale, y: 66 * scale),
        controlPoint2: NSPoint(x: 358 * scale, y: 90 * scale)
    )
    tail.close()
    NSColor(calibratedRed: 0.34, green: 0.72, blue: 1.0, alpha: 1).setFill()
    tail.fill()

    let spark = NSBezierPath()
    spark.move(to: NSPoint(x: 514 * scale, y: 664 * scale))
    spark.line(to: NSPoint(x: 560 * scale, y: 548 * scale))
    spark.line(to: NSPoint(x: 676 * scale, y: 502 * scale))
    spark.line(to: NSPoint(x: 560 * scale, y: 456 * scale))
    spark.line(to: NSPoint(x: 514 * scale, y: 340 * scale))
    spark.line(to: NSPoint(x: 468 * scale, y: 456 * scale))
    spark.line(to: NSPoint(x: 352 * scale, y: 502 * scale))
    spark.line(to: NSPoint(x: 468 * scale, y: 548 * scale))
    spark.close()
    NSColor.white.withAlphaComponent(0.96).setFill()
    spark.fill()

    let smallSpark = NSBezierPath()
    smallSpark.move(to: NSPoint(x: 704 * scale, y: 694 * scale))
    smallSpark.line(to: NSPoint(x: 730 * scale, y: 632 * scale))
    smallSpark.line(to: NSPoint(x: 792 * scale, y: 606 * scale))
    smallSpark.line(to: NSPoint(x: 730 * scale, y: 580 * scale))
    smallSpark.line(to: NSPoint(x: 704 * scale, y: 518 * scale))
    smallSpark.line(to: NSPoint(x: 678 * scale, y: 580 * scale))
    smallSpark.line(to: NSPoint(x: 616 * scale, y: 606 * scale))
    smallSpark.line(to: NSPoint(x: 678 * scale, y: 632 * scale))
    smallSpark.close()
    NSColor.white.withAlphaComponent(0.9).setFill()
    smallSpark.fill()

    image.unlockFocus()
    return image
}

func writePNG(size: Int, name: String) throws {
    let image = drawIcon(size: CGFloat(size))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: iconset.appendingPathComponent(name), options: [.atomic])
}

try writePNG(size: 16, name: "icon_16x16.png")
try writePNG(size: 32, name: "icon_16x16@2x.png")
try writePNG(size: 32, name: "icon_32x32.png")
try writePNG(size: 64, name: "icon_32x32@2x.png")
try writePNG(size: 128, name: "icon_128x128.png")
try writePNG(size: 256, name: "icon_128x128@2x.png")
try writePNG(size: 256, name: "icon_256x256.png")
try writePNG(size: 512, name: "icon_256x256@2x.png")
try writePNG(size: 512, name: "icon_512x512.png")
try writePNG(size: 1024, name: "icon_512x512@2x.png")

try? FileManager.default.removeItem(at: icns)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

print("Generated \(icns.path)")
