import Foundation
import SwiftUI

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
