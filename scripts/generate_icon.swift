#!/usr/bin/env swift

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let size = 1024
let scale: CGFloat = CGFloat(size)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
          data: nil,
          width: size,
          height: size,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    fprint("Failed to create graphics context")
    exit(1)
}

func fprint(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

// Carbon colors
let layer01 = CGColor(srgbRed: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
let textPrimary = CGColor(srgbRed: 0x16/255.0, green: 0x16/255.0, blue: 0x16/255.0, alpha: 1.0)
let supportSuccess = CGColor(srgbRed: 0x19/255.0, green: 0x80/255.0, blue: 0x38/255.0, alpha: 1.0)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

// --- Background: warm off-white ---
ctx.setFillColor(layer01)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// --- Draw a dumpling (half-moon / crescent shape) ---
// The dumpling is centered, drawn as a filled half-circle (flat side down)
// with decorative fold lines along the curved top

let centerX: CGFloat = scale * 0.5
let centerY: CGFloat = scale * 0.48
let radius: CGFloat = scale * 0.28

// Main dumpling body: half circle (curved top, flat bottom)
ctx.saveGState()

// Shadow for depth
ctx.setShadow(offset: CGSize(width: 0, height: scale * 0.015), blur: scale * 0.04, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12))

// Draw dumpling shape: a D-shape / half-moon
let dumplingPath = CGMutablePath()
// Start at left of flat bottom
let flatLeft = centerX - radius
let flatRight = centerX + radius
let flatY = centerY + radius * 0.15

dumplingPath.move(to: CGPoint(x: flatLeft, y: flatY))
// Arc over the top (180 degrees)
dumplingPath.addArc(center: CGPoint(x: centerX, y: flatY),
                    radius: radius,
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: false)
// Flat bottom with slight curve (like a real dumpling)
dumplingPath.addQuadCurve(to: CGPoint(x: flatLeft, y: flatY),
                          control: CGPoint(x: centerX, y: flatY + radius * 0.25))
dumplingPath.closeSubpath()

// Fill with white/cream
ctx.setFillColor(white)
ctx.addPath(dumplingPath)
ctx.fillPath()

ctx.restoreGState()

// Outline
ctx.setStrokeColor(textPrimary)
ctx.setLineWidth(scale * 0.02)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(dumplingPath)
ctx.strokePath()

// --- Fold lines (pleats along the top curve) ---
let numFolds = 7
for i in 0..<numFolds {
    let angle = .pi + (.pi * Double(i + 1) / Double(numFolds + 1))
    let outerX = centerX + radius * CGFloat(cos(angle))
    let outerY = flatY + radius * CGFloat(sin(angle))

    let innerRadius = radius * 0.4
    let innerX = centerX + innerRadius * CGFloat(cos(angle))
    let innerY = flatY + innerRadius * CGFloat(sin(angle))

    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: outerX, y: outerY))

    // Slight curve for natural fold look
    let midX = (outerX + innerX) / 2 + CGFloat(cos(angle + .pi/2)) * radius * 0.08
    let midY = (outerY + innerY) / 2 + CGFloat(sin(angle + .pi/2)) * radius * 0.08

    foldPath.addQuadCurve(to: CGPoint(x: innerX, y: innerY),
                          control: CGPoint(x: midX, y: midY))

    ctx.setStrokeColor(textPrimary)
    ctx.setLineWidth(scale * 0.012)
    ctx.addPath(foldPath)
    ctx.strokePath()
}

// --- Green accent line below ---
let accentWidth: CGFloat = scale * 0.08
let accentHeight: CGFloat = scale * 0.006
let accentY: CGFloat = centerY + radius * 0.55

ctx.setFillColor(supportSuccess)
let accentRect = CGRect(
    x: centerX - accentWidth / 2,
    y: scale - accentY,  // flip for CoreGraphics coords (origin bottom-left)
    width: accentWidth,
    height: accentHeight
)
// Actually, let's position it properly — CoreGraphics has origin at bottom-left
let accentPath = CGMutablePath()
let accentCenterY = scale - (centerY + radius * 0.55)
accentPath.addRoundedRect(in: CGRect(
    x: centerX - accentWidth / 2,
    y: accentCenterY - accentHeight / 2,
    width: accentWidth,
    height: accentHeight
), cornerWidth: accentHeight / 2, cornerHeight: accentHeight / 2)
ctx.addPath(accentPath)
ctx.fillPath()

// --- Save as PNG ---
guard let image = ctx.makeImage() else {
    fprint("Failed to create image")
    exit(1)
}

let outputPath = "DumplingNotDumpling/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
let url = URL(fileURLWithPath: outputPath)

guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fprint("Failed to create image destination")
    exit(1)
}

CGImageDestinationAddImage(dest, image, nil)

if CGImageDestinationFinalize(dest) {
    print("Icon saved to \(outputPath) (\(size)x\(size))")
} else {
    fprint("Failed to write PNG")
    exit(1)
}
