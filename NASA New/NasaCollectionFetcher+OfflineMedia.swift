import Foundation

extension NasaCollectionFetcher {
    var savedOfflineItemCount: Int {
        offlineMediaStorageSummary.fullyOfflineCount
    }

    var savedPreviewItemCount: Int {
        offlineMediaStorageSummary.previewCount
    }

    var offlineMediaStorageSummary: APODOfflineMediaStorageSummary {
        favorites.reduce(into: APODOfflineMediaStorageSummary()) { result, item in
            result.register(offlineMediaAsset(for: item))
        }
    }

    var offlineMediaLibraryState: APODOfflineMediaLibraryState {
        APODOfflineMediaLibraryState(summary: offlineMediaStorageSummary)
    }

    func offlineMediaAsset(for nasa: NASA) -> APODOfflineMediaAsset? {
        offlineMediaAssetsByID[nasa.id]
    }

    func offlineMediaState(for nasa: NASA, isSaved: Bool? = nil) -> APODOfflineMediaItemState {
        APODOfflineMediaItemState(
            mediaType: nasa.mediaType,
            asset: offlineMediaAsset(for: nasa),
            isSaved: isSaved ?? isFavorite(nasa)
        )
    }

    func localMediaURL(for nasa: NASA) -> URL? {
        offlineMediaAsset(for: nasa)?.state.localAssetURL
    }

    func localPreviewURL(for nasa: NASA) -> URL? {
        offlineMediaAsset(for: nasa)?.state.localPreviewURL
    }

    func bootstrapOfflineMediaState() async {
        offlineMediaAssetsByID = await offlineMediaStore.loadRecords()

        guard !favorites.isEmpty else { return }
        let favoritesSnapshot = favorites
        let preferences = currentOfflineMediaPreferences()
        markOfflineMediaSyncInProgress(for: favoritesSnapshot)
        offlineMediaAssetsByID = await offlineMediaStore.synchronizeFavorites(
            favoritesSnapshot,
            preferences: preferences
        )
    }

    func queueOfflineMediaSynchronization(marking items: [NASA]? = nil) {
        let favoritesSnapshot = favorites
        let preferences = currentOfflineMediaPreferences()
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

    func clearOfflineMedia() async {
        offlineMediaSyncTask?.cancel()
        offlineMediaAssetsByID = await offlineMediaStore.clearRecords()
    }

    func rebuildOfflineMedia() async {
        offlineMediaSyncTask?.cancel()
        await clearOfflineMedia()

        guard !favorites.isEmpty else { return }

        let favoritesSnapshot = favorites
        let preferences = currentOfflineMediaPreferences()
        markOfflineMediaSyncInProgress(for: favoritesSnapshot)
        offlineMediaAssetsByID = await offlineMediaStore.synchronizeFavorites(
            favoritesSnapshot,
            preferences: preferences
        )
    }

    private func markOfflineMediaSyncInProgress(for items: [NASA]) {
        guard !items.isEmpty else { return }

        let preferences = currentOfflineMediaPreferences()

        for item in items {
            let currentRecord = offlineMediaAssetsByID[item.id]

            if currentRecord?.state.hasStoredLocalMedia == true {
                continue
            }

            let remoteSourceURL = APODSourceLinkPolicy.preferredMediaURL(
                for: item,
                dataSaverMode: preferences.dataSaverMode,
                preferHDImages: preferences.preferHDImages
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

    private func currentOfflineMediaPreferences() -> APODOfflineMediaPreferences {
        APODOfflineMediaPreferences.current()
    }
}
