import SwiftUI

/// Settings bottom-leading, Pit bottom-trailing. Two separate controls with no selection state: a utility layer, not a
/// tab bar (REQ-UTILITY-001). Settings is a glass circle; Pit's whole circle is his head, with no glass behind it
/// (ADR 0039).
struct UtilityLayer: View {
    let onSettings: () -> Void
    let onPit: () -> Void
    var pitState: PitState = .resting

    var body: some View {
        GlassEffectContainer {
            HStack {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        // Fixed size: the glyph lives in a fixed circle and must not outgrow it at AX sizes.
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: DesignTokens.utilityButtonSize, height: DesignTokens.utilityButtonSize)
                        // The whole circle is the target, not only the drawn glyph.
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(Text("utility.settings"))
                .accessibilityIdentifier("utility.settings")

                Spacer()

                PitUtilityButton(state: pitState, action: onPit)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(PitColor.contentPrimary)
        .utilityInsets()
    }
}

/// Pit's control. The utility layer and every sheet other than the capture surface show this one control at the
/// same bottom-trailing spot, so Pit looks and reads the same wherever he is (REQ-UTILITY-012).
struct PitUtilityButton: View {
    let state: PitState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The head animates itself and drops animation with Reduce Motion.
            PitHead(state: state, size: DesignTokens.utilityButtonSize)
                .contentShape(.circle)
        }
        .buttonStyle(PitHeadButtonStyle())
        .accessibilityLabel(Text("utility.pit"))
        // A knock is a request, not motion: it is stated once as a value, not announced (REQ-PIT-019).
        .accessibilityValue(state == .knock ? Text("utility.pit.asking") : Text(verbatim: ""))
        .accessibilityHint(Text("utility.pit.hint"))
        .accessibilityIdentifier("utility.pit")
    }
}

extension View {
    /// The layer's insets from the screen edges; Pit inside a sheet keeps the same ones.
    func utilityInsets() -> some View {
        padding(.horizontal, DesignTokens.screenPadding)
            .padding(.bottom, 6)
    }
}

/// The touch feedback interactive glass gave Pit's circle, kept now that the circle is his head: it shrinks a
/// little and darkens while pressed (ADR 0039).
enum PitHeadPress {
    static let pressedScale: CGFloat = 0.92
    /// A disabled Pit (a sheet saving) is shown dimmed, as a disabled plain button is.
    static let disabledOpacity: Double = 0.45

    static func scale(isPressed: Bool) -> CGFloat {
        isPressed ? pressedScale : 1
    }

    static func highlightOpacity(isPressed: Bool) -> Double {
        isPressed ? 1 : 0
    }
}

struct PitHeadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PitHeadPressed(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct PitHeadPressed<Label: View>: View {
    let label: Label
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            // The head draws the tint itself, so it follows a lifted or tilted head (a knock is when Pit is tapped).
            .environment(\.pitHeadPressed, isPressed)
            .scaleEffect(PitHeadPress.scale(isPressed: isPressed))
            // Dimmed as one object: PitHead flattens itself into one layer before its shadow, so this opacity fades the
            // head and its shadow together and no layer of the head shows through another.
            .opacity(isEnabled ? 1 : PitHeadPress.disabledOpacity)
            // Feedback, not motion: with Reduce Motion it changes without a spring.
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.3), value: isPressed)
    }
}
