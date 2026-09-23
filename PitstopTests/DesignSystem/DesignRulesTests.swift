import Foundation
import Testing

/// Source rules that `just verify` enforces through this suite (REQ-DESIGN-002, REQ-DESIGN-004). A test in
/// the app's own target keeps the check out of `Tooling/`, which belongs to the shared Runtime.
@Suite("Design rules in source")
struct DesignRulesTests {
    /// Named system colours, colour initialisers and literals, including implicit members at the start of a line
    /// or after `(`, `?`, `:`, `,`, `[`, `=`, `{`, `return` or `in`. `Color.clear` is layout, not colour.
    /// `Font.Weight.black` must be written out in full.
    /// Multi-line regex literals are in extended mode: whitespace is ignored and `#` must be escaped. Word ends
    /// are spelled out because Swift's `\b` follows Unicode word rules, where `clear.frame` is one word. The
    /// rules are computed because a `Regex` is not Sendable and cannot be a stored static under Swift 6.
    private static var colourLiteral: some RegexComponent {
        #/
            (^|[^A-Za-z0-9_]) ( Color\.(?!clear(?![A-Za-z0-9_]))[a-z] | Color\( | UIColor | \#colorLiteral )
            | ( [(?:,\[={] | ^ | (^|[^A-Za-z0-9_]) (return | in) ) \s*
                \.( red | orange | yellow | green | mint | teal | cyan | blue | indigo | purple | pink | brown
                | white | gray | black | primary | secondary | tertiary | quaternary | quinary | accentColor )
                (?![A-Za-z0-9_])
        /#
    }

    private static var glass: some RegexComponent {
        #/\.glassEffect\(|GlassEffectContainer|(^|[^A-Za-z0-9_])Glass(Prominent)?ButtonStyle|\.buttonStyle\(\s*\.glass/#
    }

    private static let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent() // DesignSystem
        .deletingLastPathComponent() // PitstopTests
        .deletingLastPathComponent()

    @Test("REQ-DESIGN-004: feature code names PitColor roles, never a colour literal")
    func featuresUseRoles() throws {
        let files = try Self.swiftFiles(under: "Pitstop/Features")
        #expect(files.count > 10, "the Features sources were not found; the rule would pass vacuously")
        let hits = try files.flatMap { try Self.matches(of: Self.colourLiteral, in: $0) }
        #expect(hits.isEmpty, "colour literals under Features/: \(hits)")
    }

    @Test("REQ-DESIGN-002: Liquid Glass appears only inside the design system")
    func glassStaysInTheDesignSystem() throws {
        let files = try ["Pitstop", "Shared", "PitstopWidgets"].flatMap { try Self.swiftFiles(under: $0) }
            .filter { !$0.path.contains("/Pitstop/DesignSystem/") }
        #expect(files.count > 10, "the app sources were not found; the rule would pass vacuously")
        let hits = try files.flatMap { try Self.matches(of: Self.glass, in: $0) }
        #expect(hits.isEmpty, "glass outside DesignSystem/: \(hits)")
    }

    @Test("The literal rule catches the forms it names and lets roles and Color.clear through")
    func literalRuleCalibration() {
        let caught = [
            "x.foregroundStyle(Color.blue)", "x.tint(Color.accentColor)", "x.fill(.red)",
            "Color(red: 1, green: 0, blue: 0)", "UIColor.systemRed", "x.foregroundStyle(.secondary)",
            "x.tint(isOn ? .accentColor : PitColor.contentSecondary)", "isOn ? .blue : .gray",
            "x.shadow(color: .black, radius: 2)", "let colours = [.red, .blue]",
            "x.foregroundStyle(.primary, .secondary)", "        .orange", "{ _ in .red }", "return .green",
            "x.foregroundStyle(.quaternary)",
        ]
        let allowed = [
            "x.foregroundStyle(PitColor.statusDue)", "Color.clear.frame(width: 1)", "x.fill(.clear)",
            "x.fontWeight(.semibold)", "case .upcoming: .ring", "        .padding(.top, 6)", "return .dashed",
        ]
        #expect(caught.allSatisfy { $0.contains(Self.colourLiteral) })
        #expect(!allowed.contains { $0.contains(Self.colourLiteral) })
    }

    @Test("The glass rule catches the modifier, the container and both glass button styles")
    func glassRuleCalibration() {
        let caught = [
            "x.glassEffect(.regular, in: .capsule)", "GlassEffectContainer {", "x.buttonStyle(.glassProminent)",
            "x.buttonStyle(GlassButtonStyle())", "x.buttonStyle(GlassProminentButtonStyle())",
        ]
        #expect(caught.allSatisfy { $0.contains(Self.glass) })
        #expect(!"x.pitGlass(in: .capsule)".contains(Self.glass))
        #expect(!"x.buttonStyle(PitGlassButtonStyle())".contains(Self.glass))
    }

    private static func swiftFiles(under relativePath: String) throws -> [URL] {
        let directory = repositoryRoot.appending(path: relativePath)
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// `file:line` for each matching line; whole-line comments are skipped so a rule can be explained in prose.
    private static func matches(of rule: some RegexComponent, in file: URL) throws -> [String] {
        let lines = try String(contentsOf: file, encoding: .utf8).split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        return lines.enumerated().compactMap { index, line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard !code.hasPrefix("//"), !code.hasPrefix("///"), code.contains(rule) else { return nil }
            return "\(file.lastPathComponent):\(index + 1)"
        }
    }
}
