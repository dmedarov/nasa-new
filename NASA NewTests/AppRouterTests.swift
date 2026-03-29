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

    private func makeSession(
        handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)
    ) -> URLSession {
        AppRouterMockURLProtocol.setRequestHandler(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppRouterMockURLProtocol.self]
        return URLSession(configuration: configuration)
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
