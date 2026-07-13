#!/usr/bin/env swift
// Generates the placeholder app icon set: a macOS-style rounded square with the
// accent-blue gradient and a white house glyph (SF Symbol), rendered at every
// required size into App/Assets.xcassets/AppIcon.appiconset/.
//
// Rerun after design tweaks:  swift scripts/generate-appicon.swift
// Swap in commissioned art later by replacing the PNGs (keep the filenames).

import AppKit

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // scripts/
    .deletingLastPathComponent()   // repo root
let iconset = repoRoot.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")

// (filename, pixelSize, pointSize, scale)
let variants: [(String, Int, Int, Int)] = [
    ("icon_16.png", 16, 16, 1), ("icon_16@2x.png", 32, 16, 2),
    ("icon_32.png", 32, 32, 1), ("icon_32@2x.png", 64, 32, 2),
    ("icon_128.png", 128, 128, 1), ("icon_128@2x.png", 256, 128, 2),
    ("icon_256.png", 256, 256, 1), ("icon_256@2x.png", 512, 256, 2),
    ("icon_512.png", 512, 512, 1), ("icon_512@2x.png", 1024, 512, 2),
]

/// Renders into an explicitly sized bitmap — NOT lockFocus(), which rasterizes at the
/// main display's backing scale and would write 2x-sized PNGs on any Retina Mac.
func renderIcon(pixels: Int) -> NSBitmapImageRep? {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .calibratedRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: size, height: size) // 1 point = 1 pixel, display-independent
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Big Sur-style icons float in the canvas with a ~10% margin.
    let inset = size * 0.098
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = plate.width * 0.2237
    let path = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

    // Accent gradient (FediHome blue → deeper blue).
    let top = NSColor(calibratedRed: 0x3b / 255, green: 0x82 / 255, blue: 0xf6 / 255, alpha: 1)
    let bottom = NSColor(calibratedRed: 0x1e / 255, green: 0x40 / 255, blue: 0xaf / 255, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -60)

    // White house glyph, optically centered.
    let config = NSImage.SymbolConfiguration(pointSize: plate.width * 0.42, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.set()
        let rect = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: rect)
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let glyphWidth = plate.width * 0.52
        let aspect = symbol.size.height / max(symbol.size.width, 1)
        let glyphSize = NSSize(width: glyphWidth, height: glyphWidth * aspect)
        let origin = NSPoint(x: plate.midX - glyphSize.width / 2,
                             y: plate.midY - glyphSize.height / 2)
        tinted.draw(in: NSRect(origin: origin, size: glyphSize),
                    from: .zero, operation: .sourceOver, fraction: 1)
    }
    return rep
}

try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

var images: [[String: String]] = []
for (filename, pixels, points, scale) in variants {
    guard let rep = renderIcon(pixels: pixels),
          rep.pixelsWide == pixels, rep.pixelsHigh == pixels,
          let data = rep.representation(using: .png, properties: [:]) else {
        fputs("failed to render \(filename) at exactly \(pixels)px\n", stderr); exit(1)
    }
    try data.write(to: iconset.appendingPathComponent(filename))
    images.append(["size": "\(points)x\(points)", "idiom": "mac",
                   "filename": filename, "scale": "\(scale)x"])
    print("wrote \(filename) (\(pixels)px)")
}

let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconset.appendingPathComponent("Contents.json"))
print("wrote Contents.json — done.")
