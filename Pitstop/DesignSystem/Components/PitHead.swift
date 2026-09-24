import SwiftUI

/// Pit: a round pearl head with a navy face screen set in a thin bezel and two lit lens eyes (product-design.md
/// "Pit visual identity"). It is drawn from the icon's geometry (ADR 0037), so the app and its icon show one face.
/// The eyes carry the state; the head is an object, so it stays pearl in dark mode.
struct PitHead: View {
    var state: PitState = .resting
    /// Bounded life from a model (ADR 0028); the utility layer never sends any.
    var life: PitEyeLife = .still
    var size: CGFloat = DesignTokens.utilityButtonSize
    /// Set by previews and renders; otherwise the accessibility display settings decide.
    var finish: PitHeadFinish?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.pitHeadPressed) private var isPressed
    /// Counts entries into the knock, which replays its two dips.
    @State private var knocks = 0

    private typealias Geometry = PitHeadGeometry

    private var unit: CGFloat {
        size / Geometry.viewBox
    }

    private var pose: PitPose {
        PitPose(state)
    }

    private var shownFinish: PitHeadFinish {
        finish ?? PitHeadFinish(reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
    }

    /// Reduce Motion draws no life even if a model sent some.
    private var shownLife: PitEyeLife {
        reduceMotion ? .still : life
    }

    var body: some View {
        let unit = unit
        ZStack(alignment: .topLeading) {
            shell
            face
            eyes
            // Pressed feedback on the shell, inside the head so it moves with the head's tilt and lift.
            Circle()
                .fill(PitColor.headPressed)
                .place(circle: Geometry.headCenter, radius: Geometry.headRadius, unit: unit)
                .opacity(PitHeadPress.highlightOpacity(isPressed: isPressed))
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        // The head moves only as the pose says (REQ-PIT-024); with Reduce Motion it changes without animation.
        .rotationEffect(.degrees(pose.headTilt), anchor: Geometry.tiltAnchor)
        .offset(y: -pose.headLift * unit)
        .animation(PitHeadMotion.animation(into: state, reduceMotion: reduceMotion), value: state)
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: knocks) { content, dip in
            content.offset(y: dip * unit)
        } keyframes: { _ in
            // Two small dips from the lifted pose: a knock, not a bounce.
            KeyframeTrack {
                for bump in PitHeadMotion.knockBumps {
                    CubicKeyframe(bump.dip, duration: bump.duration)
                }
                SpringKeyframe(0, duration: PitHeadMotion.knockSettle)
            }
        }
        .onChange(of: state) { _, newState in
            if PitHeadMotion.playsBumps(entering: newState, reduceMotion: reduceMotion) {
                knocks += 1
            }
        }
        // One shadow from the head's outline: without the group every layer (screen, lenses, glosses) would cast
        // its own onto the shell, and each animation frame would blur all of them.
        .compositingGroup()
        .shadow(color: PitColor.headShadow, radius: 2.5 * unit, y: unit)
        .accessibilityHidden(true)
    }

    // MARK: Shell

    private var shell: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: PitColor.headShellLight, location: 0),
                        .init(color: PitColor.headShell, location: Geometry.shellLightMidStop),
                        .init(color: PitColor.headShellShade, location: 1),
                    ],
                    center: Geometry.shellLightCenter,
                    startRadius: 0,
                    endRadius: Geometry.shellLightReach * 2 * Geometry.headRadius * unit
                ))
                .place(circle: Geometry.headCenter, radius: Geometry.headRadius, unit: unit)
            Circle()
                .stroke(PitColor.headHairline, lineWidth: shownFinish.hairlineWidth * unit)
                .place(circle: Geometry.headCenter, radius: Geometry.hairlineRadius, unit: unit)
            if shownFinish.showsGloss {
                shellGloss
                    .stroke(
                        PitColor.headGloss,
                        style: StrokeStyle(lineWidth: Geometry.glossLineWidth * unit, lineCap: .round)
                    )
            }
        }
    }

    private var shellGloss: Path {
        let center = Geometry.glossCenter
        func angle(_ point: CGPoint) -> Angle {
            .radians(atan2(point.y - center.y, point.x - center.x))
        }
        var path = Path()
        path.addArc(
            center: center.scaled(unit),
            radius: Geometry.glossRadius * unit,
            startAngle: angle(Geometry.glossStart),
            endAngle: angle(Geometry.glossEnd),
            clockwise: false
        )
        return path
    }

    // MARK: Face screen

    private var face: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(PitColor.headBezel)
                .place(Geometry.bezel, unit: unit)
            Capsule()
                .fill(LinearGradient(
                    colors: [PitColor.headVisorTop, PitColor.headVisorBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .place(Geometry.visor, unit: unit)
            if shownFinish.showsGlow {
                Capsule()
                    .fill(EllipticalGradient(
                        colors: [PitColor.headGlow.opacity(pose.glow), PitColor.headGlow.opacity(0)],
                        center: Geometry.glowCenter,
                        startRadiusFraction: 0,
                        endRadiusFraction: Geometry.glowReach
                    ))
                    .place(Geometry.visor, unit: unit)
            }
            if shownFinish.showsGloss {
                visorGloss
                    .stroke(
                        PitColor.headVisorGloss,
                        style: StrokeStyle(lineWidth: Geometry.visorGlossLineWidth * unit, lineCap: .round)
                    )
            }
        }
    }

    private var visorGloss: Path {
        var path = Path()
        path.move(to: Geometry.visorGlossStart.scaled(unit))
        path.addQuadCurve(to: Geometry.visorGlossEnd.scaled(unit), control: Geometry.visorGlossControl.scaled(unit))
        return path
    }

    // MARK: Eyes

    private var eyes: some View {
        // The eye on the side Pit looks toward leads; the other follows.
        let trailing = PitEyeAnimation.trailingEyeDelay
        let leftTrails = state == .lookRight
        return ZStack(alignment: .topLeading) {
            eye(pose.left, at: Geometry.leftEyeCenter, delay: leftTrails ? trailing : 0)
            eye(pose.right, at: Geometry.rightEyeCenter, delay: leftTrails ? 0 : trailing)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        // The face screen is dark in both appearances, so the eyes resolve their roles as on a dark surface: the
        // knock's `accentPrimary` is then the pale accent, which reads on navy where the light one would not.
        .environment(\.colorScheme, .dark)
        // A breath scales the eyes about the point between them; the head itself never breathes (REQ-PIT-024).
        .scaleEffect(shownLife.breath, anchor: Geometry.eyesAnchor)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: shownLife.breath)
        .opacity(pose.dimmed ? 0.35 : 1)
    }

    private var eyeColor: Color {
        switch pose.eyeTint {
        case .lit: PitColor.headEye
        case .accent: PitColor.accentPrimary
        }
    }

    private func eye(_ eye: PitEyePose, at center: CGPoint, delay: TimeInterval) -> some View {
        let isLens = eye.outline == .lens
        let lens = Geometry.lensRadii
        let halo = CGSize(width: lens.width + Geometry.haloGrowth, height: lens.height + Geometry.haloGrowth)
        let highlight = Geometry.highlightRadii
        return ZStack {
            ZStack {
                if shownFinish.showsHalo {
                    Ellipse()
                        .fill(eyeColor.opacity(0.18))
                        .frame(width: 2 * halo.width * unit, height: 2 * halo.height * unit)
                }
                Ellipse()
                    .fill(eyeColor)
                    .frame(width: 2 * lens.width * unit, height: 2 * lens.height * unit)
                Ellipse()
                    .fill(PitColor.headEyeHighlight)
                    .frame(width: 2 * highlight.width * unit, height: 2 * highlight.height * unit)
                    .offset(x: Geometry.highlightCenter.x * unit, y: Geometry.highlightCenter.y * unit)
                    .opacity(pose.showsHighlight ? 1 : 0)
            }
            .scaleEffect(x: eye.widthScale, y: eye.heightScale)
            .rotationEffect(.degrees(eye.rotation))
            .opacity(isLens ? 1 : 0)

            PitClosedEyeArc()
                .stroke(eyeColor, style: StrokeStyle(lineWidth: Geometry.arcLineWidth * unit, lineCap: .round))
                .frame(width: 2 * Geometry.arcHalfWidth * unit, height: Geometry.arcHeight * unit)
                .offset(y: Geometry.arcCenterDrop * unit)
                .opacity(isLens ? 0 : 1)
        }
        .frame(width: 2 * halo.width * unit, height: 2 * halo.height * unit)
        .position(
            x: (center.x + pose.eyeOffset.x) * unit,
            y: (center.y + pose.eyeOffset.y) * unit
        )
        .animation(PitHeadMotion.animation(into: state, reduceMotion: reduceMotion)?.delay(delay), value: state)
        // Life is a separate offset so its steps never interrupt a state's spring.
        .offset(x: shownLife.gaze.x * 1.2 * unit, y: shownLife.gaze.y * unit)
        .animation(reduceMotion ? nil : shownLife.animation.delay(delay), value: shownLife.gaze)
    }
}

extension EnvironmentValues {
    /// Set by `PitHeadButtonStyle` while Pit's control is pressed.
    @Entry var pitHeadPressed = false
}

/// How the head moves between poses (ADR 0028 timings, REQ-PIT-024).
enum PitHeadMotion {
    /// How far each of the knock's two dips lowers the head from its lifted pose, in head units.
    static let knockDip: CGFloat = 1.5
    /// The keyframes the knock plays, in order: dip, back, dip (the head view builds its track from them).
    static let knockBumps: [(dip: CGFloat, duration: TimeInterval)] = [
        (knockDip, 0.09), (0, 0.1), (knockDip, 0.09),
    ]
    /// After the last dip the head springs back to its lifted pose.
    static let knockSettle: TimeInterval = 0.2

    /// With Reduce Motion every pose is shown at once (pit-behavior-and-motion.md, "Accessibility").
    static func animation(into state: PitState, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : PitEyeAnimation.into(state)
    }

    /// With Reduce Motion the knock is the lifted pose alone, with no dips (REQ-PIT-018).
    static func playsBumps(entering state: PitState, reduceMotion: Bool) -> Bool {
        state == .knock && !reduceMotion
    }
}

/// A closed eye: a shallow upward arc across its rect, from the lower corners to its apex at the top edge (the
/// mockup's quadratic curve, whose control point lies twice the rect's height above the ends).
struct PitClosedEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - 2 * rect.height)
        )
        return path
    }
}

private extension CGPoint {
    func scaled(_ unit: CGFloat) -> CGPoint {
        CGPoint(x: x * unit, y: y * unit)
    }
}

private extension View {
    /// Places a view on the head's view box, scaled to points.
    func place(_ rect: CGRect, unit: CGFloat) -> some View {
        frame(width: rect.width * unit, height: rect.height * unit)
            .offset(x: rect.minX * unit, y: rect.minY * unit)
    }

    func place(circle center: CGPoint, radius: CGFloat, unit: CGFloat) -> some View {
        place(CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius), unit: unit)
    }
}

#if DEBUG
    #Preview("Pit head") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    PitHead(size: DesignTokens.utilityButtonSize)
                    PitHead(size: 44)
                    PitHead(finish: PitHeadFinish(reduceTransparency: true, increaseContrast: false))
                    PitHead(finish: PitHeadFinish(reduceTransparency: false, increaseContrast: true))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(64)), count: 4), spacing: 8) {
                    ForEach(PitState.allCases, id: \.self) { state in
                        PitHead(state: state)
                    }
                }
            }
        }
    }
#endif
