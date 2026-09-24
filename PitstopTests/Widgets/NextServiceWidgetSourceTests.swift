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

    /// A declaration of `NextServiceWidgetView` at member level, from its first line to its closing brace.
    private func member(from start: String.Index, in code: String) throws -> Substring {
        let end = try #require(
            code.range(of: "\n    }\n", range: start ..< code.endIndex),
            "a member of the view does not close"
        )
        return code[start ..< end.upperBound]
    }

    /// One family's view property of `NextServiceWidgetView` with the helpers named after it (`smallOperation`,
    /// `rectangularOperation`, …), so a check cannot be met by another family's branch.
    private func family(_ name: String) throws -> String {
        let code = try code()
        let members = try ["    private var \(name)", "    private func \(name)"].flatMap { prefix in
            try code.ranges(of: prefix).map { try member(from: $0.lowerBound, in: code) }
        }
        #expect(!members.isEmpty, "no \(name) family in the view")
        return members.joined(separator: "\n")
    }

    /// `code` without its `if <condition> {` block, from that line to the brace at the same indentation.
    private func removing(block condition: String, from code: String) throws -> String {
        let opening = try #require(code.range(of: "if \(condition) {"), "no `if \(condition)` block")
        let lineStart = code[..<opening.lowerBound].lastIndex(of: "\n").map { code.index(after: $0) }
            ?? code.startIndex
        let indentation = code[lineStart ..< opening.lowerBound]
        let closing = try #require(
            code.range(of: "\n\(indentation)}", range: opening.upperBound ..< code.endIndex),
            "the `if \(condition)` block does not close"
        )
        return String(code[..<lineStart] + code[closing.upperBound...])
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

    /// A stack taller than the widget is clipped: centred, or in a frame that grows to the stack and is then
    /// centred, it loses its first and last lines at once.
    @Test("REQ-WIDGET-004: both data families anchor their content to the top of the widget")
    func familiesAnchorTheirStackToTheTop() throws {
        let topAnchored = ".frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)"
        for name in ["small", "rectangular"] {
            #expect(try family(name).contains(topAnchored), "the \(name) family is not top-anchored")
        }
    }

    /// Owner, 2026-09-24: when the content does not fit, lines go by priority instead of being clipped. The name and
    /// the status always stay; the eyebrow goes first, then the fact, and last the status word, leaving its glyph.
    /// A tap opens Service for the rest.
    @Test("REQ-WIDGET-004: the small widget drops the eyebrow, then the fact, then the word; name and status stay")
    func smallDropsLinesByPriority() throws {
        let small = try family("small")
        let step = #/smallOperation\(summary, showsEyebrow: (\w+), showsFact: (\w+)(, showsWord: false)?\)/#
        let order = small.matches(of: step).map { "\($0.1) \($0.2) \($0.3 == nil ? "word" : "glyph")" }
        #expect(order == ["true true word", "false true word", "false false word", "false false glyph"])
        let first = #/ViewThatFits\(in: \.vertical\)\s*\{\s*smallOperation\(summary, showsEyebrow: true/#
        #expect(small.contains(first))

        let start = try #require(small.range(of: "    private func smallOperation")).lowerBound
        let operation = try String(member(from: start, in: small))
        let kept = try removing(block: "showsFact", from: removing(block: "showsEyebrow", from: operation))
        #expect(kept.contains("summary.operation.widgetTitle"), "the name must not depend on a dropped line")
        #expect(kept.contains("StatusChip("), "the status must not depend on a dropped line")
        #expect(kept.contains("StatusGlyphView(glyph: summary.status.glyph"), "the last resort keeps the glyph")
        #expect(!kept.contains("summary.fact.widgetText") && !kept.contains("smallEyebrow"))
        // A spacer outside the fact would add a gap to every fact-less layout and could reject one that fits.
        #expect(!kept.contains("Spacer("), "the spacer belongs to the fact")
    }

    /// Chips wrap and are never truncated (REQ-GRAMMAR-003): a layout shows the whole word or only the glyph. A word
    /// too long for a layout makes that layout too tall, so the widget moves on to the next one.
    @Test("REQ-GRAMMAR-003: the small widget never limits or shrinks the status chip's word")
    func smallNeverTruncatesTheStatusWord() throws {
        let small = try family("small")
        let lines = small.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let chip = try #require(lines.firstIndex { $0.hasPrefix("StatusChip(") }, "no status chip")
        let modifiers = lines[(chip + 1)...].prefix { $0.hasPrefix(".") || $0.hasPrefix("//") }
        #expect(!modifiers.contains { $0.contains("lineLimit") || $0.contains("minimumScaleFactor") })
    }

    @Test("REQ-WIDGET-004: the Lock Screen rectangular widget drops the fact, then the word; name and status stay")
    func rectangularDropsLinesByPriority() throws {
        let rectangular = try family("rectangular")
        let variant = #/rectangularOperation\(summary, showsFact: (\w+)(, showsWord: false)?(, nameLines: 1)?\)/#
        let order = rectangular.matches(of: variant)
            .map { "\($0.1) \($0.2 == nil ? "word" : "glyph")\($0.3 == nil ? "" : " one-line name")" }
        #expect(order == ["true word", "false word", "false glyph", "false glyph one-line name"])
        let first = #/ViewThatFits\(in: \.vertical\)\s*\{\s*rectangularOperation\(summary, showsFact: true/#
        #expect(rectangular.contains(first))

        let start = try #require(rectangular.range(of: "    private func rectangularOperation")).lowerBound
        let kept = try removing(block: "showsFact", from: String(member(from: start, in: rectangular)))
        #expect(kept.contains("summary.operation.widgetTitle"))
        #expect(kept.contains("StatusGlyphView(glyph: summary.status.glyph"))
        #expect(kept.contains("Text(summary.word.widgetLabel)"), "the status word must not depend on the fact")
        #expect(!kept.contains("summary.fact.widgetText"))
    }

    /// `ViewThatFits` measures height only, so a status word cut sideways on one line would still "fit" and the
    /// fallback would never be reached. The word wraps instead, and nothing around it limits or shrinks it: a word
    /// that needs more room makes the layout taller, and the widget moves on to the glyph alone.
    @Test("REQ-GRAMMAR-003: the Lock Screen rectangular widget never truncates or shrinks the status word")
    func rectangularNeverTruncatesTheStatusWord() throws {
        let rectangular = try family("rectangular")
        let start = try #require(rectangular.range(of: "    private func rectangularOperation")).lowerBound
        let lines = try member(from: start, in: rectangular).split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let word = try #require(lines.firstIndex { $0.hasPrefix("Text(summary.word.widgetLabel)") }, "no status word")
        let modifiers = lines[(word + 1)...].prefix { $0.hasPrefix(".") || $0.hasPrefix("//") }
        #expect(modifiers.contains(".fixedSize(horizontal: false, vertical: true)"), "the word must wrap")
        #expect(!modifiers.contains { $0.contains("lineLimit") || $0.contains("minimumScaleFactor") })
        let containerLimits = zip(lines, lines.dropFirst()).filter { closing, next in
            closing == "}" && (next.hasPrefix(".lineLimit") || next.hasPrefix(".minimumScaleFactor"))
        }
        #expect(containerLimits.isEmpty, "a container limits or shrinks the status word")
    }

    /// Only the chosen `ViewThatFits` layout is in the accessibility tree, so combining children would silence a line
    /// dropped for room. Each family reads one label built from the whole content instead.
    @Test("REQ-WIDGET-004: VoiceOver reads name, status word and fact whichever layout is shown")
    func familiesSpeakTheWholeContent() throws {
        let code = try code()
        for name in ["small", "rectangular"] {
            let start = try #require(code.range(of: "    private var \(name): some View {"), "no \(name) family")
            let body = try member(from: start.lowerBound, in: code)
            #expect(body.contains(".accessibilityElement(children: .ignore)"), "the \(name) family combines children")
            #expect(body.contains(".accessibilityLabel(spokenSummary)"), "the \(name) family has no whole label")
        }
        let start = try #require(code.range(of: "    private var spokenSummary: Text {"), "no spoken summary")
        let summary = try member(from: start.lowerBound, in: code)
        for text in [
            "summary.operation.widgetTitle", "summary.word.widgetLabel", "summary.fact.widgetText",
            "widget.nextService.empty.headline", "widget.nextService.empty.detail", "widget.nextService.unavailable",
        ] {
            #expect(summary.contains(text), "the spoken summary leaves out \(text)")
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
