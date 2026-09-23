import SwiftUI

/// Settings bottom-leading, Pit bottom-trailing. Two separate glass controls with no selection
/// state: a utility layer, not a tab bar (REQ-UTILITY-001).
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
            // The glyph animates itself and drops animation with Reduce Motion.
            PitEyesGlyph(state: state)
                .frame(width: DesignTokens.utilityButtonSize, height: DesignTokens.utilityButtonSize)
                .contentShape(.circle)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonStyle(.plain)
        .foregroundStyle(PitColor.contentPrimary)
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
