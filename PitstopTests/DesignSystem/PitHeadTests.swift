import CoreGraphics
@testable import Pitstop
import SwiftUI
import Testing
import UIKit

/// Pit's head (RD-011): the icon's geometry, the accessibility finishes and the colour roles it is drawn with.
@MainActor
@Suite("Pit head")
struct PitHeadTests {
    private typealias Geometry = PitHeadGeometry

    @Test("ADR-0037: the head is drawn from the icon's resting geometry")
    func geometryMatchesTheIcon() {
        #expect(Geometry.viewBox == 56)
        #expect(Geometry.headCenter == CGPoint(x: 28, y: 28) && Geometry.headRadius == 27)
        #expect(Geometry.bezel == CGRect(x: 8, y: 16.5, width: 40, height: 25.5))
        #expect(Geometry.visor == CGRect(x: 9, y: 17.5, width: 38, height: 23.5))
        #expect(Geometry.leftEyeCenter == CGPoint(x: 22, y: 29.2))
        #expect(Geometry.rightEyeCenter == CGPoint(x: 34, y: 29.2))
        #expect(Geometry.lensRadii == CGSize(width: 4.1, height: 5.9))
        #expect(Geometry.restingOutwardTilt == 6)
        #expect(Geometry.highlightCenter == CGPoint(x: -1.1, y: -2.3))
        #expect(Geometry.highlightRadii == CGSize(width: 1.3, height: 1.7))
        // At the icon's 15.2 px per unit on the 1024 canvas the head spans x 102–922, 80 % of the width.
        let left = 512 + (Geometry.headCenter.x - Geometry.headRadius - Geometry.viewBox / 2) * 15.2
        let right = 512 + (Geometry.headCenter.x + Geometry.headRadius - Geometry.viewBox / 2) * 15.2
        #expect(abs(left - 101.6) < 0.01 && abs(right - 922.4) < 0.01)
    }

    @Test("ADR-0037: the screen sits in the bezel, the bezel on the head, and the resting eyes on the screen")
    func partsNest() {
        let head = CGRect(
            x: Geometry.headCenter.x - Geometry.headRadius, y: Geometry.headCenter.y - Geometry.headRadius,
            width: 2 * Geometry.headRadius, height: 2 * Geometry.headRadius
        )
        #expect(head.contains(Geometry.bezel) && Geometry.bezel.contains(Geometry.visor))
        for center in [Geometry.leftEyeCenter, Geometry.rightEyeCenter] {
            let lens = Self.tiltedLensBounds(center: center, degrees: Geometry.restingOutwardTilt)
            #expect(Geometry.visor.insetBy(dx: 1, dy: 1).contains(lens), "\(lens) leaves the screen")
        }
        // The shell's gloss arc is nearly concentric with the head, inside its edge.
        let gloss = Geometry.glossCenter
        #expect(abs(gloss.x - 27.78) < 0.01 && abs(gloss.y - 27.88) < 0.01)
    }

    @Test("ADR-0038: Reduce Transparency and Increase Contrast drop the glosses, glow and halos and firm the edge")
    func accessibilityFinishes() {
        let standard = PitHeadFinish.standard
        #expect(standard.showsGloss && standard.showsGlow && standard.showsHalo)
        for finish in [
            PitHeadFinish(reduceTransparency: true, increaseContrast: false),
            PitHeadFinish(reduceTransparency: false, increaseContrast: true),
            PitHeadFinish(reduceTransparency: true, increaseContrast: true),
        ] {
            #expect(!finish.showsGloss && !finish.showsGlow && !finish.showsHalo)
        }
        #expect(PitHeadFinish(reduceTransparency: false, increaseContrast: true).hairlineWidth > standard.hairlineWidth)
    }

    @Test("Pit visual identity: the head stays pearl with a navy screen in dark mode")
    func headIsAnObject() {
        for role in [PitColor.headShell, PitColor.headBezel, PitColor.headVisorTop, PitColor.headVisorBottom] {
            #expect(Self.resolve(role, dark: false).sameColour(as: Self.resolve(role, dark: true)))
        }
        let shell = Self.resolve(PitColor.headShell, dark: true)
        #expect(Self.luminance(shell) > 0.85)
    }

    @Test("Pit visual identity: the lit eyes read on the screen, and the screen on the shell, in every appearance")
    func eyesAndScreenContrast() {
        for dark in [false, true] {
            for highContrast in [false, true] {
                let visor = Self.resolve(PitColor.headVisorTop, dark: dark, highContrast: highContrast)
                let eye = Self.resolve(PitColor.headEye, dark: dark, highContrast: highContrast)
                let shell = Self.resolve(PitColor.headShellShade, dark: dark, highContrast: highContrast)
                #expect(Self.contrast(eye, visor) >= 7)
                #expect(Self.contrast(shell, visor) >= 7)
            }
        }
    }

    @Test("ADR-0038: Increase Contrast darkens the shell's edge, the bezel and the screen, and firms the hairline")
    func increaseContrastFirmsTheEdges() {
        for dark in [false, true] {
            for role in [PitColor.headShellShade, PitColor.headBezel, PitColor.headVisorTop] {
                let normal = Self.luminance(Self.resolve(role, dark: dark))
                let high = Self.luminance(Self.resolve(role, dark: dark, highContrast: true))
                #expect(high < normal)
            }
            let hairline = Self.resolve(PitColor.headHairline, dark: dark).alpha
            #expect(Self.resolve(PitColor.headHairline, dark: dark, highContrast: true).alpha > hairline)
            let eye = Self.luminance(Self.resolve(PitColor.headEye, dark: dark))
            #expect(Self.luminance(Self.resolve(PitColor.headEye, dark: dark, highContrast: true)) >= eye)
        }
    }

    @Test("ADR-0037: the rendered head shows the pearl shell, the navy screen and the lit eyes where the icon has them")
    func renderedHeadMatchesTheGeometry() throws {
        for size in [CGFloat(56), 44] {
            let image = try #require(Self.render(PitHead(size: size, finish: .standard), size: size))
            let unit = size / Geometry.viewBox
            func pixel(_ across: CGFloat, _ down: CGFloat) -> CGFloat {
                Self.brightness(of: image, at: CGPoint(x: across * unit, y: down * unit))
            }
            #expect(pixel(28, 10) > 0.8, "shell above the screen at \(size) pt")
            #expect(pixel(28, 36) < 0.3, "screen between the eyes at \(size) pt")
            #expect(pixel(22, 31) > 0.8, "left eye at \(size) pt")
            #expect(pixel(34, 31) > 0.8, "right eye at \(size) pt")
            #expect(pixel(0.3, 0.3) < 0.05, "outside the head at \(size) pt")
        }
    }

    @Test("ADR-0039: the head casts one shadow from its outline; no part of it shades the shell below the screen")
    func oneShadowUnderTheHead() throws {
        let size: CGFloat = 112
        let image = try #require(Self.render(PitHead(size: size, finish: .standard), size: size))
        let unit = size / Geometry.viewBox
        // The shell just below the bezel, which a shadow of the bezel or the screen would darken.
        for across in [CGFloat(20), 28, 36] {
            let shell = Self.brightness(of: image, at: CGPoint(x: across * unit, y: 43.5 * unit))
            #expect(shell > 0.88, "shell below the screen at x \(across): \(shell)")
        }
        // The shadow itself still falls outside the head's lower edge.
        let below = Self.rgb(of: image, at: CGPoint(x: 28 * unit, y: 55.8 * unit))
        #expect(below.alpha > 0.02, "no shadow under the head")
    }

    // MARK: Helpers

    struct Components {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        func sameColour(as other: Components) -> Bool {
            abs(red - other.red) < 0.001 && abs(green - other.green) < 0.001 && abs(blue - other.blue) < 0.001
                && abs(alpha - other.alpha) < 0.001
        }
    }

    static func resolve(_ color: Color, dark: Bool, highContrast: Bool = false) -> Components {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = dark ? .dark : .light
            traits.accessibilityContrast = highContrast ? .high : .normal
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Components(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// WCAG 2 relative luminance of an opaque colour.
    static func luminance(_ color: Components) -> CGFloat {
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red) + 0.7152 * channel(color.green) + 0.0722 * channel(color.blue)
    }

    static func contrast(_ first: Components, _ second: Components) -> CGFloat {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The axis-aligned bounds of a resting lens tilted by `degrees`.
    static func tiltedLensBounds(center: CGPoint, degrees: Double) -> CGRect {
        let radians = degrees * .pi / 180
        let (rx, ry) = (Geometry.lensRadii.width, Geometry.lensRadii.height)
        let halfWidth = ((rx * cos(radians)) * (rx * cos(radians)) + (ry * sin(radians)) * (ry * sin(radians)))
            .squareRoot()
        let halfHeight = ((rx * sin(radians)) * (rx * sin(radians)) + (ry * cos(radians)) * (ry * cos(radians)))
            .squareRoot()
        return CGRect(x: center.x - halfWidth, y: center.y - halfHeight, width: 2 * halfWidth, height: 2 * halfHeight)
    }

    /// Renders a view at 1 pixel per point over black.
    static func render(_ view: some View, size: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.cgImage
    }

    /// Premultiplied brightness (mean of the channels) of one pixel, so a transparent pixel reads as black.
    static func brightness(of image: CGImage, at point: CGPoint) -> CGFloat {
        let colour = rgb(of: image, at: point)
        return (colour.red + colour.green + colour.blue) / 3
    }

    /// Premultiplied red, green and blue of one pixel in 0...1.
    static func rgb(of image: CGImage, at point: CGPoint) -> Components {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return Components(red: 0, green: 0, blue: 0, alpha: 0) }
        let column = min(max(Int(point.x), 0), width - 1)
        let row = min(max(Int(point.y), 0), height - 1)
        let offset = (row * width + column) * 4
        return Components(
            red: CGFloat(pixels[offset]) / 255,
            green: CGFloat(pixels[offset + 1]) / 255,
            blue: CGFloat(pixels[offset + 2]) / 255,
            alpha: CGFloat(pixels[offset + 3]) / 255
        )
    }
}
