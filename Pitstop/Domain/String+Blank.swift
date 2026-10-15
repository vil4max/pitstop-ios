extension String {
    /// Empty or only whitespace and newlines: nothing a person wrote.
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }
}
