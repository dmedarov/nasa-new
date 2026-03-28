import SwiftUI

enum NASAAPIKeyConfiguration {
    static let infoDictionaryKey = "NASA_API_KEY"
    static let demoKey = "DEMO_KEY"

    static func resolvedAPIKey(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) -> String {
        resolvedValue(from: environment[infoDictionaryKey])
            ?? resolvedValue(from: infoDictionary[infoDictionaryKey] as? String)
            ?? demoKey
    }

    private static func resolvedValue(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        // Ignore unresolved build-setting placeholders if no local secret file is present yet.
        guard !(trimmedValue.hasPrefix("$(") && trimmedValue.hasSuffix(")")) else { return nil }

        return trimmedValue
    }
}

@MainActor
final class NasaCollectionFetcher: ObservableObject {
    enum Constants {
        static let foregroundRefreshInterval: TimeInterval = 60 * 60
        static let defaultCacheItemLimit = APODArchiveStoragePolicy.defaultArchiveLimit
        static let archiveBatchDayCount = 60
    }

    @Published var apodData = [NASA]()
    @Published var currentNasa = NASA.default
    @Published var error: FetchError?
    @Published var isFetching = false
    @Published var isUsingFixtureData = false
    @Published var favorites = [NASA]()
    @Published var lastStatusCode: Int?
    @Published var lastRequestDate: Date?
    @Published var lastTransportError: String?
    @Published var isUsingCachedData = false
    @Published var isOfflineMode = false
    @Published var requestDiagnostics = [RequestDiagnostic]()
    @Published var apiKeyWarning: String?
    @Published var rateLimitRetryDate: Date?
    @Published var cachedItemCount = 0
    @Published var cacheItemLimit = Constants.defaultCacheItemLimit
    @Published var isFetchingArchive = false
    @Published var archiveError: FetchError?

    let service: APODService
    let apiKey: String
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    let favoritesStorage: FavoritesStorage
    let cacheStorage: APODCacheStorage
    var activeRequestID = UUID()
    var latestFetchTask: Task<Void, Never>?
    var fixtureScenario: FixtureScenario?
    var fixtureFetchCycle = 0
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        return formatter
    }()
    let retryAfterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()
    let minimumAPODDate: Date = {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.locale = Locale(identifier: "en_US_POSIX")
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return utcCalendar.date(from: DateComponents(year: 1995, month: 6, day: 16)) ?? .distantPast
    }()

    var minimumSelectableDate: Date { minimumAPODDate }

    var maximumSelectableDate: Date {
        if isUsingFixtureData, let latestFixtureDate = latestAvailableAPODDate {
            return latestFixtureDate
        }
        return normalizedDate(nowProvider())
    }

    var isAPIKeyConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && apiKey != NASAAPIKeyConfiguration.demoKey
    }

    init(
        session: URLSession = .shared,
        apiKey: String = NASAAPIKeyConfiguration.resolvedAPIKey(),
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        favoritesStorage: FavoritesStorage? = nil,
        cacheStorage: APODCacheStorage? = nil
    ) {
        let defaultLibraryStorage = APODLibraryStoreFactory.makeDefault()
        self.service = URLSessionAPODService(session: session)
        self.apiKey = apiKey
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.favoritesStorage = favoritesStorage ?? defaultLibraryStorage
        self.cacheStorage = cacheStorage ?? defaultLibraryStorage
        self.favorites = self.favoritesStorage.loadFavorites()
        sortFavorites()

        let cachedItems = self.cacheStorage.loadCachedAPODItems()
        if !cachedItems.isEmpty {
            self.apodData = cachedItems.sorted { ($0.date ?? "") < ($1.date ?? "") }
            self.currentNasa = self.apodData.last ?? .default
            self.isUsingCachedData = true
        }
        self.cachedItemCount = self.apodData.count

        if !isAPIKeyConfigured, ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] != "1" {
            apiKeyWarning = L10n.text(
                "api.key.warning.unconfigured",
                default: "NASA_API_KEY is not configured. DEMO_KEY may be rate-limited."
            )
        }
    }

    func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: max(date, minimumAPODDate))
    }

    func isSameAPODDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(normalizedDate(lhs), inSameDayAs: normalizedDate(rhs))
    }

    var latestAvailableAPODDate: Date? {
        apodData
            .compactMap { date(from: $0.date) }
            .map(normalizedDate)
            .max()
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
                return L10n.text("error.bad_request", default: "Unable to load APOD data right now. Please try again.")
            case .invalidResponse:
                return L10n.text("error.invalid_response", default: "NASA API returned an invalid response.")
            case let .httpStatus(statusCode):
                if statusCode == 429 {
                    return L10n.text(
                        "error.http_429",
                        default: "NASA API rate limit reached (429). Configure a personal NASA_API_KEY and retry."
                    )
                }
                return L10n.format(
                    "error.http_status",
                    default: "NASA API request failed with status code %d.",
                    statusCode
                )
            case .emptyResponse:
                return L10n.text("error.empty_response", default: "NASA API returned no APOD items.")
            case .decoding:
                return L10n.text("error.decoding", default: "Received APOD data in an unexpected format.")
            case .network:
                return L10n.text("error.network", default: "Network request failed. Check your connection and try again.")
            case let .unknown(message):
                return L10n.format("error.unknown", default: "Unexpected error: %@", message)
            }
        }
    }
}
