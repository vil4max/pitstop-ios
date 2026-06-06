import SwiftUI

enum ThemeColors {
    static let brand = Color("VWBrand")
    static let darkBackground = Color("DarkBackground")
    static let cardDark = Color("VWBrand").opacity(0.85)
    static let cardLight = Color(.secondarySystemGroupedBackground)
}

struct ThemeController {
    var colorScheme: ColorScheme?

    func preferredScheme(for mode: AppThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func screenBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? ThemeColors.darkBackground : Color(.systemGroupedBackground)
    }

    func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? ThemeColors.cardDark : ThemeColors.cardLight
    }

    func controlTint(for scheme: ColorScheme) -> Color {
        ThemeColors.brand
    }

    func switchTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : ThemeColors.brand
    }
}

extension View {
    func themedGroupedListSurface(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        scrollContentBackground(.hidden)
            .background(theme.screenBackground(for: colorScheme))
    }

    func themedListRowBackground(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        listRowBackground(theme.cardBackground(for: colorScheme))
    }

    func themedControlTint(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        tint(theme.controlTint(for: colorScheme))
    }

    func themedSwitchTint(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        tint(theme.switchTint(for: colorScheme))
    }
}

struct CurrencyFormat {
    static func uah(_ value: Int) -> String {
        formatted(value, suffix: "₴")
    }

    static func usd(_ value: Int) -> String {
        formatted(value, prefix: "$")
    }

    private static func formatted(_ value: Int, prefix: String = "", suffix: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        if !prefix.isEmpty {
            return "\(prefix)\(number)"
        }
        return "\(number) \(suffix)"
    }
}
