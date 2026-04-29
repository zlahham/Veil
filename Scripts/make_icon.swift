#!/usr/bin/env swift

// Generates Veil's app icon: a soft-pastel neo-brutalist sticker — a
// rounded square with a heavy black border and chunky offset shadow,
// centered on a thick "V" mark.
//
// Run: swift Scripts/make_icon.swift

import AppKit

let projectRoot = FileManager.default.currentDirectoryPath
let outputDir = projectRoot + "/Resources/AppIcon.iconset"

try? FileManager.default.removeItem(atPath: outputDir)
try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

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

// Tonal palette — dusty blush card paired with a deep wine ink.
// Same hue family (red), light tint vs dark shade. Reads soft at a glance,
// holds high contrast at every size.
let card = NSColor(srgbRed: 0.96, green: 0.84, blue: 0.84, alpha: 1)   // dusty blush
let ink  = NSColor(srgbRed: 0.27, green: 0.10, blue: 0.16, alpha: 1)   // deep wine

func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }

    // Outer squircle — fill the full canvas with the ink color so the offset
    // "shadow" is just the visible negative space in the bottom-right L when
    // the card sits at the top-left. No transparent corners, so macOS doesn't
    // fall back to its system tile.
    let outerRadius = size * 0.225
    let outerRect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.saveGState()
    ctx.addPath(roundedRectPath(outerRect, radius: outerRadius))
    ctx.clip()
    ctx.setFillColor(ink.cgColor)
    ctx.fill(outerRect)

    let shadowOffset = size * 0.075
    let cardRect = CGRect(
        x: 0,
        y: shadowOffset,
        width: size - shadowOffset,
        height: size - shadowOffset
    )
    let cardRadius = size * 0.18
    let borderWidth = size * 0.05

    // Card sits on top of the inked canvas. The L-shape of ink at bottom-right
    // reads as the chunky offset shadow without a separate shadow rect.
    ctx.setFillColor(card.cgColor)
    ctx.addPath(roundedRectPath(cardRect, radius: cardRadius))
    ctx.fillPath()

    // Card border.
    let borderInset = borderWidth / 2
    let borderRect = cardRect.insetBy(dx: borderInset, dy: borderInset)
    let borderRadius = max(0, cardRadius - borderInset)
    ctx.setStrokeColor(ink.cgColor)
    ctx.setLineWidth(borderWidth)
    ctx.addPath(roundedRectPath(borderRect, radius: borderRadius))
    ctx.strokePath()

    // V monogram — two stroked diagonals meeting at the apex. Centered on
    // the card, not the canvas, so the offset shadow doesn't cause a shift.
    let vWidth = cardRect.width * 0.62
    let vHeight = cardRect.height * 0.50
    let strokeWidth = size * 0.13
    let vOriginX = cardRect.midX - vWidth / 2
    let vOriginY = cardRect.midY - vHeight / 2
    let topY = vOriginY + vHeight
    let bottomY = vOriginY

    let vPath = CGMutablePath()
    vPath.move(to: CGPoint(x: vOriginX, y: topY))
    vPath.addLine(to: CGPoint(x: vOriginX + vWidth / 2, y: bottomY))
    vPath.addLine(to: CGPoint(x: vOriginX + vWidth, y: topY))

    ctx.setStrokeColor(ink.cgColor)
    ctx.setLineWidth(strokeWidth)
    ctx.setLineJoin(.miter)
    ctx.setLineCap(.butt)
    ctx.setMiterLimit(20)
    ctx.addPath(vPath)
    ctx.strokePath()

    ctx.restoreGState()
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
