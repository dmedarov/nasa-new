import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppGroupConfiguration {
    static let identifier = "group.eu.medarov.nasa-new.shared"
    static let widgetKind = "NASA_New_Widget"

    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var sharedOfflineMediaDirectoryURL: URL {
        if let sharedContainerURL {
            return sharedContainerURL.appendingPathComponent("OfflineMedia", isDirectory: true)
        }

        let fallbackBaseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return fallbackBaseURL.appendingPathComponent("NASAOfflineMedia", isDirectory: true)
    }

    static func sharedFileURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        return sharedOfflineMediaDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    static func resetSharedUserDefaults() {
        guard let sharedDefaults = UserDefaults(suiteName: identifier) else { return }
        sharedDefaults.removePersistentDomain(forName: identifier)
        sharedDefaults.synchronize()
    }
}

enum AppWidgetRefreshCoordinator {
    static func reloadSharedTimelines() {
#if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConfiguration.widgetKind)
        }
#endif
    }
}
