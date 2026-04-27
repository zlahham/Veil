#!/usr/bin/env swift

// Generates Veil's app icon: a white bolt on a purple→indigo gradient with
// a macOS-style rounded squircle. Renders all sizes Apple expects in an
// .iconset, then `iconutil` packages it (called from the Makefile).
//
// Run: swift Scripts/make_icon.swift
//
// Output: Resources/AppIcon.iconset/icon_<size>.png × N

import AppKit

let projectRoot = FileManager.default.currentDirectoryPath
let outputDir = projectRoot + "/Resources/AppIcon.iconset"

try? FileManager.default.removeItem(atPath: outputDir)
try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

/// macOS .iconset expected entries: (size, scale, suffix).
let entries: [(size: Int, scale: Int, suffix: String)] = [
    (16, 1, "16x16"),
    (16, 2, "16x16@2x"),
    (32, 1, "32x32"),
    (32, 2, "32x32@2x"),
    (128, 1, "128x128"),
    (128, 2, "128x128@2x"),
    (256, 1, "256x256"),
    (256, 2, "256x256@2x"),
    (512, 1, "512x512"),
    (512, 2, "512x512@2x"),
]

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }

    // Rounded squircle background. macOS Big Sur+ uses ~22% corner radius.
    let radius = size * 0.225
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Vertical gradient: indigo → violet.
    let colors = [
        NSColor(srgbRed: 0.36, green: 0.31, blue: 0.78, alpha: 1).cgColor,  // indigo
        NSColor(srgbRed: 0.59, green: 0.34, blue: 0.91, alpha: 1).cgColor,  // violet
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Subtle inner highlight along the top edge.
    let highlight = NSColor.white.withAlphaComponent(0.18).cgColor
    ctx.setFillColor(highlight)
    let highlightRect = CGRect(x: 0, y: size * 0.7, width: size, height: size * 0.3)
    ctx.fill(highlightRect)

    ctx.restoreGState()

    // Draw the bolt symbol centered, white, ~55% of canvas.
    let symbolSize = size * 0.58
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .heavy)
        let configured = bolt.withSymbolConfiguration(config) ?? bolt

        let originX = (size - symbolSize) / 2
        let originY = (size - symbolSize) / 2
        let symbolRect = NSRect(x: originX, y: originY, width: symbolSize, height: symbolSize)

        // Render the symbol white via NSGraphicsContext composite mode.
        ctx.setFillColor(NSColor.white.cgColor)
        let cgImage = configured.cgImage(forProposedRect: nil, context: nil, hints: nil)
        if let cg = cgImage {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: size)
            ctx.scaleBy(x: 1, y: -1)
            let flippedRect = NSRect(x: originX, y: size - originY - symbolSize, width: symbolSize, height: symbolSize)
            ctx.clip(to: flippedRect, mask: cg)
            ctx.fill(rect)
            ctx.restoreGState()
        } else {
            // Fallback — draw the symbol normally (will be tinted by template handling).
            configured.draw(in: symbolRect)
        }
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG for \(path)")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

for entry in entries {
    let pixelSize = CGFloat(entry.size * entry.scale)
    let img = render(size: pixelSize)
    let name = "icon_\(entry.suffix).png"
    writePNG(img, to: "\(outputDir)/\(name)")
    print("wrote \(name) (\(Int(pixelSize))px)")
}

print("\nDone. Run `iconutil -c icns \(outputDir)` to package.")
