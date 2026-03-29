import SwiftUI
import UIKit
import UserNotifications
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct NASA_NewApp: App {
    @StateObject private var fetcher: NasaCollectionFetcher
    @StateObject private var router = AppRouter()
    @AppStorage(AppAppearancePolicy.storageKey) private var appearancePreferenceRawValue: String = AppAppearancePreference.system.rawValue

    init() {
        AppRuntimeConfiguration.applyDeterministicOverrides()
        AppAppearancePolicy.migrateLegacyPreferenceIfNeeded()
        APODArchiveStoragePolicy.migrateLegacyLimitIfNeeded()
#if canImport(AppIntents)
        if #available(iOS 16.0, *) {
            NASAAppShortcuts.updateAppShortcutParameters()
        }
#endif
        let configuredFetcher = NasaCollectionFetcher()
        configuredFetcher.configureFixtureModeIfNeeded()
        _fetcher = StateObject(wrappedValue: configuredFetcher)
    }

    private var appearancePreference: AppAppearancePreference {
        AppAppearancePolicy.resolvedPreference(from: appearancePreferenceRawValue)
    }
    
    var body: some Scene {
        WindowGroup {
            AppEnvironmentOverrideContainer(
                overrides: AppEnvironmentOverrides.current,
                preferredColorScheme: appearancePreference.preferredColorScheme
            ) {
                Group {
                    SplashScreenView()
                }
                .environmentObject(fetcher)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handle(url: url, fetcher: fetcher)
                }
                .onContinueUserActivity(AppUserActivityType.today) { activity in
                    router.handle(userActivity: activity, fetcher: fetcher)
                }
                .onContinueUserActivity(AppUserActivityType.archive) { activity in
                    router.handle(userActivity: activity, fetcher: fetcher)
                }
                .onContinueUserActivity(AppUserActivityType.saved) { activity in
                    router.handle(userActivity: activity, fetcher: fetcher)
                }
                .onContinueUserActivity(AppUserActivityType.apod) { activity in
                    router.handle(userActivity: activity, fetcher: fetcher)
                }
            }
        }
    }
}

private enum AppRuntimeConfiguration {
    static func applyDeterministicOverrides() {
        let environment = ProcessInfo.processInfo.environment

        if environment["UITEST_RESET_USER_DEFAULTS"] == "1",
           let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            UserDefaults.standard.synchronize()
            AppGroupConfiguration.resetSharedUserDefaults()
        }

        if let locale = environment["UITEST_LOCALE"] {
            UserDefaults.standard.set([locale], forKey: "AppleLanguages")
            UserDefaults.standard.set(locale, forKey: "AppleLocale")
        }

        if let timeZoneIdentifier = environment["UITEST_TIMEZONE"],
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            NSTimeZone.default = timeZone
        }

        if environment["UITEST_DISABLE_ANIMATIONS"] == "1" {
            UIView.setAnimationsEnabled(false)
        }

        if let dataSaver = environment["UITEST_DEFAULT_DATA_SAVER"] {
            UserDefaults.standard.set(dataSaver == "1", forKey: "dataSaverMode")
        }

        if let preferHDImages = environment["UITEST_DEFAULT_PREFER_HD_IMAGES"] {
            UserDefaults.standard.set(preferHDImages == "1", forKey: "preferHDImages")
        }

        if let wifiOnlyAutoplay = environment["UITEST_DEFAULT_WIFI_ONLY_AUTOPLAY"] {
            UserDefaults.standard.set(wifiOnlyAutoplay == "1", forKey: "wifiOnlyVideoAutoplay")
        }

        if environment["UITEST_DISABLE_SCENE_RESTORATION"] == "1" {
            UserDefaults.standard.removeObject(forKey: "MainView.selectedAPODDate")
        }

        if environment["UITEST_USE_FIXTURE"] == "1" || ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.removeAllPendingNotificationRequests()
            notificationCenter.removeAllDeliveredNotifications()
        }

        // Apple recommendation: prefer URLCache for repeatable, efficient network loading of media-heavy screens.
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "nasa-apod-urlcache"
        )
    }
}
