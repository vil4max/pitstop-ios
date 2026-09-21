import SwiftUI

/// Settings bottom-leading, Pit bottom-trailing. Two separate glass controls with no selection
/// state: a utility layer, not a tab bar (REQ-UTILITY-001).
struct UtilityLayer: View {
    let onSettings: () -> Void
    let onPit: () -> Void
    var pitState: PitState = .resting

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                Button(action: onPit) {
                    PitEyesGlyph(state: pitState)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: pitState)
                        .frame(width: DesignTokens.utilityButtonSize, height: DesignTokens.utilityButtonSize)
                        .contentShape(.circle)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(Text("utility.pit"))
                .accessibilityHint(Text("utility.pit.hint"))
                .accessibilityIdentifier("utility.pit")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(PitColor.contentPrimary)
        .padding(.horizontal, DesignTokens.screenPadding)
        .padding(.bottom, 6)
    }
}
