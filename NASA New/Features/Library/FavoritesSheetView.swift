import Combine
import SwiftUI

struct APODLibraryDisplayItem: Identifiable {
    let item: NASA
    let isSaved: Bool
    let offlineMediaState: APODOfflineMediaItemState
    let title: String
    let dateText: String
    let creditLine: String

    var id: String { item.id }

    init(item: NASA, isSaved: Bool, offlineMedia: APODOfflineMediaAsset?, locale: Locale) {
        self.item = item
        self.isSaved = isSaved
        offlineMediaState = APODOfflineMediaItemState(
            mediaType: item.mediaType,
            asset: offlineMedia,
            isSaved: isSaved
        )
        title = item.title ?? L10n.text("Untitled", default: "Untitled")
        dateText = APODDateDisplayPolicy.displayString(for: item.date, locale: locale)
        creditLine = APODAttributionPolicy.creditLine(for: item)
    }

    var offlineStatusPresentation: APODOfflineMediaStatusPresentation? {
        offlineMediaState.statusPresentation
    }

    var mediaBadgeTitle: String { item.mediaType.localizedDisplayName }

    var mediaBadgeSystemImage: String {
        item.mediaType == .video ? "play.rectangle.fill" : "photo.fill"
    }

    var archivePolicyItem: ArchiveLibraryPolicy.Item {
        ArchiveLibraryPolicy.Item(
            id: id,
            date: item.date,
            title: title,
            creditLine: creditLine,
            mediaKind: .init(item.mediaType),
            isSaved: isSaved
        )
    }

    var savedPolicyItem: SavedLibraryPolicy.Item {
        return SavedLibraryPolicy.Item(
            id: id,
            date: item.date,
            title: title,
            creditLine: creditLine,
            storageState: offlineMediaState.savedLibraryStorageState
        )
    }
}

struct ArchiveSection: Identifiable {
    let id: String
    let title: String
    let itemIDs: [String]
}

struct SavedScreenView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    let embedInRegularShell: Bool

    @AppStorage("saved.presentation.mode") private var savedPresentationModeRawValue = ArchivePresentationMode.list.rawValue
    @AppStorage("saved.filter") private var savedFilterRawValue = SavedFilter.all.rawValue
    @State private var pushedFavorite: NASA?
    @State private var selectedFavoriteID: String?
    @State private var searchQuery = ""
    @State private var savedDisplayItems = [APODLibraryDisplayItem]()
    @State private var filteredFavoriteItems = [APODLibraryDisplayItem]()

    init(embedInRegularShell: Bool = false) {
        self.embedInRegularShell = embedInRegularShell
    }

    private var usesSplitLayout: Bool {
        LibraryLayoutPolicy.usesSplitLayout(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell
        )
    }

    private var supportsGridPresentation: Bool {
        LibraryLayoutPolicy.supportsGridPresentation(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell
        )
    }

    private var savedPresentationMode: ArchivePresentationMode {
        LibraryLayoutPolicy.resolvedPresentationMode(
            from: savedPresentationModeRawValue,
            fallback: .list
        )
    }

    private var usesGridPresentation: Bool {
        LibraryLayoutPolicy.usesGridPresentation(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell,
            presentationMode: savedPresentationMode
        )
    }

    private var savedFilter: SavedFilter {
        SavedFilter(rawValue: savedFilterRawValue) ?? .all
    }

    private var selectedFavorite: NASA? {
        let preferredID = selectedFavoriteID ?? router.selectedSavedItemID
        return filteredFavoriteItems.first(where: { $0.id == preferredID })?.item
            ?? savedDisplayItems.first(where: { $0.id == preferredID })?.item
    }

    private var savedResultsSummary: String {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            if savedFilter != .all {
                return L10n.format(
                    "saved.search.summary.filtered_by_mode",
                    default: "Showing %d saved stories in %@.",
                    filteredFavoriteItems.count,
                    savedFilter.localizedTitle
                )
            }

            return L10n.format(
                "saved.search.summary.default",
                default: "Search %d saved APOD stories by title, date, or credit line.",
                savedDisplayItems.count
            )
        }

        return L10n.format(
            "saved.search.summary.filtered",
            default: "Showing %d of %d saved stories for \"%@\".",
            filteredFavoriteItems.count,
            savedDisplayItems.count,
            trimmedQuery
        )
    }

    var body: some View {
        Group {
            if embedInRegularShell {
                savedCollectionContent(
                    selectedItemID: selectedFavoriteID ?? router.selectedSavedItemID,
                    selectionAction: selectFavorite
                )
            } else if usesSplitLayout {
                NavigationSplitView {
                    savedCollectionContent(
                        selectedItemID: selectedFavoriteID ?? router.selectedSavedItemID,
                        selectionAction: selectFavorite
                    )
                } detail: {
                    if let selectedFavorite {
                        APODRecordDetailView(nasa: selectedFavorite, destination: .saved)
                    } else {
                        savedSelectionPlaceholder
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    savedCollectionContent(
                        selectedItemID: nil,
                        selectionAction: { item in
                            selectFavorite(item)
                            pushedFavorite = item
                        }
                    )
                    .navigationDestination(
                        isPresented: Binding(
                            get: { pushedFavorite != nil },
                            set: { isPresented in
                                if !isPresented {
                                    pushedFavorite = nil
                                }
                            }
                        )
                    ) {
                        if let pushedFavorite {
                            APODRecordDetailView(nasa: pushedFavorite, destination: .saved)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.favoritesSheetRoot)
        }
        .task {
            rebuildSavedLibrarySnapshot()
            syncSavedSelectionFromRouter()
        }
        .onReceive(fetcher.$favorites.combineLatest(fetcher.$offlineMediaAssetsByID)) { _, _ in
            rebuildSavedLibrarySnapshot()
        }
        .onChange(of: router.selectedSavedItemID) { _ in
            syncSavedSelectionFromRouter()
        }
        .onChange(of: searchQuery) { _ in
            rebuildSavedFiltering()
        }
        .onChange(of: savedFilterRawValue) { _ in
            rebuildSavedFiltering()
        }
        .onChange(of: locale.identifier) { _ in
            rebuildSavedLibrarySnapshot()
        }
        .onChange(of: fetcher.favorites.map(\.id)) { _ in
            if let selectedFavoriteID,
               !fetcher.favorites.contains(where: { $0.id == selectedFavoriteID }) {
                self.selectedFavoriteID = nil
            }
        }
    }

    @ViewBuilder
    private func savedCollectionContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        AppScreenSurface(title: L10n.text("Favorites", default: "Favorites")) {
            if fetcher.favorites.isEmpty {
                favoritesEmptyState
            } else if usesGridPresentation {
                savedGridContent(selectionAction: selectionAction)
            } else {
                savedListContent(
                    selectedItemID: selectedItemID,
                    selectionAction: selectionAction
                )
            }
        }
    }

    private func savedListContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        List {
            savedHeaderPanels
                .libraryHeaderRowStyle()

            if filteredFavoriteItems.isEmpty {
                searchEmptyState
                    .libraryStateRowStyle()
            } else {
                ForEach(filteredFavoriteItems) { displayItem in
                    libraryRow(
                        displayItem,
                        isSelected: displayItem.id == selectedItemID,
                        selectionAction: selectionAction
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            fetcher.removeFavorite(displayItem.item)
                        } label: {
                            Label(L10n.text("Delete", default: "Delete"), systemImage: "trash")
                        }
                        .accessibilityIdentifier(AccessibilityID.favoriteDeleteActionIdentifier(for: displayItem.item))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var savedHeaderPanels: some View {
        LibraryPanelDeck {
            if embedInRegularShell {
                savedMissionControlPanel
            } else {
                savedOverviewPanel
                savedControlsPanel
            }
        }
    }

    private var savedMissionControlPanel: some View {
        let offlineLibraryState = fetcher.offlineMediaLibraryState

        return MissionSupportPanel(
            eyebrow: L10n.text("saved.library.eyebrow", default: "Saved Library"),
            title: L10n.format(
                "saved.summary.count",
                default: "%d saved APOD stories ready to revisit",
                fetcher.favorites.count
            ),
            summary: savedResultsSummary,
            tone: .favorite,
            padding: AppTheme.Spacing.lg
        ) {
            if offlineLibraryState.showsSavedStatusBadges {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        savedStatusBadges(offlineLibraryState)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        savedStatusBadges(offlineLibraryState)
                    }
                }
            }

            MissionSearchField(
                text: $searchQuery,
                placeholder: L10n.text("Search favorites", default: "Search favorites"),
                accessibilityIdentifier: AccessibilityID.favoritesSearchField
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    savedFilterPicker
                    Spacer(minLength: 0)
                    if supportsGridPresentation {
                        savedLayoutPicker
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    savedFilterPicker
                    if supportsGridPresentation {
                        savedLayoutPicker
                    }
                }
            }
        }
    }

    private var savedOverviewPanel: some View {
        let offlineLibraryState = fetcher.offlineMediaLibraryState

        return MissionSupportPanel(
            eyebrow: L10n.text("Saved Archive", default: "Saved Archive"),
            title: L10n.format(
                "saved.summary.count",
                default: "%d saved APOD stories ready to revisit",
                fetcher.favorites.count
            ),
            summary: L10n.text(
                "saved.summary.body",
                default: "Saved APODs always keep their story and credits on device. Media badges show whether the full image or video is offline, preview-only, or still opens from the original source."
            ),
            tone: .favorite,
            padding: AppTheme.Spacing.lg
        ) {
            if offlineLibraryState.showsSavedStatusBadges {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        savedStatusBadges(offlineLibraryState)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        savedStatusBadges(offlineLibraryState)
                    }
                }
            }
        }
    }

    private var savedControlsPanel: some View {
        LibraryBrowserPanel(
            eyebrow: L10n.text("Saved Browser", default: "Saved Browser"),
            summary: savedResultsSummary,
            tone: .neutral,
            searchText: $searchQuery,
            searchPlaceholder: L10n.text("Search favorites", default: "Search favorites"),
            searchAccessibilityIdentifier: AccessibilityID.favoritesSearchField
        ) {
            savedFilterPicker
        } layoutControl: {
            if supportsGridPresentation {
                savedLayoutPicker
            }
        }
    }

    private var savedFilterPicker: some View {
        Picker(
            L10n.text("Saved filter", default: "Saved filter"),
            selection: Binding(
                get: { savedFilter },
                set: { savedFilterRawValue = $0.rawValue }
            )
        ) {
            ForEach(SavedFilter.allCases) { filter in
                Text(filter.localizedTitle).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var savedLayoutPicker: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            savedLayoutButton(for: .grid, identifier: AccessibilityID.savedGridLayoutButton)
            savedLayoutButton(for: .list, identifier: AccessibilityID.savedListLayoutButton)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Saved layout", default: "Saved layout"))
    }

    private func savedLayoutButton(for mode: ArchivePresentationMode, identifier: String) -> some View {
        Button {
            savedPresentationModeRawValue = mode.rawValue
        } label: {
            Label(mode.localizedTitle, systemImage: mode.systemImage)
                .font(AppTheme.Typography.buttonLabel)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            savedPresentationMode == mode
                                ? AppTheme.Palette.favorite.opacity(0.22)
                                : Color.secondary.opacity(0.12)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(savedPresentationMode == mode ? .isSelected : [])
    }

    @ViewBuilder
    private func savedStatusBadges(_ offlineLibraryState: APODOfflineMediaLibraryState) -> some View {
        ForEach(offlineLibraryState.savedStatusBadges) { badge in
            MissionBadge(
                title: badge.title,
                systemImage: badge.systemImage,
                tone: badge.tone
            )
        }
    }

    private func savedGridContent(selectionAction: @escaping (NASA) -> Void) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    savedHeaderPanels

                    if filteredFavoriteItems.isEmpty {
                        searchEmptyState
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    } else {
                        LazyVGrid(columns: savedGridColumns, spacing: AppTheme.Spacing.md) {
                            ForEach(filteredFavoriteItems) { displayItem in
                                ArchiveGridCard(
                                    displayItem: displayItem,
                                    isSelected: displayItem.id == selectedFavoriteID,
                                    isLocked: false,
                                    action: { selectionAction(displayItem.item) }
                                )
                                .id(displayItem.id)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                }
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
            .onChange(of: selectedFavoriteID) { newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var savedGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 220, maximum: 280), spacing: AppTheme.Spacing.md, alignment: .top)
        ]
    }

    private func selectFavorite(_ item: NASA) {
        selectedFavoriteID = item.id
        router.selectedSavedItemID = item.id
        fetcher.selectFavorite(item)
    }

    private func syncSavedSelectionFromRouter() {
        guard let selectedID = router.selectedSavedItemID else {
            selectedFavoriteID = nil
            return
        }
        selectedFavoriteID = selectedID
        if let favorite = fetcher.favorites.first(where: { $0.id == selectedID }) {
            fetcher.selectFavorite(favorite)
        }
    }

    private func rebuildSavedLibrarySnapshot() {
        savedDisplayItems = fetcher.favorites.map {
            APODLibraryDisplayItem(
                item: $0,
                isSaved: true,
                offlineMedia: fetcher.offlineMediaAsset(for: $0),
                locale: locale
            )
        }
        rebuildSavedFiltering()
    }

    private func rebuildSavedFiltering() {
        let savedItemsByID = Dictionary(uniqueKeysWithValues: savedDisplayItems.map { ($0.id, $0) })
        let filteredIDs = SavedLibraryPolicy.filteredItemIDs(
            items: savedDisplayItems.map(\.savedPolicyItem),
            filter: savedFilter,
            searchQuery: searchQuery
        )

        filteredFavoriteItems = filteredIDs.compactMap { savedItemsByID[$0] }
    }

    private var favoritesEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("Saved Archive", default: "Saved Archive"),
            title: L10n.text("No favorites saved yet", default: "No favorites saved yet"),
            message: L10n.text(
                "Bookmark an APOD from the main briefing to build your personal archive.",
                default: "Bookmark an APOD from the main briefing to build your personal archive."
            ),
            systemImage: "heart.slash",
            tone: .favorite
        )
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.favoritesEmptyState)
    }

    private var searchEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("Favorites Search", default: "Favorites Search"),
            title: L10n.text("No matching favorites", default: "No matching favorites"),
            message: L10n.text(
                "Try a different title or date to find a saved APOD.",
                default: "Try a different title or date to find a saved APOD."
            ),
            systemImage: "magnifyingglass.circle",
            tone: .neutral,
            minHeight: 180
        )
    }

    private var savedSelectionPlaceholder: some View {
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
    }
}

struct ArchiveScreenView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    let embedInRegularShell: Bool

    @AppStorage("archive.presentation.mode") private var archivePresentationModeRawValue = ArchivePresentationMode.grid.rawValue
    @AppStorage("archive.filter") private var archiveFilterRawValue = ArchiveFilter.all.rawValue
    @State private var pushedArchiveItem: NASA?
    @State private var selectedArchiveItemID: String?
    @State private var searchQuery = ""
    @State private var resolvedArchiveSearchQuery = ""
    @State private var archiveJumpDate = Date()
    @State private var archiveDisplayItemsByID = [String: APODLibraryDisplayItem]()
    @State private var archivePolicyItems = [ArchiveLibraryPolicy.Item]()
    @State private var filteredArchiveItemIDs = [String]()
    @State private var archiveSections = [ArchiveSection]()
    @State private var lockedArchiveItemIDs = Set<String>()
    @State private var archiveSearchTask: Task<Void, Never>?

    init(embedInRegularShell: Bool = false) {
        self.embedInRegularShell = embedInRegularShell
    }

    private var usesSplitLayout: Bool {
        LibraryLayoutPolicy.usesSplitLayout(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell
        )
    }

    private var archivePresentationMode: ArchivePresentationMode {
        LibraryLayoutPolicy.resolvedPresentationMode(
            from: archivePresentationModeRawValue,
            fallback: .grid
        )
    }

    private var archiveFilter: ArchiveFilter {
        ArchiveFilter(rawValue: archiveFilterRawValue) ?? .all
    }

    private var supportsGridPresentation: Bool {
        LibraryLayoutPolicy.supportsGridPresentation(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell
        )
    }

    private var usesGridPresentation: Bool {
        LibraryLayoutPolicy.usesGridPresentation(
            isRegularWidth: horizontalSizeClass == .regular,
            embedInRegularShell: embedInRegularShell,
            presentationMode: archivePresentationMode
        )
    }

    private var selectedArchiveItem: NASA? {
        guard let preferredID = selectedArchiveItemID ?? router.selectedArchiveItemID else {
            return nil
        }

        return archiveDisplayItemsByID[preferredID]?.item
    }

    private var archiveSummaryTitle: String {
        L10n.format(
            "archive.summary.count",
            default: "%d APOD entries ready to browse",
            fetcher.archiveItems.count
        )
    }

    private var archiveSummaryMessage: String {
        if let oldest = fetcher.archiveItems.last?.date,
           let newest = fetcher.archiveItems.first?.date {
            return L10n.format(
                "archive.summary.range",
                default: "Browse from %@ back to %@, then load older ranges on demand.",
                APODDateDisplayPolicy.displayString(for: newest, locale: locale),
                APODDateDisplayPolicy.displayString(for: oldest, locale: locale)
            )
        }

        return L10n.text(
            "archive.summary.empty_range",
            default: "Build a browsable APOD archive and jump straight into any saved day."
        )
    }

    private var archiveControlsSummary: String {
        let trimmedQuery = resolvedArchiveSearchQuery

        if !trimmedQuery.isEmpty {
            return L10n.format(
                "archive.controls.summary.search",
                default: "Showing %d results for \"%@\".",
                filteredArchiveItemIDs.count,
                trimmedQuery
            )
        }

        if archiveFilter != .all {
            return L10n.format(
                "archive.controls.summary.filter",
                default: "Showing %d entries in %@.",
                filteredArchiveItemIDs.count,
                archiveFilter.localizedTitle
            )
        }

        return L10n.format(
            "archive.controls.summary.default",
            default: "Search %d archived APOD entries by title, date, or credit line.",
            filteredArchiveItemIDs.count
        )
    }

    private var archiveJumpSummary: String {
        L10n.text(
            "archive.jump.summary",
            default: "Choose any APOD day and the archive will focus that editorial entry, loading it first if needed."
        )
    }

    private var archiveJumpButtonTitle: String {
        (fetcher.isFetchingArchive || fetcher.isFetching)
            ? L10n.text("Loading Day…", default: "Loading Day…")
            : L10n.text("Open Day", default: "Open Day")
    }

    var body: some View {
        Group {
            if embedInRegularShell {
                archiveCollectionContent(
                    selectedItemID: selectedArchiveItemID ?? router.selectedArchiveItemID,
                    selectionAction: { item in
                        handleArchiveSelection(item)
                    }
                )
            } else if usesSplitLayout {
                NavigationSplitView {
                    archiveCollectionContent(
                        selectedItemID: selectedArchiveItemID ?? router.selectedArchiveItemID,
                        selectionAction: { item in
                            handleArchiveSelection(item)
                        }
                    )
                } detail: {
                    if let selectedArchiveItem {
                        APODRecordDetailView(nasa: selectedArchiveItem, destination: .archive)
                    } else {
                        archiveSelectionPlaceholder
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    archiveCollectionContent(
                        selectedItemID: nil,
                        selectionAction: { item in
                            handleArchiveSelection(item, compactNavigation: true)
                        }
                    )
                    .navigationDestination(
                        isPresented: Binding(
                            get: { pushedArchiveItem != nil },
                            set: { isPresented in
                                if !isPresented {
                                    pushedArchiveItem = nil
                                }
                            }
                        )
                    ) {
                        if let pushedArchiveItem {
                            APODRecordDetailView(nasa: pushedArchiveItem, destination: .archive)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            AccessibilityMarker(identifier: AccessibilityID.archiveSheetRoot)
        }
        .task {
            resolvedArchiveSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            rebuildArchiveLibrarySnapshot()
            if purchaseManager.hasPro {
                fetcher.prefetchArchiveIfNeeded()
            }
            syncArchiveSelectionFromRouter()
            syncArchiveJumpDate()
        }
        .onReceive(fetcher.$archiveItemsByNewestFirst.combineLatest(fetcher.$favorites, fetcher.$offlineMediaAssetsByID)) { _, _, _ in
            rebuildArchiveLibrarySnapshot()
        }
        .onChange(of: router.selectedArchiveItemID) { _ in
            syncArchiveSelectionFromRouter()
            syncArchiveJumpDate()
        }
        .onChange(of: selectedArchiveItemID) { _ in
            syncArchiveJumpDate()
        }
        .onChange(of: searchQuery) { _ in
            scheduleArchiveFiltering()
        }
        .onChange(of: archiveFilterRawValue) { _ in
            rebuildArchiveFiltering()
        }
        .onChange(of: locale.identifier) { _ in
            rebuildArchiveLibrarySnapshot()
        }
        .onChange(of: purchaseManager.hasPro) { hasPro in
            rebuildArchiveAccessState()
            if hasPro {
                fetcher.prefetchArchiveIfNeeded()
            }
        }
        .onDisappear {
            archiveSearchTask?.cancel()
            archiveSearchTask = nil
        }
    }

    @ViewBuilder
    private func archiveCollectionContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        AppScreenSurface(title: L10n.text("Archive", default: "Archive")) {
            if fetcher.archiveItems.isEmpty {
                archiveEmptyContent
            } else if usesGridPresentation {
                archiveGridContent(selectionAction: selectionAction)
            } else {
                archiveListContent(selectedItemID: selectedItemID, selectionAction: selectionAction)
            }
        }
    }

    private var archiveHeaderPanels: some View {
        LibraryPanelDeck {
            if embedInRegularShell {
                archiveMissionControlPanel
            } else {
                archiveOverviewPanel
                archiveControlsPanel
                archiveJumpPanel
            }
        }
    }

    private var archiveMissionControlPanel: some View {
        MissionSupportPanel(
            eyebrow: L10n.text("archive.browser.eyebrow", default: "Archive Browser"),
            title: archiveSummaryTitle,
            summary: archiveControlsSummary,
            tone: .accent,
            padding: AppTheme.Spacing.lg
        ) {
            MissionSearchField(
                text: $searchQuery,
                placeholder: L10n.text("Search archive", default: "Search archive"),
                accessibilityIdentifier: AccessibilityID.archiveSearchField
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    archiveFilterPicker
                    Spacer(minLength: 0)
                    if supportsGridPresentation {
                        archiveLayoutPicker
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Metrics.libraryControlsSpacing) {
                    archiveFilterPicker
                    if supportsGridPresentation {
                        archiveLayoutPicker
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(L10n.text("Jump to APOD date", default: "Jump to APOD date"))
                    .font(AppTheme.Typography.sectionTitle)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                        archiveJumpDatePicker
                        archiveJumpButton(compactNavigation: !usesSplitLayout)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        archiveJumpDatePicker
                        archiveJumpButton(compactNavigation: !usesSplitLayout)
                    }
                }
            }
        }
    }

    private var archiveOverviewPanel: some View {
        MissionSupportPanel(
            eyebrow: L10n.text("Editorial Archive", default: "Editorial Archive"),
            title: archiveSummaryTitle,
            summary: archiveSummaryMessage,
            tone: .accent,
            padding: AppTheme.Spacing.lg
        ) {
            EmptyView()
        }
    }

    private var archiveControlsPanel: some View {
        LibraryBrowserPanel(
            eyebrow: L10n.text("Browse & Filter", default: "Browse & Filter"),
            summary: archiveControlsSummary,
            tone: .neutral,
            searchText: $searchQuery,
            searchPlaceholder: L10n.text("Search archive", default: "Search archive"),
            searchAccessibilityIdentifier: AccessibilityID.archiveSearchField
        ) {
            archiveFilterPicker
        } layoutControl: {
            if supportsGridPresentation {
                archiveLayoutPicker
            }
        }
    }

    private var archiveEmptyContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                archiveHeaderPanels
                archiveEmptyState
                    .padding(.horizontal, AppTheme.Spacing.lg)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }

    private func selectArchiveItem(_ item: NASA) {
        selectedArchiveItemID = item.id
        router.selectedArchiveItemID = item.id
        fetcher.selectArchivedItem(item)
        if let itemDate = fetcher.date(from: item.date) {
            archiveJumpDate = itemDate
        }
    }

    private func handleArchiveSelection(_ item: NASA, compactNavigation: Bool = false) {
        guard canOpenArchiveItem(item) else {
            purchaseManager.presentPaywall(trigger: .archiveLockedItem, feature: .fullArchive)
            return
        }

        selectArchiveItem(item)
        if compactNavigation {
            pushedArchiveItem = item
        }
    }

    private func syncArchiveSelectionFromRouter() {
        guard let selectedID = router.selectedArchiveItemID else {
            selectedArchiveItemID = nil
            return
        }
        selectedArchiveItemID = selectedID
        if let archiveItem = archiveDisplayItemsByID[selectedID]?.item {
            fetcher.selectArchivedItem(archiveItem)
        }
    }

    private func syncArchiveJumpDate() {
        if let selectedArchiveItem,
           let selectedDate = fetcher.date(from: selectedArchiveItem.date) {
            archiveJumpDate = selectedDate
            return
        }

        if let currentDate = fetcher.date(from: fetcher.currentNasa.date) {
            archiveJumpDate = currentDate
            return
        }

        archiveJumpDate = fetcher.maximumSelectableDate
    }

    private func rebuildArchiveLibrarySnapshot() {
        let favoriteIDs = Set(fetcher.favorites.map(\.id))
        let archiveDisplayItems = fetcher.archiveItems.map { item in
            APODLibraryDisplayItem(
                item: item,
                isSaved: favoriteIDs.contains(item.id),
                offlineMedia: fetcher.offlineMediaAsset(for: item),
                locale: locale
            )
        }

        archiveDisplayItemsByID = Dictionary(uniqueKeysWithValues: archiveDisplayItems.map { ($0.id, $0) })
        archivePolicyItems = archiveDisplayItems.map(\.archivePolicyItem)
        rebuildArchiveAccessState()
        rebuildArchiveFiltering()
    }

    private func rebuildArchiveFiltering() {
        let resolution = ArchiveLibraryPolicy.resolve(
            items: archivePolicyItems,
            filter: archiveFilter,
            searchQuery: resolvedArchiveSearchQuery,
            locale: locale
        )

        filteredArchiveItemIDs = resolution.filteredItemIDs
        archiveSections = resolution.sections.map { section in
            ArchiveSection(
                id: section.id,
                title: section.title,
                itemIDs: section.itemIDs
            )
        }
    }

    private func rebuildArchiveAccessState() {
        guard !purchaseManager.hasPro else {
            lockedArchiveItemIDs = []
            return
        }

        let earliestFreeArchiveDate = fetcher.apodDateString(
            from: PremiumAccessPolicy.earliestFreeArchiveDate(
                referenceDate: fetcher.maximumSelectableDate,
                calendar: fetcher.calendar
            )
        )

        lockedArchiveItemIDs = Set(
            archivePolicyItems.compactMap { item in
                guard let itemDate = item.date, itemDate < earliestFreeArchiveDate else {
                    return nil
                }

                return item.id
            }
        )
    }

    private func scheduleArchiveFiltering() {
        archiveSearchTask?.cancel()

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery != resolvedArchiveSearchQuery else { return }

        guard !trimmedQuery.isEmpty else {
            resolvedArchiveSearchQuery = ""
            rebuildArchiveFiltering()
            return
        }

        archiveSearchTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                resolvedArchiveSearchQuery = trimmedQuery
                rebuildArchiveFiltering()
            }
        }
    }

    private func jumpToArchiveDate(compactNavigation: Bool) {
        let targetDate = archiveJumpDate
        guard canOpenArchiveDate(targetDate) else {
            purchaseManager.presentPaywall(trigger: .archiveJump, feature: .fullArchive)
            return
        }

        Task {
            guard let archiveItem = await fetcher.archiveItem(for: targetDate) else { return }
            selectArchiveItem(archiveItem)
            if compactNavigation {
                pushedArchiveItem = archiveItem
            }
        }
    }

    private func canOpenArchiveItem(_ item: NASA) -> Bool {
        !lockedArchiveItemIDs.contains(item.id)
    }

    private func canOpenArchiveDate(_ date: Date) -> Bool {
        purchaseManager.canAccessArchive(
            date: fetcher.normalizedDate(date),
            referenceDate: fetcher.maximumSelectableDate,
            calendar: fetcher.calendar
        )
    }

    private func isLockedArchiveItem(_ displayItem: APODLibraryDisplayItem) -> Bool {
        lockedArchiveItemIDs.contains(displayItem.id)
    }

    private func toggleArchiveFavorite(_ item: NASA) {
        if fetcher.isFavorite(item) {
            fetcher.toggleFavorite(item)
            return
        }

        guard canOpenArchiveItem(item) else {
            purchaseManager.presentPaywall(trigger: .archiveLockedItem, feature: .fullArchive)
            return
        }

        guard purchaseManager.canAddFavorite(
            currentCount: fetcher.favorites.count,
            isAlreadyFavorite: false
        ) else {
            purchaseManager.presentPaywall(trigger: .favoriteLimit, feature: .unlimitedFavorites)
            return
        }

        fetcher.toggleFavorite(item)
    }

    private var archiveFilterPicker: some View {
        Picker(
            L10n.text("Archive filter", default: "Archive filter"),
            selection: Binding(
                get: { archiveFilter },
                set: { archiveFilterRawValue = $0.rawValue }
            )
        ) {
            ForEach(ArchiveFilter.allCases) { filter in
                Text(filter.localizedTitle).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var archiveLayoutPicker: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            archiveLayoutButton(for: .grid, identifier: AccessibilityID.archiveGridLayoutButton)
            archiveLayoutButton(for: .list, identifier: AccessibilityID.archiveListLayoutButton)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Archive layout", default: "Archive layout"))
    }

    private func archiveLayoutButton(for mode: ArchivePresentationMode, identifier: String) -> some View {
        Button {
            archivePresentationModeRawValue = mode.rawValue
        } label: {
            Label(mode.localizedTitle, systemImage: mode.systemImage)
                .font(AppTheme.Typography.buttonLabel)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            archivePresentationMode == mode
                                ? AppTheme.Palette.accentLight.opacity(0.22)
                                : Color.secondary.opacity(0.12)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(archivePresentationMode == mode ? .isSelected : [])
    }

    private var archiveJumpPanel: some View {
        MissionSupportPanel(
            eyebrow: L10n.text("Timeline Focus", default: "Timeline Focus"),
            title: L10n.text("Jump to APOD date", default: "Jump to APOD date"),
            summary: archiveJumpSummary,
            tone: .neutral
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                    archiveJumpDatePicker
                    archiveJumpButton(compactNavigation: !usesSplitLayout)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    archiveJumpDatePicker
                    archiveJumpButton(compactNavigation: !usesSplitLayout)
                }
            }
        }
    }

    private var archiveJumpDatePicker: some View {
        DatePicker(
            L10n.text("Jump to APOD date", default: "Jump to APOD date"),
            selection: $archiveJumpDate,
            in: fetcher.minimumSelectableDate...fetcher.maximumSelectableDate,
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .accessibilityLabel(L10n.text("Jump to APOD date", default: "Jump to APOD date"))
    }

    private func archiveJumpButton(compactNavigation: Bool) -> some View {
        Button {
            jumpToArchiveDate(compactNavigation: compactNavigation)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                if fetcher.isFetchingArchive || fetcher.isFetching {
                    ProgressView()
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .accessibilityHidden(true)
                }
                Text(archiveJumpButtonTitle)
                    .font(AppTheme.Typography.buttonLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.Palette.accentHighlight)
        .disabled(fetcher.isFetchingArchive || fetcher.isFetching)
        .accessibilityIdentifier(AccessibilityID.archiveJumpDateButton)
        .accessibilityHint(
            L10n.text(
                "Loads the selected APOD day into the archive browser.",
                default: "Loads the selected APOD day into the archive browser."
            )
        )
    }

    private func archiveListContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        List {
            archiveHeaderPanels
                .libraryHeaderRowStyle()

            if archiveSections.isEmpty {
                archiveSearchEmptyState
                    .libraryStateRowStyle()
            } else {
                ForEach(archiveSections) { section in
                    Section(section.title) {
                        ForEach(section.itemIDs, id: \.self) { itemID in
                            if let displayItem = archiveDisplayItemsByID[itemID] {
                                libraryRow(
                                    displayItem,
                                    isSelected: displayItem.id == selectedItemID,
                                    isLocked: isLockedArchiveItem(displayItem),
                                    selectionAction: selectionAction
                                )
                                .swipeActions(edge: .trailing) {
                                    let favoriteActionTitle = displayItem.isSaved
                                        ? L10n.text("Remove Favorite", default: "Remove Favorite")
                                        : L10n.text("Save Favorite", default: "Save Favorite")
                                    let favoriteActionSystemImage = displayItem.isSaved ? "bookmark.slash" : "bookmark"

                                    Button {
                                        toggleArchiveFavorite(displayItem.item)
                                    } label: {
                                        Label(favoriteActionTitle, systemImage: favoriteActionSystemImage)
                                    }
                                    .tint(displayItem.isSaved ? .gray : AppTheme.Palette.favorite)
                                }
                            }
                        }
                    }
                }

                if let loadError = fetcher.archiveError {
                    Section {
                        MissionStateCard(
                            eyebrow: L10n.text("Archive Sync", default: "Archive Sync"),
                            title: L10n.text("Could not load older APOD entries", default: "Could not load older APOD entries"),
                            message: loadError.localizedDescription,
                            systemImage: "exclamationmark.triangle",
                            tone: .warning,
                            minHeight: 180
                        ) {
                            Button(L10n.text("Retry", default: "Retry")) {
                                fetcher.loadOlderArchiveBatch()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .libraryStateRowStyle()
                    }
                }

                if fetcher.canLoadMoreArchiveHistory {
                    Section {
                        archiveLoadMoreButton
                            .libraryStateRowStyle()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func archiveGridContent(selectionAction: @escaping (NASA) -> Void) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    archiveHeaderPanels

                    if archiveSections.isEmpty {
                        archiveSearchEmptyState
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    } else {
                        ForEach(archiveSections) { section in
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Text(section.title)
                                    .font(AppTheme.Typography.sectionTitle)
                                    .padding(.horizontal, AppTheme.Spacing.lg)

                                LazyVGrid(columns: archiveGridColumns, spacing: AppTheme.Spacing.md) {
                                    ForEach(section.itemIDs, id: \.self) { itemID in
                                        if let displayItem = archiveDisplayItemsByID[itemID] {
                                            ArchiveGridCard(
                                                displayItem: displayItem,
                                                isSelected: displayItem.id == selectedArchiveItemID,
                                                isLocked: isLockedArchiveItem(displayItem),
                                                action: { selectionAction(displayItem.item) }
                                            )
                                            .id(displayItem.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppTheme.Spacing.lg)
                            }
                        }

                        if let loadError = fetcher.archiveError {
                            MissionStateCard(
                                eyebrow: L10n.text("Archive Sync", default: "Archive Sync"),
                                title: L10n.text("Could not load older APOD entries", default: "Could not load older APOD entries"),
                                message: loadError.localizedDescription,
                                systemImage: "exclamationmark.triangle",
                                tone: .warning,
                                minHeight: 180
                            ) {
                                Button(L10n.text("Retry", default: "Retry")) {
                                    fetcher.loadOlderArchiveBatch()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        }

                        if fetcher.canLoadMoreArchiveHistory {
                            archiveLoadMoreButton
                                .padding(.horizontal, AppTheme.Spacing.lg)
                        }
                    }
                }
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
            .onChange(of: selectedArchiveItemID) { newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var archiveGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 220, maximum: 280), spacing: AppTheme.Spacing.md, alignment: .top)
        ]
    }

    private var archiveLoadMoreButton: some View {
        Button {
            guard purchaseManager.hasPro else {
                purchaseManager.presentPaywall(trigger: .archiveLoadMore, feature: .fullArchive)
                return
            }

            fetcher.loadOlderArchiveBatch()
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                if fetcher.isFetchingArchive {
                    ProgressView()
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .accessibilityHidden(true)
                }
                Text(
                    fetcher.isFetchingArchive
                        ? L10n.text("Loading older APOD entries…", default: "Loading older APOD entries…")
                        : L10n.text("Load older APOD entries", default: "Load older APOD entries")
                )
                .font(AppTheme.Typography.buttonLabel)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(fetcher.isFetchingArchive)
        .accessibilityIdentifier(AccessibilityID.archiveLoadMoreButton)
    }

    private var archiveEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("APOD Archive", default: "APOD Archive"),
            title: L10n.text("Archive is still building", default: "Archive is still building"),
            message: L10n.text(
                "Once APOD entries are cached, you can search by title, date, or credit line and jump back into any day.",
                default: "Once APOD entries are cached, you can search by title, date, or credit line and jump back into any day."
            ),
            systemImage: "books.vertical",
            tone: .accent
        )
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.archiveEmptyState)
    }

    private var archiveSearchEmptyState: some View {
        MissionStateCard(
            eyebrow: L10n.text("Archive Search", default: "Archive Search"),
            title: L10n.text("No matching APOD entries", default: "No matching APOD entries"),
            message: L10n.text(
                "Try another title, date, or credit line to find an archived Astronomy Picture of the Day.",
                default: "Try another title, date, or credit line to find an archived Astronomy Picture of the Day."
            ),
            systemImage: "sparkle.magnifyingglass",
            tone: .neutral,
            minHeight: 180
        )
    }

    private var archiveSelectionPlaceholder: some View {
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
    }

}

private struct ArchiveGridCard: View {
    let displayItem: APODLibraryDisplayItem
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MissionPanel(tone: isSelected ? .accent : .neutral, padding: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ZStack(alignment: .topLeading) {
                        ArchiveGridThumbnailView(displayItem: displayItem)

                        if displayItem.isSaved {
                            MissionBadge(
                                title: L10n.text("Saved", default: "Saved"),
                                systemImage: "bookmark.fill",
                                tone: .favorite
                            )
                            .padding(AppTheme.Spacing.sm)
                        }

                        if isLocked {
                            MissionBadge(
                                title: L10n.text("paywall.locked_badge", default: "Pro"),
                                systemImage: "lock.fill",
                                tone: .warning
                            )
                            .padding(AppTheme.Spacing.sm)
                            .padding(.top, displayItem.isSaved ? 34 : 0)
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(displayItem.title)
                            .font(AppTheme.Typography.sectionTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(displayItem.dateText)
                            .font(AppTheme.Typography.metadata)
                            .foregroundStyle(.secondary)

                        Text(displayItem.creditLine)
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        MissionBadge(
                            title: displayItem.mediaBadgeTitle,
                            systemImage: displayItem.mediaBadgeSystemImage,
                            tone: .neutral
                        )

                        if let offlineStatusPresentation = displayItem.offlineStatusPresentation {
                            MissionBadge(
                                title: offlineStatusPresentation.title,
                                systemImage: offlineStatusPresentation.systemImage,
                                tone: offlineStatusPresentation.tone
                            )
                        }
                    }
                }
            }
            .opacity(isLocked ? 0.78 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.Palette.accentHighlight : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            displayItem.isSaved
                ? AccessibilityID.favoriteRowIdentifier(for: displayItem.item)
                : AccessibilityID.archiveRowIdentifier(for: displayItem.item)
        )
        .accessibilityHint(
            displayItem.isSaved
                ? L10n.text("Open this saved APOD", default: "Open this saved APOD")
                : L10n.text("Open this APOD from the archive", default: "Open this APOD from the archive")
        )
    }
}

private struct ArchiveGridThumbnailView: View {
    let displayItem: APODLibraryDisplayItem

    private var thumbnailURL: URL? {
        switch displayItem.item.mediaType {
        case .image:
            return displayItem.item.url ?? displayItem.item.hdurl
        case .video:
            return displayItem.item.url
        case .other:
            return displayItem.item.url ?? displayItem.item.hdurl
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            APODAsyncLocalThumbnailView(
                fileURL: displayItem.offlineMediaState.localPreviewURL,
                spec: APODLocalMediaThumbnailSpec.libraryGrid
            ) {
                remoteThumbnailContent
            }

            if displayItem.item.mediaType == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
            }
        }
        .aspectRatio(1.25, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var remoteThumbnailContent: some View {
        if displayItem.item.mediaType == .image, let thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: displayItem.item.mediaType == .video ? "play.rectangle.fill" : "photo.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func libraryRow(
    _ displayItem: APODLibraryDisplayItem,
    isSelected: Bool,
    isLocked: Bool = false,
    selectionAction: @escaping (NASA) -> Void
) -> some View {
    Button {
        selectionAction(displayItem.item)
    } label: {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            APODLibraryThumbnailView(displayItem: displayItem)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(displayItem.title)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(displayItem.dateText)
                    .font(AppTheme.Typography.metadata)
                    .foregroundStyle(.secondary)

                Text(displayItem.creditLine)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: AppTheme.Spacing.xs) {
                    MissionBadge(
                        title: displayItem.mediaBadgeTitle,
                        systemImage: displayItem.mediaBadgeSystemImage,
                        tone: .neutral
                    )

                    if isLocked {
                        MissionBadge(
                            title: L10n.text("paywall.locked_badge", default: "Pro"),
                            systemImage: "lock.fill",
                            tone: .warning
                        )
                    }

                    if displayItem.isSaved {
                        MissionBadge(
                            title: L10n.text("Saved", default: "Saved"),
                            systemImage: "bookmark.fill",
                            tone: .favorite
                        )
                    }

                    if let offlineStatusPresentation = displayItem.offlineStatusPresentation {
                        MissionBadge(
                            title: offlineStatusPresentation.title,
                            systemImage: offlineStatusPresentation.systemImage,
                            tone: offlineStatusPresentation.tone
                        )
                    }
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        .opacity(isLocked ? 0.78 : 1)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .libraryRowBackground(isSelected: isSelected)
    .accessibilityIdentifier(
        displayItem.isSaved
            ? AccessibilityID.favoriteRowIdentifier(for: displayItem.item)
            : AccessibilityID.archiveRowIdentifier(for: displayItem.item)
    )
    .accessibilityHint(
        isLocked
            ? L10n.text("paywall.locked_hint", default: "Unlock Pro to open older APOD archive entries.")
            : (displayItem.isSaved
                ? L10n.text("Open this saved APOD", default: "Open this saved APOD")
                : L10n.text("Open this APOD from the archive", default: "Open this APOD from the archive"))
    )
}

private struct APODLibraryThumbnailView: View {
    let displayItem: APODLibraryDisplayItem

    private var thumbnailURL: URL? {
        switch displayItem.item.mediaType {
        case .image:
            return displayItem.item.url ?? displayItem.item.hdurl
        case .video:
            return displayItem.item.url
        case .other:
            return displayItem.item.url ?? displayItem.item.hdurl
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            APODAsyncLocalThumbnailView(
                fileURL: displayItem.offlineMediaState.localPreviewURL,
                spec: APODLocalMediaThumbnailSpec.libraryRow
            ) {
                remoteThumbnailContent
            }

            if displayItem.item.mediaType == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var remoteThumbnailContent: some View {
        if displayItem.item.mediaType == .image, let thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: displayItem.item.mediaType == .video ? "play.rectangle.fill" : "photo.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
