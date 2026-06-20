#!/usr/bin/env swift
import AppKit
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("Assets")
let brandDirectory = assetsDirectory.appendingPathComponent("Brand")
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset")

try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
try fileManager.createDirectory(at: brandDirectory, withIntermediateDirectories: true)
try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var cgColor: CGColor {
        CGColor(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }
}

let terracotta = RGBA(red: 224, green: 122, blue: 79, alpha: 1)
let terracottaDeep = RGBA(red: 187, green: 79, blue: 45, alpha: 1)
let terracottaLight = RGBA(red: 245, green: 156, blue: 104, alpha: 1)
let charcoal = RGBA(red: 28, green: 28, blue: 30, alpha: 1)
let shadow = RGBA(red: 74, green: 40, blue: 27, alpha: 0.32)
let white = RGBA(red: 255, green: 255, blue: 255, alpha: 1)

enum BrandGeometry {
    static let iconCornerRadiusRatio: CGFloat = 0.235
    static let glyphInsetRatio: CGFloat = 0.195
    static let menuBarGlyphInsetRatio: CGFloat = 0.025
    static let transparentGlyphInsetRatio: CGFloat = 0.105
    static let centerDotDiameterRatio: CGFloat = 0.075
    static let centerDotCenterYRatio: CGFloat = 0.538
    static let centerLineXRatio: CGFloat = 0.491
    static let centerLineYRatio: CGFloat = 0.565
    static let centerLineWidthRatio: CGFloat = 0.018
    static let centerLineHeightRatio: CGFloat = 0.18
}

func roundedRect(_ context: CGContext, _ rect: CGRect, radius: CGFloat, color: CGColor) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(color)
    context.fillPath()
}

enum GlyphCenterStyle {
    case terracotta
    case cutout
    case foreground
}

func drawGlyph(
    in context: CGContext,
    size: CGFloat,
    foreground: RGBA = white,
    centerStyle: GlyphCenterStyle = .terracotta,
    insetRatio: CGFloat = BrandGeometry.glyphInsetRatio
) {
    let inset = size * insetRatio
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let w = rect.width
    let h = rect.height
    let x0 = rect.minX
    let y0 = rect.minY

    func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) {
        let barRect = CGRect(x: x0 + x * w, y: y0 + y * h, width: width * w, height: height * h)
        roundedRect(context, barRect, radius: radius * w, color: foreground.cgColor)
    }

    bar(x: 0.02, y: 0.38, width: 0.06, height: 0.24, radius: 0.03)
    bar(x: 0.14, y: 0.28, width: 0.075, height: 0.44, radius: 0.04)
    bar(x: 0.785, y: 0.28, width: 0.075, height: 0.44, radius: 0.04)
    bar(x: 0.92, y: 0.38, width: 0.06, height: 0.24, radius: 0.03)

    let nib = CGMutablePath()
    nib.move(to: CGPoint(x: x0 + 0.50 * w, y: y0 + 0.02 * h))
    nib.addCurve(
        to: CGPoint(x: x0 + 0.64 * w, y: y0 + 0.42 * h),
        control1: CGPoint(x: x0 + 0.54 * w, y: y0 + 0.20 * h),
        control2: CGPoint(x: x0 + 0.61 * w, y: y0 + 0.31 * h)
    )
    nib.addLine(to: CGPoint(x: x0 + 0.77 * w, y: y0 + 0.50 * h))
    nib.addLine(to: CGPoint(x: x0 + 0.60 * w, y: y0 + 0.58 * h))
    nib.addCurve(
        to: CGPoint(x: x0 + 0.50 * w, y: y0 + 0.98 * h),
        control1: CGPoint(x: x0 + 0.58 * w, y: y0 + 0.72 * h),
        control2: CGPoint(x: x0 + 0.54 * w, y: y0 + 0.86 * h)
    )
    nib.addCurve(
        to: CGPoint(x: x0 + 0.40 * w, y: y0 + 0.58 * h),
        control1: CGPoint(x: x0 + 0.46 * w, y: y0 + 0.86 * h),
        control2: CGPoint(x: x0 + 0.42 * w, y: y0 + 0.72 * h)
    )
    nib.addLine(to: CGPoint(x: x0 + 0.23 * w, y: y0 + 0.50 * h))
    nib.addLine(to: CGPoint(x: x0 + 0.36 * w, y: y0 + 0.42 * h))
    nib.addCurve(
        to: CGPoint(x: x0 + 0.50 * w, y: y0 + 0.02 * h),
        control1: CGPoint(x: x0 + 0.39 * w, y: y0 + 0.31 * h),
        control2: CGPoint(x: x0 + 0.46 * w, y: y0 + 0.20 * h)
    )
    nib.closeSubpath()
    context.addPath(nib)
    context.setFillColor(foreground.cgColor)
    context.fillPath()

    func drawCenterMarks(color: CGColor) {
        let center = CGPoint(x: size * 0.5, y: size * BrandGeometry.centerDotCenterYRatio)
        let dotDiameter = size * BrandGeometry.centerDotDiameterRatio
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(
            x: center.x - dotDiameter / 2,
            y: center.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
        ))
        roundedRect(
            context,
            CGRect(
                x: size * BrandGeometry.centerLineXRatio,
                y: size * BrandGeometry.centerLineYRatio,
                width: size * BrandGeometry.centerLineWidthRatio,
                height: size * BrandGeometry.centerLineHeightRatio
            ),
            radius: size * BrandGeometry.centerLineWidthRatio / 2,
            color: color
        )
    }

    switch centerStyle {
    case .terracotta:
        drawCenterMarks(color: terracotta.cgColor)
    case .foreground:
        drawCenterMarks(color: foreground.cgColor)
    case .cutout:
        context.saveGState()
        context.setBlendMode(.clear)
        drawCenterMarks(color: white.cgColor)
        context.restoreGState()
    }
}

func iconImage(size: Int, includeCanvas: Bool) throws -> NSImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocusFlipped(false)
    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "ScrivoraBrandAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing graphics context"])
    }

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.clear(CGRect(x: 0, y: 0, width: dimension, height: dimension))
    context.translateBy(x: 0, y: dimension)
    context.scaleBy(x: 1, y: -1)

    let inset = includeCanvas ? dimension * 0.055 : 0
    let iconRect = CGRect(x: inset, y: inset, width: dimension - inset * 2, height: dimension - inset * 2)
    let cornerRadius = iconRect.width * BrandGeometry.iconCornerRadiusRatio

    if includeCanvas {
        context.setShadow(offset: CGSize(width: 0, height: dimension * 0.035), blur: dimension * 0.055, color: shadow.cgColor)
    }
    context.addPath(CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [terracottaLight.cgColor, terracotta.cgColor, terracottaDeep.cgColor] as CFArray,
        locations: [0.0, 0.58, 1.0]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: iconRect.minX, y: iconRect.minY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.maxY),
        options: []
    )
    context.resetClip()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    context.saveGState()
    context.translateBy(x: iconRect.minX, y: iconRect.minY)
    drawGlyph(in: context, size: iconRect.width)
    context.restoreGState()

    image.unlockFocus()
    return image
}

func transparentGlyphImage(
    size: Int,
    foreground: RGBA,
    centerStyle: GlyphCenterStyle,
    insetRatio: CGFloat = 0.105
) throws -> NSImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocusFlipped(false)
    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "ScrivoraBrandAssets", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing graphics context"])
    }

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.clear(CGRect(x: 0, y: 0, width: dimension, height: dimension))
    context.translateBy(x: 0, y: dimension)
    context.scaleBy(x: 1, y: -1)
    drawGlyph(in: context, size: dimension, foreground: foreground, centerStyle: centerStyle, insetRatio: insetRatio)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ScrivoraBrandAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

let iconset: [(String, Int)] = [
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

for (name, size) in iconset {
    let image = try iconImage(size: size, includeCanvas: true)
    try writePNG(image, to: iconsetDirectory.appendingPathComponent(name))
}

try writePNG(
    try iconImage(size: 1024, includeCanvas: true),
    to: assetsDirectory.appendingPathComponent("ScrivoraIcon.png")
)
try writePNG(
    try iconImage(size: 1024, includeCanvas: false),
    to: brandDirectory.appendingPathComponent("ScrivoraMark.png")
)
try writePNG(
    try transparentGlyphImage(
        size: 256,
        foreground: charcoal,
        centerStyle: .cutout,
        insetRatio: BrandGeometry.menuBarGlyphInsetRatio
    ),
    to: brandDirectory.appendingPathComponent("ScrivoraMenuBarTemplate.png")
)
try writePNG(
    try transparentGlyphImage(size: 1024, foreground: charcoal, centerStyle: .cutout),
    to: brandDirectory.appendingPathComponent("ScrivoraGlyphDark.png")
)
try writePNG(
    try transparentGlyphImage(size: 1024, foreground: white, centerStyle: .cutout),
    to: brandDirectory.appendingPathComponent("ScrivoraGlyphLight.png")
)
try writePNG(
    try transparentGlyphImage(size: 1024, foreground: terracotta, centerStyle: .cutout),
    to: brandDirectory.appendingPathComponent("ScrivoraGlyphTerracotta.png")
)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c",
    "icns",
    iconsetDirectory.path,
    "-o",
    assetsDirectory.appendingPathComponent("ScrivoraIcon.icns").path
]
try iconutil.run()
iconutil.waitUntilExit()
if iconutil.terminationStatus != 0 {
    throw NSError(domain: "ScrivoraBrandAssets", code: Int(iconutil.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print(assetsDirectory.appendingPathComponent("ScrivoraIcon.icns").path)
