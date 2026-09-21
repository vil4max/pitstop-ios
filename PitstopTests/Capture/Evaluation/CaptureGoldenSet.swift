import Foundation
@testable import Pitstop
import Testing

/// Fictional captures with the proposal each one should produce (ADR 0027, test-strategy "AI golden
/// set"). No real vehicle, place, or person. `expected == nil` means "no supported meaning": the
/// wording is kept raw, which is the correct answer for every ambiguous, unsupported, correction,
/// and hedged case.
struct GoldenCase: Sendable, CustomTestStringConvertible {
    enum Category: String, Sendable, CaseIterable {
        case positive
        case ambiguous
        case unsupported
        case correction
        case hedged
    }

    struct Expected: Hashable, Sendable {
        let kind: ProposalKind
        var operation: MaintenanceOperationID?
        var odometerKm: Double?
        var amount: Decimal?
    }

    let text: String
    let locale: String
    let category: Category
    let expected: Expected?

    var testDescription: String {
        "\(category.rawValue) [\(locale)] \(text)"
    }

    static func completion(
        _ text: String,
        _ operation: MaintenanceOperationID,
        km: Double? = nil,
        locale: String = "ru_RU"
    ) -> GoldenCase {
        GoldenCase(
            text: text,
            locale: locale,
            category: .positive,
            expected: Expected(kind: .maintenanceCompletion, operation: operation, odometerKm: km)
        )
    }

    static func wash(_ text: String, amount: Decimal? = nil, km: Double? = nil,
                     locale: String = "ru_RU") -> GoldenCase
    {
        GoldenCase(
            text: text,
            locale: locale,
            category: .positive,
            expected: Expected(kind: .vehicleEvent, odometerKm: km, amount: amount)
        )
    }

    static func reading(_ text: String, km: Double, locale: String = "ru_RU") -> GoldenCase {
        GoldenCase(
            text: text,
            locale: locale,
            category: .positive,
            expected: Expected(kind: .odometerReading, odometerKm: km)
        )
    }

    static func none(_ text: String, _ category: Category, locale: String = "ru_RU") -> GoldenCase {
        GoldenCase(text: text, locale: locale, category: category, expected: nil)
    }
}

enum CaptureGoldenSet {
    static let cases: [GoldenCase] = positive + ambiguous + unsupported + corrections + hedged

    static let positive: [GoldenCase] = [
        .completion("Поменял масло и масляный фильтр на 85 000", .engineOilService, km: 85000),
        .completion("Сегодня сделал замену масла в двигателе", .engineOilService),
        .completion("Заменил тормозную жидкость", .brakeFluid),
        .completion("Поставил новые свечи зажигания, пробег 92 300", .sparkPlugs, km: 92300),
        .completion("Обслужил муфту халдекс на 118000 км", .awdCouplingService, km: 118_000),
        .completion("Сменил салонный фильтр", .cabinFilter),
        .completion("Прошёл ТО коробки DSG на 60 000", .dsgService, km: 60000),
        .completion("Replaced the cabin filter today", .cabinFilter, locale: "en_US"),
        .completion("Got the engine oil changed at 90,000 km", .engineOilService, km: 90000, locale: "en_US"),
        .completion("Замінив масло в двигуні на 70 000", .engineOilService, km: 70000, locale: "uk_UA"),
        .wash("Помыл машину за 700 рублей", amount: 700),
        .wash("Помыли машину на мойке самообслуживания за 450", amount: 450),
        .wash("Съездил на мойку, отдал 900", amount: 900),
        .wash("Washed the car for 15 dollars", amount: 15, locale: "en_US"),
        .wash("Помив машину за 300 гривень", amount: 300, locale: "uk_UA"),
        .reading("Пробег 84 200", km: 84200),
        .reading("На одометре сейчас 101 500 км", km: 101_500),
        .reading("Odometer reads 45,600 km", km: 45600, locale: "en_US"),
        .reading("Пробіг 77 000 км", km: 77000, locale: "uk_UA"),
    ]

    static let ambiguous: [GoldenCase] = [
        .none("Масло 85000", .ambiguous),
        .none("Долил масла пол литра", .ambiguous),
        .none("Был в сервисе, посмотрели подвеску", .ambiguous),
        .none("Поменял масло и тормозную жидкость", .ambiguous),
        .none("Фильтр", .ambiguous),
        .none("Serviced the car", .ambiguous, locale: "en_US"),
    ]

    static let unsupported: [GoldenCase] = [
        .none("Купить подарок на день рождения", .unsupported),
        .none("Шиномонтаж на Лесной улице открыт до восьми", .unsupported),
        .none("Заправился на 3000 рублей", .unsupported),
        .none("Страховка заканчивается в марте", .unsupported),
        .none("Remember the parking level is B2", .unsupported, locale: "en_US"),
        .none("Треба купити щітки склоочисника", .unsupported, locale: "uk_UA"),
    ]

    static let corrections: [GoldenCase] = [
        .none("Ошибся, пробег не 84 000, а 48 000", .correction),
        .none("Масло менял не вчера, а в прошлом месяце", .correction),
        .none("Correction: the wash was 12 dollars, not 15", .correction, locale: "en_US"),
    ]

    static let hedged: [GoldenCase] = [
        .none("Надо поменять масло до зимы", .hedged),
        .none("Хочу помыть машину в субботу", .hedged),
        .none("Пора менять тормозную жидкость", .hedged),
        .none("Когда я менял свечи?", .hedged),
        .none("Масло не менял с весны", .hedged),
        .none("Планирую замену салонного фильтра на 90 000", .hedged),
        .none("Need to replace the cabin filter", .hedged, locale: "en_US"),
        .none("Should I change the oil at 90000 km?", .hedged, locale: "en_US"),
        .none("Going to change the oil at 90000 km", .hedged, locale: "en_US"),
        .none("Will wash the car tomorrow", .hedged, locale: "en_US"),
        .none("I'll replace the spark plugs next week", .hedged, locale: "en_US"),
        .none("Have to book the brake fluid change", .hedged, locale: "en_US"),
        .none("Planning to replace the cabin filter at 95000 km", .hedged, locale: "en_US"),
        .none("Треба замінити масло", .hedged, locale: "uk_UA"),
    ]
}
