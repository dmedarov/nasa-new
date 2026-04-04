import Foundation

enum ArchiveFilter: String, CaseIterable, Identifiable {
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

enum ArchivePresentationMode: String, CaseIterable, Identifiable {
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

enum SavedFilter: String, CaseIterable, Identifiable {
    case all
    case offline
    case preview
    case sourceRequired

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all:
            return L10n.text("All", default: "All")
        case .offline:
            return L10n.text("Offline", default: "Offline")
        case .preview:
            return L10n.text("Preview", default: "Preview")
        case .sourceRequired:
            return L10n.text("Source", default: "Source")
        }
    }
}

struct LibraryLayoutPolicy {
    static func usesSplitLayout(isRegularWidth: Bool, embedInRegularShell: Bool) -> Bool {
        isRegularWidth && !embedInRegularShell
    }

    static func supportsGridPresentation(isRegularWidth: Bool, embedInRegularShell: Bool) -> Bool {
        usesSplitLayout(isRegularWidth: isRegularWidth, embedInRegularShell: embedInRegularShell)
    }

    static func resolvedPresentationMode(
        from rawValue: String,
        fallback: ArchivePresentationMode
    ) -> ArchivePresentationMode {
        ArchivePresentationMode(rawValue: rawValue) ?? fallback
    }

    static func usesGridPresentation(
        isRegularWidth: Bool,
        embedInRegularShell: Bool,
        presentationMode: ArchivePresentationMode
    ) -> Bool {
        supportsGridPresentation(isRegularWidth: isRegularWidth, embedInRegularShell: embedInRegularShell)
            && presentationMode == .grid
    }
}

struct ArchiveLibraryPolicy {
    struct Item: Identifiable, Equatable {
        enum MediaKind: Equatable {
            case image
            case video
            case other

            init(_ mediaType: MediaType) {
                switch mediaType {
                case .image:
                    self = .image
                case .video:
                    self = .video
                case .other:
                    self = .other
                }
            }
        }

        let id: String
        let date: String?
        let title: String
        let creditLine: String
        let mediaKind: MediaKind
        let isSaved: Bool
        let sectionKey: String
        private let searchText: String

        init(
            id: String,
            date: String?,
            title: String,
            creditLine: String,
            mediaKind: MediaKind,
            isSaved: Bool,
            sectionKey: String? = nil,
            searchText: String? = nil
        ) {
            self.id = id
            self.date = date
            self.title = title
            self.creditLine = creditLine
            self.mediaKind = mediaKind
            self.isSaved = isSaved
            self.sectionKey = sectionKey ?? ArchiveLibraryPolicy.sectionKey(for: date)
            self.searchText = searchText ?? Self.makeSearchText(
                title: title,
                date: date,
                creditLine: creditLine
            )
        }

        func matchesSearch(_ query: String) -> Bool {
            guard !query.isEmpty else { return true }

            return searchText.localizedCaseInsensitiveContains(query)
        }

        func matchesFilter(_ filter: ArchiveFilter) -> Bool {
            switch filter {
            case .all:
                return true
            case .image:
                return mediaKind == .image
            case .video:
                return mediaKind == .video
            case .saved:
                return isSaved
            }
        }

        private static func makeSearchText(
            title: String,
            date: String?,
            creditLine: String
        ) -> String {
            [title, date ?? "", creditLine]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let itemIDs: [String]
    }

    struct Resolution: Equatable {
        let filteredItemIDs: [String]
        let sections: [Section]
    }

    static func resolve(
        items: [Item],
        filter: ArchiveFilter,
        searchQuery: String,
        locale: Locale
    ) -> Resolution {
        let normalizedSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let sectionTitleFormatter = makeSectionTitleFormatter(locale: locale)
        let filteredItems = items.filter { item in
            item.matchesFilter(filter) && item.matchesSearch(normalizedSearchQuery)
        }

        let groupedItems = Dictionary(grouping: filteredItems) { item in
            item.sectionKey
        }

        let sections = groupedItems.keys
            .sorted(by: >)
            .map { key in
                Section(
                    id: key,
                    title: sectionTitle(for: key, formatter: sectionTitleFormatter),
                    itemIDs: groupedItems[key, default: []]
                        .sorted { ($0.date ?? "") > ($1.date ?? "") }
                        .map(\.id)
                )
            }

        return Resolution(
            filteredItemIDs: filteredItems.map(\.id),
            sections: sections
        )
    }

    static func sectionKey(for apiDateString: String?) -> String {
        guard
            let apiDateString,
            let parsedDate = DateFormatter.archiveAPODDateFormatter.date(from: apiDateString)
        else {
            return "unknown"
        }

        return DateFormatter.archiveSectionKeyFormatter.string(from: parsedDate)
    }

    static func sectionTitle(for key: String, locale: Locale) -> String {
        sectionTitle(for: key, formatter: makeSectionTitleFormatter(locale: locale))
    }

    private static func sectionTitle(for key: String, formatter: DateFormatter) -> String {
        guard key != "unknown",
              let parsedDate = DateFormatter.archiveSectionKeyFormatter.date(from: key) else {
            return L10n.text("Unknown", default: "Unknown")
        }

        return formatter.string(from: parsedDate)
    }

    private static func makeSectionTitleFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }
}

struct SavedLibraryPolicy {
    struct Item: Identifiable, Equatable {
        enum StorageState: Equatable {
            case full
            case preview
            case sourceBacked
        }

        let id: String
        let date: String?
        let title: String
        let creditLine: String
        let storageState: StorageState
        private let searchText: String

        init(
            id: String,
            date: String?,
            title: String,
            creditLine: String,
            storageState: StorageState,
            searchText: String? = nil
        ) {
            self.id = id
            self.date = date
            self.title = title
            self.creditLine = creditLine
            self.storageState = storageState
            self.searchText = searchText ?? Self.makeSearchText(
                title: title,
                date: date,
                creditLine: creditLine
            )
        }

        func matchesSearch(_ query: String) -> Bool {
            guard !query.isEmpty else { return true }

            return searchText.localizedCaseInsensitiveContains(query)
        }

        func matchesFilter(_ filter: SavedFilter) -> Bool {
            switch filter {
            case .all:
                return true
            case .offline:
                return storageState == .full
            case .preview:
                return storageState == .preview
            case .sourceRequired:
                return storageState == .sourceBacked
            }
        }

        private static func makeSearchText(
            title: String,
            date: String?,
            creditLine: String
        ) -> String {
            [title, date ?? "", creditLine]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    static func filteredItemIDs(
        items: [Item],
        filter: SavedFilter,
        searchQuery: String
    ) -> [String] {
        let normalizedSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        return items
            .filter { $0.matchesFilter(filter) && $0.matchesSearch(normalizedSearchQuery) }
            .map(\.id)
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
