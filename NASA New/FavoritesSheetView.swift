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

private struct ArchiveSection: Identifiable {
    let id: String
    let title: String
    let items: [NASA]
}

struct FavoritesSheetView: View {
    let favorites: [NASA]
    @Binding var isPresented: Bool
    let selectAction: (NASA) -> Void
    let removeAction: (NASA) -> Void
    @State private var searchQuery = ""

    private var filteredFavorites: [NASA] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return favorites }
        return favorites.filter { item in
            (item.title ?? "").localizedCaseInsensitiveContains(trimmed) ||
            (item.date ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        AdaptiveNavigationContainer {
            Group {
                if favorites.isEmpty {
                    favoritesEmptyState
                } else {
                    VStack(spacing: AppTheme.Spacing.md) {
                        MissionSearchField(
                            text: $searchQuery,
                            placeholder: L10n.text("Search favorites", default: "Search favorites"),
                            accessibilityIdentifier: AccessibilityID.favoritesSearchField
                        )
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.xs)

                        List {
                            ForEach(filteredFavorites) { item in
                                Button {
                                    selectAction(item)
                                    isPresented = false
                                } label: {
                                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                            Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                                                .font(AppTheme.Typography.sectionTitle)
                                                .foregroundColor(.primary)
                                            Text(APODDateDisplayPolicy.displayString(for: item.date))
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundColor(.secondary)
                                            Text(APODAttributionPolicy.creditLine(for: item))
                                                .font(AppTheme.Typography.footnote)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: AppTheme.Spacing.sm)

                                        VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                                            Image(systemName: item.mediaType == .video ? "play.rectangle" : "photo")
                                                .foregroundColor(.secondary)
                                                .accessibilityHidden(true)
                                            Text(item.mediaType.localizedDisplayName)
                                                .font(AppTheme.Typography.metadata)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, AppTheme.Spacing.xxs)
                                }
                                .accessibilityIdentifier(AccessibilityID.favoriteRowIdentifier(for: item))
                                .accessibilityHint(L10n.text("Open this saved APOD", default: "Open this saved APOD"))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        removeAction(item)
                                    } label: {
                                        Label(L10n.text("Delete", default: "Delete"), systemImage: "trash")
                                    }
                                    .accessibilityIdentifier(AccessibilityID.favoriteDeleteActionIdentifier(for: item))
                                }
                            }
                        }
                        .overlay {
                            if filteredFavorites.isEmpty {
                                searchEmptyState
                                    .padding(AppTheme.Spacing.lg)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle(L10n.text("Favorites", default: "Favorites"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.favoritesSheetRoot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Done", default: "Done")) { isPresented = false }
                        .accessibilityIdentifier(AccessibilityID.favoritesDoneButton)
                }
            }
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
}

struct ArchiveSheetView: View {
    @Environment(\.locale) private var locale
    let archivedItems: [NASA]
    let favoriteIDs: Set<String>
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let loadError: NasaCollectionFetcher.FetchError?
    @Binding var isPresented: Bool
    let selectAction: (NASA) -> Void
    let toggleFavoriteAction: (NASA) -> Void
    let loadMoreAction: () -> Void
    @State private var searchQuery = ""
    @State private var filter: ArchiveFilter = .all

    private var filteredItems: [NASA] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return archivedItems.filter { item in
            let matchesFilter: Bool = {
                switch filter {
                case .all:
                    return true
                case .image:
                    return item.mediaType == .image
                case .video:
                    return item.mediaType == .video
                case .saved:
                    return favoriteIDs.contains(item.id)
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

    private var archiveSummaryTitle: String {
        L10n.format(
            "archive.summary.count",
            default: "%d APOD entries ready to browse",
            archivedItems.count
        )
    }

    private var archiveSummaryMessage: String {
        if let oldest = archivedItems.last?.date,
           let newest = archivedItems.first?.date {
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

    var body: some View {
        AdaptiveNavigationContainer {
            VStack(spacing: AppTheme.Spacing.md) {
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
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.xs)

                MissionSearchField(
                    text: $searchQuery,
                    placeholder: L10n.text("Search archive", default: "Search archive"),
                    accessibilityIdentifier: AccessibilityID.archiveSearchField
                )
                .padding(.horizontal, AppTheme.Spacing.lg)

                Picker(L10n.text("Archive filter", default: "Archive filter"), selection: $filter) {
                    ForEach(ArchiveFilter.allCases) { filter in
                        Text(filter.localizedTitle).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.lg)

                if archivedItems.isEmpty {
                    archiveEmptyState
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.items) { item in
                                    archiveRow(item)
                                }
                            }
                        }

                        if let loadError {
                            Section {
                                MissionStateCard(
                                    eyebrow: L10n.text("Archive Sync", default: "Archive Sync"),
                                    title: L10n.text("Could not load older APOD entries", default: "Could not load older APOD entries"),
                                    message: loadError.localizedDescription,
                                    systemImage: "exclamationmark.triangle",
                                    tone: .warning,
                                    minHeight: 180
                                ) {
                                    Button(L10n.text("Retry", default: "Retry"), action: loadMoreAction)
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }

                        if canLoadMore {
                            Section {
                                Button(action: loadMoreAction) {
                                    HStack(spacing: AppTheme.Spacing.sm) {
                                        if isLoadingMore {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .accessibilityHidden(true)
                                        }
                                        Text(
                                            isLoadingMore
                                                ? L10n.text("Loading older APOD entries…", default: "Loading older APOD entries…")
                                                : L10n.text("Load older APOD entries", default: "Load older APOD entries")
                                        )
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(isLoadingMore)
                                .accessibilityIdentifier(AccessibilityID.archiveLoadMoreButton)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .overlay {
                        if !archivedItems.isEmpty && sections.isEmpty {
                            archiveSearchEmptyState
                                .padding(AppTheme.Spacing.lg)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("Archive", default: "Archive"))
            .overlay(alignment: .topLeading) {
                AccessibilityMarker(identifier: AccessibilityID.archiveSheetRoot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Done", default: "Done")) {
                        isPresented = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func archiveRow(_ item: NASA) -> some View {
        Button {
            selectAction(item)
            isPresented = false
        } label: {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(item.title ?? L10n.text("Untitled", default: "Untitled"))
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(APODDateDisplayPolicy.displayString(for: item.date, locale: locale))
                        .font(AppTheme.Typography.metadata)
                        .foregroundStyle(.secondary)

                    Text(APODAttributionPolicy.creditLine(for: item))
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                    Image(systemName: item.mediaType == .video ? "play.rectangle.fill" : "photo.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    if favoriteIDs.contains(item.id) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.Palette.favorite)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
        }
        .accessibilityIdentifier(AccessibilityID.archiveRowIdentifier(for: item))
        .accessibilityHint(L10n.text("Open this APOD from the archive", default: "Open this APOD from the archive"))
        .swipeActions(edge: .trailing) {
            Button {
                toggleFavoriteAction(item)
            } label: {
                Label(
                    favoriteIDs.contains(item.id)
                        ? L10n.text("Remove Favorite", default: "Remove Favorite")
                        : L10n.text("Save Favorite", default: "Save Favorite"),
                    systemImage: favoriteIDs.contains(item.id) ? "bookmark.slash" : "bookmark"
                )
            }
            .tint(favoriteIDs.contains(item.id) ? .gray : AppTheme.Palette.favorite)
        }
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
