import SwiftData
import SwiftUI

struct ServiceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServiceVisitEntity.sortOrder) private var visits: [ServiceVisitEntity]
    @Query private var vehicles: [VehicleConfig]
    @State private var selectedVisitIndex = 0
    private let themeController = ThemeController()

    private var vehicle: VehicleConfig? { vehicles.first }

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    ScrollView {
                        serviceSummaryContent(for: nil)
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                    }
                } else {
                    visitPager
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeController.screenBackground(for: colorScheme))
            .navigationTitle("tab.service")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: scrollToNearest)
        }
    }

    private var visitPager: some View {
        TabView(selection: $selectedVisitIndex) {
            ForEach(Array(visits.enumerated()), id: \.element.seedId) { index, visit in
                ScrollView {
                    serviceSummaryContent(for: visit)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .onChange(of: selectedVisitIndex) { oldIndex, newIndex in
            guard oldIndex != newIndex else { return }
            TapFeedback.selection()
        }
    }

    @ViewBuilder
    private func serviceSummaryContent(for visit: ServiceVisitEntity?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let vehicle, let lastOil = MaintenanceEngine.lastOilChangeOdometer(visits: visitSnapshots) {
                oilSummary(vehicle: vehicle, lastOil: lastOil)
            }
            if let visit {
                Text("service.visitsSection")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                visitHeaderPage(visit)
                visitDetailsBlock(visit)
            }
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
        VStack(alignment: .leading, spacing: 12) {
            let required = visit.tasks.filter { $0.isMandatory && $0.isApplicable }
            let optional = visit.tasks.filter { !$0.isMandatory && $0.isApplicable && $0.isEnabled }
            if !required.isEmpty {
                taskListCard(title: "service.required", tasks: required, emphasized: true, visit: visit)
            }
            if !optional.isEmpty {
                taskListCard(title: "service.optional", tasks: optional, emphasized: false, visit: visit)
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
            Label("service.visitStatus.completed", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.green)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
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

    private func canCompleteVisitNow(_ visit: ServiceVisitEntity) -> Bool {
        guard let vehicle else { return false }
        return MaintenanceEngine.canCompleteVisitAtOdometer(
            visit: visitSnapshot(for: visit),
            odometer: vehicle.odometerKm
        )
    }

    private func visitSnapshot(for visit: ServiceVisitEntity) -> VisitSnapshot {
        VisitSnapshot(
            id: visit.seedId,
            kind: visit.kind,
            sortOrder: visit.sortOrder,
            targetOdometerKm: visit.targetOdometerKm,
            includesOilChange: visit.includesOilChange,
            isCompleted: visit.isCompleted,
            completedOdometer: visit.completedOdometer,
            windowFromKm: visit.windowFromKm,
            windowToKm: visit.windowToKm
        )
    }

    @ViewBuilder
    private func visitRoleBadge(_ visit: ServiceVisitEntity) -> some View {
        if isNextVisit(visit) {
            Label("service.visitStatus.next", systemImage: "arrow.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white : ThemeColors.brand)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? ThemeColors.brand : ThemeColors.brand.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func completedVisitMeta(_ visit: ServiceVisitEntity) -> some View {
        HStack(spacing: 12) {
            if let dealer = visit.dealer {
                Text(dealer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let cost = visit.costUah {
                Spacer(minLength: 0)
                MonospacedUAH(value: cost)
            }
        }
    }

    private func taskListCard(
        title: LocalizedStringKey,
        tasks: [ServiceTaskEntity],
        emphasized: Bool,
        visit: ServiceVisitEntity
    ) -> some View {
        VWCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .padding(.bottom, 8)
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

    private func isTaskCompleted(_ task: ServiceTaskEntity, visit: ServiceVisitEntity) -> Bool {
        visit.isCompleted && task.isApplicable
    }

    @ViewBuilder
    private func taskRow(_ task: ServiceTaskEntity, emphasized: Bool, visit: ServiceVisitEntity) -> some View {
        let completed = isTaskCompleted(task, visit: visit)
        if visit.isCompleted || completed {
            Text(task.title)
                .font(emphasized ? .body.weight(.semibold) : .body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.leading)
                .strikethrough(completed, pattern: .solid, color: .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .opacity(completed ? 0.85 : 1)
        } else {
            ThemedToggle(isOn: Binding(
                get: { task.isDone },
                set: { newValue in
                    task.isDone = newValue
                    if newValue {
                        task.doneAt = Date()
                        task.doneOdometer = vehicle?.odometerKm
                    } else {
                        task.doneAt = nil
                        task.doneOdometer = nil
                    }
                    try? modelContext.save()
                }
            )) {
                Text(task.title)
                    .font(emphasized ? .body.weight(.semibold) : .body)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 6)
        }
    }

    private func completeNextVisit(_ visit: ServiceVisitEntity) {
        guard let vehicle, canCompleteVisitNow(visit) else { return }
        ServiceVisitCompletion.completeVisit(
            visit,
            completedAt: Date(),
            completedOdometer: vehicle.odometerKm
        )
        try? modelContext.save()
        Task { await NotificationRefresh.apply(context: modelContext, visits: visits) }
    }

    private func scrollToNearest() {
        guard let vehicle, let nearest = MaintenanceEngine.nearestVisit(visits: visitSnapshots, odometer: vehicle.odometerKm),
              let index = visits.firstIndex(where: { $0.seedId == nearest.id }) else { return }
        selectedVisitIndex = index
    }

    private var visitSnapshots: [VisitSnapshot] {
        visits.map {
            VisitSnapshot(
                id: $0.seedId,
                kind: $0.kind,
                sortOrder: $0.sortOrder,
                targetOdometerKm: $0.targetOdometerKm,
                includesOilChange: $0.includesOilChange,
                isCompleted: $0.isCompleted,
                completedOdometer: $0.completedOdometer,
                windowFromKm: $0.windowFromKm,
                windowToKm: $0.windowToKm
            )
        }
    }
}

struct AtlantHistorySheet: View {
    var body: some View {
        NavigationStack {
            List {
                if let statement = try? DealerStatementReader.dealerStatement() {
                    Section {
                        ForEach(statement.arteonVisits) { visit in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(visit.serviceDate)
                                    Text("\(visit.completedOdometerKm) km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                MonospacedUAH(value: visit.totalUah)
                            }
                        }
                    } header: {
                        HStack {
                            Text("atlant.total")
                            Spacer()
                            MonospacedUAH(value: statement.arteonVisitsTotalUah)
                        }
                    }
                    if !statement.otherPayments.isEmpty {
                        Section {
                            ForEach(statement.otherPayments) { payment in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(payment.title)
                                        Text(payment.date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    MonospacedUAH(value: payment.amountUah)
                                }
                            }
                        } header: {
                            Text("atlant.otherPayments")
                        }
                    }
                }
            }
            .navigationTitle("atlant.history")
        }
    }
}

extension ServiceVisitEntity: Identifiable {
    var id: String { seedId }
}
