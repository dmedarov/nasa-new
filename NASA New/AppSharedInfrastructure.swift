import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

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

        guard !(trimmedValue.hasPrefix("$(") && trimmedValue.hasSuffix(")")) else {
            return nil
        }

        return trimmedValue
    }
}

enum AppGroupConfiguration {
    static let identifier = "group.eu.medarov.nasa-new.shared"
    static let widgetKind = "NASA_New_Widget"

    static var sharedUserDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var sharedOfflineMediaDirectoryURL: URL {
        if let sharedContainerURL {
            return sharedContainerURL.appendingPathComponent("OfflineMedia", isDirectory: true)
        }

        let fallbackBaseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return fallbackBaseURL.appendingPathComponent("NASAOfflineMedia", isDirectory: true)
    }

    static func sharedFileURL(for relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        return sharedOfflineMediaDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    static func resetSharedUserDefaults() {
        guard let sharedDefaults = UserDefaults(suiteName: identifier) else { return }
        sharedDefaults.removePersistentDomain(forName: identifier)
        sharedDefaults.synchronize()
    }
}

enum AppWidgetRefreshCoordinator {
    static func reloadSharedTimelines() {
#if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConfiguration.widgetKind)
        }
#endif
    }
}

enum AppDestination: String, CaseIterable, Identifiable, Hashable, Codable {
    case today
    case archive
    case saved

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .today:
            return L10n.text("Today", default: "Today")
        case .archive:
            return L10n.text("Archive", default: "Archive")
        case .saved:
            return L10n.text("Saved", default: "Saved")
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "sparkles.tv"
        case .archive:
            return "books.vertical"
        case .saved:
            return "bookmark"
        }
    }
}

struct AppRoute: Codable, Equatable {
    let destination: AppDestination
    let apodDate: String?

    init(destination: AppDestination, apodDate: String? = nil) {
        self.destination = destination
        self.apodDate = apodDate
    }
}

enum AppDeepLink {
    static let scheme = "nasanew"
    private static let publicBaseURLInfoDictionaryKey = "APOD_PUBLIC_WEB_BASE_URL"
    private static let archiveHost = "archive"
    private static let savedHost = "saved"
    private static let todayHost = "today"
    private static let routeDateParameter = "date"

    static func configuredPublicBaseURL(bundle: Bundle = .main) -> URL? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: publicBaseURLInfoDictionaryKey) as? String else {
            return nil
        }
        return normalizedPublicBaseURL(from: rawValue)
    }

    static func publicWebURL(for route: AppRoute, publicBaseURL: URL? = configuredPublicBaseURL()) -> URL? {
        guard let publicBaseURL else { return nil }
        guard var components = URLComponents(url: publicBaseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = publicBaseURL.scheme?.lowercased()
        components.host = publicBaseURL.host?.lowercased()
        components.fragment = nil
        components.queryItems = nil

        let baseComponents = publicBaseURL.pathComponents.filter { $0 != "/" }
        components.path = "/" + (baseComponents + [route.destination.rawValue]).joined(separator: "/")

        if let apodDate = route.apodDate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !apodDate.isEmpty {
            components.queryItems = [URLQueryItem(name: routeDateParameter, value: apodDate)]
        }

        return components.url
    }

    static func url(for route: AppRoute, publicBaseURL: URL? = configuredPublicBaseURL()) -> URL? {
        var components = URLComponents()
        components.scheme = scheme

        switch route.destination {
        case .today:
            components.host = todayHost
        case .archive:
            components.host = archiveHost
        case .saved:
            components.host = savedHost
        }

        if let apodDate = route.apodDate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !apodDate.isEmpty {
            components.queryItems = [URLQueryItem(name: routeDateParameter, value: apodDate)]
        }

        return components.url
    }

    static func route(from url: URL, publicBaseURL: URL? = configuredPublicBaseURL()) -> AppRoute? {
        switch url.scheme?.lowercased() {
        case scheme:
            return routeFromCustomURL(url)
        case "http", "https":
            return routeFromPublicWebURL(url, publicBaseURL: publicBaseURL)
        default:
            return nil
        }
    }

    private static func routeFromCustomURL(_ url: URL) -> AppRoute? {
        let host = url.host?.lowercased()
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let date = components?.queryItems?.first(where: { $0.name == routeDateParameter })?.value

        switch host {
        case todayHost:
            return AppRoute(destination: .today, apodDate: date)
        case archiveHost:
            return AppRoute(destination: .archive, apodDate: date)
        case savedHost:
            return AppRoute(destination: .saved, apodDate: date)
        default:
            return nil
        }
    }

    private static func routeFromPublicWebURL(_ url: URL, publicBaseURL: URL?) -> AppRoute? {
        guard let publicBaseURL else { return nil }
        guard url.scheme?.lowercased() == publicBaseURL.scheme?.lowercased() else { return nil }
        guard url.host?.lowercased() == publicBaseURL.host?.lowercased() else { return nil }

        let basePathComponents = publicBaseURL.pathComponents.filter { $0 != "/" }
        var routePathComponents = url.pathComponents.filter { $0 != "/" }

        guard routePathComponents.starts(with: basePathComponents) else { return nil }
        routePathComponents.removeFirst(basePathComponents.count)

        guard let destinationComponent = routePathComponents.first,
              let destination = AppDestination(rawValue: destinationComponent.lowercased()) else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let date = components?.queryItems?.first(where: { $0.name == routeDateParameter })?.value
        return AppRoute(destination: destination, apodDate: date)
    }

    private static func normalizedPublicBaseURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        guard !trimmedValue.contains("$(") else { return nil }
        guard var components = URLComponents(string: trimmedValue) else { return nil }
        guard let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        guard components.host != nil else { return nil }

        components.fragment = nil
        components.query = nil
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }

        return components.url
    }
}

enum APODDateCoding {
    private static let displayHour = 12

    static func gregorianCalendar(from base: Calendar = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = base.locale
        calendar.timeZone = base.timeZone
        calendar.firstWeekday = base.firstWeekday
        calendar.minimumDaysInFirstWeek = base.minimumDaysInFirstWeek
        return calendar
    }

    static func date(from apiDateString: String?, calendar: Calendar = .current) -> Date? {
        guard let apiDateString = apiDateString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiDateString.isEmpty else {
            return nil
        }

        let parts = apiDateString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        let resolvedCalendar = gregorianCalendar(from: calendar)
        let components = DateComponents(year: year, month: month, day: day, hour: displayHour)

        guard let date = resolvedCalendar.date(from: components) else {
            return nil
        }

        let resolvedComponents = resolvedCalendar.dateComponents([.year, .month, .day], from: date)
        guard resolvedComponents.year == year,
              resolvedComponents.month == month,
              resolvedComponents.day == day else {
            return nil
        }

        return date
    }

    static func apiDateString(from date: Date, calendar: Calendar = .current) -> String {
        let resolvedCalendar = gregorianCalendar(from: calendar)
        let components = resolvedCalendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func normalizedDate(
        _ date: Date,
        minimumDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let resolvedCalendar = gregorianCalendar(from: calendar)
        let clampedDate = max(date, minimumDate)
        let components = resolvedCalendar.dateComponents([.year, .month, .day], from: clampedDate)

        return resolvedCalendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: displayHour
        )) ?? clampedDate
    }
}

enum AppUserActivityType {
    static let today = "eu.medarov.nasa-new.today"
    static let archive = "eu.medarov.nasa-new.archive"
    static let saved = "eu.medarov.nasa-new.saved"
    static let apod = "eu.medarov.nasa-new.apod"
}

enum PendingAppRouteStore {
    private static let storageKey = "app.pending.route.v1"

    static func save(_ route: AppRoute, userDefaults: UserDefaults = AppGroupConfiguration.sharedUserDefaults) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    static func consume(userDefaults: UserDefaults = AppGroupConfiguration.sharedUserDefaults) -> AppRoute? {
        defer { userDefaults.removeObject(forKey: storageKey) }

        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(AppRoute.self, from: data)
    }
}

enum APODContentSummaryPolicy {
    static func shortSummary(
        for explanation: String?,
        wordLimit: Int,
        placeholder: String
    ) -> String {
        guard let explanation = explanation?.trimmingCharacters(in: .whitespacesAndNewlines),
              !explanation.isEmpty else {
            return placeholder
        }

        let words = explanation.split(separator: " ")
        let limitedWords = words.prefix(wordLimit)
        let summary = limitedWords.joined(separator: " ")
        return limitedWords.count < words.count ? "\(summary)..." : summary
    }
}

struct APODLibrarySnapshot: Equatable {
    let cachedItems: [NASA]
    let favorites: [NASA]
}

enum APODStoredOfflineAvailability: String, Codable, Equatable {
    case remoteOnly
    case syncing
    case availableOffline
    case previewOffline
    case failed
}

struct APODStoredOfflineAsset: Codable, Equatable {
    let localAssetRelativePath: String?
    let localPreviewRelativePath: String?
    let availabilityRawValue: String

    var availability: APODStoredOfflineAvailability {
        APODStoredOfflineAvailability(rawValue: availabilityRawValue) ?? .remoteOnly
    }

    var localAssetURL: URL? {
        AppGroupConfiguration.sharedFileURL(for: localAssetRelativePath)
    }

    var localPreviewURL: URL? {
        if let localPreviewRelativePath {
            return AppGroupConfiguration.sharedFileURL(for: localPreviewRelativePath)
        }

        return localAssetURL
    }
}

protocol APODOfflineMediaRecordLoading {
    func loadRecords() async -> [String: APODStoredOfflineAsset]
}

actor SharedAPODOfflineMediaRecordLoader: APODOfflineMediaRecordLoading {
    private static let recordsKey = "nasa.apod.offline-media.records.v1"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = AppGroupConfiguration.sharedUserDefaults) {
        self.userDefaults = userDefaults
    }

    func loadRecords() async -> [String: APODStoredOfflineAsset] {
        guard let data = userDefaults.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([String: APODStoredOfflineAsset].self, from: data) else {
            return [:]
        }

        return records
    }
}

struct APODStoredEntry: Equatable {
    let nasa: NASA
    let isFavorite: Bool
    let offlineMedia: APODStoredOfflineAsset?

    var preferredLocalPreviewURL: URL? {
        if let previewURL = offlineMedia?.localPreviewURL {
            return previewURL
        }

        if nasa.mediaType == .image {
            return offlineMedia?.localAssetURL
        }

        return nil
    }
}

enum APODStoredEntryFreshness: Equatable {
    case current
    case stale
    case undated
}

struct APODStoredEntryResult: Equatable {
    let entry: APODStoredEntry
    let freshness: APODStoredEntryFreshness
}

protocol APODContentProviding {
    var apiKey: String { get }

    func dailyRequestURL(for date: Date, includeThumbnails: Bool) -> URL?
    func latestEntriesRequestURL(windowDayCount: Int) -> URL?
    func archiveRangeURL(startDate: Date, endDate: Date, includeThumbnails: Bool) -> URL?
    func librarySnapshot() -> APODLibrarySnapshot
    func latestStoredEntry() async -> APODStoredEntryResult?
    func storedEntry(forAPODDate apodDate: String) async -> APODStoredEntry?
    func route(for destination: AppDestination, date: Date) -> AppRoute
}

struct SharedAPODContentProvider: APODContentProviding {
    private static let defaultRecentWindowDayCount = 90

    let apiKey: String

    private let libraryStorage: any APODLibraryStorage
    private let offlineMediaLoader: any APODOfflineMediaRecordLoading
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var minimumAPODDate: Date {
        APODDateCoding.date(from: "1995-06-16", calendar: calendar) ?? .distantPast
    }

    init(
        libraryStorage: any APODLibraryStorage = APODLibraryStoreFactory.makeDefault(),
        offlineMediaLoader: any APODOfflineMediaRecordLoading = SharedAPODOfflineMediaRecordLoader(),
        apiKey: String = NASAAPIKeyConfiguration.resolvedAPIKey(),
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.libraryStorage = libraryStorage
        self.offlineMediaLoader = offlineMediaLoader
        self.apiKey = apiKey
        self.calendar = APODDateCoding.gregorianCalendar(from: calendar)
        self.nowProvider = nowProvider
    }

    func dailyRequestURL(for date: Date, includeThumbnails: Bool = false) -> URL? {
        requestURL(
            with: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "date", value: apiDateString(from: date))
            ],
            includeThumbnails: includeThumbnails
        )
    }

    func latestEntriesRequestURL(windowDayCount: Int = Self.defaultRecentWindowDayCount) -> URL? {
        let endDate = normalizedDate(nowProvider())
        let startDate = normalizedDate(
            calendar.date(byAdding: .day, value: -max(0, windowDayCount), to: endDate) ?? endDate
        )

        return requestURL(
            with: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "start_date", value: apiDateString(from: startDate)),
                URLQueryItem(name: "end_date", value: apiDateString(from: endDate))
            ],
            includeThumbnails: false
        )
    }

    func archiveRangeURL(
        startDate: Date,
        endDate: Date,
        includeThumbnails: Bool = false
    ) -> URL? {
        requestURL(
            with: [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "start_date", value: apiDateString(from: startDate)),
                URLQueryItem(name: "end_date", value: apiDateString(from: endDate))
            ],
            includeThumbnails: includeThumbnails
        )
    }

    func librarySnapshot() -> APODLibrarySnapshot {
        APODLibrarySnapshot(
            cachedItems: libraryStorage.loadCachedAPODItems().sorted { ($0.date ?? "") < ($1.date ?? "") },
            favorites: libraryStorage.loadFavorites().sorted { ($0.date ?? "") > ($1.date ?? "") }
        )
    }

    func latestStoredEntry() async -> APODStoredEntryResult? {
        let entries = await storedEntries()
        guard let latestEntry = entries.first else { return nil }
        return APODStoredEntryResult(entry: latestEntry, freshness: freshness(for: latestEntry.nasa))
    }

    func storedEntry(forAPODDate apodDate: String) async -> APODStoredEntry? {
        let normalizedDateString = apodDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDateString.isEmpty else { return nil }

        return await storedEntries().first(where: { $0.nasa.date == normalizedDateString })
    }

    func route(for destination: AppDestination = .today, date: Date) -> AppRoute {
        AppRoute(destination: destination, apodDate: apiDateString(from: date))
    }

    private func storedEntries() async -> [APODStoredEntry] {
        let snapshot = librarySnapshot()
        let offlineRecords = await offlineMediaLoader.loadRecords()
        var entriesByID = [String: APODStoredEntry]()

        for item in snapshot.cachedItems {
            entriesByID[item.id] = APODStoredEntry(
                nasa: item,
                isFavorite: false,
                offlineMedia: offlineRecords[item.id]
            )
        }

        for item in snapshot.favorites {
            let existingEntry = entriesByID[item.id]
            entriesByID[item.id] = APODStoredEntry(
                nasa: item,
                isFavorite: true,
                offlineMedia: existingEntry?.offlineMedia ?? offlineRecords[item.id]
            )
        }

        return entriesByID.values.sorted { lhs, rhs in
            let lhsDate = lhs.nasa.date ?? ""
            let rhsDate = rhs.nasa.date ?? ""

            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }

            return lhs.isFavorite && !rhs.isFavorite
        }
    }

    private func freshness(for nasa: NASA) -> APODStoredEntryFreshness {
        guard let rawDate = nasa.date else { return .undated }
        return rawDate == apiDateString(from: nowProvider()) ? .current : .stale
    }

    private func requestURL(with queryItems: [URLQueryItem], includeThumbnails: Bool) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        var resolvedQueryItems = queryItems
        if includeThumbnails {
            resolvedQueryItems.append(URLQueryItem(name: "thumbs", value: "true"))
        }
        components?.queryItems = resolvedQueryItems
        return components?.url
    }

    private func normalizedDate(_ date: Date) -> Date {
        APODDateCoding.normalizedDate(date, minimumDate: minimumAPODDate, calendar: calendar)
    }

    private func apiDateString(from date: Date) -> String {
        APODDateCoding.apiDateString(from: normalizedDate(date), calendar: calendar)
    }
}
