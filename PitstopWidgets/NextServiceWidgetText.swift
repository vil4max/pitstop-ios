import SwiftUI

extension MaintenanceOperationID {
    /// The extension's own copy of Service's operation names; an ID without a name is shown verbatim.
    var widgetTitle: Text {
        switch self {
        case .engineOilService: Text("widget.operation.engineOilService")
        case .dsgService: Text("widget.operation.dsgService")
        case .awdCouplingService: Text("widget.operation.awdCouplingService")
        case .brakeFluid: Text("widget.operation.brakeFluid")
        case .cabinFilter: Text("widget.operation.cabinFilter")
        case .airFilter: Text("widget.operation.airFilter")
        case .sparkPlugs: Text("widget.operation.sparkPlugs")
        default: Text(verbatim: rawValue)
        }
    }
}

extension MaintenanceStatusWord {
    var widgetLabel: LocalizedStringKey {
        switch self {
        case .unknown: "widget.status.unknown"
        case .upToDate: "widget.status.upToDate"
        case .upToDateByDate: "widget.status.upToDate.byDate"
        case .approaching: "widget.status.approaching"
        case .approachingByDate: "widget.status.approaching.byDate"
        case .due: "widget.status.due"
        }
    }
}

extension ProgressFact {
    /// The short form of Service's progress line: the measure when there is one, otherwise the reason
    /// nothing is counted.
    var widgetText: Text {
        switch self {
        case .readingSuperseded: Text("widget.fact.nothingCounted")
        case .noBaseline: Text("widget.fact.noBaseline")
        case let .progress(measure?, _): measure.widgetText
        case let .progress(nil, block?): block.widgetText
        case .progress(nil, nil): DistanceBlock.mileageUnknown.widgetText
        }
    }
}

extension ProgressMeasure {
    var widgetText: Text {
        switch self {
        case let .kilometersAhead(kilometers): Text("widget.fact.inKm \(kilometers)")
        case let .kilometersPast(kilometers): Text("widget.fact.overKm \(kilometers)")
        case let .daysLeft(days): Text("widget.fact.inDays \(days)")
        case let .daysPast(days): Text("widget.fact.overDays \(days)")
        case .reached: Text("widget.fact.reached")
        case .almost: Text("widget.fact.almost")
        }
    }
}

extension DistanceBlock {
    var widgetText: Text {
        switch self {
        case .mileageUnknown: Text("widget.fact.mileageUnknown")
        case .mileageStale: Text("widget.fact.mileageStale")
        case .completionMileageMissing, .completionMissing: Text("widget.fact.distanceNotCounted")
        }
    }
}
