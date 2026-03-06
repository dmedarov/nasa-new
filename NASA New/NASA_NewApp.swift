import SwiftUI
import UIKit

@main
struct NASA_NewApp: App {
    @StateObject private var fetcher: NasaCollectionFetcher
    @AppStorage("isDarkMode") var isDarkMode: Bool = true

    init() {
        AppRuntimeConfiguration.applyDeterministicOverrides()
        let configuredFetcher = NasaCollectionFetcher()
        configuredFetcher.configureFixtureModeIfNeeded()
        _fetcher = StateObject(wrappedValue: configuredFetcher)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        SplashScreenView()
                    }
                } else {
                    NavigationView {
                        SplashScreenView()
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .environmentObject(fetcher)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .accessibilityElement()
            .accessibilityLabel("NASA APOD App")
            .accessibilityHint("Displays NASA's Astronomy Picture of the Day with dark/light mode support.")
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
