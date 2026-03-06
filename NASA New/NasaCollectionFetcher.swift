import SwiftUI

@MainActor
final class NasaCollectionFetcher: ObservableObject {
    @Published private(set) var apodData = [NASA]()
    @Published var currentNasa = NASA.default
    @Published var error: FetchError?
    @Published private(set) var isFetching = false
    @Published private(set) var isUsingFixtureData = false
    @Published private(set) var favorites = [NASA]()
    @Published private(set) var lastStatusCode: Int?
    @Published private(set) var lastRequestDate: Date?
    @Published private(set) var lastTransportError: String?
    @Published private(set) var isUsingCachedData = false

    private let session: URLSession
    private let apiKey: String
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private let favoritesStorage: FavoritesStorage
    private let cacheStorage: APODCacheStorage
    private var activeRequestID = UUID()
    private var latestFetchTask: Task<Void, Never>?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let minimumAPODDate: Date = {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.locale = Locale(identifier: "en_US_POSIX")
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return utcCalendar.date(from: DateComponents(year: 1995, month: 6, day: 16)) ?? .distantPast
    }()

    var minimumSelectableDate: Date { minimumAPODDate }

    var maximumSelectableDate: Date { normalizedDate(nowProvider()) }

    var isAPIKeyConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && apiKey != "DEMO_KEY"
    }

    init(
        session: URLSession = .shared,
        apiKey: String = ProcessInfo.processInfo.environment["NASA_API_KEY"] ?? "DEMO_KEY",
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        favoritesStorage: FavoritesStorage = UserDefaultsFavoritesStorage(),
        cacheStorage: APODCacheStorage = UserDefaultsAPODCacheStorage()
    ) {
        self.session = session
        self.apiKey = apiKey
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.favoritesStorage = favoritesStorage
        self.cacheStorage = cacheStorage
        self.favorites = favoritesStorage.loadFavorites()
        sortFavorites()

        let cachedItems = cacheStorage.loadCachedAPODItems()
        if !cachedItems.isEmpty {
            self.apodData = cachedItems.sorted { ($0.date ?? "") < ($1.date ?? "") }
            self.currentNasa = self.apodData.last ?? .default
            self.isUsingCachedData = true
        }
    }

    private func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: max(date, minimumAPODDate))
    }

    func isSameAPODDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(normalizedDate(lhs), inSameDayAs: normalizedDate(rhs))
    }

    private func buildURL(for date: Date? = nil) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        if let date {
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: normalizedDate(date))))
        } else {
            let now = nowProvider()
            let endDate = dateFormatter.string(from: now)
            let startDate = normalizedDate(calendar.date(byAdding: .day, value: -90, to: now) ?? now)
            let startDateString = dateFormatter.string(from: startDate)
            queryItems.append(URLQueryItem(name: "start_date", value: startDateString))
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    @available(iOS 15.0, *)
    func fetchData() async {
        await fetchData(for: nil)
    }

    @available(iOS 15.0, *)
    func startLatestFetch(for date: Date? = nil) {
        latestFetchTask?.cancel()
        latestFetchTask = Task { [weak self] in
            await self?.fetchData(for: date)
        }
    }

    func cancelLatestFetch() {
        latestFetchTask?.cancel()
        latestFetchTask = nil
    }

    @available(iOS 15.0, *)
    func fetchData(for date: Date?) async {
        guard !isUsingFixtureData else { return }
        let requestID = UUID()
        activeRequestID = requestID
        isFetching = true
        error = nil
        lastRequestDate = Date()
        lastTransportError = nil
        defer {
            if requestID == activeRequestID {
                isFetching = false
            }
        }

        guard let url = buildURL(for: date) else {
            if requestID == activeRequestID {
                error = .badRequest
            }
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            if requestID == activeRequestID {
                lastStatusCode = httpResponse.statusCode
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw FetchError.httpStatus(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()

            if date != nil {
                let item = try decoder.decode(NASA.self, from: data)
                guard requestID == activeRequestID else { return }
                currentNasa = item
                if let index = apodData.firstIndex(where: { $0.id == item.id }) {
                    apodData[index] = item
                } else {
                    apodData.append(item)
                }
                apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
                refreshFavoriteIfNeeded(with: item)
                cacheStorage.saveCachedAPODItems(apodData)
                isUsingCachedData = false
            } else {
                let decoded = try decoder.decode([NASA].self, from: data)
                    .sorted { ($0.date ?? "") < ($1.date ?? "") }
                guard !decoded.isEmpty else {
                    throw FetchError.emptyResponse
                }
                guard requestID == activeRequestID else { return }
                apodData = decoded
                currentNasa = decoded.last ?? .default
                refreshFavoritesFromData(decoded)
                cacheStorage.saveCachedAPODItems(decoded)
                isUsingCachedData = false
            }
        } catch is CancellationError {
            return
        } catch let fetchError as FetchError {
            if requestID == activeRequestID {
                error = fetchError
            }
        } catch let urlError as URLError {
            if requestID == activeRequestID, urlError.code != .cancelled {
                error = .network(urlError)
                lastTransportError = urlError.localizedDescription
            }
        } catch let decodeError as DecodingError {
            if requestID == activeRequestID {
                error = .decoding(decodeError)
                lastTransportError = "Failed to decode NASA API payload."
            }
        } catch {
            if requestID == activeRequestID {
                self.error = .unknown(error.localizedDescription)
                lastTransportError = error.localizedDescription
            }
        }
    }

    func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    func selectRandom(preferImagesOnly: Bool) {
        let candidates = preferImagesOnly ? apodData.filter { $0.mediaType == .image } : apodData
        guard let random = candidates.randomElement() else { return }
        currentNasa = random
    }

    func clearError() {
        error = nil
    }

    func isFavorite(_ nasa: NASA) -> Bool {
        favorites.contains(where: { $0.id == nasa.id })
    }

    func toggleFavorite(_ nasa: NASA) {
        if let index = favorites.firstIndex(where: { $0.id == nasa.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(nasa)
        }
        sortFavorites()
        favoritesStorage.saveFavorites(favorites)
    }

    func removeFavorite(_ nasa: NASA) {
        guard let index = favorites.firstIndex(where: { $0.id == nasa.id }) else { return }
        favorites.remove(at: index)
        favoritesStorage.saveFavorites(favorites)
    }

    func selectFavorite(_ nasa: NASA) {
        currentNasa = nasa
        if let index = apodData.firstIndex(where: { $0.id == nasa.id }) {
            apodData[index] = nasa
        } else {
            apodData.append(nasa)
            apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
        }
    }

    func configureFixtureModeIfNeeded() {
        guard ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] == "1" else { return }
        isUsingFixtureData = true
        isUsingCachedData = false
        error = nil

        let fixture = NASA(
            copyright: "NASA",
            date: "2025-01-15",
            explanation: "This is deterministic fixture content used for UI testing.",
            hdurl: URL(string: "https://example.com/apod_hd.jpg"),
            mediaType: .image,
            serviceVersion: "v1",
            title: "Fixture APOD",
            url: URL(string: "https://example.com/apod.jpg")
        )

        apodData = [fixture]
        currentNasa = fixture
    }

    private func refreshFavoriteIfNeeded(with item: NASA) {
        guard let index = favorites.firstIndex(where: { $0.id == item.id }) else { return }
        favorites[index] = item
        sortFavorites()
        favoritesStorage.saveFavorites(favorites)
    }

    private func refreshFavoritesFromData(_ items: [NASA]) {
        var didChange = false
        for item in items {
            if let index = favorites.firstIndex(where: { $0.id == item.id }) {
                favorites[index] = item
                didChange = true
            }
        }
        if didChange {
            sortFavorites()
            favoritesStorage.saveFavorites(favorites)
        }
    }

    private func sortFavorites() {
        favorites.sort { ($0.date ?? "") > ($1.date ?? "") }
    }

    enum FetchError: LocalizedError {
        case badRequest
        case invalidResponse
        case httpStatus(Int)
        case emptyResponse
        case decoding(DecodingError)
        case network(URLError)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .badRequest:
                return "Unable to load APOD data right now. Please try again."
            case .invalidResponse:
                return "NASA API returned an invalid response."
            case let .httpStatus(statusCode):
                if statusCode == 429 {
                    return "NASA API rate limit reached (429). Configure a personal NASA_API_KEY and retry."
                }
                return "NASA API request failed with status code \(statusCode)."
            case .emptyResponse:
                return "NASA API returned no APOD items."
            case .decoding:
                return "Received APOD data in an unexpected format."
            case .network:
                return "Network request failed. Check your connection and try again."
            case let .unknown(message):
                return "Unexpected error: \(message)"
            }
        }
    }
}

protocol FavoritesStorage {
    func loadFavorites() -> [NASA]
    func saveFavorites(_ favorites: [NASA])
}

protocol APODCacheStorage {
    func loadCachedAPODItems() -> [NASA]
    func saveCachedAPODItems(_ items: [NASA])
}

struct UserDefaultsFavoritesStorage: FavoritesStorage {
    private static let key = "nasa.favorite.items.v1"

    func loadFavorites() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let favorites = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return favorites
    }

    func saveFavorites(_ favorites: [NASA]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

struct UserDefaultsAPODCacheStorage: APODCacheStorage {
    private static let key = "nasa.apod.cache.items.v1"

    func loadCachedAPODItems() -> [NASA] {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let items = try? JSONDecoder().decode([NASA].self, from: data)
        else {
            return []
        }
        return items
    }

    func saveCachedAPODItems(_ items: [NASA]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
