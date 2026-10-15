import Foundation

extension ProvisionalCarContext {
    /// The name every screen shows. The stored placeholder stays English, because validation compares against it;
    /// that placeholder is shown in the user's language by the same rule validation uses (the stored name equals
    /// it), so a car that gained a fact without a name keeps the translated title. Any other name is shown as typed.
    var displayName: String { displayName(locale: nil) }

    /// `nil` resolves in the app's language; a locale resolves in that language.
    func displayName(locale: Locale?) -> String {
        guard name == Self.defaultName else { return name }
        guard let locale else { return String(localized: "carBoard.provisionalName") }
        return String(localized: LocalizedStringResource("carBoard.provisionalName", locale: locale))
    }
}
