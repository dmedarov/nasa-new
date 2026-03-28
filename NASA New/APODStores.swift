import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

protocol FavoritesStorage {
    func loadFavorites() -> [NASA]
    func saveFavorites(_ favorites: [NASA])
}

protocol APODCacheStorage {
    func loadCachedAPODItems() -> [NASA]
    func saveCachedAPODItems(_ items: [NASA])
}

protocol APODLibraryStateStorage {
    func sync(items: [NASA], favorites: [NASA], currentID: String?, limit: Int)
    func noteViewed(_ nasa: NASA)
}

typealias APODLibraryStorage = FavoritesStorage & APODCacheStorage

enum APODLibraryStoreFactory {
    static func makeDefault() -> any APODLibraryStorage {
        if usesVolatileStoreForCurrentRuntime {
            return VolatileAPODLibraryStorage()
        }

#if canImport(SwiftData)
        if #available(iOS 17.0, *),
           let storage = try? SwiftDataAPODLibraryStorage(
                legacyStorage: UserDefaultsAPODLibraryStorage()
           ) {
            return storage
        }
#endif

        return UserDefaultsAPODLibraryStorage()
    }

    private static var usesVolatileStoreForCurrentRuntime: Bool {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments

        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        if environment["UITEST_USE_FIXTURE"] == "1" {
            return true
        }

        if arguments.contains("-ui-testing") {
            return true
        }

        return false
    }
}

final class VolatileAPODLibraryStorage: APODLibraryStorage, APODLibraryStateStorage {
    private var cachedItems: [NASA]
    private var favorites: [NASA]

    init(cachedItems: [NASA] = [], favorites: [NASA] = []) {
        self.cachedItems = cachedItems.sorted { ($0.date ?? "") < ($1.date ?? "") }
        self.favorites = favorites.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    func loadFavorites() -> [NASA] {
        favorites
    }

    func saveFavorites(_ favorites: [NASA]) {
        self.favorites = favorites.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    func loadCachedAPODItems() -> [NASA] {
        cachedItems
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        cachedItems = items.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    func sync(items: [NASA], favorites: [NASA], currentID: String?, limit: Int) {
        let mergedItems = mergedArchiveItems(
            existingItems: cachedItems,
            incomingItems: items,
            favorites: favorites,
            currentID: currentID,
            limit: limit
        )

        cachedItems = mergedItems
        self.favorites = favorites.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    func noteViewed(_ nasa: NASA) {
        var merged = Dictionary(uniqueKeysWithValues: cachedItems.map { ($0.id, $0) })
        merged[nasa.id] = nasa
        cachedItems = merged.values.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }
}

struct UserDefaultsAPODLibraryStorage: APODLibraryStorage, APODLibraryStateStorage {
    private static let favoritesKey = "nasa.favorite.items.v2"
    private static let archiveKey = "nasa.apod.cache.items.v2"

    func loadFavorites() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.favoritesKey),
            let favorites = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return favorites.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    func saveFavorites(_ favorites: [NASA]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: Self.favoritesKey)
    }

    func loadCachedAPODItems() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.archiveKey),
            let items = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return items.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.archiveKey)
    }

    func sync(items: [NASA], favorites: [NASA], currentID: String?, limit: Int) {
        let mergedItems = mergedArchiveItems(
            existingItems: loadCachedAPODItems(),
            incomingItems: items,
            favorites: favorites,
            currentID: currentID,
            limit: limit
        )

        saveCachedAPODItems(mergedItems)
        saveFavorites(favorites.sorted { ($0.date ?? "") > ($1.date ?? "") })
    }

    func noteViewed(_ nasa: NASA) {
        let mergedItems = mergedArchiveItems(
            existingItems: loadCachedAPODItems(),
            incomingItems: [nasa],
            favorites: loadFavorites(),
            currentID: nasa.id,
            limit: Int.max
        )
        saveCachedAPODItems(mergedItems)
    }
}

#if canImport(SwiftData)
@available(iOS 17.0, *)
@Model
private final class StoredAPODRecord {
    @Attribute(.unique) var id: String
    var copyrightText: String?
    var date: String?
    var explanation: String?
    var fetchedAt: Date
    var hdurlString: String?
    var isFavorite: Bool
    var lastViewedAt: Date?
    var mediaTypeRawValue: String
    var serviceVersion: String?
    var title: String?
    var urlString: String?

    init(from nasa: NASA, fetchedAt: Date, isFavorite: Bool = false, lastViewedAt: Date? = nil) {
        id = nasa.id
        copyrightText = nasa.copyright
        date = nasa.date
        explanation = nasa.explanation
        self.fetchedAt = fetchedAt
        hdurlString = nasa.hdurl?.absoluteString
        self.isFavorite = isFavorite
        self.lastViewedAt = lastViewedAt
        mediaTypeRawValue = nasa.mediaType.rawValue
        serviceVersion = nasa.serviceVersion
        title = nasa.title
        urlString = nasa.url?.absoluteString
    }

    func update(from nasa: NASA, fetchedAt: Date? = nil) {
        copyrightText = nasa.copyright
        date = nasa.date
        explanation = nasa.explanation
        hdurlString = nasa.hdurl?.absoluteString
        mediaTypeRawValue = nasa.mediaType.rawValue
        serviceVersion = nasa.serviceVersion
        title = nasa.title
        urlString = nasa.url?.absoluteString
        if let fetchedAt {
            self.fetchedAt = fetchedAt
        }
    }

    var nasa: NASA {
        NASA(
            copyright: copyrightText,
            date: date,
            explanation: explanation,
            hdurl: hdurlString.flatMap(URL.init(string:)),
            mediaType: MediaType(rawValue: mediaTypeRawValue) ?? .other,
            serviceVersion: serviceVersion,
            title: title,
            url: urlString.flatMap(URL.init(string:))
        )
    }
}

@available(iOS 17.0, *)
final class SwiftDataAPODLibraryStorage: APODLibraryStorage, APODLibraryStateStorage {
    private let container: ModelContainer
    private let legacyStorage: UserDefaultsAPODLibraryStorage
    private let nowProvider: () -> Date

    init(
        legacyStorage: UserDefaultsAPODLibraryStorage,
        nowProvider: @escaping () -> Date = { Date() }
    ) throws {
        self.container = try ModelContainer(for: StoredAPODRecord.self)
        self.legacyStorage = legacyStorage
        self.nowProvider = nowProvider
        migrateLegacyDataIfNeeded()
    }

    func loadFavorites() -> [NASA] {
        let descriptor = FetchDescriptor<StoredAPODRecord>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? makeContext().fetch(descriptor).map(\.nasa)) ?? []
    }

    func saveFavorites(_ favorites: [NASA]) {
        sync(
            items: loadCachedAPODItems(),
            favorites: favorites,
            currentID: nil,
            limit: Int.max
        )
    }

    func loadCachedAPODItems() -> [NASA] {
        let descriptor = FetchDescriptor<StoredAPODRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? makeContext().fetch(descriptor).map(\.nasa)) ?? []
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        sync(
            items: items,
            favorites: loadFavorites(),
            currentID: nil,
            limit: Int.max
        )
    }

    func sync(items: [NASA], favorites: [NASA], currentID: String?, limit: Int) {
        let context = makeContext()
        let favoriteIDs = Set(favorites.map(\.id))
        let now = nowProvider()
        let currentRecordID = currentID

        guard let records = try? context.fetch(FetchDescriptor<StoredAPODRecord>()) else {
            return
        }

        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        for item in items {
            if let record = recordsByID[item.id] {
                record.update(from: item, fetchedAt: now)
                record.isFavorite = favoriteIDs.contains(item.id)
                if currentRecordID == item.id {
                    record.lastViewedAt = now
                }
            } else {
                let record = StoredAPODRecord(
                    from: item,
                    fetchedAt: now,
                    isFavorite: favoriteIDs.contains(item.id),
                    lastViewedAt: currentRecordID == item.id ? now : nil
                )
                context.insert(record)
                recordsByID[item.id] = record
            }
        }

        for favorite in favorites where recordsByID[favorite.id] == nil {
            let record = StoredAPODRecord(
                from: favorite,
                fetchedAt: now,
                isFavorite: true,
                lastViewedAt: currentRecordID == favorite.id ? now : nil
            )
            context.insert(record)
            recordsByID[favorite.id] = record
        }

        for record in recordsByID.values {
            record.isFavorite = favoriteIDs.contains(record.id)
            if currentRecordID == record.id {
                record.lastViewedAt = now
            }
        }

        trimIfNeeded(
            recordsByID: recordsByID,
            context: context,
            currentID: currentRecordID,
            limit: limit
        )

        try? context.save()
    }

    func noteViewed(_ nasa: NASA) {
        let context = makeContext()
        let descriptor = FetchDescriptor<StoredAPODRecord>(
            predicate: #Predicate { $0.id == nasa.id }
        )
        let now = nowProvider()

        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: nasa)
            existing.lastViewedAt = now
        } else {
            let record = StoredAPODRecord(from: nasa, fetchedAt: now, lastViewedAt: now)
            context.insert(record)
        }

        try? context.save()
    }

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    private func trimIfNeeded(
        recordsByID: [String: StoredAPODRecord],
        context: ModelContext,
        currentID: String?,
        limit: Int
    ) {
        guard limit != Int.max else { return }
        guard recordsByID.count > limit else { return }

        let protectedIDs = Set(loadFavorites().map(\.id)).union(currentID.map { [$0] } ?? [])
        let rankedRecords = recordsByID.values.sorted { lhs, rhs in
            let lhsScore = recordScore(lhs, protectedIDs: protectedIDs)
            let rhsScore = recordScore(rhs, protectedIDs: protectedIDs)

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            let lhsDate = lhs.lastViewedAt ?? lhs.fetchedAt
            let rhsDate = rhs.lastViewedAt ?? rhs.fetchedAt
            return lhsDate > rhsDate
        }

        let recordsToDelete = rankedRecords.dropFirst(limit)
        for record in recordsToDelete where !protectedIDs.contains(record.id) {
            context.delete(record)
        }
    }

    private func recordScore(_ record: StoredAPODRecord, protectedIDs: Set<String>) -> Int {
        var score = 0
        if protectedIDs.contains(record.id) { score += 1000 }
        if record.isFavorite { score += 500 }
        if record.lastViewedAt != nil { score += 100 }
        return score
    }

    private func migrateLegacyDataIfNeeded() {
        let migratedKey = "nasa.apod.library.swiftdata.migrated.v1"
        if UserDefaults.standard.bool(forKey: migratedKey) {
            return
        }

        let legacyItems = legacyStorage.loadCachedAPODItems()
        let legacyFavorites = legacyStorage.loadFavorites()

        if !legacyItems.isEmpty || !legacyFavorites.isEmpty {
            sync(
                items: legacyItems,
                favorites: legacyFavorites,
                currentID: nil,
                limit: Int.max
            )
        }

        UserDefaults.standard.set(true, forKey: migratedKey)
    }
}
#endif

private func mergedArchiveItems(
    existingItems: [NASA],
    incomingItems: [NASA],
    favorites: [NASA],
    currentID: String?,
    limit: Int
) -> [NASA] {
    var mergedItems = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

    for item in incomingItems {
        mergedItems[item.id] = item
    }

    for favorite in favorites {
        mergedItems[favorite.id] = favorite
    }

    let sortedItems = mergedItems.values.sorted { ($0.date ?? "") < ($1.date ?? "") }
    guard limit != Int.max, sortedItems.count > limit else {
        return sortedItems
    }

    let protectedIDs = Set(favorites.map(\.id)).union(currentID.map { [$0] } ?? [])
    let protectedItems = sortedItems.filter { protectedIDs.contains($0.id) }
    let evictableItems = sortedItems.filter { !protectedIDs.contains($0.id) }
    let availableSlots = max(0, limit - protectedItems.count)
    let retained = Array(evictableItems.suffix(availableSlots)) + protectedItems

    return Dictionary(uniqueKeysWithValues: retained.map { ($0.id, $0) })
        .values
        .sorted { ($0.date ?? "") < ($1.date ?? "") }
}
