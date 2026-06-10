import SwiftData
import SwiftUI

@main
struct ArteonApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
    @State private var navigation = AppNavigationState()

    private let container: ModelContainer?
    private let bootstrapError: String?

    init() {
        var loadedContainer: ModelContainer?
        var errorMessage: String?
        do {
            loadedContainer = try AppModelContainerFactory.make()
            let context = ModelContext(loadedContainer!)
            try PlanSeedImporter.importIfNeeded(into: context)
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
                    .modelContainer(container)
                    .onReceive(NotificationCenter.default.publisher(for: .arteonOpenDestination)) { notification in
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
    static let arteonOpenDestination = Notification.Name("arteon.openDestination")
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
    private let themeController = ThemeController()

    private var tabBarTint: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    var body: some View {
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
        .task {
            await NotificationRefresh.apply(context: modelContext)
        }
    }
}
