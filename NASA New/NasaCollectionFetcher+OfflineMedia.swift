import Foundation

extension NasaCollectionFetcher {
    var savedOfflineItemCount: Int {
        favorites.reduce(into: 0) { result, item in
            if offlineMediaAsset(for: item)?.availability == .availableOffline {
                result += 1
            }
        }
    }

    var savedPreviewItemCount: Int {
        favorites.reduce(into: 0) { result, item in
            if offlineMediaAsset(for: item)?.availability == .previewOffline {
                result += 1
            }
        }
    }

    func offlineMediaAsset(for nasa: NASA) -> APODOfflineMediaAsset? {
        offlineMediaAssetsByID[nasa.id]
    }

    func localMediaURL(for nasa: NASA) -> URL? {
        offlineMediaAsset(for: nasa)?.localAssetURL
    }

    func localPreviewURL(for nasa: NASA) -> URL? {
        offlineMediaAsset(for: nasa)?.localPreviewURL
    }

    func bootstrapOfflineMediaState() async {
        offlineMediaAssetsByID = await offlineMediaStore.loadRecords()

        guard !favorites.isEmpty else { return }
        let favoritesSnapshot = favorites
        let preferences = APODOfflineMediaPreferences.current()
        markOfflineMediaSyncInProgress(for: favoritesSnapshot)
        offlineMediaAssetsByID = await offlineMediaStore.synchronizeFavorites(
            favoritesSnapshot,
            preferences: preferences
        )
    }

    func queueOfflineMediaSynchronization(marking items: [NASA]? = nil) {
        let favoritesSnapshot = favorites
        let preferences = APODOfflineMediaPreferences.current()
        let offlineMediaStore = self.offlineMediaStore
        let itemsToMark = items ?? favoritesSnapshot

        markOfflineMediaSyncInProgress(for: itemsToMark)

        offlineMediaSyncTask?.cancel()
        offlineMediaSyncTask = Task { [weak self, favoritesSnapshot, preferences] in
            let records = await offlineMediaStore.synchronizeFavorites(
                favoritesSnapshot,
                preferences: preferences
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.offlineMediaAssetsByID = records
            }
        }
    }

    private func markOfflineMediaSyncInProgress(for items: [NASA]) {
        guard !items.isEmpty else { return }

        for item in items {
            let currentRecord = offlineMediaAssetsByID[item.id]

            if currentRecord?.availability == .availableOffline || currentRecord?.availability == .previewOffline {
                continue
            }

            let remoteSourceURL = APODSourceLinkPolicy.preferredMediaURL(
                for: item,
                dataSaverMode: APODOfflineMediaPreferences.current().dataSaverMode,
                preferHDImages: APODOfflineMediaPreferences.current().preferHDImages
            )

            offlineMediaAssetsByID[item.id] = APODOfflineMediaAsset(
                apodID: item.id,
                mediaType: item.mediaType,
                remoteSourceURL: remoteSourceURL ?? item.url ?? item.hdurl,
                availability: .syncing,
                updatedAt: Date()
            )
        }

        let favoriteIDs = Set(favorites.map(\.id))
        offlineMediaAssetsByID = offlineMediaAssetsByID.filter { favoriteIDs.contains($0.key) }
    }
}
