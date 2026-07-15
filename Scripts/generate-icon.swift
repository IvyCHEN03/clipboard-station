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
    let rect = NSRect(x: 148 * scale, y: 148 * scale, width: 728 * scale, height: 728 * scale)
    let bubble = NSBezierPath(ovalIn: rect)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.76, green: 0.93, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 0.34, green: 0.72, blue: 1.0, alpha: 1)
    ])!
    gradient.draw(in: bubble, angle: 135)

    NSColor.white.withAlphaComponent(0.68).setStroke()
    bubble.lineWidth = 22 * scale
    bubble.stroke()

    let spark = NSBezierPath()
    spark.move(to: NSPoint(x: 512 * scale, y: 648 * scale))
    spark.line(to: NSPoint(x: 552 * scale, y: 548 * scale))
    spark.line(to: NSPoint(x: 652 * scale, y: 508 * scale))
    spark.line(to: NSPoint(x: 552 * scale, y: 468 * scale))
    spark.line(to: NSPoint(x: 512 * scale, y: 368 * scale))
    spark.line(to: NSPoint(x: 472 * scale, y: 468 * scale))
    spark.line(to: NSPoint(x: 372 * scale, y: 508 * scale))
    spark.line(to: NSPoint(x: 472 * scale, y: 548 * scale))
    spark.close()
    NSColor.white.withAlphaComponent(0.96).setFill()
    spark.fill()

    let smallSpark = NSBezierPath()
    smallSpark.move(to: NSPoint(x: 690 * scale, y: 682 * scale))
    smallSpark.line(to: NSPoint(x: 712 * scale, y: 630 * scale))
    smallSpark.line(to: NSPoint(x: 764 * scale, y: 608 * scale))
    smallSpark.line(to: NSPoint(x: 712 * scale, y: 586 * scale))
    smallSpark.line(to: NSPoint(x: 690 * scale, y: 534 * scale))
    smallSpark.line(to: NSPoint(x: 668 * scale, y: 586 * scale))
    smallSpark.line(to: NSPoint(x: 616 * scale, y: 608 * scale))
    smallSpark.line(to: NSPoint(x: 668 * scale, y: 630 * scale))
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
