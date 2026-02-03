#!/usr/bin/env swift

import AppKit
import Foundation

func generateAppIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size)

    // Background - rounded square with blue gradient
    let bgRect = CGRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: s * 0.18, yRadius: s * 0.18)

    // Blue gradient background
    let gradient = NSGradient(colors: [
        NSColor(red: 0.25, green: 0.5, blue: 0.85, alpha: 1.0),
        NSColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1.0),
        NSColor(red: 0.1, green: 0.25, blue: 0.5, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Add subtle border
    NSColor(white: 1.0, alpha: 0.2).setStroke()
    bgPath.lineWidth = s * 0.01
    bgPath.stroke()

    // Draw 3x3 grid of circles (simplified Connect Four board)
    let gridSize = 3
    let margin = s * 0.18
    let spacing = (s * 0.64) / CGFloat(gridSize)
    let circleSize = spacing * 0.7

    // Piece colors
    let redColor = NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
    let yellowColor = NSColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1.0)
    let emptyColor = NSColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1.0)

    // Pattern: some filled, some empty to show game in progress
    let pattern: [[NSColor?]] = [
        [nil, yellowColor, nil],
        [redColor, redColor, yellowColor],
        [yellowColor, redColor, redColor]
    ]

    for row in 0..<gridSize {
        for col in 0..<gridSize {
            let x = margin + CGFloat(col) * spacing + (spacing - circleSize) / 2
            let y = margin + CGFloat(2 - row) * spacing + (spacing - circleSize) / 2
            let rect = CGRect(x: x, y: y, width: circleSize, height: circleSize)

            // Draw slot hole
            let holePath = NSBezierPath(ovalIn: rect)
            emptyColor.setFill()
            holePath.fill()

            // Inner shadow for depth
            NSColor(white: 0, alpha: 0.4).setStroke()
            holePath.lineWidth = s * 0.008
            holePath.stroke()

            // Draw piece if present
            if let pieceColor = pattern[row][col] {
                let pieceRect = rect.insetBy(dx: circleSize * 0.08, dy: circleSize * 0.08)
                let piecePath = NSBezierPath(ovalIn: pieceRect)

                // Piece gradient for 3D effect
                let pieceGradient = NSGradient(colors: [
                    pieceColor.blended(withFraction: 0.3, of: .white)!,
                    pieceColor,
                    pieceColor.blended(withFraction: 0.3, of: .black)!
                ])!

                pieceGradient.draw(in: piecePath, angle: -45)

                // Highlight
                let highlightRect = CGRect(
                    x: pieceRect.minX + pieceRect.width * 0.15,
                    y: pieceRect.minY + pieceRect.height * 0.5,
                    width: pieceRect.width * 0.35,
                    height: pieceRect.height * 0.35
                )
                let highlightPath = NSBezierPath(ovalIn: highlightRect)
                NSColor(white: 1.0, alpha: 0.4).setFill()
                highlightPath.fill()
            }
        }
    }

    image.unlockFocus()
    return image
}

func saveIcon(image: NSImage, size: Int, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for size \(size)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate all required sizes
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let basePath = "Assets.xcassets/AppIcon.appiconset"

for size in sizes {
    let image = generateAppIcon(size: size)
    let filename = "\(basePath)/AppIcon-\(size).png"
    saveIcon(image: image, size: size, path: filename)
}

print("App icons generated successfully!")
