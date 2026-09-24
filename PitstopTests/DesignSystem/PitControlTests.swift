import Foundation
@testable import Pitstop
import SwiftUI
import Testing

/// Pit's control is his head, in the utility layer, inside sheets and in the capture sheet header (RD-011).
@Suite("Pit control")
struct PitControlTests {
    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // DesignSystem
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
    }

    /// The source of one declaration, from its first line to the next top-level declaration.
    private static func declaration(_ name: String, in path: String) throws -> Substring {
        let text = try source(path)
        let start = try #require(text.range(of: name))
        let rest = text[start.upperBound...]
        let end = rest.range(of: "\n}\n")?.upperBound ?? rest.endIndex
        return rest[..<end]
    }

    @Test("ADR-0039: Pit's control is his 56 pt head with no glass behind it; Settings keeps its glass circle")
    func controlIsTheHead() throws {
        let button = try Self.declaration(
            "struct PitUtilityButton",
            in: "Pitstop/DesignSystem/Components/UtilityLayer.swift"
        )
        #expect(button.contains("PitHead(state: state, size: DesignTokens.utilityButtonSize)"))
        #expect(button.contains(".buttonStyle(PitHeadButtonStyle())"))
        #expect(!button.contains("glass") && !button.contains("Glass"))
        let layer = try Self.declaration(
            "struct UtilityLayer",
            in: "Pitstop/DesignSystem/Components/UtilityLayer.swift"
        )
        #expect(layer.contains(".glassEffect(.regular.interactive(), in: .circle)"), "Settings lost its glass")
        #expect(layer.contains("PitUtilityButton(state: pitState, action: onPit)"))
        #expect(DesignTokens.utilityButtonSize == 56)
    }

    @Test("ADR-0039: the control keeps its label, hint, knock value and identifier")
    func controlKeepsItsAccessibility() throws {
        let button = try Self.declaration(
            "struct PitUtilityButton",
            in: "Pitstop/DesignSystem/Components/UtilityLayer.swift"
        )
        for line in [
            #".accessibilityLabel(Text("utility.pit"))"#,
            #".accessibilityValue(state == .knock ? Text("utility.pit.asking") : Text(verbatim: ""))"#,
            #".accessibilityHint(Text("utility.pit.hint"))"#,
            #".accessibilityIdentifier("utility.pit")"#,
        ] {
            #expect(button.contains(line), "lost \(line)")
        }
    }

    @Test("ADR-0039: Pit inside a sheet is the same control, disabled while the sheet saves")
    func sheetControlIsTheSameHead() throws {
        let control = try Self.declaration("struct PitInSheetControl", in: "Pitstop/Features/Pit/PitInSheet.swift")
        #expect(control.contains("PitUtilityButton(state: context.presence.state)"))
        #expect(control.contains(".disabled(saving.isSaving)"))
        #expect(PitHeadPress.disabledOpacity < 1)
    }

    @Test("ADR-0039: the capture sheet header shows the 44 pt head beside the moment title")
    func headerShowsTheHead() throws {
        let header = try Self.declaration("struct PitMomentHeader", in: "Pitstop/Features/Pit/PitSheetParts.swift")
        #expect(header.contains("PitHead(state: eyes, life: life, size: DesignTokens.pitHeaderHeadSize)"))
        #expect(DesignTokens.pitHeaderHeadSize == 44)
    }

    @MainActor
    @Test("ADR-0039: a disabled Pit is dimmed as one object, not layer by layer")
    func disabledHeadDimsEvenly() throws {
        // The control draws the head at its fixed 56 pt.
        let size = DesignTokens.utilityButtonSize
        func render(enabled: Bool) throws -> CGImage {
            try #require(PitHeadTests.render(
                PitUtilityButton(state: .resting) {}
                    .disabled(!enabled)
                    .environment(\.dynamicTypeSize, .large)
                    .frame(width: size, height: size)
                    .background(PitColor.headShellLight),
                size: size
            ))
        }
        let unit = size / PitHeadGeometry.viewBox
        // Inside the left lens, below its highlight.
        let eye = CGPoint(x: 22 * unit, y: 32 * unit)
        let enabled = try PitHeadTests.brightness(of: render(enabled: true), at: eye)
        let disabled = try PitHeadTests.brightness(of: render(enabled: false), at: eye)
        // As one object the lit eye fades toward the white ground; layer by layer the dark screen shows through it.
        let ground: CGFloat = 0.7
        let opacity = CGFloat(PitHeadPress.disabledOpacity)
        #expect(disabled > opacity * enabled + (1 - opacity) * ground, "eye \(disabled), enabled \(enabled)")
    }

    @Test("ADR-0039: pressing the head shrinks and darkens it, as the glass circle's touch feedback did")
    func pressFeedback() {
        #expect(PitHeadPress.scale(isPressed: false) == 1)
        #expect(PitHeadPress.highlightOpacity(isPressed: false) == 0)
        #expect(PitHeadPress.scale(isPressed: true) < 1 && PitHeadPress.scale(isPressed: true) >= 0.9)
        #expect(PitHeadPress.highlightOpacity(isPressed: true) > 0)
    }
}
