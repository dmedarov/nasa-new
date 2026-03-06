import Foundation
import Testing

@Suite(.serialized)
@MainActor
struct NasaCollectionFetcherTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_736_467_200) // 2025-01-15T00:00:00Z
    private var deterministicCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    @Test
    func mapsHTTPStatusToFetchError() async {
        let session = makeSession { request in
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        await fetcher.fetchData()

        guard case let .httpStatus(code)? = fetcher.error else {
            Issue.record("Expected httpStatus error, got \(String(describing: fetcher.error))")
            return
        }
        #expect(code == 500)
    }

    @Test
    func mapsDecodingFailuresToDecodingError() async {
        let session = makeSession { request in
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let malformedJSON = Data("not-json".utf8)
            return (response, malformedJSON)
        }
        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        await fetcher.fetchData(for: Date())

        guard case .decoding? = fetcher.error else {
            Issue.record("Expected decoding error, got \(String(describing: fetcher.error))")
            return
        }
    }

    @Test
    func mapsNetworkFailuresToNetworkError() async {
        let session = makeSession { _ in
            throw URLError(.notConnectedToInternet)
        }
        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        await fetcher.fetchData()

        guard case let .network(urlError)? = fetcher.error else {
            Issue.record("Expected network error, got \(String(describing: fetcher.error))")
            return
        }
        #expect(urlError.code == .notConnectedToInternet)
    }

    @Test
    func updatesCurrentNasaForSingleDateResponse() async {
        let payload = """
        {
            "date": "2025-02-10",
            "explanation": "Single item.",
            "media_type": "image",
            "title": "Single",
            "url": "https://example.com/single.jpg"
        }
        """.data(using: .utf8)!

        let session = makeSession { request in
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        await fetcher.fetchData(for: Date())

        #expect(fetcher.error == nil)
        #expect(fetcher.currentNasa.title == "Single")
        #expect(fetcher.apodData.contains(where: { $0.title == "Single" }))
    }

    @Test
    func usesFixedNowToBuildDateRangeQuery() async {
        let requestedURL = ThreadSafeBox<URL?>(nil)
        let payload = """
        [
            {
                "date": "2024-10-17",
                "explanation": "Range item.",
                "media_type": "image",
                "title": "Range",
                "url": "https://example.com/range.jpg"
            }
        ]
        """.data(using: .utf8)!

        let session = makeSession { request in
            requestedURL.set(request.url)
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        await fetcher.fetchData()

        guard let url = requestedURL.get(), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Issue.record("Expected a request URL to be captured.")
            return
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query["api_key"] == "TEST_KEY")

        // Validate deterministic query keys in exact API format.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        #expect(query["end_date"] == formatter.string(from: fixedNow))
        #expect(query["start_date"] == formatter.string(from: deterministicCalendar.date(byAdding: .day, value: -90, to: fixedNow) ?? fixedNow))
    }

    @Test
    func clampsDatesEarlierThanAPODAvailabilityWindow() async {
        let requestedURL = ThreadSafeBox<URL?>(nil)
        let payload = """
        {
            "date": "1995-06-16",
            "explanation": "First APOD.",
            "media_type": "image",
            "title": "First",
            "url": "https://example.com/first.jpg"
        }
        """.data(using: .utf8)!

        let session = makeSession { request in
            requestedURL.set(request.url)
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        let earlyDate = Date(timeIntervalSince1970: 0)
        await fetcher.fetchData(for: earlyDate)

        guard let url = requestedURL.get(), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Issue.record("Expected a request URL to be captured.")
            return
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query["date"] == "1995-06-16")
    }

    @Test
    func togglesFavoriteAndPersistsState() {
        let storage = InMemoryFavoritesStorage()
        let fetcher = NasaCollectionFetcher(
            session: makeSession { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow },
            favoritesStorage: storage
        )

        let item = NASA(
            date: "2025-01-20",
            explanation: "Favorite test item.",
            mediaType: .image,
            title: "Favorite APOD",
            url: URL(string: "https://example.com/favorite.jpg")
        )

        #expect(fetcher.favorites.isEmpty)
        fetcher.toggleFavorite(item)
        #expect(fetcher.isFavorite(item))
        #expect(fetcher.favorites.count == 1)
        #expect(storage.savedFavorites.count == 1)

        fetcher.toggleFavorite(item)
        #expect(!fetcher.isFavorite(item))
        #expect(fetcher.favorites.isEmpty)
        #expect(storage.savedFavorites.isEmpty)
    }

    @Test
    func selectingFavoriteUpdatesCurrentNasaAndCollection() {
        let favorite = NASA(
            date: "2025-01-10",
            explanation: "Saved item.",
            mediaType: .video,
            title: "Saved Favorite",
            url: URL(string: "https://example.com/saved")
        )
        let storage = InMemoryFavoritesStorage(initialFavorites: [favorite])
        let fetcher = NasaCollectionFetcher(
            session: makeSession { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow },
            favoritesStorage: storage
        )

        #expect(fetcher.favorites.count == 1)
        fetcher.selectFavorite(favorite)

        #expect(fetcher.currentNasa.id == favorite.id)
        #expect(fetcher.apodData.contains(where: { $0.id == favorite.id }))
    }

    @Test
    func latestRequestWinsWhenResponsesReturnOutOfOrder() async {
        let firstPayload = """
        {
            "date": "2025-01-01",
            "explanation": "First response",
            "media_type": "image",
            "title": "First",
            "url": "https://example.com/first.jpg"
        }
        """.data(using: .utf8)!

        let secondPayload = """
        {
            "date": "2025-01-02",
            "explanation": "Second response",
            "media_type": "image",
            "title": "Second",
            "url": "https://example.com/second.jpg"
        }
        """.data(using: .utf8)!

        let session = makeSession { request in
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let query = URLComponents(url: responseURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let requestedDate = query.first(where: { $0.name == "date" })?.value

            if requestedDate == "2025-01-01" {
                Thread.sleep(forTimeInterval: 0.2)
                return (response, firstPayload)
            } else if requestedDate == "2025-01-02" {
                return (response, secondPayload)
            }

            return (response, secondPayload)
        }

        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow }
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let firstDate = formatter.date(from: "2025-01-01")!
        let secondDate = formatter.date(from: "2025-01-02")!

        async let firstRequest: Void = fetcher.fetchData(for: firstDate)
        try? await Task.sleep(nanoseconds: 40_000_000)
        async let secondRequest: Void = fetcher.fetchData(for: secondDate)
        _ = await (firstRequest, secondRequest)

        #expect(fetcher.currentNasa.title == "Second")
    }

    @Test
    func loadsCachedDataOnInitWhenAvailable() {
        let cached = [
            NASA(
                date: "2025-01-01",
                explanation: "Cached item",
                mediaType: .image,
                title: "Cached",
                url: URL(string: "https://example.com/cached.jpg")
            )
        ]
        let cacheStorage = InMemoryAPODCacheStorage(initialItems: cached)
        let fetcher = NasaCollectionFetcher(
            session: makeSession { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com/fallback")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data("[]".utf8))
            },
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow },
            favoritesStorage: InMemoryFavoritesStorage(),
            cacheStorage: cacheStorage
        )

        #expect(fetcher.isUsingCachedData)
        #expect(fetcher.currentNasa.title == "Cached")
        #expect(fetcher.apodData.count == 1)
    }

    @Test
    func savesFetchedRangeDataToCache() async {
        let cacheStorage = InMemoryAPODCacheStorage()
        let payload = """
        [
            {
                "date": "2025-01-03",
                "explanation": "Network item",
                "media_type": "image",
                "title": "Network",
                "url": "https://example.com/network.jpg"
            }
        ]
        """.data(using: .utf8)!

        let session = makeSession { request in
            let responseURL = request.url ?? URL(string: "https://example.com/fallback")!
            let response = HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }
        let fetcher = NasaCollectionFetcher(
            session: session,
            apiKey: "TEST_KEY",
            calendar: deterministicCalendar,
            nowProvider: { fixedNow },
            favoritesStorage: InMemoryFavoritesStorage(),
            cacheStorage: cacheStorage
        )

        await fetcher.fetchData()

        #expect(!fetcher.isUsingCachedData)
        #expect(cacheStorage.cachedItems.count == 1)
        #expect(cacheStorage.cachedItems.first?.title == "Network")
    }

    private func makeSession(handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)) -> URLSession {
        MockURLProtocol.setRequestHandler(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class ThreadSafeBox<Value>: @unchecked Sendable {
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

private final class MockURLProtocol: URLProtocol {
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

private final class InMemoryFavoritesStorage: FavoritesStorage {
    private(set) var savedFavorites: [NASA]

    init(initialFavorites: [NASA] = []) {
        self.savedFavorites = initialFavorites
    }

    func loadFavorites() -> [NASA] {
        savedFavorites
    }

    func saveFavorites(_ favorites: [NASA]) {
        savedFavorites = favorites
    }
}

private final class InMemoryAPODCacheStorage: APODCacheStorage {
    private(set) var cachedItems: [NASA]

    init(initialItems: [NASA] = []) {
        self.cachedItems = initialItems
    }

    func loadCachedAPODItems() -> [NASA] {
        cachedItems
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        cachedItems = items
    }
}
