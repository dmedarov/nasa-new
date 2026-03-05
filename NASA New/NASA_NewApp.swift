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
    
    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { fetcher.error != nil },
            set: { isPresented in
                if !isPresented {
                    Task { @MainActor in
                        fetcher.clearError()
                    }
                }
            }
        )
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
            .alert(isPresented: isErrorPresented) {
                Alert(
                    title: Text("Error"),
                    message: Text(fetcher.error?.localizedDescription ?? "Failed to load Astronomy Picture of the Day data."),
                    primaryButton: .default(Text("Retry")) {
                        Task { await fetcher.fetchData() }
                        Task { @MainActor in
                            fetcher.clearError()
                        }
                    },
                    secondaryButton: .cancel(Text("OK")) {
                        Task { @MainActor in
                            fetcher.clearError()
                        }
                    }
                )
            }
            .accessibilityElement()
            .accessibilityLabel("NASA APOD App")
            .accessibilityHint("Displays NASA's Astronomy Picture of the Day with dark/light mode support.")
        }
    }
}

private enum AppRuntimeConfiguration {
    static func applyDeterministicOverrides() {
        let environment = ProcessInfo.processInfo.environment

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
    }
}
