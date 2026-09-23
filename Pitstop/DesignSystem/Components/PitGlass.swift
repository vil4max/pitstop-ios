import SwiftUI

extension View {
    /// The only way feature code gets Liquid Glass (REQ-DESIGN-002): floating controls only. With Reduce
    /// Transparency or Increase Contrast the control becomes an opaque `surfaceSecondary` shape with a hairline
    /// (proposal §6).
    func pitGlass(in shape: some Shape, interactive: Bool = true) -> some View {
        modifier(PitGlassModifier(shape: shape, interactive: interactive))
    }
}

private struct PitGlassModifier<GlassShape: Shape>: ViewModifier {
    let shape: GlassShape
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(PitColor.surfaceSecondary, in: shape)
                .overlay(shape.stroke(PitColor.separator, lineWidth: DesignTokens.hairline))
        } else {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        }
    }
}
