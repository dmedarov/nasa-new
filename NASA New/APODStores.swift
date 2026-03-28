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

final class VolatileAPODCacheStorage: APODCacheStorage {
    private var items: [NASA]

    init(initialItems: [NASA] = []) {
        self.items = initialItems
    }

    func loadCachedAPODItems() -> [NASA] {
        items
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        self.items = items
    }
}

enum APODCacheStorageFactory {
    static func makeDefault() -> APODCacheStorage {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return VolatileAPODCacheStorage()
        }

#if canImport(SwiftData)
        if #available(iOS 17.0, *),
           let storage = try? SwiftDataAPODCacheStorage(legacyStorage: UserDefaultsAPODCacheStorage()) {
            return storage
        }
#endif
        return UserDefaultsAPODCacheStorage()
    }
}

struct UserDefaultsFavoritesStorage: FavoritesStorage {
    private static let key = "nasa.favorite.items.v1"

    func loadFavorites() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let favorites = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return favorites
    }

    func saveFavorites(_ favorites: [NASA]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

struct UserDefaultsAPODCacheStorage: APODCacheStorage {
    private static let key = "nasa.apod.cache.items.v1"

    func loadCachedAPODItems() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let items = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return items
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

#if canImport(SwiftData)
@available(iOS 17.0, *)
@Model
private final class CachedAPODRecord {
    @Attribute(.unique) var id: String
    var copyrightText: String?
    var date: String?
    var explanation: String?
    var hdurlString: String?
    var mediaTypeRawValue: String
    var serviceVersion: String?
    var title: String?
    var urlString: String?

    init(from nasa: NASA) {
        id = nasa.id
        copyrightText = nasa.copyright
        date = nasa.date
        explanation = nasa.explanation
        hdurlString = nasa.hdurl?.absoluteString
        mediaTypeRawValue = nasa.mediaType.rawValue
        serviceVersion = nasa.serviceVersion
        title = nasa.title
        urlString = nasa.url?.absoluteString
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
final class SwiftDataAPODCacheStorage: APODCacheStorage {
    private let container: ModelContainer
    private let legacyStorage: APODCacheStorage

    init(legacyStorage: APODCacheStorage) throws {
        container = try ModelContainer(for: CachedAPODRecord.self)
        self.legacyStorage = legacyStorage
        migrateLegacyCacheIfNeeded()
    }

    func loadCachedAPODItems() -> [NASA] {
        let context = makeContext()
        let descriptor = FetchDescriptor<CachedAPODRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        guard let records = try? context.fetch(descriptor) else { return [] }
        return records.map(\.nasa)
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        let context = makeContext()
        guard let existingRecords = try? context.fetch(FetchDescriptor<CachedAPODRecord>()) else {
            return
        }

        for record in existingRecords {
            context.delete(record)
        }

        for item in items {
            context.insert(CachedAPODRecord(from: item))
        }

        try? context.save()
    }

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    private func migrateLegacyCacheIfNeeded() {
        let migratedKey = "nasa.apod.cache.swiftdata.migrated.v1"
        if UserDefaults.standard.bool(forKey: migratedKey) {
            return
        }

        let legacyItems = legacyStorage.loadCachedAPODItems()
        if !legacyItems.isEmpty, loadCachedAPODItems().isEmpty {
            saveCachedAPODItems(legacyItems)
        }

        UserDefaults.standard.set(true, forKey: migratedKey)
    }
}
#endif
