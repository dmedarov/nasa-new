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

    func consumePendingRouteIfNeeded(
        fetcher: NasaCollectionFetcher,
        purchaseManager: PurchaseManager? = nil
    ) {
        guard let route = PendingAppRouteStore.consume() else { return }
        handle(
            route,
            fetcher: fetcher,
            purchaseManager: purchaseManager,
            lockedDateTrigger: .appIntentLockedDate
        )
    }

    func handle(
        url: URL,
        fetcher: NasaCollectionFetcher,
        purchaseManager: PurchaseManager? = nil
    ) {
        guard let route = AppDeepLink.route(from: url) else { return }
        handle(
            route,
            fetcher: fetcher,
            purchaseManager: purchaseManager,
            lockedDateTrigger: .deepLinkLockedDate
        )
    }

    func handle(
        userActivity: NSUserActivity,
        fetcher: NasaCollectionFetcher,
        purchaseManager: PurchaseManager? = nil
    ) {
        if let webpageURL = userActivity.webpageURL {
            handle(url: webpageURL, fetcher: fetcher, purchaseManager: purchaseManager)
            return
        }

        guard let route = userActivity.userInfo.flatMap(Self.route(from:)) else { return }
        handle(
            route,
            fetcher: fetcher,
            purchaseManager: purchaseManager,
            lockedDateTrigger: .appIntentLockedDate
        )
    }

    func handle(
        _ route: AppRoute,
        fetcher: NasaCollectionFetcher,
        purchaseManager: PurchaseManager? = nil,
        lockedDateTrigger: PaywallTrigger = .appIntentLockedDate
    ) {
        let requestedDate = route.apodDate.flatMap(fetcher.date(from:))
        let matchingItem = route.apodDate.flatMap(fetcher.apodItem(forAPODDate:))

        if let requestedDate,
           shouldPresentArchivePaywall(
                for: route,
                requestedDate: requestedDate,
                matchingItem: matchingItem,
                fetcher: fetcher,
                purchaseManager: purchaseManager
           ) {
            purchaseManager?.presentPaywall(trigger: lockedDateTrigger, feature: .fullArchive)
            return
        }

        if let matchingItem {
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

        guard route.apodDate != nil,
              let requestedDate else {
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

    private func shouldPresentArchivePaywall(
        for route: AppRoute,
        requestedDate: Date,
        matchingItem: NASA?,
        fetcher: NasaCollectionFetcher,
        purchaseManager: PurchaseManager?
    ) -> Bool {
        guard let purchaseManager else { return false }

        if route.destination == .saved,
           let matchingItem,
           fetcher.isFavorite(matchingItem) {
            return false
        }

        return !purchaseManager.canAccessArchive(
            date: requestedDate,
            referenceDate: fetcher.maximumSelectableDate,
            calendar: fetcher.calendar
        )
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
