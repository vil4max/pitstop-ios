import SwiftUI

enum ThemeColors {
    static let brand = Color("Brand")
    static let darkBackground = Color("DarkBackground")
    static let cardDark = Color("Brand").opacity(0.85)
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

    func actionTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : ThemeColors.brand
    }

    func controlTint(for scheme: ColorScheme) -> Color {
        actionTint(for: scheme)
    }

    func switchTint(for scheme: ColorScheme) -> Color {
        actionTint(for: scheme)
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
        tint(theme.actionTint(for: colorScheme))
    }

    func themedSwitchTint(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        tint(theme.actionTint(for: colorScheme))
    }

    func themedActionTint(colorScheme: ColorScheme, theme: ThemeController = ThemeController()) -> some View {
        tint(theme.actionTint(for: colorScheme))
    }

    func tabRootScreen(
        title: LocalizedStringKey,
        colorScheme: ColorScheme,
        theme: ThemeController = ThemeController()
    ) -> some View {
        background(theme.screenBackground(for: colorScheme))
            .navigationTitle(title)
    }
}
