import SwiftUI

struct AppShellView: View {
    private enum StorageKey {
        static let destination = "app.shell.destination"
    }

    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(StorageKey.destination) private var persistedDestinationRawValue = AppDestination.today.rawValue
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
            ensureRegularShellSelectionIfNeeded()
            trackArchiveVisitIfNeeded(for: router.destination)
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            router.consumePendingRouteIfNeeded(fetcher: fetcher, purchaseManager: purchaseManager)
            ensureRegularShellSelectionIfNeeded()
            Task {
                await purchaseManager.refreshEntitlements()
            }
        }
        .onChange(of: router.destination) { newValue in
            persistDestination(newValue)
            ensureRegularShellSelectionIfNeeded()
            trackArchiveVisitIfNeeded(for: newValue)
        }
        .onChange(of: fetcher.archiveItems.map(\.id)) { _ in
            ensureRegularShellSelectionIfNeeded()
        }
        .onChange(of: fetcher.favorites.map(\.id)) { _ in
            ensureRegularShellSelectionIfNeeded()
        }
    }

    private var tabShell: some View {
        TabView(selection: destinationBinding) {
            todayRoot(shellContext: .compactTabs)
                .tag(AppDestination.today)
                .tabItem {
                    Label(AppDestination.today.localizedTitle, systemImage: AppDestination.today.systemImage)
                }

            archiveRoot(embedInRegularShell: false)
                .tag(AppDestination.archive)
                .tabItem {
                    Label(AppDestination.archive.localizedTitle, systemImage: AppDestination.archive.systemImage)
                }

            savedRoot(embedInRegularShell: false)
                .tag(AppDestination.saved)
                .tabItem {
                    Label(AppDestination.saved.localizedTitle, systemImage: AppDestination.saved.systemImage)
                }
        }
    }

    private var splitShell: some View {
        GeometryReader { proxy in
            let railWidth = min(
                max(proxy.size.width * 0.18, AppTheme.Metrics.shellRailMinimumWidth),
                AppTheme.Metrics.shellRailMaximumWidth
            )
            let contentWidth = max(
                proxy.size.width - railWidth - AppTheme.Metrics.shellContentGap - (AppTheme.Metrics.shellWorkspaceHorizontalPadding * 2),
                AppTheme.Metrics.shellLibraryPaneMinimumWidth
            )

            PremiumShellWorkspace(railWidth: railWidth) {
                premiumSidebarRail
                    .overlay(alignment: .topLeading) {
                        AccessibilityMarker(identifier: AccessibilityID.appShellSidebar)
                    }
            } content: {
                regularShellStageContent(availableWidth: contentWidth)
                    .overlay(alignment: .topLeading) {
                        AccessibilityMarker(identifier: AccessibilityID.appShellDetail)
                    }
            }
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.appShellSplitRoot)
            }
        }
    }

    @ViewBuilder
    private func regularShellStageContent(availableWidth: CGFloat) -> some View {
        switch router.destination {
        case .today:
            PremiumShellStage(tone: .accent) {
                todayRoot(
                    shellContext: .premiumRegularShell,
                    availableWidth: availableWidth
                )
            }
        case .archive:
            regularArchiveStage(availableWidth: availableWidth)
        case .saved:
            regularSavedStage(availableWidth: availableWidth)
        }
    }

    private var premiumSidebarRail: some View {
        PremiumShellStage(tone: .accent) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    SectionEyebrow(L10n.text("Space Briefing", default: "Space Briefing"), tone: .accent)

                    Text(L10n.text("app.shell.story_title", default: "NASA stories, framed with calm."))
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(AppTheme.inkPrimary(isDarkMode: true))

                    Text(L10n.text("app.shell.story_subtitle", default: "Today, archive, saved."))
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(AppTheme.inkSecondary(isDarkMode: true))
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(AppDestination.allCases) { destination in
                        splitDestinationRow(for: destination)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        shellStatusBadges
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        shellStatusBadges
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
    }

    @ViewBuilder
    private var shellStatusBadges: some View {
        MissionBadge(
            title: purchaseManager.hasPro
                ? L10n.text("Pro unlocked", default: "Pro unlocked")
                : L10n.text("Free edition", default: "Free edition"),
            systemImage: purchaseManager.hasPro ? "sparkles" : "lock.open",
            tone: purchaseManager.hasPro ? .accent : .neutral
        )

        MissionBadge(
            title: L10n.format(
                "app.shell.saved.count",
                default: "%d saved",
                fetcher.favorites.count
            ),
            systemImage: "bookmark.fill",
            tone: .favorite
        )

        MissionBadge(
            title: L10n.format(
                "app.shell.archive.count",
                default: "%d archive",
                fetcher.archiveItems.count
            ),
            systemImage: "books.vertical.fill",
            tone: .neutral
        )
    }

    private func todayRoot(
        shellContext: AppShellContext,
        availableWidth: CGFloat? = nil
    ) -> some View {
        NavigationStack {
            MainView(
                preferredAvailableWidth: availableWidth,
                openArchiveAction: { router.showArchive() },
                openSavedAction: { router.showSaved() }
            )
        }
        .environment(\.appShellContext, shellContext)
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

    @ViewBuilder
    private func archiveRoot(embedInRegularShell: Bool) -> some View {
        let archiveScreen = ArchiveScreenView(embedInRegularShell: embedInRegularShell)
            .environmentObject(fetcher)
            .environmentObject(router)
            .environment(\.appShellContext, embedInRegularShell ? .premiumRegularShell : .compactTabs)

        if embedInRegularShell {
            NavigationStack {
                archiveScreen
            }
            .userActivity(SpaceBriefingUserActivityType.archive, isActive: router.destination == .archive) { activity in
                activity.title = L10n.text("APOD Archive", default: "APOD Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .archive))
                activity.isEligibleForSearch = true
                activity.isEligibleForHandoff = true
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.webpageURL = AppDeepLink.publicWebURL(for: AppRoute(destination: .archive))
            }
        } else {
            archiveScreen
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
    }

    @ViewBuilder
    private func savedRoot(embedInRegularShell: Bool) -> some View {
        let savedScreen = SavedScreenView(embedInRegularShell: embedInRegularShell)
            .environmentObject(fetcher)
            .environmentObject(router)
            .environment(\.appShellContext, embedInRegularShell ? .premiumRegularShell : .compactTabs)

        if embedInRegularShell {
            NavigationStack {
                savedScreen
            }
            .userActivity(SpaceBriefingUserActivityType.saved, isActive: router.destination == .saved) { activity in
                activity.title = L10n.text("Saved Archive", default: "Saved Archive")
                activity.userInfo = AppDiscoveryCoordinator.userInfo(for: AppRoute(destination: .saved))
                activity.isEligibleForSearch = true
                activity.isEligibleForHandoff = true
                activity.isEligibleForPrediction = true
                activity.isEligibleForPublicIndexing = false
                activity.webpageURL = AppDeepLink.publicWebURL(for: AppRoute(destination: .saved))
            }
        } else {
            savedScreen
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
    }

    private func splitDestinationRow(for destination: AppDestination) -> some View {
        let isSelected = router.destination == destination

        return Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                updateDestination(destination)
            }
        } label: {
            AppShellSidebarRow(destination: destination, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.appShellSidebarDestinationIdentifier(for: destination))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedArchiveItem: NASA? {
        guard let selectedID = router.selectedArchiveItemID else { return nil }
        return fetcher.archiveItems.first(where: { $0.id == selectedID })
            ?? fetcher.favorites.first(where: { $0.id == selectedID })
    }

    private var fallbackArchiveItem: NASA? {
        fetcher.archiveItems.first
    }

    private var selectedSavedItem: NASA? {
        guard let selectedID = router.selectedSavedItemID else { return nil }
        return fetcher.favorites.first(where: { $0.id == selectedID })
    }

    private var fallbackSavedItem: NASA? {
        fetcher.favorites.first
    }

    private func regularArchiveStage(availableWidth: CGFloat) -> some View {
        let supportsDualPane = availableWidth >= AppTheme.Metrics.shellDualStageMinimumWidth
        let libraryWidth = min(
            max(availableWidth * 0.31, AppTheme.Metrics.shellLibraryPaneMinimumWidth),
            AppTheme.Metrics.shellLibraryPaneMaximumWidth
        )

        guard !fetcher.archiveItems.isEmpty else {
            return AnyView(
                PremiumShellStage {
                    archiveRoot(embedInRegularShell: true)
                }
            )
        }

        return AnyView(PremiumDualPaneStage(primaryWidth: supportsDualPane ? libraryWidth : nil) {
            if supportsDualPane || selectedArchiveItem == nil {
                PremiumShellStage {
                    archiveRoot(embedInRegularShell: true)
                }
            }
        } secondary: {
            if supportsDualPane || selectedArchiveItem != nil || fallbackArchiveItem != nil {
                PremiumShellStage(tone: .accent) {
                    archiveDetailContent(showsBackButton: !supportsDualPane)
                }
            }
        })
    }

    private func regularSavedStage(availableWidth: CGFloat) -> some View {
        let supportsDualPane = availableWidth >= AppTheme.Metrics.shellDualStageMinimumWidth
        let libraryWidth = min(
            max(availableWidth * 0.31, AppTheme.Metrics.shellLibraryPaneMinimumWidth),
            AppTheme.Metrics.shellLibraryPaneMaximumWidth
        )

        guard !fetcher.favorites.isEmpty else {
            return AnyView(
                PremiumShellStage(tone: .favorite) {
                    savedRoot(embedInRegularShell: true)
                }
            )
        }

        return AnyView(PremiumDualPaneStage(primaryWidth: supportsDualPane ? libraryWidth : nil) {
            if supportsDualPane || selectedSavedItem == nil {
                PremiumShellStage(tone: .favorite) {
                    savedRoot(embedInRegularShell: true)
                }
            }
        } secondary: {
            if supportsDualPane || selectedSavedItem != nil || fallbackSavedItem != nil {
                PremiumShellStage(tone: .favorite) {
                    savedDetailContent(showsBackButton: !supportsDualPane)
                }
            }
        })
    }

    @ViewBuilder
    private func archiveDetailContent(showsBackButton: Bool) -> some View {
        NavigationStack {
            if let resolvedArchiveItem = selectedArchiveItem ?? fallbackArchiveItem {
                APODRecordDetailView(nasa: resolvedArchiveItem, destination: .archive)
                    .toolbar {
                        if showsBackButton {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    clearArchiveSelection()
                                } label: {
                                    Label(L10n.text("Archive", default: "Archive"), systemImage: "chevron.left")
                                }
                            }
                        }
                    }
            } else {
                LibrarySelectionPlaceholderView(
                    eyebrow: L10n.text("Editorial Archive", default: "Editorial Archive"),
                    title: L10n.text("Select an APOD entry", default: "Select an APOD entry"),
                    message: L10n.text(
                        "Choose a story from the archive to read it with the full media, attribution, and source context.",
                        default: "Choose a story from the archive to read it with the full media, attribution, and source context."
                    ),
                    systemImage: "sparkles.rectangle.stack",
                    tone: .accent
                )
                .navigationTitle(L10n.text("Detail", default: "Detail"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private func savedDetailContent(showsBackButton: Bool) -> some View {
        NavigationStack {
            if let resolvedSavedItem = selectedSavedItem ?? fallbackSavedItem {
                APODRecordDetailView(nasa: resolvedSavedItem, destination: .saved)
                    .toolbar {
                        if showsBackButton {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    clearSavedSelection()
                                } label: {
                                    Label(L10n.text("Saved", default: "Saved"), systemImage: "chevron.left")
                                }
                            }
                        }
                    }
            } else {
                LibrarySelectionPlaceholderView(
                    eyebrow: L10n.text("Saved Archive", default: "Saved Archive"),
                    title: L10n.text("Select a saved APOD", default: "Select a saved APOD"),
                    message: L10n.text(
                        "Choose a saved story from the list to read it with the full editorial layout.",
                        default: "Choose a saved story from the list to read it with the full editorial layout."
                    ),
                    systemImage: "bookmark.circle",
                    tone: .favorite
                )
                .navigationTitle(L10n.text("Detail", default: "Detail"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var destinationBinding: Binding<AppDestination> {
        Binding(
            get: { router.destination },
            set: { updateDestination($0) }
        )
    }

    private func updateDestination(_ destination: AppDestination) {
        router.destination = destination
        persistDestination(destination)
    }

    private func restorePersistedDestinationIfNeeded() {
        guard router.destination == .today else {
            persistDestination(router.destination)
            return
        }

        guard let persistedDestination = AppDestination(rawValue: persistedDestinationRawValue) else {
            persistDestination(.today)
            return
        }

        router.destination = persistedDestination
    }

    private func persistDestination(_ destination: AppDestination) {
        persistedDestinationRawValue = destination.rawValue

        // Flush the shell selection explicitly so relaunches and UI tests can restore the last
        // active destination even when the app is terminated immediately after a tab/sidebar change.
        UserDefaults.standard.set(destination.rawValue, forKey: StorageKey.destination)
        UserDefaults.standard.synchronize()
    }

    private func clearArchiveSelection() {
        router.selectedArchiveItemID = nil
    }

    private func clearSavedSelection() {
        router.selectedSavedItemID = nil
    }

    private func ensureRegularShellSelectionIfNeeded() {
        guard usesSplitShell else { return }

        switch router.destination {
        case .today:
            break
        case .archive:
            guard let firstArchiveItem = fetcher.archiveItems.first else {
                router.selectedArchiveItemID = nil
                return
            }

            if let selectedID = router.selectedArchiveItemID,
               fetcher.archiveItems.contains(where: { $0.id == selectedID }) {
                return
            }

            router.selectedArchiveItemID = firstArchiveItem.id
            fetcher.selectArchivedItem(firstArchiveItem)
        case .saved:
            guard let firstSavedItem = fetcher.favorites.first else {
                router.selectedSavedItemID = nil
                return
            }

            if let selectedID = router.selectedSavedItemID,
               fetcher.favorites.contains(where: { $0.id == selectedID }) {
                return
            }

            router.selectedSavedItemID = firstSavedItem.id
            fetcher.selectFavorite(firstSavedItem)
        }
    }
    private func trackArchiveVisitIfNeeded(for destination: AppDestination) {
        guard lastTrackedDestination != destination else { return }
        lastTrackedDestination = destination

        guard destination == .archive else { return }
        purchaseManager.registerArchiveVisitIfNeeded()
    }
}

private struct AppShellSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let destination: AppDestination
    let isSelected: Bool

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? AppTheme.accentColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.28 : 0.16)
                            : Color.white.opacity(isDarkMode ? 0.08 : 0.42)
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: destination.systemImage)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.Palette.accentHighlight
                            : AppTheme.inkPrimary(isDarkMode: isDarkMode)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.localizedTitle)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(AppTheme.inkPrimary(isDarkMode: isDarkMode))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "arrow.right.circle.fill" : "circle")
                .foregroundStyle(
                    isSelected
                        ? AppTheme.Palette.accentHighlight
                        : AppTheme.panelStroke(isDarkMode: isDarkMode)
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isSelected
                        ? AppTheme.accentColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.24 : 0.14)
                        : Color.white.opacity(isDarkMode ? 0.06 : 0.32)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? AppTheme.Palette.accentHighlight.opacity(isDarkMode ? 0.6 : 0.38)
                        : AppTheme.panelStroke(isDarkMode: isDarkMode),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .shadow(
            color: isSelected
                ? AppTheme.Palette.accentHighlight.opacity(isDarkMode ? 0.16 : 0.08)
                : .clear,
            radius: 16,
            y: 10
        )
        .contentShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
