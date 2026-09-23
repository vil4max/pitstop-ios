import SwiftUI

struct NextVisitLine {
    let operation: MaintenanceOperationState
    /// Set for an operation suggested only because it is close enough to the visit.
    let note: LocalizedStringKey?
}

/// A suggested operation: the state glyph, the title and why it is in the visit. The Tracked row below says the
/// status in words.
struct NextVisitRow: View {
    let line: NextVisitLine
    var showsSeparator = false

    var body: some View {
        GlyphColumnRow(
            glyph: line.operation.status.glyph, color: line.operation.status.color, showsSeparator: showsSeparator
        ) {
            VStack(alignment: .leading, spacing: 3) {
                line.operation.id.titleText
                    .font(PitTypography.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                (line.note.map { Text($0) } ?? line.operation.progressText)
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// One tracked operation: title, status chip, the neutral fact line, the car's reading, the remaining-share
/// track when its facts are fresh, then "Mark as done" and the corrections menu.
struct OperationRow: View {
    let operation: MaintenanceOperationState
    /// From `drawnUsedShare(mileage:)`; nil draws no track.
    let usedShare: Double?
    var showsSeparator = false
    let onMarkDone: () -> Void
    let onChangeInterval: () -> Void
    let onUndo: () -> Void
    let onStopTracking: () -> Void
    let onEnterReport: () -> Void
    let onDeleteReport: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            details
            actions
        }
        .padding(.vertical, 12)
        .padding(.horizontal, DesignTokens.groupedRowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedRowSeparator(showsSeparator)
    }

    /// VoiceOver reads the row as one element: title, status word, fact line and the car's reading. The track is
    /// hidden from it (ADR 0038); the fact line says the same in words.
    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            operation.id.titleText
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.contentPrimary)
            StatusChip(Text(operation.statusLabel), glyph: operation.status.glyph, color: operation.status.color)
            operation.progressText
                .font(PitTypography.supportingSmall)
                .foregroundStyle(PitColor.contentSecondary)
            // Secondary to the status: what the car said and when, never a second status (ADR 0035).
            if let reportText = operation.reportText(now: .now) {
                reportText
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
                    .accessibilityIdentifier("service.report.\(operation.id.rawValue)")
            }
            if let usedShare {
                RemainingShareTrack(usedShare: usedShare, color: operation.status.color)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// At accessibility sizes the more menu moves under "Mark as done", so the button keeps the row's width.
    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return layout {
            Button("service.markDone", systemImage: "checkmark", action: onMarkDone)
                .font(PitTypography.supporting.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(PitColor.accentPrimary)
                .accessibilityIdentifier("service.markDone.\(operation.id.rawValue)")
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            moreMenu
        }
    }

    /// Stored facts stay correctable: the interval, a confirmation made by mistake, the car's reading, and the
    /// tracking itself.
    private var moreMenu: some View {
        Menu {
            Button("service.changeInterval", systemImage: "slider.horizontal.3", action: onChangeInterval)
            if operation.lastCompletion != nil {
                Button("service.undoDone", systemImage: "arrow.uturn.backward", role: .destructive, action: onUndo)
            }
            Button("service.report.enter", systemImage: "gauge.with.dots.needle.33percent", action: onEnterReport)
                .accessibilityIdentifier("service.report.enter.\(operation.id.rawValue)")
            if operation.report != nil {
                Button("service.report.delete", systemImage: "gauge.badge.minus", role: .destructive,
                       action: onDeleteReport)
                    .accessibilityIdentifier("service.report.delete.\(operation.id.rawValue)")
            }
            if operation.policy?.source == .userCustom {
                Button("service.stopTracking", systemImage: "eye.slash", role: .destructive, action: onStopTracking)
                    .accessibilityIdentifier("service.stopTracking.\(operation.id.rawValue)")
            }
        } label: {
            MoreMenuLabel()
        }
    }
}

#if DEBUG
    #Preview("Service rows") {
        let now = Date.now
        let vehicle = VehicleID()
        let completions = [
            (MaintenanceOperationID.engineOilService, 200.0, Optional(50000)),
            (.brakeFluid, 740, nil),
            (.cabinFilter, 300, 44000),
        ].map { operation, daysAgo, km in
            MaintenanceCompletion(
                vehicleID: vehicle, operationID: operation,
                performedAt: now.addingTimeInterval(-daysAgo * 86400), odometerKm: km
            )
        }
        let context = MaintenanceContext(
            now: now,
            latestReading: OdometerReading(vehicleID: vehicle, value: 57800, recordedAt: now),
            completions: completions
        )
        let states = MaintenanceEngine().states(
            policies: [
                MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom),
                MaintenancePolicy(operationID: .brakeFluid, timeIntervalMonths: 24, source: .userCustom),
                MaintenancePolicy(operationID: .cabinFilter, distanceIntervalKm: 15000, source: .userCustom),
                MaintenancePolicy(operationID: .sparkPlugs, distanceIntervalKm: 60000, source: .userCustom),
            ],
            completions: completions,
            context: context
        ).byUrgency
        PreviewMatrix {
            GroupedSection(title: "service.tracked") {
                ForEach(Array(states.enumerated()), id: \.element.id) { index, operation in
                    OperationRow(
                        operation: operation,
                        usedShare: operation.drawnUsedShare(mileage: context.mileage),
                        showsSeparator: index > 0
                    ) {} onChangeInterval: {} onUndo: {} onStopTracking: {} onEnterReport: {} onDeleteReport: {}
                }
            }
        }
    }
#endif
