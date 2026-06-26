#!/usr/bin/env swift
//
// Headless icon generator for Jarvis.
//
// Recreates the Jarvis mark — a dark rounded app tile, a glowing "notch" pill,
// two cyan arc eyes flanking a blue voice waveform — and writes a 1024×1024 PNG.
// Run: swift scripts/make_icon.swift <output.png>
// The packaging script turns that PNG into AppIcon.icns. Drop your own
// Resources/AppIcon.png to override this generated art.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIconGenerated.png"

let size = 1024
let s = CGFloat(size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create bitmap context")
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

let cyan = color(0.39, 0.89, 1.0)
let blue = color(0.36, 0.55, 1.0)

// Rounded app tile (squircle-ish) as the clip + background.
let tileRect = CGRect(x: 0, y: 0, width: s, height: s)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
ctx.addPath(tilePath)
ctx.clip()

let bgGradient = CGGradient(
    colorsSpace: space,
    colors: [color(0.06, 0.08, 0.11), color(0.02, 0.03, 0.04)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Soft halo behind the pill.
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 130, color: color(0.30, 0.70, 1.0, 0.9))

// The notch pill.
let pillRect = CGRect(x: s * 0.16, y: s * 0.34, width: s * 0.68, height: s * 0.32)
let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillRect.height / 2, cornerHeight: pillRect.height / 2, transform: nil)
ctx.addPath(pillPath)
ctx.setFillColor(color(0.015, 0.02, 0.03))
ctx.fillPath()
ctx.restoreGState()

// Thin cyan rim on the pill.
ctx.addPath(pillPath)
ctx.setStrokeColor(color(0.39, 0.89, 1.0, 0.45))
ctx.setLineWidth(4)
ctx.strokePath()

let midY = pillRect.midY

// Eyes: two upward arcs flanking the centre.
func drawArchEye(centerX: CGFloat) {
    let half: CGFloat = 70
    let path = CGMutablePath()
    path.move(to: CGPoint(x: centerX - half, y: midY - 22))
    path.addQuadCurve(
        to: CGPoint(x: centerX + half, y: midY - 22),
        control: CGPoint(x: centerX, y: midY + 70)
    )
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 36, color: color(0.39, 0.89, 1.0, 0.95))
    ctx.addPath(path)
    ctx.setStrokeColor(cyan)
    ctx.setLineWidth(34)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

drawArchEye(centerX: pillRect.minX + pillRect.width * 0.22)
drawArchEye(centerX: pillRect.minX + pillRect.width * 0.78)

// Central voice waveform.
let barHeights: [CGFloat] = [70, 130, 200, 250, 200, 130, 70]
let barWidth: CGFloat = 26
let gap: CGFloat = 26
let totalWidth = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * gap
var x = pillRect.midX - totalWidth / 2
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 32, color: color(0.36, 0.55, 1.0, 0.95))
ctx.setFillColor(blue)
for height in barHeights {
    let bar = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
    ctx.fillPath()
    x += barWidth + gap
}
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("Could not render image") }

let url = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create image destination at \(outputPath)")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write PNG") }
print("Wrote icon: \(outputPath)")
