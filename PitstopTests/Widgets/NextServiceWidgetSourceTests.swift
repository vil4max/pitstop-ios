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

    /// One family's own view property alone, for modifiers that must wrap every layout rather than sit on one
    /// helper's layout.
    private func familyBody(_ name: String) throws -> Substring {
        let code = try code()
        let start = try #require(code.range(of: "    private var \(name): some View {"), "no \(name) family")
        return try member(from: start.lowerBound, in: code)
    }

    /// A helper's own declaration, such as `smallOperation`, from its first line to its closing brace.
    private func helper(_ name: String) throws -> String {
        let code = try code()
        let start = try #require(code.range(of: "    private func \(name)("), "no \(name) in the view")
        return try String(member(from: start.lowerBound, in: code))
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
            // On the family itself, so every layout is covered, not only the one a helper draws.
            #expect(try familyBody(name).contains(".privacySensitive()"), "the \(name) family is not privacy-sensitive")
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
            #expect(try familyBody(name).contains(topAnchored), "the \(name) family is not top-anchored")
        }
    }

    /// The sparse and unreadable states keep their sentence; the widget's name above it (eyebrow or title) goes first.
    @Test("REQ-WIDGET-006: the sparse and unreadable states drop the widget's name first and keep their sentence")
    func sparseStatesDropTheirTitleFirst() throws {
        let small = try familyBody("small")
        for helper in ["smallEmpty", "smallUnavailable"] {
            let step = try Regex(#"\#(helper)\(showsEyebrow: (\w+)\)"#)
            let order = small.matches(of: step).map { "\($0.output[1].substring ?? "")" }
            #expect(order == ["true", "false"], "\(helper) does not drop the eyebrow first")
        }
        let rectangular = try familyBody("rectangular")
        for key in ["widget.nextService.empty.detail", "widget.nextService.unavailable"] {
            let step = try Regex(#"rectangularSentence\("\#(key)", showsTitle: (\w+)\)"#)
            let order = rectangular.matches(of: step).map { "\($0.output[1].substring ?? "")" }
            #expect(order == ["true", "false"], "the rectangular \(key) state does not drop the title first")
        }

        let emptyKept = try removing(block: "showsEyebrow", from: helper("smallEmpty"))
        #expect(emptyKept.contains(#"Text("widget.nextService.empty.headline")"#))
        #expect(emptyKept.contains(#"Text("widget.nextService.empty.detail")"#))
        let unavailableKept = try removing(block: "showsEyebrow", from: helper("smallUnavailable"))
        #expect(unavailableKept.contains(#"Text("widget.nextService.unavailable")"#))
        let sentenceKept = try removing(block: "showsTitle", from: helper("rectangularSentence"))
        #expect(sentenceKept.contains("Text(sentence)"))
        for kept in [emptyKept, unavailableKept, sentenceKept] {
            #expect(!kept.contains("smallEyebrow") && !kept.contains(#"Text("widget.nextService.title")"#))
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
        #expect(kept.contains(#/StatusGlyphView\(\s*glyph: summary\.status\.glyph/#), "the last resort keeps the glyph")
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
        // A limit on a stack around the chip reaches the chip's word through the environment just the same.
        let operation = try helper("smallOperation").split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let containerLimits = zip(operation, operation.dropFirst()).filter { closing, next in
            closing.hasPrefix("}") && (next.hasPrefix(".lineLimit") || next.hasPrefix(".minimumScaleFactor"))
        }
        #expect(containerLimits.isEmpty, "a stack around the chip limits or shrinks its word")
    }

    @Test("REQ-WIDGET-004: the Lock Screen rectangular widget drops the fact, then the word; name and status stay")
    func rectangularDropsLinesByPriority() throws {
        let rectangular = try family("rectangular")
        let variant = #/rectangularOperation\(summary, showsFact: (\w+)(, showsWord: false)?(, isLastResort: true)?\)/#
        let order = rectangular.matches(of: variant)
            .map { "\($0.1) \($0.2 == nil ? "word" : "glyph")\($0.3 == nil ? "" : " last")" }
        #expect(order == ["true word", "false word", "false glyph", "false glyph last"])
        let first = #/ViewThatFits\(in: \.vertical\)\s*\{\s*rectangularOperation\(summary, showsFact: true/#
        #expect(rectangular.contains(first))

        let start = try #require(rectangular.range(of: "    private func rectangularOperation")).lowerBound
        let kept = try removing(block: "showsFact", from: String(member(from: start, in: rectangular)))
        #expect(kept.contains("summary.operation.widgetTitle"))
        #expect(kept.contains("StatusGlyphView(glyph: summary.status.glyph"))
        #expect(kept.contains("Text(summary.word.widgetLabel)"), "the status word must not depend on the fact")
        #expect(!kept.contains("summary.fact.widgetText"))
    }

    /// The modifier lines written directly after each line of `lines` that starts with `prefix`.
    private func modifierChains(after prefix: String, in lines: [String]) -> [[String]] {
        lines.indices.filter { lines[$0].hasPrefix(prefix) }.map { index in
            Array(lines[(index + 1)...].prefix { $0.hasPrefix(".") || $0.hasPrefix("//") })
        }
    }

    /// `ViewThatFits(in: .vertical)` measures height only, so a status word cut sideways would still "fit" and the
    /// fallback would never be reached. The word row therefore tries the word on one line, then one type step
    /// smaller on one line, inside `ViewThatFits(in: .horizontal)`, which accepts a one-line word only when its whole
    /// width fits; last it wraps, which makes the layout taller so the widget moves on. Nothing shrinks the word, and
    /// no container limits it (REQ-GRAMMAR-003).
    @Test("REQ-GRAMMAR-003: the Lock Screen rectangular widget never truncates or shrinks the status word")
    func rectangularNeverTruncatesTheStatusWord() throws {
        let rectangular = try family("rectangular")
        let start = try #require(rectangular.range(of: "    private func rectangularOperation")).lowerBound
        let lines = try member(from: start, in: rectangular).split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let fits = try #require(lines.firstIndex(of: "ViewThatFits(in: .horizontal) {"), "no one-line word row")
        let chains = modifierChains(after: "Text(summary.word.widgetLabel)", in: lines)
        #expect(chains.count == 3, "the word row has one line, a smaller line, then a wrap")
        #expect(lines[(fits + 1)...].prefix(while: { $0 != "}" }).filter {
            $0.hasPrefix("Text(summary.word.widgetLabel)")
        }.count == 3, "every word variant sits inside the horizontal fit")
        if chains.count == 3 {
            #expect(chains[0].contains(".lineLimit(1)"))
            #expect(chains[1].contains(".lineLimit(1)") && chains[1].contains { $0.hasPrefix(".font(") })
            #expect(chains[2].contains(".fixedSize(horizontal: false, vertical: true)"), "the last word must wrap")
            #expect(!chains[2].contains { $0.contains("lineLimit") })
        }
        #expect(!chains.joined().contains { $0.contains("minimumScaleFactor") }, "the word must not shrink")
        let containerLimits = zip(lines, lines.dropFirst()).filter { closing, next in
            closing == "}" && (next.hasPrefix(".lineLimit") || next.hasPrefix(".minimumScaleFactor"))
        }
        #expect(containerLimits.isEmpty, "a container limits or shrinks the status word")
    }

    /// The name ranks first, so it must not be cut while a lower line stays. A `Text` with a line limit reports the
    /// same height cut or whole, so `ViewThatFits(in: .vertical)` would accept a layout with a cut name. In every
    /// layout but its family's last, the name therefore has no line limit and no scale factor: it wraps, and a name
    /// that does not fit makes the layout too tall, so the next layout is tried. Only the last layout, which has no
    /// fallback, may cap or shrink the name.
    @Test("REQ-WIDGET-004: before the last layout the name wraps whole, with no line limit or shrink")
    func nameWrapsBeforeLowerLinesDrop() throws {
        let wraps = ".fixedSize(horizontal: false, vertical: true)"
        // Each helper's last layout is the branch that opens with this line and runs to the next branch or the end.
        let lastBranches = [("smallOperation", "} else {"), ("rectangularOperation", "} else if isLastResort {")]
        for (helper, lastBranch) in lastBranches {
            let lines = try self.helper(helper).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            let last = try #require(lines.firstIndex(of: lastBranch), "\(helper) has no last layout")
            let lastEnd = lines[(last + 1)...].firstIndex { $0.hasPrefix("} else") } ?? lines.endIndex
            let earlier = Array(lines[..<last]) + Array(lines[lastEnd...])
            let chains = modifierChains(after: "name", in: earlier).filter { !$0.isEmpty }
            #expect(!chains.isEmpty, "\(helper) draws no name before its last layout")
            for chain in chains {
                #expect(chain.contains(wraps), "\(helper) does not let the name wrap before its last layout")
                #expect(!chain.contains { $0.contains("lineLimit") }, "\(helper) caps the name before its last layout")
                #expect(!chain.contains { $0.contains("minimumScaleFactor") }, "\(helper) shrinks the name early")
            }
        }
        let rectangular = try helper("rectangularOperation").split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let last = try #require(rectangular.firstIndex(of: "} else if isLastResort {"), "no Lock Screen last layout")
        let lastResort = try #require(
            modifierChains(after: "name", in: Array(rectangular[last...])).first { !$0.isEmpty }
        )
        // The Lock Screen's last layout: up to three rows, shrinking to half before an ellipsis.
        #expect(lastResort.contains(".lineLimit(3)") && lastResort.contains(".minimumScaleFactor(0.5)"))
    }

    /// The small widget's last layout has no fallback and a whole tile of height. A line limit there would shrink or
    /// cut the name while the tile still has room, so the name takes as many lines as the tile holds and shrinks
    /// only when it still does not fit.
    @Test("REQ-WIDGET-004: the small widget's last layout lets the name use the whole tile before it shrinks")
    func smallLastLayoutUsesTheWholeTile() throws {
        let lines = try helper("smallOperation").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let last = try #require(lines.firstIndex(of: "} else {"), "the small widget has no last layout")
        let name = try #require(
            modifierChains(after: "name", in: Array(lines[last...])).first { !$0.isEmpty },
            "the small widget's last layout draws no name"
        )
        #expect(!name.contains { $0.contains("lineLimit") }, "the last layout caps the name's lines")
        #expect(name.contains(".minimumScaleFactor(0.6)"), "the last layout lost its shrink floor")
    }

    /// A glyph that scales with body text reaches about 34 pt at the largest size, a quarter of the Lock Screen slot,
    /// and cuts the one name the rule keeps. Beside the name the glyph is capped in every glyph-only layout.
    @Test("REQ-WIDGET-004: beside the name the status glyph is capped")
    func glyphBesideTheNameLeavesItsRoom() throws {
        let capped = #/
            StatusGlyphView\( \s* glyph: \s summary\.status\.glyph, \s*
            size: \s min\(statusGlyphSize, \s DesignTokens\.statusGlyphBesideNameMaxSize\) \s* \)
        /#
        // One glyph-only layout on the small widget, two on the Lock Screen.
        for (helper, glyphOnlyLayouts) in [("smallOperation", 1), ("rectangularOperation", 2)] {
            let count = try self.helper(helper).matches(of: capped).count
            #expect(count == glyphOnlyLayouts, "\(helper) does not cap every glyph beside a name")
        }
    }

    /// Only the chosen `ViewThatFits` layout is in the accessibility tree, so combining children would silence a line
    /// dropped for room. Each family reads one label built from the whole content instead.
    @Test("REQ-WIDGET-004: VoiceOver reads name, status word and fact whichever layout is shown")
    func familiesSpeakTheWholeContent() throws {
        for name in ["small", "rectangular"] {
            let body = try familyBody(name)
            #expect(body.contains(".accessibilityElement(children: .ignore)"), "the \(name) family combines children")
            #expect(body.contains(".accessibilityLabel(spokenSummary)"), "the \(name) family has no whole label")
        }
        let code = try code()
        let start = try #require(code.range(of: "    private var spokenSummary: Text {"), "no spoken summary")
        let summary = try member(from: start.lowerBound, in: code)
        for text in [
            "summary.operation.widgetTitle", "summary.word.widgetLabel", "summary.fact.widgetText",
            "widget.nextService.empty.headline", "widget.nextService.empty.detail", "widget.nextService.unavailable",
        ] {
            #expect(summary.contains(text), "the spoken summary leaves out \(text)")
        }
    }

    /// Redaction hides what is drawn, but an explicit accessibility label is not a drawn text. On a locked device
    /// (or any redaction) the label therefore says only the widget's name, never the service data (REQ-WIDGET-008).
    @Test("REQ-WIDGET-008: a redacted widget's spoken label names the widget and no service data")
    func redactedLabelSpeaksNoServiceData() throws {
        let code = try code()
        #expect(code.contains("@Environment(\\.redactionReasons) private var redactionReasons"))
        let start = try #require(code.range(of: "    private var spokenSummary: Text {"), "no spoken summary")
        let lines = try member(from: start.lowerBound, in: code).split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let body = Array(lines.dropFirst())
        #expect(
            body.first == #"guard redactionReasons.isEmpty else { return Text("widget.nextService.title") }"#,
            "the spoken summary must check for redaction before it reads any service data"
        )
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
