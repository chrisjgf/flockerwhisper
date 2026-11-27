import AppKit
import Foundation

// Renders a crisp dark macOS AppIcon.icns matching Flockerwhisper's HUD aesthetic.
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FlockerwhisperIcon-\(UUID().uuidString).iconset")

try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDir) }

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    let inset = size * 0.08
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = rect.width * 0.23
    let roundedPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Subtle dark gradient background
    ctx.saveGState()
    ctx.addPath(roundedPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.145, green: 0.145, blue: 0.155, alpha: 1.0),
        CGColor(red: 0.075, green: 0.075, blue: 0.082, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Crisp outer rim stroke
    ctx.addPath(roundedPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1, size * 0.012))
    ctx.strokePath()

    // Centered waveform bars (reminiscent of the HUD dots rising with speech)
    let barHeights: [CGFloat] = [0.10, 0.22, 0.42, 0.56, 0.34, 0.62, 0.44, 0.24, 0.10]
    let barCount = barHeights.count
    let barWidth = rect.width * 0.045
    let totalSpan = rect.width * 0.64
    let spacing = (totalSpan - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1)
    let startX = rect.midX - totalSpan / 2

    for (index, relativeHeight) in barHeights.enumerated() {
        let h = max(barWidth, rect.height * relativeHeight * 0.78)
        let x = startX + CGFloat(index) * (barWidth + spacing)
        let y = rect.midY - h / 2
        let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
        let alpha = 0.42 + Double(relativeHeight) * 0.85
        ctx.addPath(barPath)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: min(0.95, alpha)))
        ctx.fillPath()
    }

    image.unlockFocus()
    return image
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in entries {
    let img = drawIcon(size: CGFloat(px))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        fputs("Failed to render \(filename)\n", stderr)
        exit(1)
    }
    try png.write(to: tempDir.appendingPathComponent(filename))
}

try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", tempDir.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

print("Generated \(outputURL.path)")
