import SwiftUI

@main
struct NASA_NewApp: App {
    @StateObject private var fetcher = NasaCollectionFetcher()
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
    
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
            NavigationView {
                SplashScreenView()
                    .environmentObject(fetcher)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            }
            .navigationViewStyle(.stack) // Ensure consistent navigation on all devices
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
