#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("Usage: generate_app_icon.swift <output-png-path> <size>\n", stderr)
    exit(1)
}

let outputPath = arguments[1]
let outputURL = URL(fileURLWithPath: outputPath)
let size = CGFloat(Int(arguments[2]) ?? 1024)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Failed to create graphics context.\n", stderr)
    exit(1)
}

let canvas = CGRect(x: 0, y: 0, width: size, height: size)
let cornerRadius = size * 0.22

let clipPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)
clipPath.addClip()

let backgroundColors = [
    NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.29, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.99, green: 0.80, blue: 0.37, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.31, green: 0.59, blue: 0.93, alpha: 1.0).cgColor
]

let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: backgroundColors as CFArray,
    locations: [0.0, 0.45, 1.0]
)!

context.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

let haloColor = NSColor.white.withAlphaComponent(0.18).cgColor
let haloGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [haloColor, NSColor.clear.cgColor] as CFArray,
    locations: [0.0, 1.0]
)!

context.drawRadialGradient(
    haloGradient,
    startCenter: CGPoint(x: size * 0.32, y: size * 0.72),
    startRadius: 0,
    endCenter: CGPoint(x: size * 0.32, y: size * 0.72),
    endRadius: size * 0.55,
    options: []
)

let orbitPath = NSBezierPath()
orbitPath.lineWidth = size * 0.018
orbitPath.appendArc(
    withCenter: NSPoint(x: size * 0.58, y: size * 0.45),
    radius: size * 0.28,
    startAngle: 205,
    endAngle: 24,
    clockwise: false
)
NSColor.white.withAlphaComponent(0.24).setStroke()
orbitPath.stroke()

let orbitDotRect = CGRect(
    x: size * 0.74,
    y: size * 0.25,
    width: size * 0.06,
    height: size * 0.06
)
NSColor.white.withAlphaComponent(0.7).setFill()
NSBezierPath(ovalIn: orbitDotRect).fill()

let timerRect = CGRect(
    x: size * 0.19,
    y: size * 0.15,
    width: size * 0.62,
    height: size * 0.62
)

let timerShadow = NSShadow()
timerShadow.shadowBlurRadius = size * 0.04
timerShadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
timerShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
timerShadow.set()

let timerPath = NSBezierPath(ovalIn: timerRect)
NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.26, alpha: 0.92).setFill()
timerPath.fill()

let ringPath = NSBezierPath(ovalIn: timerRect.insetBy(dx: size * 0.02, dy: size * 0.02))
ringPath.lineWidth = size * 0.024
NSColor.white.withAlphaComponent(0.75).setStroke()
ringPath.stroke()

let clockPath = NSBezierPath()
clockPath.lineCapStyle = .round
clockPath.lineWidth = size * 0.03
clockPath.move(to: NSPoint(x: size * 0.50, y: size * 0.66))
clockPath.line(to: NSPoint(x: size * 0.50, y: size * 0.77))
clockPath.move(to: NSPoint(x: size * 0.50, y: size * 0.77))
clockPath.line(to: NSPoint(x: size * 0.58, y: size * 0.84))
NSColor.white.withAlphaComponent(0.9).setStroke()
clockPath.stroke()

let bellRect = CGRect(
    x: size * 0.42,
    y: size * 0.77,
    width: size * 0.16,
    height: size * 0.12
)
let bellPath = NSBezierPath(roundedRect: bellRect, xRadius: size * 0.035, yRadius: size * 0.035)
NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.86, alpha: 1.0).setFill()
bellPath.fill()

let buttonRect = CGRect(
    x: size * 0.62,
    y: size * 0.60,
    width: size * 0.14,
    height: size * 0.14
)
let buttonPath = NSBezierPath(roundedRect: buttonRect, xRadius: size * 0.05, yRadius: size * 0.05)
NSColor(calibratedRed: 0.99, green: 0.87, blue: 0.50, alpha: 1.0).setFill()
buttonPath.fill()

let trianglePath = NSBezierPath()
trianglePath.move(to: NSPoint(x: size * 0.665, y: size * 0.635))
trianglePath.line(to: NSPoint(x: size * 0.665, y: size * 0.705))
trianglePath.line(to: NSPoint(x: size * 0.72, y: size * 0.67))
trianglePath.close()
NSColor(calibratedRed: 0.15, green: 0.22, blue: 0.33, alpha: 1.0).setFill()
trianglePath.fill()

let numberParagraph = NSMutableParagraphStyle()
numberParagraph.alignment = .center

let numberAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: size * 0.25, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.88, alpha: 1.0),
    .paragraphStyle: numberParagraph
]

let numberText = NSAttributedString(string: "05", attributes: numberAttributes)
let numberRect = CGRect(
    x: size * 0.19,
    y: size * 0.29,
    width: size * 0.62,
    height: size * 0.28
)
numberText.draw(in: numberRect)

let captionAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size * 0.06, weight: .semibold),
    .foregroundColor: NSColor.white.withAlphaComponent(0.78),
    .paragraphStyle: numberParagraph
]

let captionText = NSAttributedString(string: "COUNTDOWN", attributes: captionAttributes)
let captionRect = CGRect(
    x: size * 0.18,
    y: size * 0.20,
    width: size * 0.64,
    height: size * 0.08
)
captionText.draw(in: captionRect)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render PNG data.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
