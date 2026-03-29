import SwiftUI

private enum ArchiveFilter: String, CaseIterable, Identifiable {
    case all
    case image
    case video
    case saved

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all:
            return L10n.text("All", default: "All")
        case .image:
            return L10n.text("Images", default: "Images")
        case .video:
            return L10n.text("Videos", default: "Videos")
        case .saved:
            return L10n.text("Saved", default: "Saved")
        }
    }
}

private enum ArchivePresentationMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .grid:
            return L10n.text("Grid", default: "Grid")
        case .list:
            return L10n.text("List", default: "List")
        }
    }

    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet.rectangle"
        }
    }
}

private struct ArchiveSection: Identifiable {
    let id: String
    let title: String
    let items: [NASA]
}

struct SavedScreenView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var pushedFavorite: NASA?
    @State private var selectedFavoriteID: String?
    @State private var searchQuery = ""

    private var usesSplitLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var filteredFavorites: [NASA] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fetcher.favorites }

        return fetcher.favorites.filter { item in
            (item.title ?? "").localizedCaseInsensitiveContains(trimmed) ||
            (item.date ?? "").localizedCaseInsensitiveContains(trimmed) ||
            APODAttributionPolicy.creditLine(for: item).localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var selectedFavorite: NASA? {
        let preferredID = selectedFavoriteID ?? router.selectedSavedItemID
        return filteredFavorites.first(where: { $0.id == preferredID })
            ?? fetcher.favorites.first(where: { $0.id == preferredID })
    }

    private var savedResultsSummary: String {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return L10n.format(
                "saved.search.summary.default",
                default: "Search %d saved APOD stories by title, date, or credit line.",
                fetcher.favorites.count
            )
        }

        return L10n.format(
            "saved.search.summary.filtered",
            default: "Showing %d of %d saved stories for \"%@\".",
            filteredFavorites.count,
            fetcher.favorites.count,
            trimmedQuery
        )
    }

    var body: some View {
        Group {
            if usesSplitLayout {
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
        .onAppear {
            syncSavedSelectionFromRouter()
        }
        .onChange(of: router.selectedSavedItemID) { _ in
            syncSavedSelectionFromRouter()
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
        Group {
            if fetcher.favorites.isEmpty {
                favoritesEmptyState
            } else {
                savedListContent(
                    selectedItemID: selectedItemID,
                    selectionAction: selectionAction
                )
            }
        }
        .background(SpaceBackdropView())
        .navigationTitle(L10n.text("Favorites", default: "Favorites"))
    }

    private func savedListContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        List {
            savedHeaderPanels
                .libraryHeaderRowStyle()

            if filteredFavorites.isEmpty {
                searchEmptyState
                    .libraryStateRowStyle()
            } else {
                ForEach(filteredFavorites) { item in
                    libraryRow(
                        item,
                        isSelected: item.id == selectedItemID,
                        isSaved: true,
                        offlineMedia: fetcher.offlineMediaAsset(for: item),
                        selectionAction: selectionAction
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            fetcher.removeFavorite(item)
                        } label: {
                            Label(L10n.text("Delete", default: "Delete"), systemImage: "trash")
                        }
                        .accessibilityIdentifier(AccessibilityID.favoriteDeleteActionIdentifier(for: item))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var savedHeaderPanels: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            savedOverviewPanel
            savedSearchPanel
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs)
        .padding(.bottom, AppTheme.Spacing.xs)
    }

    private var savedOverviewPanel: some View {
        MissionPanel(tone: .favorite, padding: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionEyebrow(L10n.text("Saved Archive", default: "Saved Archive"), tone: .favorite)
                Text(
                    L10n.format(
                        "saved.summary.count",
                        default: "%d saved APOD stories ready to revisit",
                        fetcher.favorites.count
                    )
                )
                .font(AppTheme.Typography.cardTitle)
                Text(
                    L10n.text(
                        "saved.summary.body",
                        default: "Saved APODs keep their story and credits on device, while images and supported media are downloaded locally when available."
                    )
                )
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)

                if fetcher.savedOfflineItemCount > 0 || fetcher.savedPreviewItemCount > 0 {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        if fetcher.savedOfflineItemCount > 0 {
                            MissionBadge(
                                title: L10n.format(
                                    "saved.summary.offline_count",
                                    default: "%d offline",
                                    fetcher.savedOfflineItemCount
                                ),
                                systemImage: "arrow.down.circle.fill",
                                tone: .accent
                            )
                        }

                        if fetcher.savedPreviewItemCount > 0 {
                            MissionBadge(
                                title: L10n.format(
                                    "saved.summary.preview_count",
                                    default: "%d preview",
                                    fetcher.savedPreviewItemCount
                                ),
                                systemImage: "photo.badge.arrow.down",
                                tone: .neutral
                            )
                        }
                    }
                }
            }
        }
    }

    private var savedSearchPanel: some View {
        MissionPanel(tone: .neutral, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionEyebrow(L10n.text("Saved Search", default: "Saved Search"), tone: .neutral)
                Text(savedResultsSummary)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)

                MissionSearchField(
                    text: $searchQuery,
                    placeholder: L10n.text("Search favorites", default: "Search favorites"),
                    accessibilityIdentifier: AccessibilityID.favoritesSearchField
                )
            }
        }
    }

    private func selectFavorite(_ item: NASA) {
        selectedFavoriteID = item.id
        router.selectedSavedItemID = item.id
        fetcher.selectFavorite(item)
    }

    private func syncSavedSelectionFromRouter() {
        guard let selectedID = router.selectedSavedItemID else { return }
        selectedFavoriteID = selectedID
        if let favorite = fetcher.favorites.first(where: { $0.id == selectedID }) {
            fetcher.selectFavorite(favorite)
        }
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
        MissionStateCard(
            eyebrow: L10n.text("Saved Archive", default: "Saved Archive"),
            title: L10n.text("Select a saved APOD", default: "Select a saved APOD"),
            message: L10n.text(
                "Choose a saved story from the list to read it with the full editorial layout.",
                default: "Choose a saved story from the list to read it with the full editorial layout."
            ),
            systemImage: "bookmark.circle",
            tone: .favorite
        )
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpaceBackdropView())
    }
}

struct ArchiveScreenView: View {
    @EnvironmentObject private var fetcher: NasaCollectionFetcher
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale

    @AppStorage("archive.presentation.mode") private var archivePresentationModeRawValue = ArchivePresentationMode.grid.rawValue
    @State private var pushedArchiveItem: NASA?
    @State private var selectedArchiveItemID: String?
    @State private var searchQuery = ""
    @State private var filter: ArchiveFilter = .all
    @State private var archiveJumpDate = Date()

    private var usesSplitLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var archivePresentationMode: ArchivePresentationMode {
        ArchivePresentationMode(rawValue: archivePresentationModeRawValue) ?? .grid
    }

    private var supportsGridPresentation: Bool {
        usesSplitLayout
    }

    private var usesGridPresentation: Bool {
        supportsGridPresentation && archivePresentationMode == .grid
    }

    private var filteredItems: [NASA] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return fetcher.archiveItems.filter { item in
            let matchesFilter: Bool = {
                switch filter {
                case .all:
                    return true
                case .image:
                    return item.mediaType == .image
                case .video:
                    return item.mediaType == .video
                case .saved:
                    return fetcher.isFavorite(item)
                }
            }()

            guard matchesFilter else { return false }
            guard !trimmedQuery.isEmpty else { return true }

            return (item.title ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                || (item.date ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                || APODAttributionPolicy.creditLine(for: item).localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var sections: [ArchiveSection] {
        var grouped = [String: [NASA]]()

        for item in filteredItems {
            let key = archiveSectionKey(for: item.date)
            grouped[key, default: []].append(item)
        }

        return grouped.keys
            .sorted(by: >)
            .map { key in
                ArchiveSection(
                    id: key,
                    title: archiveSectionTitle(for: key),
                    items: grouped[key, default: []].sorted { ($0.date ?? "") > ($1.date ?? "") }
                )
            }
    }

    private var selectedArchiveItem: NASA? {
        let preferredID = selectedArchiveItemID ?? router.selectedArchiveItemID
        return filteredItems.first(where: { $0.id == preferredID })
            ?? fetcher.archiveItems.first(where: { $0.id == preferredID })
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
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedQuery.isEmpty {
            return L10n.format(
                "archive.controls.summary.search",
                default: "Showing %d results for \"%@\".",
                filteredItems.count,
                trimmedQuery
            )
        }

        if filter != .all {
            return L10n.format(
                "archive.controls.summary.filter",
                default: "Showing %d entries in %@.",
                filteredItems.count,
                filter.localizedTitle
            )
        }

        return L10n.format(
            "archive.controls.summary.default",
            default: "Search %d archived APOD entries by title, date, or credit line.",
            filteredItems.count
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
            if usesSplitLayout {
                NavigationSplitView {
                    archiveCollectionContent(
                        selectedItemID: selectedArchiveItemID ?? router.selectedArchiveItemID,
                        selectionAction: selectArchiveItem
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
                            selectArchiveItem(item)
                            pushedArchiveItem = item
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
            fetcher.prefetchArchiveIfNeeded()
            syncArchiveSelectionFromRouter()
            syncArchiveJumpDate()
        }
        .onChange(of: router.selectedArchiveItemID) { _ in
            syncArchiveSelectionFromRouter()
            syncArchiveJumpDate()
        }
        .onChange(of: selectedArchiveItemID) { _ in
            syncArchiveJumpDate()
        }
    }

    @ViewBuilder
    private func archiveCollectionContent(
        selectedItemID: String?,
        selectionAction: @escaping (NASA) -> Void
    ) -> some View {
        Group {
            if fetcher.archiveItems.isEmpty {
                archiveEmptyContent
            } else if usesGridPresentation {
                archiveGridContent(selectionAction: selectionAction)
            } else {
                archiveListContent(selectedItemID: selectedItemID, selectionAction: selectionAction)
            }
        }
        .background(SpaceBackdropView())
        .navigationTitle(L10n.text("Archive", default: "Archive"))
    }

    private var archiveHeaderPanels: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            archiveOverviewPanel
            archiveControlsPanel
            archiveJumpPanel
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs)
        .padding(.bottom, AppTheme.Spacing.xs)
    }

    private var archiveOverviewPanel: some View {
        MissionPanel(tone: .accent, padding: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                SectionEyebrow(L10n.text("Editorial Archive", default: "Editorial Archive"), tone: .accent)
                Text(archiveSummaryTitle)
                    .font(AppTheme.Typography.cardTitle)
                Text(archiveSummaryMessage)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var archiveControlsPanel: some View {
        MissionPanel(tone: .neutral, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionEyebrow(L10n.text("Browse & Filter", default: "Browse & Filter"), tone: .neutral)

                Text(archiveControlsSummary)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)

                MissionSearchField(
                    text: $searchQuery,
                    placeholder: L10n.text("Search archive", default: "Search archive"),
                    accessibilityIdentifier: AccessibilityID.archiveSearchField
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        archiveFilterPicker
                        Spacer(minLength: 0)
                        if supportsGridPresentation {
                            archiveLayoutPicker
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        archiveFilterPicker
                        if supportsGridPresentation {
                            archiveLayoutPicker
                        }
                    }
                }
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

    private func syncArchiveSelectionFromRouter() {
        guard let selectedID = router.selectedArchiveItemID else { return }
        selectedArchiveItemID = selectedID
        if let archiveItem = fetcher.archiveItems.first(where: { $0.id == selectedID }) {
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

    private func jumpToArchiveDate(compactNavigation: Bool) {
        let targetDate = archiveJumpDate
        Task {
            guard let archiveItem = await fetcher.archiveItem(for: targetDate) else { return }
            selectArchiveItem(archiveItem)
            if compactNavigation {
                pushedArchiveItem = archiveItem
            }
        }
    }

    private var archiveFilterPicker: some View {
        Picker(L10n.text("Archive filter", default: "Archive filter"), selection: $filter) {
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
        MissionPanel(tone: .neutral, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionEyebrow(L10n.text("Timeline Focus", default: "Timeline Focus"), tone: .neutral)

                Text(L10n.text("Jump to APOD date", default: "Jump to APOD date"))
                    .font(AppTheme.Typography.sectionTitle)

                Text(archiveJumpSummary)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)

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

            if sections.isEmpty {
                archiveSearchEmptyState
                    .libraryStateRowStyle()
            } else {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            libraryRow(
                                item,
                                isSelected: item.id == selectedItemID,
                                isSaved: fetcher.isFavorite(item),
                                offlineMedia: fetcher.offlineMediaAsset(for: item),
                                selectionAction: selectionAction
                            )
                            .swipeActions(edge: .trailing) {
                                Button {
                                    fetcher.toggleFavorite(item)
                                } label: {
                                    Label(
                                        fetcher.isFavorite(item)
                                            ? L10n.text("Remove Favorite", default: "Remove Favorite")
                                            : L10n.text("Save Favorite", default: "Save Favorite"),
                                        systemImage: fetcher.isFavorite(item) ? "bookmark.slash" : "bookmark"
                                    )
                                }
                                .tint(fetcher.isFavorite(item) ? .gray : AppTheme.Palette.favorite)
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
                    }
                    .listRowBackground(Color.clear)
                }

                if fetcher.canLoadMoreArchiveHistory {
                    Section {
                        archiveLoadMoreButton
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func archiveGridContent(selectionAction: @escaping (NASA) -> Void) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    archiveHeaderPanels

                    if sections.isEmpty {
                        archiveSearchEmptyState
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Text(section.title)
                                    .font(AppTheme.Typography.sectionTitle)
                                    .padding(.horizontal, AppTheme.Spacing.lg)

                                LazyVGrid(columns: archiveGridColumns, spacing: AppTheme.Spacing.md) {
                                    ForEach(section.items) { item in
                                        ArchiveGridCard(
                                            item: item,
                                            isSelected: item.id == selectedArchiveItemID,
                                            isSaved: fetcher.isFavorite(item),
                                            offlineMedia: fetcher.offlineMediaAsset(for: item),
                                            action: { selectionAction(item) }
                                        )
                                        .id(item.id)
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
        Button(action: fetcher.loadOlderArchiveBatch) {
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
        MissionStateCard(
            eyebrow: L10n.text("Editorial Archive", default: "Editorial Archive"),
            title: L10n.text("Select an APOD entry", default: "Select an APOD entry"),
            message: L10n.text(
                "Choose a story from the archive to read it with the full media, attribution, and source context.",
                default: "Choose a story from the archive to read it with the full media, attribution, and source context."
            ),
            systemImage: "sparkles.rectangle.stack",
            tone: .accent
        )
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpaceBackdropView())
    }

    private func archiveSectionKey(for apiDateString: String?) -> String {
        guard
            let apiDateString,
            let parsedDate = DateFormatter.archiveAPODDateFormatter.date(from: apiDateString)
        else {
            return "unknown"
        }

        return DateFormatter.archiveSectionKeyFormatter.string(from: parsedDate)
    }

    private func archiveSectionTitle(for key: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        guard key != "unknown",
              let parsedDate = DateFormatter.archiveSectionKeyFormatter.date(from: key) else {
            return L10n.text("Unknown", default: "Unknown")
        }

        return formatter.string(from: parsedDate)
    }
}

private struct ArchiveGridCard: View {
    let item: NASA
    let isSelected: Bool
    let isSaved: Bool
    let offlineMedia: APODOfflineMediaAsset?
    let action: () -> Void

    private var offlineStatusPresentation: APODOfflineMediaStatusPresentation? {
        APODOfflineMediaStatusPolicy.presentation(
            for: item,
            asset: offlineMedia,
            isSaved: isSaved
        )
    }

    var body: some View {
        Button(action: action) {
            MissionPanel(tone: isSelected ? .accent : .neutral, padding: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ZStack(alignment: .topLeading) {
                        ArchiveGridThumbnailView(item: item, offlineMedia: offlineMedia)

                        if isSaved {
                            MissionBadge(
                                title: L10n.text("Saved", default: "Saved"),
                                systemImage: "bookmark.fill",
                                tone: .favorite
                            )
                            .padding(AppTheme.Spacing.sm)
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                            .font(AppTheme.Typography.sectionTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(APODDateDisplayPolicy.displayString(for: item.date))
                            .font(AppTheme.Typography.metadata)
                            .foregroundStyle(.secondary)

                        Text(APODAttributionPolicy.creditLine(for: item))
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        MissionBadge(
                            title: item.mediaType.localizedDisplayName,
                            systemImage: item.mediaType == .video ? "play.rectangle.fill" : "photo.fill",
                            tone: .neutral
                        )

                        if let offlineStatusPresentation {
                            MissionBadge(
                                title: offlineStatusPresentation.title,
                                systemImage: offlineStatusPresentation.systemImage,
                                tone: offlineStatusPresentation.tone
                            )
                        }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppTheme.Palette.accentHighlight : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.archiveRowIdentifier(for: item))
        .accessibilityHint(L10n.text("Open this APOD from the archive", default: "Open this APOD from the archive"))
    }
}

private struct ArchiveGridThumbnailView: View {
    let item: NASA
    let offlineMedia: APODOfflineMediaAsset?

    private var thumbnailURL: URL? {
        switch item.mediaType {
        case .image:
            return item.url ?? item.hdurl
        case .video:
            return item.url
        case .other:
            return item.url ?? item.hdurl
        }
    }

    private var localThumbnailImage: Image? {
        APODLocalMediaImageLoader.image(from: offlineMedia?.localPreviewURL)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let localThumbnailImage {
                localThumbnailImage
                    .resizable()
                    .scaledToFill()
            } else if item.mediaType == .image, let thumbnailURL {
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

            if item.mediaType == .video {
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

    private var fallbackIcon: some View {
        Image(systemName: item.mediaType == .video ? "play.rectangle.fill" : "photo.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    func libraryHeaderRowStyle() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func libraryStateRowStyle() -> some View {
        listRowInsets(
            EdgeInsets(
                top: AppTheme.Spacing.sm,
                leading: AppTheme.Spacing.lg,
                bottom: AppTheme.Spacing.sm,
                trailing: AppTheme.Spacing.lg
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    func libraryRowBackground(isSelected: Bool) -> some View {
        listRowBackground(
            isSelected
                ? AppTheme.Palette.accentLight.opacity(0.08)
                : Color.clear
        )
    }
}

private func libraryRow(
    _ item: NASA,
    isSelected: Bool,
    isSaved: Bool,
    offlineMedia: APODOfflineMediaAsset?,
    selectionAction: @escaping (NASA) -> Void
) -> some View {
    Button {
        selectionAction(item)
    } label: {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            APODLibraryThumbnailView(item: item, offlineMedia: offlineMedia)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(APODDateDisplayPolicy.displayString(for: item.date))
                    .font(AppTheme.Typography.metadata)
                    .foregroundStyle(.secondary)

                Text(APODAttributionPolicy.creditLine(for: item))
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: AppTheme.Spacing.xs) {
                    MissionBadge(
                        title: item.mediaType.localizedDisplayName,
                        systemImage: item.mediaType == .video ? "play.rectangle.fill" : "photo.fill",
                        tone: .neutral
                    )

                    if isSaved {
                        MissionBadge(
                            title: L10n.text("Saved", default: "Saved"),
                            systemImage: "bookmark.fill",
                            tone: .favorite
                        )
                    }

                    if let offlineStatusPresentation = APODOfflineMediaStatusPolicy.presentation(
                        for: item,
                        asset: offlineMedia,
                        isSaved: isSaved
                    ) {
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
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .libraryRowBackground(isSelected: isSelected)
    .accessibilityIdentifier(
        isSaved
            ? AccessibilityID.favoriteRowIdentifier(for: item)
            : AccessibilityID.archiveRowIdentifier(for: item)
    )
    .accessibilityHint(
        isSaved
            ? L10n.text("Open this saved APOD", default: "Open this saved APOD")
            : L10n.text("Open this APOD from the archive", default: "Open this APOD from the archive")
    )
}

private struct APODLibraryThumbnailView: View {
    let item: NASA
    let offlineMedia: APODOfflineMediaAsset?

    private var thumbnailURL: URL? {
        switch item.mediaType {
        case .image:
            return item.url ?? item.hdurl
        case .video:
            return item.url
        case .other:
            return item.url ?? item.hdurl
        }
    }

    private var localThumbnailImage: Image? {
        APODLocalMediaImageLoader.image(from: offlineMedia?.localPreviewURL)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let localThumbnailImage {
                localThumbnailImage
                    .resizable()
                    .scaledToFill()
            } else if item.mediaType == .image, let thumbnailURL {
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

            if item.mediaType == .video {
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

    private var fallbackIcon: some View {
        Image(systemName: item.mediaType == .video ? "play.rectangle.fill" : "photo.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension DateFormatter {
    static let archiveAPODDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static let archiveSectionKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        formatter.isLenient = false
        return formatter
    }()
}
