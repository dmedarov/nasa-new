import Foundation
import SwiftUI

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
    private static let archiveHost = "archive"
    private static let savedHost = "saved"
    private static let todayHost = "today"
    private static let routeDateParameter = "date"

    static func url(for route: AppRoute) -> URL? {
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

    static func route(from url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == scheme else { return nil }

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

@MainActor
final class AppRouter: ObservableObject {
    @Published var destination: AppDestination = .today
    @Published var selectedArchiveItemID: String?
    @Published var selectedSavedItemID: String?

    func showToday() {
        destination = .today
    }

    func showArchive(item: NASA? = nil) {
        destination = .archive
        selectedArchiveItemID = item?.id
    }

    func showSaved(item: NASA? = nil) {
        destination = .saved
        selectedSavedItemID = item?.id
    }

    func consumePendingRouteIfNeeded(fetcher: NasaCollectionFetcher) {
        guard let route = PendingAppRouteStore.consume() else { return }
        handle(route, fetcher: fetcher)
    }

    func handle(url: URL, fetcher: NasaCollectionFetcher) {
        guard let route = AppDeepLink.route(from: url) else { return }
        handle(route, fetcher: fetcher)
    }

    func handle(userActivity: NSUserActivity, fetcher: NasaCollectionFetcher) {
        if let webpageURL = userActivity.webpageURL {
            handle(url: webpageURL, fetcher: fetcher)
            return
        }

        guard let route = userActivity.userInfo.flatMap(Self.route(from:)) else { return }
        handle(route, fetcher: fetcher)
    }

    func handle(_ route: AppRoute, fetcher: NasaCollectionFetcher) {
        if let matchingItem = route.apodDate.flatMap(fetcher.apodItem(forAPODDate:)) {
            fetcher.selectArchivedItem(matchingItem)

            switch route.destination {
            case .today:
                showToday()
            case .archive:
                showArchive(item: matchingItem)
            case .saved:
                if fetcher.isFavorite(matchingItem) {
                    showSaved(item: matchingItem)
                } else {
                    showArchive(item: matchingItem)
                }
            }
            return
        }

        guard let dateString = route.apodDate,
              let requestedDate = fetcher.date(from: dateString) else {
            switch route.destination {
            case .today:
                showToday()
            case .archive:
                showArchive()
            case .saved:
                showSaved()
            }
            return
        }

        // If the entry is not cached yet, fetch it directly and land in the editorial reader.
        showToday()
        fetcher.startLatestFetch(for: requestedDate)
    }

    private static func route(from userInfo: [AnyHashable: Any]) -> AppRoute? {
        if let data = userInfo["routeData"] as? Data,
           let route = try? JSONDecoder().decode(AppRoute.self, from: data) {
            return route
        }

        guard let destinationRawValue = userInfo["destination"] as? String,
              let destination = AppDestination(rawValue: destinationRawValue) else {
            return nil
        }

        return AppRoute(destination: destination, apodDate: userInfo["apodDate"] as? String)
    }
}
