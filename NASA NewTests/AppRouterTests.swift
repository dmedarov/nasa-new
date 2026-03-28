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
}
