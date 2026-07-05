import SwiftData
import SwiftUI

@main
struct PitstopApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
    @State private var navigation = AppNavigationState()
    @State private var activeVehicleStore = ActiveVehicleStore()

    private let container: ModelContainer?
    private let bootstrapError: String?

    init() {
        var loadedContainer: ModelContainer?
        var errorMessage: String?
        do {
            loadedContainer = try AppModelContainerFactory.make()
            let context = ModelContext(loadedContainer!)
            try PlanSeedImporter.prepareAppStorage(into: context)
        } catch {
            errorMessage = String(describing: error)
        }
        container = loadedContainer
        bootstrapError = errorMessage
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .environment(navigation)
                    .environment(activeVehicleStore)
                    .modelContainer(container)
                    .onReceive(NotificationCenter.default.publisher(for: .pitstopOpenDestination)) { notification in
                        guard let destination = notification.object as? AppDestination else { return }
                        navigation.open(destination)
                    }
            } else {
                BootstrapErrorView(message: bootstrapError ?? "unknown")
            }
        }
    }
}

extension Notification.Name {
    static let pitstopOpenDestination = Notification.Name("pitstop.openDestination")
}

struct BootstrapErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Text("common.error")
                .font(.headline)
            Text("seed.importFailed")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .modifier(OptionalLocaleModifier())
    }
}

private struct OptionalLocaleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if let locale = AppConfiguration.forcedLocale {
            content.environment(\.locale, locale)
        } else {
            content
        }
    }
}

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationState.self) private var navigation
    @Query private var settingsList: [AppSettingsEntity]
    @Query private var insurancePolicies: [InsurancePolicyEntity]
    @Query private var vehicles: [VehicleConfig]
    private let themeController = ThemeController()

    private var tabBarTint: Color {
        themeController.actionTint(for: colorScheme)
    }

    var body: some View {
        Group {
            if vehicles.isEmpty {
                OnboardingView()
            } else {
                mainTabs
            }
        }
        .task(id: vehicles.isEmpty) {
            guard !vehicles.isEmpty else { return }
            try? PlanSeedImporter.importIfNeeded(into: modelContext)
            await NotificationRefresh.apply(context: modelContext)
        }
    }

    private var mainTabs: some View {
        TabView(selection: Bindable(navigation).selectedTab) {
            MyCarView()
                .tabItem { Label(AppTab.myCar.title, systemImage: AppTab.myCar.symbol) }
                .tag(AppTab.myCar)
            ServiceView()
                .tabItem { Label(AppTab.service.title, systemImage: AppTab.service.symbol) }
                .tag(AppTab.service)
            UpgradeView()
                .tabItem { Label(AppTab.upgrade.title, systemImage: AppTab.upgrade.symbol) }
                .tag(AppTab.upgrade)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
                .tag(AppTab.settings)
        }
        .tint(tabBarTint)
        .onChange(of: navigation.selectedTab) { oldTab, newTab in
            guard oldTab != newTab else { return }
            TapFeedback.selection()
        }
        .preferredColorScheme(themeController.preferredScheme(for: settingsList.first?.theme ?? .system))
        .modifier(OptionalLocaleModifier())
        .sheet(item: Bindable(navigation).presentedDetail) { destination in
            ReminderDetailView(destination: destination)
                .environment(navigation)
        }
        .sheet(isPresented: Bindable(navigation).showInsurancePolicy) {
            if let insurance = insurancePolicies.first {
                NavigationStack {
                    InsuranceView(policy: insurance)
                }
            }
        }
    }
}
