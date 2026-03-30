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
        let availability = asset?.availability ?? .remoteOnly

        switch availability {
        case .availableOffline:
            fullyOfflineCount += 1
            totalByteCount += max(asset?.byteCount ?? 0, 0)
        case .previewOffline:
            previewCount += 1
            totalByteCount += max(asset?.byteCount ?? 0, 0)
        case .remoteOnly:
            remoteOnlyCount += 1
        case .syncing:
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
        guard isSaved else { return nil }

        switch asset?.availability ?? .remoteOnly {
        case .availableOffline:
            if nasa.mediaType == .video {
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

        case .previewOffline:
            return APODOfflineMediaStatusPresentation(
                title: L10n.text("offline.media.preview", default: "Preview Saved"),
                systemImage: "photo.badge.arrow.down",
                tone: .neutral,
                detail: L10n.text(
                    "offline.media.detail.preview",
                    default: "This saved entry keeps a local preview, but full playback still depends on the original source host."
                )
            )

        case .syncing:
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

        case .remoteOnly:
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
