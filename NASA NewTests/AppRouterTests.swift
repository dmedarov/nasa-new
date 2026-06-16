import Foundation
import Testing

@Suite(.serialized)
@MainActor
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

        let generatedURL = AppDeepLink.publicWebURL(for: route, publicBaseURL: publicBaseURL)

        #expect(generatedURL == URL(string: "https://example.com/space-briefing/archive?date=2025-01-07"))
    }

    @Test
    func appDeepLinkUsesCustomSchemeForInternalNavigationEvenWhenPublicWebURLIsConfigured() {
        let route = AppRoute(destination: .archive, apodDate: "2025-01-07")
        let publicBaseURL = URL(string: "https://example.com/space-briefing")!

        let generatedURL = AppDeepLink.url(for: route, publicBaseURL: publicBaseURL)

        #expect(generatedURL == URL(string: "nasanew://archive?date=2025-01-07"))
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

    @Test
    func appRouterRoutesSavedEntryIntoSavedSelectionWhenFavoriteExists() {
        let favorite = NASA(
            date: "2025-01-15",
            explanation: "Saved route target.",
            mediaType: .image,
            title: "Saved Route Target",
            url: URL(string: "https://example.com/saved-route.jpg")
        )
        let fetcher = NasaCollectionFetcher(
            session: makeSession { request in
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            favoritesStorage: AppRouterInMemoryFavoritesStorage(initialFavorites: [favorite]),
            cacheStorage: AppRouterInMemoryCacheStorage(initialItems: [favorite])
        )
        let router = AppRouter()

        router.handle(AppRoute(destination: .saved, apodDate: "2025-01-15"), fetcher: fetcher)

        #expect(router.destination == .saved)
        #expect(router.selectedSavedItemID == favorite.id)
        #expect(fetcher.currentNasa.id == favorite.id)
    }

    @Test
    func appRouterFallsBackToArchiveWhenSavedRouteMatchesNonFavoriteItem() {
        let archiveItem = NASA(
            date: "2025-01-14",
            explanation: "Archive-only route target.",
            mediaType: .image,
            title: "Archive Route Target",
            url: URL(string: "https://example.com/archive-route.jpg")
        )
        let fetcher = NasaCollectionFetcher(
            session: makeSession { request in
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            favoritesStorage: AppRouterInMemoryFavoritesStorage(),
            cacheStorage: AppRouterInMemoryCacheStorage(initialItems: [archiveItem])
        )
        let router = AppRouter()

        router.handle(AppRoute(destination: .saved, apodDate: "2025-01-14"), fetcher: fetcher)

        #expect(router.destination == .archive)
        #expect(router.selectedArchiveItemID == archiveItem.id)
        #expect(router.selectedSavedItemID == nil)
        #expect(fetcher.currentNasa.id == archiveItem.id)
    }

    @Test
    func appRouterFetchesMissingExactDateIntoTodayReader() async {
        let requestedURL = AppRouterThreadSafeBox<URL?>(nil)
        let payload = """
        {
            "date": "2025-01-13",
            "explanation": "Fetched route target.",
            "media_type": "image",
            "title": "Fetched Route Target",
            "url": "https://example.com/fetched-route.jpg"
        }
        """.data(using: .utf8)!
        let fetcher = NasaCollectionFetcher(
            session: makeSession { request in
                requestedURL.set(request.url)
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, payload)
            },
            apiKey: "TEST_KEY"
        )
        let router = AppRouter()

        router.handle(AppRoute(destination: .archive, apodDate: "2025-01-13"), fetcher: fetcher)
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(router.destination == .today)
        #expect(fetcher.currentNasa.date == "2025-01-13")
        #expect(fetcher.apodData.contains(where: { $0.date == "2025-01-13" }))

        guard let url = requestedURL.get(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Issue.record("Expected the routed fetch to capture a request URL.")
            return
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query["date"] == "2025-01-13")
    }

    @Test
    func appRouterPresentsDeepLinkPaywallForLockedArchiveDate() {
        let lockedItem = makeAPOD(date: "2025-01-04", title: "Locked Archive Story")
        let latestItem = makeAPOD(date: "2025-01-15", title: "Latest Archive Story")
        let fetcher = makeFetcher(cachedItems: [lockedItem, latestItem])
        let router = AppRouter()
        let purchaseManager = makePurchaseManager(name: "deepLinkLockedDate")

        router.handle(
            url: URL(string: "nasanew://archive?date=2025-01-04")!,
            fetcher: fetcher,
            purchaseManager: purchaseManager
        )

        #expect(purchaseManager.activePaywall?.trigger == .deepLinkLockedDate)
        #expect(purchaseManager.activePaywall?.feature == .fullArchive)
        #expect(router.destination == .today)
        #expect(fetcher.currentNasa.date == "2025-01-15")
    }

    @Test
    func appRouterPresentsAppIntentPaywallForLockedArchiveDate() {
        let lockedItem = makeAPOD(date: "2025-01-04", title: "Locked Archive Story")
        let latestItem = makeAPOD(date: "2025-01-15", title: "Latest Archive Story")
        let fetcher = makeFetcher(cachedItems: [lockedItem, latestItem])
        let router = AppRouter()
        let purchaseManager = makePurchaseManager(name: "appIntentLockedDate")

        router.handle(
            AppRoute(destination: .archive, apodDate: "2025-01-04"),
            fetcher: fetcher,
            purchaseManager: purchaseManager,
            lockedDateTrigger: .appIntentLockedDate
        )

        #expect(purchaseManager.activePaywall?.trigger == .appIntentLockedDate)
        #expect(purchaseManager.activePaywall?.feature == .fullArchive)
        #expect(router.selectedArchiveItemID == nil)
    }

    @Test
    func appRouterAllowsOlderSavedFavoriteRouteWithoutPro() {
        let favorite = makeAPOD(date: "2025-01-04", title: "Saved Older Story")
        let latestItem = makeAPOD(date: "2025-01-15", title: "Latest Archive Story")
        let fetcher = makeFetcher(
            cachedItems: [favorite, latestItem],
            favorites: [favorite]
        )
        let router = AppRouter()
        let purchaseManager = makePurchaseManager(name: "savedFavoriteBypass")

        router.handle(
            AppRoute(destination: .saved, apodDate: "2025-01-04"),
            fetcher: fetcher,
            purchaseManager: purchaseManager
        )

        #expect(purchaseManager.activePaywall == nil)
        #expect(router.destination == .saved)
        #expect(router.selectedSavedItemID == favorite.id)
        #expect(fetcher.currentNasa.id == favorite.id)
    }

    @Test
    func appShellSelectionPolicyKeepsValidArchiveSelection() {
        let firstArchive = makeAPOD(date: "2025-01-14", title: "Archive First")
        let selectedArchive = makeAPOD(date: "2025-01-15", title: "Archive Selected")

        let resolution = AppShellSelectionPolicy.resolveArchive(
            selectedID: selectedArchive.id,
            selectionClearedByUser: false,
            archiveItems: [firstArchive, selectedArchive],
            favoriteItems: []
        )

        #expect(resolution.normalizedSelectionID == selectedArchive.id)
        #expect(resolution.selectedItem?.id == selectedArchive.id)
        #expect(resolution.fallbackItem?.id == firstArchive.id)
        #expect(resolution.hasDetailContent)
    }

    @Test
    func appShellSelectionPolicyAllowsArchiveDetailForFavoriteSelection() {
        let firstArchive = makeAPOD(date: "2025-01-14", title: "Archive First")
        let favorite = makeAPOD(date: "2025-01-16", title: "Favorite Selected")

        let resolution = AppShellSelectionPolicy.resolveArchive(
            selectedID: favorite.id,
            selectionClearedByUser: false,
            archiveItems: [firstArchive],
            favoriteItems: [favorite]
        )

        #expect(resolution.normalizedSelectionID == favorite.id)
        #expect(resolution.selectedItem?.id == favorite.id)
        #expect(resolution.fallbackItem?.id == firstArchive.id)
        #expect(resolution.hasDetailContent)
    }

    @Test
    func appShellSelectionPolicySuppressesFallbackAfterExplicitClear() {
        let favorite = makeAPOD(date: "2025-01-15", title: "Saved Favorite")

        let resolution = AppShellSelectionPolicy.resolveSaved(
            selectedID: favorite.id,
            selectionClearedByUser: true,
            favoriteItems: [favorite]
        )

        #expect(resolution.normalizedSelectionID == nil)
        #expect(resolution.selectedItem == nil)
        #expect(resolution.fallbackItem == nil)
        #expect(!resolution.hasDetailContent)
    }

    @Test
    func appShellSelectionPolicyClearsInvalidSavedSelectionButKeepsFallback() {
        let firstFavorite = makeAPOD(date: "2025-01-15", title: "Saved First")
        let secondFavorite = makeAPOD(date: "2025-01-16", title: "Saved Second")

        let resolution = AppShellSelectionPolicy.resolveSaved(
            selectedID: "missing-selection",
            selectionClearedByUser: false,
            favoriteItems: [firstFavorite, secondFavorite]
        )

        #expect(resolution.normalizedSelectionID == nil)
        #expect(resolution.selectedItem == nil)
        #expect(resolution.fallbackItem?.id == firstFavorite.id)
        #expect(resolution.hasDetailContent)
    }

    @Test
    func appShellRouteSelectionContractResetsInactiveClearFlagsOnNavigation() {
        let currentFlags = AppShellSelectionFlags(
            archiveSelectionClearedByUser: true,
            savedSelectionClearedByUser: true
        )

        let archiveNavigationFlags = AppShellRouteSelectionContract.flagsAfterNavigating(
            to: .archive,
            current: currentFlags
        )
        let todayNavigationFlags = AppShellRouteSelectionContract.flagsAfterNavigating(
            to: .today,
            current: currentFlags
        )

        #expect(archiveNavigationFlags.archiveSelectionClearedByUser)
        #expect(!archiveNavigationFlags.savedSelectionClearedByUser)
        #expect(!todayNavigationFlags.archiveSelectionClearedByUser)
        #expect(!todayNavigationFlags.savedSelectionClearedByUser)
    }

    @Test
    func appShellRouteSelectionContractRestoresClearFlagAfterExplicitSelection() {
        let currentFlags = AppShellSelectionFlags(
            archiveSelectionClearedByUser: true,
            savedSelectionClearedByUser: true
        )

        let archiveSelectionFlags = AppShellRouteSelectionContract.flagsAfterSelectionChange(
            for: .archive,
            selectedID: "archive-selection",
            current: currentFlags
        )
        let unchangedFlags = AppShellRouteSelectionContract.flagsAfterSelectionChange(
            for: .saved,
            selectedID: nil,
            current: currentFlags
        )

        #expect(!archiveSelectionFlags.archiveSelectionClearedByUser)
        #expect(archiveSelectionFlags.savedSelectionClearedByUser)
        #expect(unchangedFlags == currentFlags)
    }

    @Test
    func appShellRouteSelectionContractOnlyNormalizesActiveDestinationSelection() {
        let firstArchive = makeAPOD(date: "2025-01-14", title: "Archive First")
        let selectedArchive = makeAPOD(date: "2025-01-15", title: "Archive Selected")
        let favorite = makeAPOD(date: "2025-01-16", title: "Saved Favorite")

        let synchronization = AppShellRouteSelectionContract.synchronize(
            destination: .archive,
            archiveSelectedID: selectedArchive.id,
            savedSelectedID: "stale-saved-selection",
            flags: AppShellSelectionFlags(),
            archiveItems: [firstArchive, selectedArchive],
            favoriteItems: [favorite]
        )

        #expect(synchronization.normalizedArchiveSelectionID == selectedArchive.id)
        #expect(synchronization.normalizedSavedSelectionID == "stale-saved-selection")
        #expect(synchronization.archiveSelectedItemForFetcher?.id == selectedArchive.id)
        #expect(synchronization.savedSelectedItemForFetcher == nil)
    }

    @Test
    func appShellRouteSelectionContractSuppressesActiveFallbackAfterExplicitClear() {
        let firstArchive = makeAPOD(date: "2025-01-14", title: "Archive First")

        let synchronization = AppShellRouteSelectionContract.synchronize(
            destination: .archive,
            archiveSelectedID: nil,
            savedSelectedID: nil,
            flags: AppShellSelectionFlags(archiveSelectionClearedByUser: true),
            archiveItems: [firstArchive],
            favoriteItems: []
        )

        #expect(synchronization.normalizedArchiveSelectionID == nil)
        #expect(synchronization.archiveResolution.selectedItem == nil)
        #expect(synchronization.archiveResolution.fallbackItem == nil)
        #expect(synchronization.archiveSelectedItemForFetcher == nil)
    }

    @Test
    func appRouterAllowsProUserToOpenLockedArchiveDate() {
        let lockedItem = makeAPOD(date: "2025-01-04", title: "Locked Archive Story")
        let latestItem = makeAPOD(date: "2025-01-15", title: "Latest Archive Story")
        let fetcher = makeFetcher(cachedItems: [lockedItem, latestItem])
        let router = AppRouter()
        let purchaseManager = makePurchaseManager(
            name: "proLockedDate",
            environment: ["UITEST_HAS_PRO": "1"]
        )

        router.handle(
            AppRoute(destination: .archive, apodDate: "2025-01-04"),
            fetcher: fetcher,
            purchaseManager: purchaseManager,
            lockedDateTrigger: .appIntentLockedDate
        )

        #expect(purchaseManager.activePaywall == nil)
        #expect(router.destination == .archive)
        #expect(router.selectedArchiveItemID == lockedItem.id)
        #expect(fetcher.currentNasa.id == lockedItem.id)
    }

    private func makeSession(
        handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)
    ) -> URLSession {
        AppRouterMockURLProtocol.setRequestHandler(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppRouterMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeFetcher(
        cachedItems: [NASA],
        favorites: [NASA] = [],
        referenceDate: Date = Date(timeIntervalSince1970: 1_736_899_200)
    ) -> NasaCollectionFetcher {
        let calendar = Calendar(identifier: .gregorian)
        return NasaCollectionFetcher(
            session: makeSession { request in
                let response = HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            calendar: calendar,
            nowProvider: { referenceDate },
            favoritesStorage: AppRouterInMemoryFavoritesStorage(initialFavorites: favorites),
            cacheStorage: AppRouterInMemoryCacheStorage(initialItems: cachedItems)
        )
    }

    private func makePurchaseManager(
        name: String,
        environment: [String: String] = [:]
    ) -> PurchaseManager {
        let suiteName = "AppRouterTests.\(name).\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected isolated test defaults suite.")
            return PurchaseManager(environment: environment)
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        return PurchaseManager(
            userDefaults: userDefaults,
            environment: environment
        )
    }

    private func makeAPOD(date: String, title: String) -> NASA {
        NASA(
            date: date,
            explanation: "App router test fixture for \(title).",
            mediaType: .image,
            title: title,
            url: URL(string: "https://example.com/\(date).jpg")
        )
    }
}

private final class AppRouterThreadSafeBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func set(_ newValue: Value) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> Value {
        lock.lock()
        let currentValue = value
        lock.unlock()
        return currentValue
    }
}

private final class AppRouterMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requestHandler: (@Sendable (URLRequest) throws -> (URLResponse, Data))?

    static func setRequestHandler(_ handler: (@Sendable (URLRequest) throws -> (URLResponse, Data))?) {
        lock.lock()
        requestHandler = handler
        lock.unlock()
    }

    private static func currentRequestHandler() -> (@Sendable (URLRequest) throws -> (URLResponse, Data))? {
        lock.lock()
        let handler = requestHandler
        lock.unlock()
        return handler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.currentRequestHandler() else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class AppRouterInMemoryFavoritesStorage: FavoritesStorage {
    private let favorites: [NASA]

    init(initialFavorites: [NASA] = []) {
        favorites = initialFavorites
    }

    func loadFavorites() -> [NASA] {
        favorites
    }

    func saveFavorites(_ favorites: [NASA]) {}
}

private final class AppRouterInMemoryCacheStorage: APODCacheStorage {
    private let items: [NASA]

    init(initialItems: [NASA] = []) {
        items = initialItems
    }

    func loadCachedAPODItems() -> [NASA] {
        items
    }

    func saveCachedAPODItems(_ items: [NASA]) {}
}
