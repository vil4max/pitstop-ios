import SwiftUI

struct NextVisitLine {
    let operation: MaintenanceOperationState
    /// Set for an operation suggested only because it is close enough to the visit.
    let note: LocalizedStringKey?
}

enum ServiceListMetrics {
    static let glyphColumn: CGFloat = 20
    static let glyphSpacing: CGFloat = 12
}

/// A suggested operation: the state glyph, the title and why it is in the visit. The Tracked row below says the
/// status in words.
struct NextVisitRow: View {
    let line: NextVisitLine
    var showsSeparator = false

    @ScaledMetric(relativeTo: .headline) private var glyphSize: CGFloat = 13
    /// Half the headline's cap height: it centres the glyph on the title's first line.
    @ScaledMetric(relativeTo: .headline) private var glyphLift: CGFloat = 6

    var body: some View {
        // Read on the main actor: the alignment closure below is Sendable.
        let lift = glyphLift
        HStack(alignment: .firstTextBaseline, spacing: ServiceListMetrics.glyphSpacing) {
            StatusGlyphView(glyph: line.operation.status.glyph, size: glyphSize)
                .foregroundStyle(line.operation.status.color)
                .frame(width: glyphColumnWidth)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + lift }
            VStack(alignment: .leading, spacing: 3) {
                line.operation.id.titleText
                    .font(PitTypography.headline)
                    .foregroundStyle(PitColor.contentPrimary)
                (line.note.map { Text($0) } ?? line.operation.progressText)
                    .font(PitTypography.supportingSmall)
                    .foregroundStyle(PitColor.contentSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, DesignTokens.groupedRowPadding)
        .accessibilityElement(children: .combine)
        .groupedRowSeparator(
            showsSeparator,
            leadingInset: DesignTokens.groupedRowPadding + glyphColumnWidth + ServiceListMetrics.glyphSpacing
        )
    }

    private var glyphColumnWidth: CGFloat {
        max(ServiceListMetrics.glyphColumn, glyphSize)
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
            Label("service.more", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(PitTypography.headline)
                .foregroundStyle(PitColor.accentPrimary)
                // The glyph is small; the target keeps the 44 pt minimum (REQ-GRAMMAR-003).
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
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
