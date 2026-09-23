import CoreGraphics
import SwiftUI

/// Pit's head as the app icon draws it at rest (ADR 0037), in the icon's 56-unit view box. One unit is one point
/// at the utility control's 56 pt size; the sheet header scales the same drawing to 44 pt. Changing a number here
/// changes the face the icon shows, so the icon would have to be regenerated with it (REQ-ICON-002).
enum PitHeadGeometry {
    static let viewBox: CGFloat = 56

    static let headCenter = CGPoint(x: 28, y: 28)
    static let headRadius: CGFloat = 27
    /// The hairline sits half a unit inside the shell's edge.
    static let hairlineRadius: CGFloat = 26.5

    /// The grey rim and the navy face screen inside it; both are capsules (the corner radius is half the height).
    static let bezel = CGRect(x: 8, y: 16.5, width: 40, height: 25.5)
    static let visor = CGRect(x: 9, y: 17.5, width: 38, height: 23.5)

    static let leftEyeCenter = CGPoint(x: 22, y: 29.2)
    static let rightEyeCenter = CGPoint(x: 34, y: 29.2)
    /// The lens radii at rest.
    static let lensRadii = CGSize(width: 4.1, height: 5.9)
    /// At rest the tops of both lenses lean outward by this many degrees.
    static let restingOutwardTilt: Double = 6
    /// The highlight, in each lens's own frame (before its tilt).
    static let highlightCenter = CGPoint(x: -1.1, y: -2.3)
    static let highlightRadii = CGSize(width: 1.3, height: 1.7)
    /// The halo around a lens is the lens grown by this much on each radius.
    static let haloGrowth: CGFloat = 1.6

    /// Closed eyes are shallow upward arcs: from `arcHalfWidth` either side of the eye centre, `arcDrop` below it,
    /// through a control point `arcRise` above it.
    static let arcHalfWidth: CGFloat = 3.4
    static let arcDrop: CGFloat = 1.4
    static let arcRise: CGFloat = 2.8
    static let arcLineWidth: CGFloat = 1.9
    /// The drawn arc's height: a quadratic curve reaches halfway toward its control point.
    static var arcHeight: CGFloat {
        (arcDrop + arcRise) / 2
    }

    /// How far the middle of the arc's bounds lies below the eye centre.
    static var arcCenterDrop: CGFloat {
        (3 * arcDrop - arcRise) / 4
    }

    /// The point between the two eyes at rest.
    static var eyesAnchor: UnitPoint {
        UnitPoint(
            x: (leftEyeCenter.x + rightEyeCenter.x) / 2 / viewBox,
            y: (leftEyeCenter.y + rightEyeCenter.y) / 2 / viewBox
        )
    }

    /// The shell's gloss: an arc of radius 20 from (11, 17) to (30, 8), nearly concentric with the head.
    static let glossStart = CGPoint(x: 11, y: 17)
    static let glossEnd = CGPoint(x: 30, y: 8)
    static let glossRadius: CGFloat = 20
    static let glossLineWidth: CGFloat = 2.2
    /// The face screen's gloss: a quadratic curve across its upper left.
    static let visorGlossStart = CGPoint(x: 15, y: 22.6)
    static let visorGlossControl = CGPoint(x: 22, y: 20)
    static let visorGlossEnd = CGPoint(x: 31, y: 20.3)
    static let visorGlossLineWidth: CGFloat = 1.3

    /// The shell's light: a radial gradient centred up and to the left, reaching 0.8 of the head's diameter.
    static let shellLightCenter = UnitPoint(x: 0.36, y: 0.3)
    static let shellLightReach: CGFloat = 0.8
    static let shellLightMidStop: CGFloat = 0.62

    /// The glow behind the eyes, centred a little below the screen's middle.
    static let glowCenter = UnitPoint(x: 0.5, y: 0.55)
    static let glowReach: CGFloat = 0.55

    /// The shell's gloss arc centre, from the two end points, the radius and SVG's small clockwise arc.
    static var glossCenter: CGPoint {
        let middle = CGPoint(x: (glossStart.x + glossEnd.x) / 2, y: (glossStart.y + glossEnd.y) / 2)
        let chord = CGPoint(x: glossEnd.x - glossStart.x, y: glossEnd.y - glossStart.y)
        let length = (chord.x * chord.x + chord.y * chord.y).squareRoot()
        let depth = (glossRadius * glossRadius - length * length / 4).squareRoot()
        // Perpendicular to the chord, toward the inside of the head.
        return CGPoint(x: middle.x - chord.y / length * depth, y: middle.y + chord.x / length * depth)
    }
}

/// How the head is finished under the accessibility display settings (ADR 0038 gives glass the same two
/// variants). Reduce Transparency removes every translucent layer: the glosses, the glow and the eye halos, so the
/// head is drawn from opaque fills only. Increase Contrast removes them too, and the colour roles darken the shell's
/// edge, the bezel and the screen, while the hairline gets heavier.
struct PitHeadFinish: Hashable {
    let showsGloss: Bool
    let showsGlow: Bool
    let showsHalo: Bool
    /// In head units.
    let hairlineWidth: CGFloat

    init(reduceTransparency: Bool, increaseContrast: Bool) {
        let plain = reduceTransparency || increaseContrast
        showsGloss = !plain
        showsGlow = !plain
        showsHalo = !plain
        hairlineWidth = increaseContrast ? 1.5 : 1
    }

    static let standard = PitHeadFinish(reduceTransparency: false, increaseContrast: false)
}
