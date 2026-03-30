import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("app.shell.destination") private var persistedDestinationRawValue = AppDestination.today.rawValue
    @State private var lastTrackedDestination: AppDestination?

    private var usesSplitShell: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if usesSplitShell {
                splitShell
            } else {
                tabShell
            }
        }
        .task {
            restorePersistedDestinationIfNeeded()
            router.consumePendingRouteIfNeeded(fetcher: fetcher, purchaseManager: purchaseManager)
            trackArchiveVisitIfNeeded(for: router.destination)
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            router.consumePendingRouteIfNeeded(fetcher: fetcher, purchaseManager: purchaseManager)
            Task {
                await purchaseManager.refreshEntitlements()
            }
        }
        .onChange(of: router.destination) { newValue in
            persistedDestinationRawValue = newValue.rawValue
            trackArchiveVisitIfNeeded(for: newValue)
        }
        .sheet(item: activePaywallBinding) { context in
            MonetizationPaywallView(context: context)
                .environmentObject(purchaseManager)
        }
    }

    private var tabShell: some View {
        TabView(selection: destinationBinding) {
            todayRoot
                .tag(AppDestination.today)
                .tabItem {
                    Label(AppDestination.today.localizedTitle, systemImage: AppDestination.today.systemImage)
                }

            archiveRoot
                .tag(AppDestination.archive)
                .tabItem {
                    Label(AppDestination.archive.localizedTitle, systemImage: AppDestination.archive.systemImage)
                }

            savedRoot
                .tag(AppDestination.saved)
                .tabItem {
                    Label(AppDestination.saved.localizedTitle, systemImage: AppDestination.saved.systemImage)
                }
        }
    }

    private var splitShell: some View {
        NavigationSplitView {
            List {
                ForEach(AppDestination.allCases) { destination in
                    splitDestinationRow(for: destination)
                }
            }
            .navigationTitle(L10n.text("Space Briefing", default: "Space Briefing"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.appShellSidebar)
            }
        } detail: {
            activeDetailRoot
                .overlay(alignment: .topLeading) {
                    AccessibilityMarker(identifier: AccessibilityID.appShellDetail)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.appShellSplitRoot)
        }
    }

    private var activeDetailRoot: some View {
        Group {
            switch router.destination {
            case .today:
                todayRoot
            case .archive:
                archiveRoot
            case .saved:
                savedRoot
            }
        }
    }

    private var todayRoot: some View {
        NavigationStack {
            MainView(
                openArchiveAction: { router.showArchive() },
                openSavedAction: { router.showSaved() }
            )
        }
        .userActivity(SpaceBriefingUserActivityType.today, isActive: router.destination == .today) { activity in
            activity.title = L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day")
            activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .today))
            activity.isEligibleForSearch = true
            activity.isEligibleForHandoff = true
            activity.isEligibleForPrediction = true
            activity.isEligibleForPublicIndexing = false
            activity.webpageURL = AppDeepLink.publicWebURL(for: AppRoute(destination: .today))
        }
    }

    private var archiveRoot: some View {
        ArchiveScreenView()
            .environmentObject(fetcher)
            .environmentObject(router)
            .userActivity(SpaceBriefingUserActivityType.archive, isActive: router.destination == .archive) { activity in
                activity.title = L10n.text("APOD Archive", default: "APOD Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .archive))
                activity.isEligibleForSearch = true
                activity.isEligibleForHandoff = true
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.webpageURL = AppDeepLink.publicWebURL(for: AppRoute(destination: .archive))
            }
    }

    private var savedRoot: some View {
        SavedScreenView()
            .environmentObject(fetcher)
            .environmentObject(router)
            .userActivity(SpaceBriefingUserActivityType.saved, isActive: router.destination == .saved) { activity in
                activity.title = L10n.text("Saved Archive", default: "Saved Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .saved))
                activity.isEligibleForSearch = true
                activity.isEligibleForHandoff = true
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.webpageURL = AppDeepLink.publicWebURL(for: AppRoute(destination: .saved))
            }
    }

    private func splitDestinationRow(for destination: AppDestination) -> some View {
        let isSelected = router.destination == destination

        return Button {
            updateDestination(destination)
        } label: {
            AppShellSidebarRow(destination: destination, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? AppTheme.Palette.accentLight.opacity(0.16) : Color.clear)
        .accessibilityIdentifier(AccessibilityID.appShellSidebarDestinationIdentifier(for: destination))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var destinationBinding: Binding<AppDestination> {
        Binding(
            get: { router.destination },
            set: { updateDestination($0) }
        )
    }

    private func updateDestination(_ destination: AppDestination) {
        router.destination = destination
        persistedDestinationRawValue = destination.rawValue
    }

    private func restorePersistedDestinationIfNeeded() {
        guard router.destination == .today else {
            persistedDestinationRawValue = router.destination.rawValue
            return
        }

        guard let persistedDestination = AppDestination(rawValue: persistedDestinationRawValue) else {
            persistedDestinationRawValue = AppDestination.today.rawValue
            return
        }

        router.destination = persistedDestination
    }

    private var activePaywallBinding: Binding<PaywallPresentation?> {
        Binding(
            get: { purchaseManager.activePaywall },
            set: { newValue in
                if let newValue {
                    purchaseManager.activePaywall = newValue
                } else {
                    purchaseManager.dismissPaywall()
                }
            }
        )
    }

    private func trackArchiveVisitIfNeeded(for destination: AppDestination) {
        guard lastTrackedDestination != destination else { return }
        lastTrackedDestination = destination

        guard destination == .archive else { return }
        purchaseManager.registerArchiveVisitIfNeeded()
    }
}

private struct AppShellSidebarRow: View {
    let destination: AppDestination
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: destination.systemImage)
                .foregroundStyle(isSelected ? AppTheme.Palette.accentHighlight : .primary)
                .frame(width: 22)

            Text(destination.localizedTitle)
                .font(AppTheme.Typography.sectionTitle)

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Palette.accentHighlight)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}
