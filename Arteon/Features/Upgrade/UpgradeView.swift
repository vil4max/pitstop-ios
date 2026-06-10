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
                status: $0.status,
                completedDate: $0.completedDate,
                priority: $0.priority
            )
        }
    }

    private var dealerStatement: DealerStatementDTO? {
        try? DealerStatementReader.dealerStatement()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                upgradesSection
                    .padding()
            }
            .tabRootScreen(title: "tab.upgrade", colorScheme: colorScheme, theme: themeController)
            .sheet(isPresented: $showServiceHistory) {
                AtlantHistorySheet()
            }
        }
    }

    private var upgradesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("upgrade.section.all")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if dealerStatement != nil {
                    Button {
                        showServiceHistory = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.hapticPlain)
                }
            }
            .padding(.leading, 4)
            VWCard {
                VStack(spacing: 0) {
                    let items = combinedItems
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        upgradeRow(item)
                            .frame(minHeight: 56, alignment: .center)
                        if index < items.count - 1 {
                            rowDivider
                        }
                    }
                }
            }
        }
    }

    private var combinedItems: [UpgradeItemSnapshot] {
        UpgradeTotals.sortedPlanned(snapshots) + UpgradeTotals.sortedDone(snapshots)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
            .padding(.vertical, 10)
    }

    private func upgradeRow(_ item: UpgradeItemSnapshot) -> some View {
        let isDone = item.status == .done
        return VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(item.localizedTitleKey))
                .font(.body)
                .foregroundStyle(isDone ? Color.secondary : Color.primary)
                .strikethrough(isDone, pattern: .solid, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isDone ? 0.85 : 1)
            if isDone, let date = item.completedDate {
                Text(LocalizedFormat.monthYear(date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }

}

private extension UpgradeItemSnapshot {
    var localizedTitleKey: String { "upgrade.item.\(id)" }
}
