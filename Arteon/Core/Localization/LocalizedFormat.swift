import Foundation

enum LocalizedFormat {
    static var locale: Locale { AppConfiguration.forcedLocale }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }

    static func string(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(localized: LocalizedStringResource(key, locale: locale))
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(locale)
        )
    }

    static func date(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(locale)
        )
    }

    static func monthYear(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .month(.wide)
                .year()
                .locale(locale)
        )
    }
}
