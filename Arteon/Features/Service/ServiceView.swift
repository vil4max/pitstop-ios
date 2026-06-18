import SwiftData
import SwiftUI

struct ServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationState.self) private var navigation
    @Query(sort: \ServiceVisitEntity.sortOrder) private var visits: [ServiceVisitEntity]
    @Query private var vehicles: [VehicleConfig]
    @State private var selectedVisitIndex = 0
    @State private var reopenVisitSeedId: String?
    private let themeController = ThemeController()

    private var vehicle: VehicleConfig? { vehicles.first }

    private var selectedVisit: ServiceVisitEntity? {
        guard visits.indices.contains(selectedVisitIndex) else { return nil }
        return visits[selectedVisitIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let vehicle, let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visitSnapshots) {
                        oilSummary(vehicle: vehicle, lastOil: lastOil)
                    }
                    if !visits.isEmpty {
                        Text("service.visitsSection")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        visitNavigator
                        if let selectedVisit {
                            visitPageContent(for: selectedVisit)
                                .id(selectedVisit.seedId)
                                .animation(.easeInOut(duration: 0.2), value: selectedVisitIndex)
                        }
                    }
                }
                .padding()
            }
            .tabRootScreen(title: "tab.service", colorScheme: colorScheme, theme: themeController)
            .onAppear {
                scrollToNearest()
                focusPendingVisitIfNeeded()
            }
            .onChange(of: navigation.serviceVisitSeedId) { _, _ in
                focusPendingVisitIfNeeded()
            }
            .alert("service.reopenVisit.confirm.title", isPresented: Binding(
                get: { reopenVisitSeedId != nil },
                set: { if !$0 { reopenVisitSeedId = nil } }
            )) {
                Button("service.reopenVisit", role: .destructive) {
                    if let seedId = reopenVisitSeedId,
                       let visit = visits.first(where: { $0.seedId == seedId }) {
                        reopenVisit(visit)
                    }
                    reopenVisitSeedId = nil
                }
                Button("common.cancel", role: .cancel) {
                    reopenVisitSeedId = nil
                }
            } message: {
                Text("service.reopenVisit.confirm.message")
            }
        }
    }

    private var visitNavigator: some View {
        HStack(spacing: 12) {
            visitStepButton(systemName: "chevron.left", enabled: selectedVisitIndex > 0) {
                selectedVisitIndex -= 1
            }
            Spacer(minLength: 0)
            Text(LocalizedFormat.string(
                "service.visitPager.progress",
                selectedVisitIndex + 1,
                visits.count
            ))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            visitStepButton(systemName: "chevron.right", enabled: selectedVisitIndex < visits.count - 1) {
                selectedVisitIndex += 1
            }
        }
        .padding(.horizontal, 4)
    }

    private func visitStepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            TapFeedback.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(navigatorButtonColor(enabled: enabled))
                .background(navigatorButtonBackground(enabled: enabled))
                .clipShape(Circle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(!enabled)
    }

    private func navigatorButtonColor(enabled: Bool) -> Color {
        guard enabled else { return .secondary.opacity(0.35) }
        return themeController.actionTint(for: colorScheme)
    }

    private func navigatorButtonBackground(enabled: Bool) -> Color {
        guard enabled else { return Color.primary.opacity(0.04) }
        return colorScheme == .dark ? ThemeColors.brand.opacity(0.35) : ThemeColors.brand.opacity(0.12)
    }

    @ViewBuilder
    private func visitPageContent(for visit: ServiceVisitEntity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            visitHeaderPage(visit)
            visitDetailsBlock(visit)
        }
    }

    private func visitHeaderPage(_ visit: ServiceVisitEntity) -> some View {
        VStack(spacing: 8) {
            Text(visitHeaderTitle(visit))
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            visitRoleBadge(visit)
            if visit.isCompleted {
                if let date = visit.completedAt {
                    Text(LocalizedFormat.date(date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                completedVisitMeta(visit)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(visit.isCompleted ? 0.9 : 1)
    }

    private func visitDetailsBlock(_ visit: ServiceVisitEntity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let required = visit.tasks.filter { $0.isMandatory && $0.isApplicable }
            let optional = visit.tasks.filter { !$0.isMandatory && $0.isApplicable && $0.isEnabled }
            if !required.isEmpty {
                taskSection(title: "service.required", tasks: required, emphasized: true, visit: visit)
            }
            if !optional.isEmpty {
                taskSection(title: "service.optional", tasks: optional, emphasized: false, visit: visit)
            }
            visitActionFooter(visit)
        }
    }

    @ViewBuilder
    private func visitActionFooter(_ visit: ServiceVisitEntity) -> some View {
        if isNextVisit(visit) {
            SlideToCompleteControl(canComplete: { canCompleteVisitNow(visit) }) {
                completeNextVisit(visit)
            }
            .padding(.top, 4)
            .id(visit.seedId)
        } else if visit.isCompleted {
            if canReopenVisit(visit) {
                Button {
                    reopenVisitSeedId = visit.seedId
                } label: {
                    Label("service.reopenVisit", systemImage: "arrow.uturn.backward.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.hapticPlain)
                .foregroundStyle(themeController.actionTint(for: colorScheme))
                .padding(.top, 8)
            } else {
                Label("service.visitStatus.completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.green)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }

    private func oilSummary(vehicle: VehicleConfig, lastOil: Int) -> some View {
        let kmSince = MaintenanceEngine.kmSinceLastOil(odometer: vehicle.odometerKm, lastOilOdometer: lastOil)
        return VWCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("nextOil.title")
                    .font(.headline)
                Text(LocalizedFormat.string("service.oilSince", kmSince))
            }
        }
    }

    private func visitHeaderTitle(_ visit: ServiceVisitEntity) -> String {
        if visit.isCompleted, let odometer = visit.completedOdometer {
            return LocalizedFormat.string("service.visitTargetKm", odometer)
        }
        if visit.windowFromKm != nil, visit.windowToKm != nil {
            return visit.title
        }
        return LocalizedFormat.string("service.visitTargetKm", visit.targetOdometerKm)
    }

    private var nextVisitSeedId: String? {
        guard let vehicle else { return nil }
        return MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm)?.id
    }

    private func isNextVisit(_ visit: ServiceVisitEntity) -> Bool {
        guard !visit.isCompleted, let nextVisitSeedId else { return false }
        return visit.seedId == nextVisitSeedId
    }

    private var lastCompletedVisitSeedId: String? {
        MaintenanceEngine.lastCompletedVisit(visits: visitSnapshots)?.id
    }

    private func canReopenVisit(_ visit: ServiceVisitEntity) -> Bool {
        visit.isCompleted && visit.seedId == lastCompletedVisitSeedId
    }

    private func canCompleteVisitNow(_ visit: ServiceVisitEntity) -> Bool {
        guard let vehicle else { return false }
        let snapshot = VisitSnapshot(from: visit)
        return MaintenanceEngine.canCompleteVisitAtOdometer(visit: snapshot, odometer: vehicle.odometerKm)
    }

    @ViewBuilder
    private func visitRoleBadge(_ visit: ServiceVisitEntity) -> some View {
        if isNextVisit(visit) {
            Label("service.visitStatus.next", systemImage: "arrow.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeController.actionTint(for: colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? ThemeColors.brand : ThemeColors.brand.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func completedVisitMeta(_ visit: ServiceVisitEntity) -> some View {
        if let dealer = visit.dealer {
            Text(dealer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func taskSection(
        title: LocalizedStringKey,
        tasks: [ServiceTaskEntity],
        emphasized: Bool,
        visit: ServiceVisitEntity
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VWCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tasks.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated()), id: \.element.seedId) { index, task in
                        taskRow(task, emphasized: emphasized, visit: visit)
                        if index < tasks.count - 1 {
                            Divider()
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: ServiceTaskEntity, emphasized: Bool, visit: ServiceVisitEntity) -> some View {
        let completed = visit.isCompleted && task.isApplicable
        return Group {
            if let key = task.localizedTitleKey {
                Text(LocalizedStringKey(key))
            } else {
                Text(task.title)
            }
        }
            .font(emphasized ? .body.weight(.semibold) : .body)
            .foregroundStyle(completed ? Color.secondary : Color.primary)
            .multilineTextAlignment(.leading)
            .strikethrough(completed, pattern: .solid, color: .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .opacity(completed ? 0.85 : 1)
    }

    private func completeNextVisit(_ visit: ServiceVisitEntity) {
        guard let vehicle, canCompleteVisitNow(visit) else { return }
        ServiceVisitCompletion.completeVisit(
            visit,
            completedAt: Date(),
            completedOdometer: vehicle.odometerKm
        )
        try? modelContext.save()
        Task { await NotificationRefresh.apply(context: modelContext) }
    }

    private func reopenVisit(_ visit: ServiceVisitEntity) {
        ServiceVisitCompletion.reopenVisit(visit)
        try? modelContext.save()
        Task { await NotificationRefresh.apply(context: modelContext) }
        scrollToNearest()
    }

    private func scrollToNearest() {
        guard let vehicle, let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm),
              let index = visits.firstIndex(where: { $0.seedId == nearest.id }) else { return }
        selectedVisitIndex = index
    }

    private func focusPendingVisitIfNeeded() {
        guard let seedId = navigation.serviceVisitSeedId,
              let index = visits.firstIndex(where: { $0.seedId == seedId }) else { return }
        selectedVisitIndex = index
        navigation.serviceVisitSeedId = nil
    }

    private var visitSnapshots: [VisitSnapshot] {
        visits.map(VisitSnapshot.init(from:))
    }
}

struct AtlantHistorySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    private let themeController = ThemeController()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let statement = try? DealerStatementReader.dealerStatement() {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statement.dealer)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        VWCard {
                            VStack(spacing: 0) {
                                ForEach(Array(statement.arteonVisits.enumerated()), id: \.element.id) { index, visit in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formattedServiceDate(visit.serviceDate))
                                        Text(mileageLabel(for: visit))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    if index < statement.arteonVisits.count - 1 {
                                        Divider()
                                            .overlay(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(themeController.screenBackground(for: colorScheme))
            .navigationTitle("atlant.history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        TapFeedback.light()
                        dismiss()
                    }
                }
            }
            .themedActionTint(colorScheme: colorScheme, theme: themeController)
        }
    }

    private func formattedServiceDate(_ isoDate: String) -> String {
        guard let date = Self.isoDateFormatter.date(from: isoDate) else { return isoDate }
        return LocalizedFormat.date(date)
    }

    private func mileageLabel(for visit: DealerVisitDTO) -> String {
        if visit.odometerIsEstimate == true {
            return LocalizedFormat.string("atlant.history.odometerApprox", visit.completedOdometerKm)
        }
        return LocalizedFormat.string("service.visitTargetKm", visit.completedOdometerKm)
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension ServiceVisitEntity: Identifiable {
    var id: String { seedId }
}
