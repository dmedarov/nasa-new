import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

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
            router.consumePendingRouteIfNeeded(fetcher: fetcher)
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            router.consumePendingRouteIfNeeded(fetcher: fetcher)
        }
    }

    private var tabShell: some View {
        TabView(selection: $router.destination) {
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
        } detail: {
            activeDetailRoot
        }
        .navigationSplitViewStyle(.balanced)
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
        .userActivity(AppUserActivityType.today, isActive: router.destination == .today) { activity in
            activity.title = L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day")
            activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .today))
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
        }
    }

    private var archiveRoot: some View {
        ArchiveScreenView()
            .environmentObject(fetcher)
            .environmentObject(router)
            .userActivity(AppUserActivityType.archive, isActive: router.destination == .archive) { activity in
                activity.title = L10n.text("APOD Archive", default: "APOD Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .archive))
                activity.isEligibleForSearch = true
                activity.isEligibleForPrediction = true
            }
    }

    private var savedRoot: some View {
        SavedScreenView()
            .environmentObject(fetcher)
            .environmentObject(router)
            .userActivity(AppUserActivityType.saved, isActive: router.destination == .saved) { activity in
                activity.title = L10n.text("Saved Archive", default: "Saved Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .saved))
                activity.isEligibleForSearch = true
                activity.isEligibleForPrediction = true
            }
    }

    private func splitDestinationRow(for destination: AppDestination) -> some View {
        let isSelected = router.destination == destination

        return Button {
            router.destination = destination
        } label: {
            AppShellSidebarRow(destination: destination, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? AppTheme.Palette.accentLight.opacity(0.16) : Color.clear)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
