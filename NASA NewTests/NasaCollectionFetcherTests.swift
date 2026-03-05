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

    private func makeSession(handler: @escaping @Sendable (URLRequest) throws -> (URLResponse, Data)) -> URLSession {
        MockURLProtocol.requestHandler = handler
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
    static var requestHandler: (@Sendable (URLRequest) throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
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
