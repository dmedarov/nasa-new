import Foundation

protocol FavoritesStorage {
    func loadFavorites() -> [NASA]
    func saveFavorites(_ favorites: [NASA])
}

protocol APODCacheStorage {
    func loadCachedAPODItems() -> [NASA]
    func saveCachedAPODItems(_ items: [NASA])
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
