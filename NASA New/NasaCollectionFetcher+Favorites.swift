import Foundation

extension NasaCollectionFetcher {
    var archiveItems: [NASA] {
        apodData.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    func apodItem(forAPODDate dateString: String) -> NASA? {
        apodData.first(where: { $0.date == dateString })
            ?? favorites.first(where: { $0.date == dateString })
    }

    func selectRandom(preferImagesOnly: Bool) {
        let candidates = preferImagesOnly ? apodData.filter { $0.mediaType == .image } : apodData
        let nonCurrentCandidates = candidates.filter { $0.id != currentNasa.id }
        let pool = nonCurrentCandidates.isEmpty ? candidates : nonCurrentCandidates
        guard let random = pool.randomElement() else { return }
        currentNasa = random
    }

    func clearError() {
        error = nil
    }

    func isFavorite(_ nasa: NASA) -> Bool {
        favorites.contains(where: { $0.id == nasa.id })
    }

    func toggleFavorite(_ nasa: NASA) {
        if let index = favorites.firstIndex(where: { $0.id == nasa.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(nasa)
        }
        sortFavorites()
        persistLibraryState()
    }

    func removeFavorite(_ nasa: NASA) {
        guard let index = favorites.firstIndex(where: { $0.id == nasa.id }) else { return }
        favorites.remove(at: index)
        persistLibraryState()
    }

    func selectArchivedItem(_ nasa: NASA) {
        currentNasa = nasa
        if let index = apodData.firstIndex(where: { $0.id == nasa.id }) {
            apodData[index] = nasa
        } else {
            apodData.append(nasa)
            apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
        }
        persistLibraryState()
    }

    func selectFavorite(_ nasa: NASA) {
        selectArchivedItem(nasa)
    }

    func recordPresentedItem(_ nasa: NASA) {
        currentNasa = nasa
        if !apodData.contains(where: { $0.id == nasa.id }) {
            apodData.append(nasa)
            apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
        }

        if let libraryStorage = cacheStorage as? APODLibraryStateStorage {
            libraryStorage.noteViewed(nasa)
            apodData = cacheStorage.loadCachedAPODItems().sorted { ($0.date ?? "") < ($1.date ?? "") }
        } else {
            cacheStorage.saveCachedAPODItems(apodData)
        }

        cachedItemCount = apodData.count
        AppDiscoveryCoordinator.refreshSearchIndex(archive: archiveItems, favorites: favorites)
        AppWidgetRefreshCoordinator.reloadSharedTimelines()
    }

    func refreshFavoriteIfNeeded(with item: NASA) {
        guard let index = favorites.firstIndex(where: { $0.id == item.id }) else { return }
        favorites[index] = item
        sortFavorites()
    }

    func refreshFavoritesFromData(_ items: [NASA]) {
        var didChange = false
        for item in items {
            if let index = favorites.firstIndex(where: { $0.id == item.id }) {
                favorites[index] = item
                didChange = true
            }
        }
        if didChange {
            sortFavorites()
        }
    }

    func sortFavorites() {
        favorites.sort { ($0.date ?? "") > ($1.date ?? "") }
    }

    func trimCacheIfNeeded() {
        guard apodData.count > cacheItemLimit else { return }
        apodData = Array(apodData.suffix(cacheItemLimit))
        if !apodData.contains(where: { $0.id == currentNasa.id }) {
            currentNasa = apodData.last ?? .default
        }
    }

    func persistLibraryState() {
        if let libraryStorage = cacheStorage as? APODLibraryStateStorage {
            libraryStorage.sync(
                items: apodData,
                favorites: favorites,
                currentID: currentNasa.id,
                limit: cacheItemLimit
            )
            apodData = cacheStorage.loadCachedAPODItems().sorted { ($0.date ?? "") < ($1.date ?? "") }
        } else {
            trimCacheIfNeeded()
            cacheStorage.saveCachedAPODItems(apodData)
            favoritesStorage.saveFavorites(favorites)
        }

        if !(favoritesStorage is APODLibraryStateStorage) {
            favoritesStorage.saveFavorites(favorites)
        }

        cachedItemCount = apodData.count
        AppDiscoveryCoordinator.refreshSearchIndex(archive: archiveItems, favorites: favorites)
        AppWidgetRefreshCoordinator.reloadSharedTimelines()
    }
}
