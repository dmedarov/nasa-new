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

        func matchesSearch(_ query: String) -> Bool {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else { return true }

            return title.localizedCaseInsensitiveContains(trimmedQuery)
                || (date ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                || creditLine.localizedCaseInsensitiveContains(trimmedQuery)
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
        let filteredItems = items.filter { item in
            item.matchesFilter(filter) && item.matchesSearch(searchQuery)
        }

        let groupedItems = Dictionary(grouping: filteredItems) { item in
            sectionKey(for: item.date)
        }

        let sections = groupedItems.keys
            .sorted(by: >)
            .map { key in
                Section(
                    id: key,
                    title: sectionTitle(for: key, locale: locale),
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

        func matchesSearch(_ query: String) -> Bool {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else { return true }

            return title.localizedCaseInsensitiveContains(trimmedQuery)
                || (date ?? "").localizedCaseInsensitiveContains(trimmedQuery)
                || creditLine.localizedCaseInsensitiveContains(trimmedQuery)
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
    }

    static func filteredItemIDs(
        items: [Item],
        filter: SavedFilter,
        searchQuery: String
    ) -> [String] {
        items
            .filter { $0.matchesFilter(filter) && $0.matchesSearch(searchQuery) }
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
