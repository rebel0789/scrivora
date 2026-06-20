import SwiftUI

enum BrandColor {
    static let terracotta = Color(red: 224.0 / 255.0, green: 122.0 / 255.0, blue: 79.0 / 255.0)
    static let terracottaDeep = Color(red: 187.0 / 255.0, green: 79.0 / 255.0, blue: 45.0 / 255.0)
    static let terracottaLight = Color(red: 245.0 / 255.0, green: 156.0 / 255.0, blue: 104.0 / 255.0)
    static let warmSand = Color(red: 246.0 / 255.0, green: 242.0 / 255.0, blue: 239.0 / 255.0)
    static let paper = Color(red: 252.0 / 255.0, green: 250.0 / 255.0, blue: 247.0 / 255.0)
    static let charcoal = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    static let slate = Color(red: 82.0 / 255.0, green: 82.0 / 255.0, blue: 88.0 / 255.0)
    static let mutedSage = Color(red: 111.0 / 255.0, green: 128.0 / 255.0, blue: 111.0 / 255.0)
}

enum ScrivoraBrandGeometry {
    static let iconCornerRadiusRatio: CGFloat = 0.235
    static let glyphInsetRatio: CGFloat = 0.195
    static let centerDotDiameterRatio: CGFloat = 0.075
    static let centerDotCenterYRatio: CGFloat = 0.538
    static let centerLineXRatio: CGFloat = 0.491
    static let centerLineYRatio: CGFloat = 0.565
    static let centerLineWidthRatio: CGFloat = 0.018
    static let centerLineHeightRatio: CGFloat = 0.18
}

struct ScrivoraAppIconMark: View {
    var cornerRadiusRatio: CGFloat = ScrivoraBrandGeometry.iconCornerRadiusRatio

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let rect = CGRect(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2,
                width: side,
                height: side
            )

            ZStack {
                RoundedRectangle(cornerRadius: side * cornerRadiusRatio, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BrandColor.terracottaLight,
                                BrandColor.terracotta,
                                BrandColor.terracottaDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ScrivoraGlyph()
                    .fill(.white)
                    .padding(side * ScrivoraBrandGeometry.glyphInsetRatio)

                ScrivoraGlyphCenterMarks()
                    .fill(BrandColor.terracotta)
                    .frame(width: side, height: side)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Scrivora logo")
    }
}

private struct ScrivoraGlyphCenterMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var path = Path()

        let dotDiameter = side * ScrivoraBrandGeometry.centerDotDiameterRatio
        let dotCenter = CGPoint(
            x: origin.x + side * 0.5,
            y: origin.y + side * ScrivoraBrandGeometry.centerDotCenterYRatio
        )
        path.addEllipse(in: CGRect(
            x: dotCenter.x - dotDiameter / 2,
            y: dotCenter.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
        ))

        let lineRect = CGRect(
            x: origin.x + side * ScrivoraBrandGeometry.centerLineXRatio,
            y: origin.y + side * ScrivoraBrandGeometry.centerLineYRatio,
            width: side * ScrivoraBrandGeometry.centerLineWidthRatio,
            height: side * ScrivoraBrandGeometry.centerLineHeightRatio
        )
        path.addRoundedRect(
            in: lineRect,
            cornerSize: CGSize(
                width: side * ScrivoraBrandGeometry.centerLineWidthRatio / 2,
                height: side * ScrivoraBrandGeometry.centerLineWidthRatio / 2
            )
        )

        return path
    }
}

private struct ScrivoraGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let minX = rect.minX
        let minY = rect.minY

        func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) {
            path.addRoundedRect(
                in: CGRect(x: minX + x * w, y: minY + y * h, width: width * w, height: height * h),
                cornerSize: CGSize(width: radius * w, height: radius * w)
            )
        }

        bar(x: 0.02, y: 0.38, width: 0.06, height: 0.24, radius: 0.03)
        bar(x: 0.14, y: 0.28, width: 0.075, height: 0.44, radius: 0.04)
        bar(x: 0.785, y: 0.28, width: 0.075, height: 0.44, radius: 0.04)
        bar(x: 0.92, y: 0.38, width: 0.06, height: 0.24, radius: 0.03)

        path.move(to: CGPoint(x: minX + 0.50 * w, y: minY + 0.02 * h))
        path.addCurve(
            to: CGPoint(x: minX + 0.64 * w, y: minY + 0.42 * h),
            control1: CGPoint(x: minX + 0.54 * w, y: minY + 0.20 * h),
            control2: CGPoint(x: minX + 0.61 * w, y: minY + 0.31 * h)
        )
        path.addLine(to: CGPoint(x: minX + 0.77 * w, y: minY + 0.50 * h))
        path.addLine(to: CGPoint(x: minX + 0.60 * w, y: minY + 0.58 * h))
        path.addCurve(
            to: CGPoint(x: minX + 0.50 * w, y: minY + 0.98 * h),
            control1: CGPoint(x: minX + 0.58 * w, y: minY + 0.72 * h),
            control2: CGPoint(x: minX + 0.54 * w, y: minY + 0.86 * h)
        )
        path.addCurve(
            to: CGPoint(x: minX + 0.40 * w, y: minY + 0.58 * h),
            control1: CGPoint(x: minX + 0.46 * w, y: minY + 0.86 * h),
            control2: CGPoint(x: minX + 0.42 * w, y: minY + 0.72 * h)
        )
        path.addLine(to: CGPoint(x: minX + 0.23 * w, y: minY + 0.50 * h))
        path.addLine(to: CGPoint(x: minX + 0.36 * w, y: minY + 0.42 * h))
        path.addCurve(
            to: CGPoint(x: minX + 0.50 * w, y: minY + 0.02 * h),
            control1: CGPoint(x: minX + 0.39 * w, y: minY + 0.31 * h),
            control2: CGPoint(x: minX + 0.46 * w, y: minY + 0.20 * h)
        )
        path.closeSubpath()

        return path
    }
}
