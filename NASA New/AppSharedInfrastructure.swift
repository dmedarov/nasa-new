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
