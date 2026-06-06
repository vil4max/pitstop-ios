import SwiftData
import SwiftUI

struct UpgradeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \UpgradeItemEntity.sortOrder) private var items: [UpgradeItemEntity]
    @State private var showServiceHistory = false
    private let themeController = ThemeController()

    private var snapshots: [UpgradeItemSnapshot] {
        items.map {
            UpgradeItemSnapshot(
                id: $0.seedId,
                title: $0.title,
                costUah: $0.costUah,
                currencyCode: $0.currencyCode,
                status: $0.status,
                completedDate: $0.completedDate,
                priority: $0.priority
            )
        }
    }

    private var dealerStatement: DealerStatementDTO? {
        try? DealerStatementReader.dealerStatement()
    }

    private var doneGrandTotalUah: Int {
        var total = UpgradeTotals.totalSpentUah(items: snapshots)
        if let dealerStatement {
            total += dealerStatement.arteonVisitsTotalUah
        }
        return total
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    doneSection
                    plannedSection
                }
                .padding()
            }
            .background(themeController.screenBackground(for: colorScheme))
            .navigationTitle("tab.upgrade")
            .sheet(isPresented: $showServiceHistory) {
                AtlantHistorySheet()
            }
        }
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("upgrade.section.done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VWCard {
                VStack(spacing: 0) {
                    let rows = sortedDoneRows
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        doneSectionRow(row)
                            .frame(minHeight: 56, alignment: .center)
                        if index < rows.count - 1 {
                            rowDivider
                        }
                    }
                    if !rows.isEmpty {
                        summaryTopDivider
                    }
                    upgradeSummaryRow(title: "upgrade.total") {
                        MonospacedUAH(value: doneGrandTotalUah)
                    } accessory: {
                        Button {
                            showServiceHistory = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.hapticPlain)
                    }
                }
            }
        }
    }

    private var plannedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("upgrade.section.planned")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VWCard {
                VStack(spacing: 0) {
                    let plannedItems = UpgradeTotals.sortedPlanned(snapshots)
                    ForEach(Array(plannedItems.enumerated()), id: \.element.id) { index, item in
                        upgradeRow(item)
                            .frame(minHeight: 56, alignment: .center)
                        if index < plannedItems.count - 1 {
                            rowDivider
                        }
                    }
                    if !plannedItems.isEmpty {
                        summaryTopDivider
                    }
                    upgradeSummaryRow(title: "upgrade.summary.planned") {
                        MonospacedUSD(value: UpgradeTotals.totalPlannedUsd(items: snapshots))
                    }
                }
            }
        }
    }

    private var sortedDoneRows: [DoneSectionRow] {
        var rows: [DoneSectionRow] = UpgradeTotals.sortedDone(snapshots).map { item in
            DoneSectionRow(
                id: item.id,
                sortDate: item.completedDate ?? .distantFuture,
                content: .upgrade(item)
            )
        }
        if let statement = dealerStatement {
            rows.append(
                DoneSectionRow(
                    id: "atlant-service-total",
                    sortDate: latestServiceDate(in: statement) ?? .distantPast,
                    content: .serviceTotal(statement.arteonVisitsTotalUah)
                )
            )
        }
        return rows.sorted { $0.sortDate < $1.sortDate }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
            .padding(.vertical, 10)
    }

    private var summaryTopDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .frame(height: 1)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private func upgradeSummaryRow<Amount: View, Accessory: View>(
        title: LocalizedStringKey,
        @ViewBuilder amount: () -> Amount,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            amount()
                .font(.headline.weight(.semibold))
            accessory()
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(sectionTotalForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionTotalBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .padding(.horizontal, -16)
        .padding(.bottom, -16)
    }

    private var sectionTotalForeground: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    private var sectionTotalBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : ThemeColors.brand.opacity(0.16)
    }

    @ViewBuilder
    private func doneSectionRow(_ row: DoneSectionRow) -> some View {
        switch row.content {
        case let .upgrade(item):
            upgradeRow(item)
        case let .serviceTotal(totalUah):
            serviceSpendRow(
                totalUah: totalUah,
                date: dealerStatement.flatMap { latestServiceDate(in: $0) }
            )
        }
    }

    private func serviceSpendRow(totalUah: Int, date: Date? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("atlant.total")
                    .font(.body)
                if let date {
                    Text(LocalizedFormat.monthYear(date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            MonospacedUAH(value: totalUah)
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 14)
    }

    private func upgradeRow(_ item: UpgradeItemSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = item.completedDate {
                    Text(LocalizedFormat.monthYear(date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            upgradeCost(item)
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func upgradeCost(_ item: UpgradeItemSnapshot) -> some View {
        if item.currencyCode == "USD" {
            MonospacedUSD(value: item.costUah)
        } else {
            MonospacedUAH(value: item.costUah)
        }
    }

    private func latestServiceDate(in statement: DealerStatementDTO) -> Date? {
        statement.arteonVisits
            .compactMap { SeedDateParser.date(from: $0.serviceDate) }
            .max()
    }
}

private struct DoneSectionRow: Identifiable {
    enum Content {
        case upgrade(UpgradeItemSnapshot)
        case serviceTotal(Int)
    }

    let id: String
    let sortDate: Date
    let content: Content
}
