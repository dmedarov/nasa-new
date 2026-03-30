import Foundation
import Photos

struct APODDownloadedFile: Sendable {
    let fileURL: URL
    let byteCount: Int64
    let mimeType: String?
    let fileExtension: String
}

struct APODDownloadValidation: Sendable {
    let expectedContentLabel: String
    let allowedExactMIMETypes: Set<String>
    let allowedMIMETypePrefixes: [String]
    let allowedPathExtensions: Set<String>
    let fallbackExtension: String
    let maxByteCount: Int64?

    fileprivate func allows(mimeType: String?, fileExtension: String) -> Bool {
        let normalizedExtension = fileExtension.lowercased()
        guard allowedPathExtensions.isEmpty || allowedPathExtensions.contains(normalizedExtension) else {
            return false
        }

        guard let mimeType = mimeType?.lowercased(), !mimeType.isEmpty else {
            return true
        }

        if allowedExactMIMETypes.contains(mimeType) {
            return true
        }

        if allowedMIMETypePrefixes.contains(where: { mimeType.hasPrefix($0) }) {
            return true
        }

        if Self.genericBinaryMIMETypes.contains(mimeType) {
            return true
        }

        return false
    }

    private static let genericBinaryMIMETypes: Set<String> = [
        "application/octet-stream",
        "binary/octet-stream"
    ]

    static let photoExportImage = APODDownloadValidation(
        expectedContentLabel: "image file",
        allowedExactMIMETypes: [
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "image/heic",
            "image/heif",
            "image/tiff",
            "image/bmp"
        ],
        allowedMIMETypePrefixes: ["image/"],
        allowedPathExtensions: [
            "jpg",
            "jpeg",
            "png",
            "gif",
            "webp",
            "heic",
            "heif",
            "tif",
            "tiff",
            "bmp"
        ],
        fallbackExtension: "jpg",
        maxByteCount: 150 * 1_024 * 1_024
    )

    static let offlineImageAsset = APODDownloadValidation(
        expectedContentLabel: "offline image",
        allowedExactMIMETypes: photoExportImage.allowedExactMIMETypes,
        allowedMIMETypePrefixes: photoExportImage.allowedMIMETypePrefixes,
        allowedPathExtensions: photoExportImage.allowedPathExtensions,
        fallbackExtension: "jpg",
        maxByteCount: 120 * 1_024 * 1_024
    )

    static let offlinePreviewImage = APODDownloadValidation(
        expectedContentLabel: "preview image",
        allowedExactMIMETypes: photoExportImage.allowedExactMIMETypes,
        allowedMIMETypePrefixes: photoExportImage.allowedMIMETypePrefixes,
        allowedPathExtensions: photoExportImage.allowedPathExtensions,
        fallbackExtension: "jpg",
        maxByteCount: 20 * 1_024 * 1_024
    )

    static let offlineVideoAsset = APODDownloadValidation(
        expectedContentLabel: "video file",
        allowedExactMIMETypes: [
            "video/mp4",
            "video/quicktime",
            "application/vnd.apple.mpegurl",
            "application/x-mpegurl"
        ],
        allowedMIMETypePrefixes: ["video/"],
        allowedPathExtensions: [
            "mp4",
            "m4v",
            "mov",
            "m3u8"
        ],
        fallbackExtension: "mp4",
        maxByteCount: 500 * 1_024 * 1_024
    )
}

struct APODDownloadService {
    enum DownloadError: LocalizedError, Equatable {
        case invalidResponse
        case unsupportedContentType(expected: String, actual: String?)
        case fileTooLarge(maxBytes: Int64, actualBytes: Int64)
        case unreadableFile

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The source file could not be downloaded right now."
            case .unsupportedContentType(let expected, let actual):
                if let actual, !actual.isEmpty {
                    return "Expected a \(expected), but received \(actual)."
                }
                return "Expected a \(expected), but the source did not expose a compatible file type."
            case .fileTooLarge(let maxBytes, _):
                return "The source file is larger than the allowed download size of \(maxBytes) bytes."
            case .unreadableFile:
                return "The downloaded file could not be prepared for local use."
            }
        }
    }

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func download(
        from remoteURL: URL,
        to directoryURL: URL,
        fileStem: String,
        validation: APODDownloadValidation
    ) async throws -> APODDownloadedFile {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let (temporaryFileURL, response) = try await session.download(from: remoteURL)
        var shouldDeleteTemporaryFile = true

        defer {
            if shouldDeleteTemporaryFile {
                try? fileManager.removeItem(at: temporaryFileURL)
            }
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw DownloadError.invalidResponse
        }

        if let maxByteCount = validation.maxByteCount,
           response.expectedContentLength > 0,
           response.expectedContentLength > maxByteCount {
            throw DownloadError.fileTooLarge(
                maxBytes: maxByteCount,
                actualBytes: response.expectedContentLength
            )
        }

        let fileExtension = resolvedFileExtension(
            response: response,
            remoteURL: remoteURL,
            fallbackExtension: validation.fallbackExtension
        )
        let mimeType = normalizedMIMEType(from: response)

        guard validation.allows(mimeType: mimeType, fileExtension: fileExtension) else {
            throw DownloadError.unsupportedContentType(
                expected: validation.expectedContentLabel,
                actual: mimeType
            )
        }

        let byteCount = try fileSize(at: temporaryFileURL)
        if let maxByteCount = validation.maxByteCount,
           byteCount > maxByteCount {
            throw DownloadError.fileTooLarge(maxBytes: maxByteCount, actualBytes: byteCount)
        }

        let destinationURL = directoryURL.appendingPathComponent(
            "\(fileStem).\(fileExtension)",
            isDirectory: false
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.moveItem(at: temporaryFileURL, to: destinationURL)
            shouldDeleteTemporaryFile = false
        } catch {
            try fileManager.copyItem(at: temporaryFileURL, to: destinationURL)
        }

        return APODDownloadedFile(
            fileURL: destinationURL,
            byteCount: byteCount,
            mimeType: mimeType,
            fileExtension: fileExtension
        )
    }

    private func fileSize(at fileURL: URL) throws -> Int64 {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values.fileSize {
            return Int64(fileSize)
        }

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        if let fileSize = attributes[.size] as? NSNumber {
            return fileSize.int64Value
        }

        throw DownloadError.unreadableFile
    }

    private func normalizedMIMEType(from response: URLResponse) -> String? {
        response.mimeType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func resolvedFileExtension(
        response: URLResponse,
        remoteURL: URL,
        fallbackExtension: String
    ) -> String {
        let suggestedFilenameExtension = (response.suggestedFilename as NSString?)?
            .pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let suggestedFilenameExtension, !suggestedFilenameExtension.isEmpty {
            return suggestedFilenameExtension
        }

        let remoteExtension = remoteURL.pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !remoteExtension.isEmpty {
            return remoteExtension
        }

        switch normalizedMIMEType(from: response) {
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        case "image/heic":
            return "heic"
        case "image/heif":
            return "heif"
        case "image/tiff":
            return "tiff"
        case "image/bmp":
            return "bmp"
        case "video/mp4":
            return "mp4"
        case "video/quicktime":
            return "mov"
        case "application/vnd.apple.mpegurl", "application/x-mpegurl":
            return "m3u8"
        default:
            return fallbackExtension
        }
    }
}

struct PhotoExportService {
    enum ExportError: LocalizedError, Equatable {
        case unsupportedMedia
        case missingSource
        case unsupportedFormat
        case fileTooLarge
        case permissionDenied
        case invalidResponse
        case saveFailed

        var errorTitle: String {
            switch self {
            case .unsupportedMedia, .missingSource, .unsupportedFormat:
                return L10n.text("media.save_unavailable_title", default: "Save unavailable")
            case .fileTooLarge, .invalidResponse, .saveFailed:
                return L10n.text("media.save_failed_title", default: "Could not save image")
            case .permissionDenied:
                return L10n.text("media.save_permission_title", default: "Photo access needed")
            }
        }

        var errorDescription: String? {
            switch self {
            case .unsupportedMedia:
                return L10n.text(
                    "media.save_unavailable_message",
                    default: "Only image-based APOD entries can be saved to Photos."
                )
            case .missingSource:
                return L10n.text(
                    "media.save_missing_source",
                    default: "This APOD does not expose an original image file to save."
                )
            case .unsupportedFormat:
                return L10n.text(
                    "media.save_unsupported_format",
                    default: "The source host did not return a supported image format for this APOD."
                )
            case .fileTooLarge:
                return L10n.text(
                    "media.save_too_large",
                    default: "The original image is too large to save on this device right now."
                )
            case .permissionDenied:
                return L10n.text(
                    "media.save_permission_message",
                    default: "Allow photo library access in Settings to save original APOD images."
                )
            case .invalidResponse:
                return L10n.text(
                    "media.save_invalid_response",
                    default: "The original image could not be downloaded right now."
                )
            case .saveFailed:
                return L10n.text(
                    "media.save_failed_message",
                    default: "The app downloaded the image, but Photos could not store it."
                )
            }
        }
    }

    private let downloadService: APODDownloadService
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        downloadService = APODDownloadService(session: session, fileManager: fileManager)
    }

    static func exportSourceURL(for apod: NASA) -> URL? {
        APODSourceLinkPolicy.originalImageURL(for: apod)
    }

    func exportOriginalImage(for apod: NASA) async throws {
        if ProcessInfo.processInfo.environment["UITEST_FORCE_PHOTO_EXPORT_SUCCESS"] == "1" {
            return
        }

        guard apod.mediaType == .image else {
            throw ExportError.unsupportedMedia
        }

        guard let sourceURL = Self.exportSourceURL(for: apod) else {
            throw ExportError.missingSource
        }

        let authorizationStatus = await requestPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw ExportError.permissionDenied
        }

        let temporaryDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "SpaceBriefing-PhotoExport-\(UUID().uuidString)",
            isDirectory: true
        )

        defer {
            try? fileManager.removeItem(at: temporaryDirectoryURL)
        }

        let downloadedFile: APODDownloadedFile
        do {
            downloadedFile = try await downloadService.download(
                from: sourceURL,
                to: temporaryDirectoryURL,
                fileStem: sanitizedStem(for: apod),
                validation: .photoExportImage
            )
        } catch let error as APODDownloadService.DownloadError {
            switch error {
            case .unsupportedContentType:
                throw ExportError.unsupportedFormat
            case .fileTooLarge:
                throw ExportError.fileTooLarge
            case .invalidResponse, .unreadableFile:
                throw ExportError.invalidResponse
            }
        }

        try await savePhotoFile(at: downloadedFile.fileURL)
    }

    private func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func savePhotoFile(at fileURL: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileURL.lastPathComponent
                request.addResource(with: .photo, fileURL: fileURL, options: options)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? ExportError.saveFailed)
                }
            }
        }
    }

    private func sanitizedStem(for apod: NASA) -> String {
        let rawValue = (apod.date ?? apod.title ?? "apod")
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return rawValue.isEmpty ? "apod" : rawValue
    }
}
