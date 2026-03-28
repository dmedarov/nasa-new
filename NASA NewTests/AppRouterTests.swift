import Foundation
import Testing

struct AppRouterTests {
    @Test
    func pendingRouteStoreConsumesSavedRouteFromProvidedDefaults() {
        let suiteName = "AppRouterTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated test defaults suite.")
            return
        }

        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let route = AppRoute(destination: .archive, apodDate: "2025-01-07")
        PendingAppRouteStore.save(route, userDefaults: userDefaults)

        #expect(PendingAppRouteStore.consume(userDefaults: userDefaults) == route)
        #expect(PendingAppRouteStore.consume(userDefaults: userDefaults) == nil)
    }

    @Test
    func appDeepLinkBuildsPublicWebURLWhenConfigured() {
        let route = AppRoute(destination: .archive, apodDate: "2025-01-07")
        let publicBaseURL = URL(string: "https://example.com/space-briefing")!

        let generatedURL = AppDeepLink.url(for: route, publicBaseURL: publicBaseURL)

        #expect(generatedURL == URL(string: "https://example.com/space-briefing/archive?date=2025-01-07"))
    }

    @Test
    func appDeepLinkParsesConfiguredPublicWebURL() {
        let publicBaseURL = URL(string: "https://example.com/space-briefing")!
        let url = URL(string: "https://example.com/space-briefing/saved?date=2025-02-11")!

        let route = AppDeepLink.route(from: url, publicBaseURL: publicBaseURL)

        #expect(route == AppRoute(destination: .saved, apodDate: "2025-02-11"))
    }

    @Test
    func appDeepLinkFallsBackToCustomSchemeWithoutPublicBaseURL() {
        let route = AppRoute(destination: .today, apodDate: "2025-03-01")

        let generatedURL = AppDeepLink.url(for: route, publicBaseURL: nil)
        let parsedRoute = generatedURL.flatMap { AppDeepLink.route(from: $0, publicBaseURL: nil) }

        #expect(generatedURL == URL(string: "nasanew://today?date=2025-03-01"))
        #expect(parsedRoute == route)
    }
}
