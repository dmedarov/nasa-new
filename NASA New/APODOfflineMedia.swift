import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct APODOfflineMediaPreferences: Sendable, Equatable {
    let dataSaverMode: Bool
    let preferHDImages: Bool

    static func current(userDefaults: UserDefaults = .standard) -> Self {
        let dataSaverMode = userDefaults.bool(forKey: "dataSaverMode")
        let preferredValue = userDefaults.object(forKey: "preferHDImages") as? Bool ?? true

        return Self(
            dataSaverMode: dataSaverMode,
            preferHDImages: DataSaverPreferencePolicy.resolvedPreferHDImages(
                dataSaverMode: dataSaverMode,
                preferHDImages: preferredValue
            )
        )
    }
}

enum APODOfflineMediaAvailability: String, Codable, Hashable, Sendable {
    case remoteOnly
    case syncing
    case availableOffline
    case previewOffline
    case failed
}

enum APODOfflineMediaState: Hashable, Sendable {
    case sourceRequired(remoteSourceURL: URL?)
    case saving(remoteSourceURL: URL?)
    case full(localAssetURL: URL, remoteSourceURL: URL?)
    case preview(localPreviewURL: URL, remoteSourceURL: URL?)
    case failed(remoteSourceURL: URL?, message: String?)

    var availability: APODOfflineMediaAvailability {
        switch self {
        case .sourceRequired:
            return .remoteOnly
        case .saving:
            return .syncing
        case .full:
            return .availableOffline
        case .preview:
            return .previewOffline
        case .failed:
            return .failed
        }
    }

    var hasStoredLocalMedia: Bool {
        switch self {
        case .full, .preview:
            return true
        case .sourceRequired, .saving, .failed:
            return false
        }
    }

    var localAssetURL: URL? {
        switch self {
        case .full(let localAssetURL, _):
            return localAssetURL
        case .sourceRequired, .saving, .preview, .failed:
            return nil
        }
    }

    var localPreviewURL: URL? {
        switch self {
        case .full(let localAssetURL, _):
            return localAssetURL
        case .preview(let localPreviewURL, _):
            return localPreviewURL
        case .sourceRequired, .saving, .failed:
            return nil
        }
    }

    var countsAsSourceBacked: Bool {
        switch self {
        case .sourceRequired, .saving, .failed:
            return true
        case .full, .preview:
            return false
        }
    }
}

struct APODOfflineMediaAsset: Codable, Hashable, Sendable {
    let apodID: String
    let mediaTypeRawValue: String
    let remoteSourceURLString: String?
    let localAssetRelativePath: String?
    let localPreviewRelativePath: String?
    let availabilityRawValue: String
    let byteCount: Int64
    let updatedAt: Date?
    let errorDescription: String?

    init(
        apodID: String,
        mediaType: MediaType,
        remoteSourceURL: URL?,
        localAssetRelativePath: String? = nil,
        localPreviewRelativePath: String? = nil,
        availability: APODOfflineMediaAvailability,
        byteCount: Int64 = 0,
        updatedAt: Date? = nil,
        errorDescription: String? = nil
    ) {
        self.apodID = apodID
        mediaTypeRawValue = mediaType.rawValue
        remoteSourceURLString = remoteSourceURL?.absoluteString
        self.localAssetRelativePath = localAssetRelativePath
        self.localPreviewRelativePath = localPreviewRelativePath
        availabilityRawValue = availability.rawValue
        self.byteCount = byteCount
        self.updatedAt = updatedAt
        self.errorDescription = errorDescription
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRawValue) ?? .other
    }

    var availability: APODOfflineMediaAvailability {
        APODOfflineMediaAvailability(rawValue: availabilityRawValue) ?? .remoteOnly
    }

    var remoteSourceURL: URL? {
        remoteSourceURLString.flatMap(URL.init(string:))
    }

    var localAssetURL: URL? {
        AppGroupConfiguration.sharedFileURL(for: localAssetRelativePath)
    }

    var localPreviewURL: URL? {
        if let localPreviewRelativePath {
            return AppGroupConfiguration.sharedFileURL(for: localPreviewRelativePath)
        }
        if mediaType == .image {
            return localAssetURL
        }
        return nil
    }

    var state: APODOfflineMediaState {
        switch availability {
        case .availableOffline:
            if let localAssetURL {
                return .full(localAssetURL: localAssetURL, remoteSourceURL: remoteSourceURL)
            }
        case .previewOffline:
            if let localPreviewURL {
                return .preview(localPreviewURL: localPreviewURL, remoteSourceURL: remoteSourceURL)
            }
        case .syncing:
            return .saving(remoteSourceURL: remoteSourceURL)
        case .failed:
            return .failed(remoteSourceURL: remoteSourceURL, message: errorDescription)
        case .remoteOnly:
            break
        }

        return .sourceRequired(remoteSourceURL: remoteSourceURL)
    }
}

struct APODOfflineMediaStorageSummary: Equatable, Sendable {
    var fullyOfflineCount = 0
    var previewCount = 0
    var remoteOnlyCount = 0
    var syncingCount = 0
    var failedCount = 0
    var totalByteCount: Int64 = 0
    var lastUpdatedAt: Date?

    var totalManagedItemCount: Int {
        fullyOfflineCount + previewCount + remoteOnlyCount + syncingCount + failedCount
    }

    var hasStoredLocalMedia: Bool {
        fullyOfflineCount > 0 || previewCount > 0 || totalByteCount > 0
    }

    var canClearStorage: Bool {
        hasStoredLocalMedia || syncingCount > 0 || failedCount > 0
    }

    mutating func register(_ asset: APODOfflineMediaAsset?) {
        let state = asset?.state ?? .sourceRequired(remoteSourceURL: nil)

        switch state {
        case .full:
            fullyOfflineCount += 1
            totalByteCount += max(asset?.byteCount ?? 0, 0)
        case .preview:
            previewCount += 1
            totalByteCount += max(asset?.byteCount ?? 0, 0)
        case .sourceRequired:
            remoteOnlyCount += 1
        case .saving:
            syncingCount += 1
        case .failed:
            failedCount += 1
        }

        if let updatedAt = asset?.updatedAt {
            lastUpdatedAt = max(lastUpdatedAt ?? updatedAt, updatedAt)
        }
    }
}

protocol APODOfflineMediaStore: Sendable {
    func loadRecords() async -> [String: APODOfflineMediaAsset]
    func synchronizeFavorites(
        _ favorites: [NASA],
        preferences: APODOfflineMediaPreferences
    ) async -> [String: APODOfflineMediaAsset]
    func clearRecords() async -> [String: APODOfflineMediaAsset]
}

actor SharedAPODOfflineMediaStore: APODOfflineMediaStore {
    private static let recordsKey = "nasa.apod.offline-media.records.v1"

    private let downloadService: APODDownloadService
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let rootDirectoryURL: URL

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = AppGroupConfiguration.sharedUserDefaults,
        fileManager: FileManager = .default,
        rootDirectoryURL: URL? = nil
    ) {
        downloadService = APODDownloadService(session: session, fileManager: fileManager)
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.rootDirectoryURL = rootDirectoryURL ?? AppGroupConfiguration.sharedOfflineMediaDirectoryURL
    }

    func loadRecords() async -> [String: APODOfflineMediaAsset] {
        let sanitized = sanitizePersistedRecords(loadPersistedRecords())
        persist(sanitized)
        return sanitized
    }

    func synchronizeFavorites(
        _ favorites: [NASA],
        preferences: APODOfflineMediaPreferences
    ) async -> [String: APODOfflineMediaAsset] {
        var records = sanitizePersistedRecords(loadPersistedRecords())
        let favoriteIDs = Set(favorites.map(\.id))

        for (id, record) in records where !favoriteIDs.contains(id) {
            removeFiles(for: record)
            records.removeValue(forKey: id)
        }

        for favorite in favorites {
            records[favorite.id] = await synchronizedRecord(
                for: favorite,
                existing: records[favorite.id],
                preferences: preferences
            )
        }

        let sanitized = sanitizePersistedRecords(records)
        persist(sanitized)
        return sanitized
    }

    func clearRecords() async -> [String: APODOfflineMediaAsset] {
        offlineMediaFiles().forEach { fileURL in
            removeFileIfPresent(at: fileURL)
        }
        removeRootDirectoryIfPresent()
        userDefaults.removeObject(forKey: Self.recordsKey)
        return [:]
    }

    private func synchronizedRecord(
        for nasa: NASA,
        existing: APODOfflineMediaAsset?,
        preferences: APODOfflineMediaPreferences
    ) async -> APODOfflineMediaAsset {
        let plan = APODOfflineMediaPlanningPolicy.plan(for: nasa, preferences: preferences)

        switch plan.mode {
        case .remoteOnly:
            if let existing {
                removeFiles(for: existing)
            }
            return APODOfflineMediaAsset(
                apodID: nasa.id,
                mediaType: nasa.mediaType,
                remoteSourceURL: plan.remoteSourceURL,
                availability: .remoteOnly,
                updatedAt: Date()
            )

        case .fullAsset, .previewOnly:
            guard let remoteSourceURL = plan.remoteSourceURL else {
                return APODOfflineMediaAsset(
                    apodID: nasa.id,
                    mediaType: nasa.mediaType,
                    remoteSourceURL: nil,
                    availability: .remoteOnly,
                    updatedAt: Date()
                )
            }

            if let existing,
               existing.remoteSourceURLString == remoteSourceURL.absoluteString,
               existing.availability == plan.resultingAvailability,
               hasUsableLocalFiles(for: existing, expectedAvailability: plan.resultingAvailability) {
                return existing
            }

            if let existing {
                removeFiles(for: existing)
            }

            do {
                try ensureRootDirectory()
                let download = try await downloadAsset(
                    from: remoteSourceURL,
                    fileStem: sanitizedStem(for: nasa.id, suffix: plan.fileStemSuffix),
                    validation: plan.validation
                )

                return APODOfflineMediaAsset(
                    apodID: nasa.id,
                    mediaType: nasa.mediaType,
                    remoteSourceURL: remoteSourceURL,
                    localAssetRelativePath: plan.mode == .fullAsset ? download.relativePath : nil,
                    localPreviewRelativePath: plan.mode == .previewOnly ? download.relativePath : nil,
                    availability: plan.resultingAvailability,
                    byteCount: download.byteCount,
                    updatedAt: Date()
                )
            } catch {
                if let existing,
                   hasUsableLocalFiles(for: existing, expectedAvailability: existing.availability) {
                    return existing
                }

                return APODOfflineMediaAsset(
                    apodID: nasa.id,
                    mediaType: nasa.mediaType,
                    remoteSourceURL: remoteSourceURL,
                    availability: .failed,
                    updatedAt: Date(),
                    errorDescription: error.localizedDescription
                )
            }
        }
    }

    private func loadPersistedRecords() -> [String: APODOfflineMediaAsset] {
        guard
            let data = userDefaults.data(forKey: Self.recordsKey),
            let records = try? JSONDecoder().decode([String: APODOfflineMediaAsset].self, from: data)
        else {
            return [:]
        }
        return records
    }

    private func persist(_ records: [String: APODOfflineMediaAsset]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        userDefaults.set(data, forKey: Self.recordsKey)
    }

    private func sanitizePersistedRecords(_ records: [String: APODOfflineMediaAsset]) -> [String: APODOfflineMediaAsset] {
        var sanitized = records

        for (id, record) in records {
            if !hasUsableLocalFiles(for: record, expectedAvailability: record.availability),
               record.availability == .availableOffline || record.availability == .previewOffline {
                sanitized[id] = APODOfflineMediaAsset(
                    apodID: record.apodID,
                    mediaType: record.mediaType,
                    remoteSourceURL: record.remoteSourceURL,
                    availability: .remoteOnly,
                    updatedAt: record.updatedAt
                )
            }
        }

        return sanitized
    }

    private func ensureRootDirectory() throws {
        try fileManager.createDirectory(
            at: rootDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func hasUsableLocalFiles(
        for record: APODOfflineMediaAsset,
        expectedAvailability: APODOfflineMediaAvailability
    ) -> Bool {
        switch expectedAvailability {
        case .availableOffline:
            guard let localAssetRelativePath = record.localAssetRelativePath else { return false }
            return fileExists(for: localAssetRelativePath)
        case .previewOffline:
            guard let localPreviewRelativePath = record.localPreviewRelativePath else { return false }
            return fileExists(for: localPreviewRelativePath)
        case .remoteOnly, .syncing, .failed:
            return false
        }
    }

    private func fileExists(for relativePath: String) -> Bool {
        let fileURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    private func removeFiles(for record: APODOfflineMediaAsset) {
        let candidatePaths = Set([
            record.localAssetRelativePath,
            record.localPreviewRelativePath
        ].compactMap { $0 })

        for relativePath in candidatePaths {
            let fileURL = rootDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
            removeFileIfPresent(at: fileURL)
        }
    }

    private func offlineMediaFiles() -> [URL] {
        guard let recordsData = userDefaults.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([String: APODOfflineMediaAsset].self, from: recordsData) else {
            return []
        }

        return Array(
            Set(
                records.values.flatMap { record in
                    [record.localAssetRelativePath, record.localPreviewRelativePath]
                        .compactMap { $0 }
                        .map { rootDirectoryURL.appendingPathComponent($0, isDirectory: false) }
                }
            )
        )
    }

    private func removeRootDirectoryIfPresent() {
        guard fileManager.fileExists(atPath: rootDirectoryURL.path) else { return }
        try? fileManager.removeItem(at: rootDirectoryURL)
    }

    private func removeFileIfPresent(at fileURL: URL) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    private func sanitizedStem(for identifier: String, suffix: String) -> String {
        let safeIdentifier = identifier
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = safeIdentifier.isEmpty ? "apod" : safeIdentifier
        return "\(base)-\(suffix)"
    }

    private func downloadAsset(
        from remoteURL: URL,
        fileStem: String,
        validation: APODDownloadValidation?
    ) async throws -> (relativePath: String, byteCount: Int64) {
        guard let validation else {
            throw APODDownloadService.DownloadError.invalidResponse
        }

        let downloadedFile = try await downloadService.download(
            from: remoteURL,
            to: rootDirectoryURL,
            fileStem: fileStem,
            validation: validation
        )

        return (downloadedFile.fileURL.lastPathComponent, downloadedFile.byteCount)
    }
}

private enum APODOfflineMediaDownloadMode {
    case remoteOnly
    case fullAsset
    case previewOnly
}

private struct APODOfflineMediaDownloadPlan {
    let mode: APODOfflineMediaDownloadMode
    let remoteSourceURL: URL?
    let validation: APODDownloadValidation?
    let fileStemSuffix: String

    var resultingAvailability: APODOfflineMediaAvailability {
        switch mode {
        case .remoteOnly:
            return .remoteOnly
        case .fullAsset:
            return .availableOffline
        case .previewOnly:
            return .previewOffline
        }
    }
}

private enum APODOfflineMediaPlanningPolicy {
    static func plan(for nasa: NASA, preferences: APODOfflineMediaPreferences) -> APODOfflineMediaDownloadPlan {
        switch nasa.mediaType {
        case .image:
            let preferredURL = APODSourceLinkPolicy.preferredMediaURL(
                for: nasa,
                dataSaverMode: preferences.dataSaverMode,
                preferHDImages: preferences.preferHDImages
            )
            return APODOfflineMediaDownloadPlan(
                mode: preferredURL == nil ? .remoteOnly : .fullAsset,
                remoteSourceURL: preferredURL,
                validation: .offlineImageAsset,
                fileStemSuffix: "asset"
            )

        case .video:
            if let previewURL = youtubeThumbnailURL(for: nasa.url) {
                return APODOfflineMediaDownloadPlan(
                    mode: .previewOnly,
                    remoteSourceURL: previewURL,
                    validation: .offlinePreviewImage,
                    fileStemSuffix: "preview"
                )
            }

            return APODOfflineMediaDownloadPlan(
                mode: .remoteOnly,
                remoteSourceURL: nasa.url,
                validation: nil,
                fileStemSuffix: "asset"
            )

        case .other:
            return APODOfflineMediaDownloadPlan(
                mode: .remoteOnly,
                remoteSourceURL: nasa.url ?? nasa.hdurl,
                validation: nil,
                fileStemSuffix: "asset"
            )
        }
    }

    private static func youtubeThumbnailURL(for url: URL?) -> URL? {
        guard let videoID = youtubeVideoID(from: url) else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
    }

    private static func youtubeVideoID(from url: URL?) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let youtubeHosts = ["youtube.com", "youtu.be", "www.youtube.com"]
        if youtubeHosts.contains(where: { url.host?.contains($0) == true }) {
            if url.host?.contains("youtu.be") == true || url.path.contains("/embed/") || url.path.contains("/v/"),
               let path = components.path.components(separatedBy: "/").last,
               !path.isEmpty {
                return path
            }

            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }

        return nil
    }
}

struct APODOfflineMediaStatusPresentation {
    let title: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone
    let detail: String
}

enum APODOfflineMediaStatusPolicy {
    static func presentation(
        for nasa: NASA,
        asset: APODOfflineMediaAsset?,
        isSaved: Bool
    ) -> APODOfflineMediaStatusPresentation? {
        presentation(
            mediaType: nasa.mediaType,
            state: asset?.state ?? .sourceRequired(remoteSourceURL: nil),
            isSaved: isSaved
        )
    }

    static func presentation(
        mediaType: MediaType,
        state: APODOfflineMediaState,
        isSaved: Bool
    ) -> APODOfflineMediaStatusPresentation? {
        guard isSaved else { return nil }

        switch state {
        case .full:
            if mediaType == .video {
                return APODOfflineMediaStatusPresentation(
                    title: L10n.text("offline.media.available", default: "Available Offline"),
                    systemImage: "arrow.down.circle.fill",
                    tone: .accent,
                    detail: L10n.text(
                        "offline.media.detail.video",
                        default: "This saved video file is stored locally and can keep playing without reopening the source host."
                    )
                )
            }

            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.available", default: "Available Offline"),
                systemImage: "arrow.down.circle.fill",
                tone: .accent,
                detail: L10n.text(
                    "offline.media.detail.image",
                    default: "This saved image is stored locally and should remain available without a connection."
                )
            )

        case .preview:
            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.preview", default: "Preview Saved"),
                systemImage: "photo.badge.arrow.down",
                tone: .neutral,
                detail: L10n.text(
                    "offline.media.detail.preview",
                    default: "This saved entry keeps a local preview, but full playback still depends on the original source host."
                )
            )

        case .saving:
            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.syncing", default: "Saving Offline"),
                systemImage: "arrow.down.circle",
                tone: .neutral,
                detail: L10n.text(
                    "offline.media.detail.syncing",
                    default: "The app is downloading local media for this saved APOD."
                )
            )

        case .failed:
            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.failed", default: "Offline Save Failed"),
                systemImage: "exclamationmark.triangle.fill",
                tone: .warning,
                detail: L10n.text(
                    "offline.media.detail.failed",
                    default: "The story is saved, but local media could not be downloaded yet."
                )
            )

        case .sourceRequired:
            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.remote", default: "Source Required"),
                systemImage: "icloud.and.arrow.down",
                tone: .warning,
                detail: L10n.text(
                    "offline.media.detail.remote",
                    default: "This saved entry keeps its story and credits on device, but the media still comes from the original source."
                )
            )
        }
    }
}

struct APODOfflineMediaItemState: Equatable {
    let mediaType: MediaType
    let state: APODOfflineMediaState
    let isSaved: Bool

    init(mediaType: MediaType, asset: APODOfflineMediaAsset?, isSaved: Bool) {
        self.mediaType = mediaType
        state = asset?.state ?? .sourceRequired(remoteSourceURL: nil)
        self.isSaved = isSaved
    }

    var localPreviewURL: URL? {
        state.localPreviewURL
    }

    var localAssetURL: URL? {
        state.localAssetURL
    }

    var localVideoURL: URL? {
        guard mediaType == .video,
              case .full(let localAssetURL, _) = state else {
            return nil
        }

        return localAssetURL
    }

    var statusPresentation: APODOfflineMediaStatusPresentation? {
        APODOfflineMediaStatusPolicy.presentation(
            mediaType: mediaType,
            state: state,
            isSaved: isSaved
        )
    }

    var savedLibraryStorageState: SavedLibraryPolicy.Item.StorageState {
        switch state {
        case .full:
            return .full
        case .preview:
            return .preview
        case .sourceRequired, .saving, .failed:
            return .sourceBacked
        }
    }
}

struct APODOfflineMediaLibraryBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let tone: AppTheme.SurfaceTone
}

struct APODOfflineMediaLibraryState: Equatable {
    let summary: APODOfflineMediaStorageSummary

    var showsSavedStatusBadges: Bool {
        !savedStatusBadges.isEmpty
    }

    var savedStatusBadges: [APODOfflineMediaLibraryBadge] {
        var badges = [APODOfflineMediaLibraryBadge]()

        if summary.fullyOfflineCount > 0 {
            badges.append(
                APODOfflineMediaLibraryBadge(
                    id: "offline",
                    title: L10n.format(
                        "saved.summary.offline_count",
                        default: "%d offline",
                        summary.fullyOfflineCount
                    ),
                    systemImage: "arrow.down.circle.fill",
                    tone: .accent
                )
            )
        }

        if summary.previewCount > 0 {
            badges.append(
                APODOfflineMediaLibraryBadge(
                    id: "preview",
                    title: L10n.format(
                        "saved.summary.preview_count",
                        default: "%d preview",
                        summary.previewCount
                    ),
                    systemImage: "photo.badge.arrow.down",
                    tone: .neutral
                )
            )
        }

        return badges
    }
}

enum APODOfflineMediaManagementOperation: Equatable {
    case idle
    case clearing
    case rebuilding
}

enum APODOfflineMediaManagementCompletedAction: Equatable {
    case cleared
    case rebuilt
}

struct APODOfflineMediaManagementMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct APODOfflineMediaManagementState: Equatable {
    let summary: APODOfflineMediaStorageSummary
    let operation: APODOfflineMediaManagementOperation
    let lastUpdatedText: String
    let lastCompletedAction: APODOfflineMediaManagementCompletedAction?

    var metrics: [APODOfflineMediaManagementMetric] {
        var items = [
            APODOfflineMediaManagementMetric(
                id: "saved-offline",
                title: L10n.text("Saved Offline Items", default: "Saved Offline Items"),
                value: String(summary.fullyOfflineCount)
            ),
            APODOfflineMediaManagementMetric(
                id: "saved-preview",
                title: L10n.text("Saved Preview Items", default: "Saved Preview Items"),
                value: String(summary.previewCount)
            ),
            APODOfflineMediaManagementMetric(
                id: "source-required",
                title: L10n.text("Source Required Items", default: "Source Required Items"),
                value: String(summary.remoteOnlyCount)
            )
        ]

        if summary.syncingCount > 0 {
            items.append(
                APODOfflineMediaManagementMetric(
                    id: "syncing",
                    title: L10n.text("Offline Sync In Progress", default: "Offline Sync In Progress"),
                    value: String(summary.syncingCount)
                )
            )
        }

        if summary.failedCount > 0 {
            items.append(
                APODOfflineMediaManagementMetric(
                    id: "failed",
                    title: L10n.text("Offline Save Failures", default: "Offline Save Failures"),
                    value: String(summary.failedCount)
                )
            )
        }

        items.append(
            APODOfflineMediaManagementMetric(
                id: "media-size",
                title: L10n.text("Offline Media Size", default: "Offline Media Size"),
                value: ByteCountFormatter.string(fromByteCount: summary.totalByteCount, countStyle: .file)
            )
        )

        items.append(
            APODOfflineMediaManagementMetric(
                id: "last-updated",
                title: L10n.text("Last Offline Update", default: "Last Offline Update"),
                value: lastUpdatedText
            )
        )

        return items
    }

    var canClear: Bool {
        summary.canClearStorage && operation == .idle
    }

    var canRebuild: Bool {
        summary.totalManagedItemCount > 0 && operation == .idle
    }

    var actionMessage: String? {
        switch lastCompletedAction {
        case .cleared:
            return L10n.text(
                "offline.media.clear.success",
                default: "Offline files removed. Saved APOD stories remain in Favorites."
            )
        case .rebuilt:
            return L10n.text(
                "offline.media.rebuild.success",
                default: "Offline media refreshed for your saved APOD items."
            )
        case nil:
            return nil
        }
    }
}

enum APODLocalMediaImageLoader {
    static func image(from fileURL: URL?) -> Image? {
#if canImport(UIKit)
        guard let fileURL, let uiImage = UIImage(contentsOfFile: fileURL.path) else {
            return nil
        }
        return Image(uiImage: uiImage)
#else
        return nil
#endif
    }
}
