import SwiftUI

@MainActor
final class NasaCollectionFetcher: ObservableObject {
    enum Constants {
        static let foregroundRefreshInterval: TimeInterval = 60 * 60
        static let defaultCacheItemLimit = APODArchiveStoragePolicy.defaultArchiveLimit
        static let archiveBatchDayCount = 60
    }

    @Published var apodData = [NASA]() {
        didSet {
            refreshArchiveItemsCache()
        }
    }
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
    @Published var offlineMediaAssetsByID = [String: APODOfflineMediaAsset]()
    @Published private(set) var archiveItemsByNewestFirst = [NASA]()

    let service: APODService
    let apiKey: String
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    let contentProvider: any APODContentProviding
    let favoritesStorage: FavoritesStorage
    let cacheStorage: APODCacheStorage
    let offlineMediaStore: any APODOfflineMediaStore
    var activeRequestID = UUID()
    var latestFetchTask: Task<Void, Never>?
    var offlineMediaSyncTask: Task<Void, Never>?
    var fixtureScenario: FixtureScenario?
    var fixtureFetchCycle = 0
    let retryAfterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()
    private static let minimumAPODDateString = "1995-06-16"

    var minimumAPODDate: Date {
        APODDateCoding.date(from: Self.minimumAPODDateString, calendar: calendar) ?? .distantPast
    }

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
        cacheStorage: APODCacheStorage? = nil,
        offlineMediaStore: (any APODOfflineMediaStore)? = nil,
        contentProvider: (any APODContentProviding)? = nil
    ) {
        let defaultLibraryStorage = APODLibraryStoreFactory.makeDefault()
        let resolvedFavoritesStorage = favoritesStorage ?? defaultLibraryStorage
        let resolvedCacheStorage = cacheStorage ?? defaultLibraryStorage
        let resolvedOfflineMediaStore = offlineMediaStore ?? SharedAPODOfflineMediaStore(session: session)
        let resolvedLibraryStorage = CompositeAPODLibraryStorage(
            favoritesStorage: resolvedFavoritesStorage,
            cacheStorage: resolvedCacheStorage
        )

        self.service = URLSessionAPODService(session: session)
        self.apiKey = apiKey
        self.calendar = APODDateCoding.gregorianCalendar(from: calendar)
        self.nowProvider = nowProvider
        self.favoritesStorage = resolvedFavoritesStorage
        self.cacheStorage = resolvedCacheStorage
        self.offlineMediaStore = resolvedOfflineMediaStore
        self.contentProvider = contentProvider ?? SharedAPODContentProvider(
            libraryStorage: resolvedLibraryStorage,
            apiKey: apiKey,
            calendar: calendar,
            nowProvider: nowProvider
        )

        let librarySnapshot = self.contentProvider.librarySnapshot()
        self.favorites = librarySnapshot.favorites
        sortFavorites()

        let cachedItems = librarySnapshot.cachedItems
        if !cachedItems.isEmpty {
            self.apodData = cachedItems.sorted { ($0.date ?? "") < ($1.date ?? "") }
            self.currentNasa = self.apodData.last ?? .default
            self.isUsingCachedData = true
        }
        refreshArchiveItemsCache()

        if !isAPIKeyConfigured, ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] != "1" {
            apiKeyWarning = L10n.text(
                "api.key.warning.unconfigured",
                default: "NASA_API_KEY is not configured. Space Briefing is using DEMO_KEY, which is shared and may hit rate limits sooner."
            )
        }

        Task { [weak self] in
            await self?.bootstrapOfflineMediaState()
        }
    }

    func normalizedDate(_ date: Date) -> Date {
        APODDateCoding.normalizedDate(date, minimumDate: minimumAPODDate, calendar: calendar)
    }

    func apodDateString(from date: Date) -> String {
        APODDateCoding.apiDateString(from: normalizedDate(date), calendar: calendar)
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

    func refreshArchiveItemsCache() {
        archiveItemsByNewestFirst = Array(apodData.reversed())
        cachedItemCount = apodData.count
    }
}
