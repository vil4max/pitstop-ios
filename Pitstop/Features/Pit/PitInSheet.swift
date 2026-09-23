import SwiftUI

/// What Pit needs inside a sheet: the one capture entry, Pit's motion, and the surface under every sheet. The root
/// view provides it; outside the root (previews) sheets show no Pit.
///
/// Equal by identity and the visible surface, not by Pit's state: the root re-renders on every blink, and a new
/// value each time would invalidate every open sheet.
struct PitInSheetContext: Equatable {
    let entry: PitCaptureEntry
    let presence: PitPresenceModel
    /// A prior for capture only (REQ-CAPTURE-022).
    let visible: VisibleFeature

    static func == (lhs: PitInSheetContext, rhs: PitInSheetContext) -> Bool {
        lhs.entry === rhs.entry && lhs.presence === rhs.presence && lhs.visible == rhs.visible
    }
}

extension EnvironmentValues {
    @Entry var pitInSheet: PitInSheetContext?
}

extension View {
    /// Presents a sheet that keeps Pit at its bottom-trailing spot (REQ-UTILITY-012). Every sheet other than the
    /// capture surface is presented through `pitSheet` or carries `pitStaysInSheet()` (`PitInSheetTests`).
    func pitSheet<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        sheet(item: item) { item in
            content(item).pitStaysInSheet()
        }
    }

    func pitSheet(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
        sheet(isPresented: isPresented) {
            content().pitStaysInSheet()
        }
    }

    /// Apply to a sheet's content, outside its navigation stack. The sheet covers the utility layer, Settings
    /// included; Pit alone stays, and tapping him opens capture over this sheet (REQ-PIT-026).
    func pitStaysInSheet() -> some View {
        modifier(PitStaysInSheet())
    }
}

private struct PitStaysInSheet: ViewModifier {
    @Environment(\.pitInSheet) private var context
    /// This sheet as a capture host; a new sheet is a new host.
    @State private var id = UUID()

    func body(content: Content) -> some View {
        let host = PitCaptureEntry.Host.sheet(id)
        // Read here, not inside the binding, so the sheet follows the entry.
        let isCapturing = context?.entry.host == host
        content
            // A safe-area inset, not an overlay: the sheet's rows scroll clear of Pit, so he never covers a
            // trailing control, and it keeps the keyboard's safe area, so he rides above the keyboard and any
            // accessory bar instead of over them.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let context {
                    PitInSheetControl(context: context, host: host)
                }
            }
            .sheet(isPresented: Binding(
                get: { isCapturing },
                set: { isPresented in
                    if !isPresented {
                        context?.entry.close(from: host)
                    }
                }
            )) {
                if let context {
                    // The saved moment still names where the capture went, in words (REQ-CAPTURE-010).
                    PitCaptureView(
                        viewModel: context.entry.capture,
                        question: context.entry.question,
                        visible: context.visible,
                        onOpen: nil
                    )
                }
            }
    }
}

/// Reads Pit's motion on its own, so a blink redraws the control and not the sheet around it.
private struct PitInSheetControl: View {
    let context: PitInSheetContext
    let host: PitCaptureEntry.Host

    var body: some View {
        HStack {
            Spacer()
            PitUtilityButton(state: context.presence.state) {
                context.entry.open(from: host)
            }
        }
        .utilityInsets()
    }
}
