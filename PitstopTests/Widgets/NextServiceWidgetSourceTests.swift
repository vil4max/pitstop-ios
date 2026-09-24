import Foundation
import Testing

/// The next-service widget's view lives in the extension, which the test host cannot import, so its look contracts
/// are read from the source file, as `CaptureWidgetSourceTests` and `DesignRulesTests` read theirs. Its content,
/// timeline and store access are tested on the shared code in `NextServiceWidgetTests`.
@Suite("Next-service widget source")
struct NextServiceWidgetSourceTests {
    private static let file = URL(filePath: #filePath)
        .deletingLastPathComponent() // Widgets
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()
        .appending(path: "PitstopWidgets/NextServiceWidget.swift")

    /// Code only: whole-line comments may explain what the code does not do.
    private func code() throws -> String {
        try String(contentsOf: Self.file, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// One family's view property of `NextServiceWidgetView`, from its declaration to its closing brace, so a check
    /// cannot be met by another family's branch.
    private func family(_ name: String) throws -> Substring {
        let code = try code()
        let start = try #require(code.range(of: "private var \(name): some View {"), "no \(name) family in the view")
        let end = try #require(
            code.range(of: "\n    }\n", range: start.upperBound ..< code.endIndex),
            "the \(name) family does not close"
        )
        return code[start.lowerBound ..< end.upperBound]
    }

    @Test("ADR-0036, REQ-WIDGET-007: the widget keeps its families, link, kind and read-only timeline")
    func keepsContractsOfTheDeliveredWidget() throws {
        let code = try code()
        #expect(code.contains(".supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])"))
        #expect(code.contains(".widgetURL(AppLink.service.url)"))
        #expect(code.contains("StaticConfiguration(kind: NextServiceWidgetKind.kind"))
        #expect(code.contains("try StoreLocation.readableGroupStore().map(NextServiceStoreReader.facts(at:))"))
        #expect(code.contains("let policy: TimelineReloadPolicy = plan.refreshDate.map { .after($0) } ?? .never"))
        for name in ["small", "rectangular"] {
            #expect(try family(name).contains(".privacySensitive()"), "the \(name) family is not privacy-sensitive")
        }
    }

    @Test("REQ-WIDGET-004, REQ-WIDGET-006: the small widget keeps its words for every state")
    func smallKeepsItsWords() throws {
        let small = try family("small")
        for text in [
            #"Text("widget.nextService.title")"#, "summary.operation.widgetTitle", "summary.word.widgetLabel",
            "summary.fact.widgetText", #"Text("widget.nextService.empty.headline")"#,
            #"Text("widget.nextService.empty.detail")"#, #"Text("widget.nextService.unavailable")"#,
        ] {
            #expect(small.contains(text), "\(text) is not shown on the small widget")
        }
    }

    @Test("REQ-DESIGN-001: the small widget says the status as a chip of word, shared glyph and colour")
    func smallDrawsTheStatusChip() throws {
        let chip = "StatusChip(Text(summary.word.widgetLabel), glyph: summary.status.glyph, "
            + "color: summary.status.color)"
        #expect(try family("small").contains(chip))
    }

    @Test("REQ-DESIGN-001: the Lock Screen rectangular widget draws the shared status glyph beside the word")
    func rectangularDrawsTheStatusGlyph() throws {
        let rectangular = try family("rectangular")
        #expect(rectangular.contains("StatusGlyphView(glyph: summary.status.glyph"))
        #expect(rectangular.contains("Text(summary.word.widgetLabel)"))
        // The pre-redesign status symbols are gone from every family, so no family says the state two ways.
        #expect(try !code().contains("summary.status.systemImage"))
    }

    @Test("ADR-0038: the small widget sits on the grouped surface, its eyebrow in the tinted mode's accent group")
    func smallUsesRolesAndAccentGroup() throws {
        let small = try family("small")
        // The eyebrow's own modifier chain must end in the accent modifier, not some later view's.
        let accentedEyebrow = #/Text\("widget\.nextService\.title"\)(\s*\.\w+\(.*\))*\s*\.widgetAccentable\(\)/#
        #expect(small.contains(accentedEyebrow))
        let background = #/\.containerBackground\(for: \.widget\)\s*\{\s*PitColor\.surfaceSecondary\s*\}/#
        #expect(try code().contains(background))
    }

    @Test("ADR-0036: every family has a preview that includes the sparse state")
    func previewsCoverEveryFamilyAndTheSparseState() throws {
        let code = try code()
        for family in ["systemSmall", "accessoryRectangular", "accessoryInline"] {
            let start = try #require(code.range(of: "#Preview(as: .\(family))"), "no \(family) preview")
            let end = code.range(of: "#Preview", range: start.upperBound ..< code.endIndex)?.lowerBound
                ?? code.endIndex
            let preview = code[start.upperBound ..< end]
            #expect(preview.contains("content: .empty"), "the \(family) preview has no sparse state")
        }
    }
}
