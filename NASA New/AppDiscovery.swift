import Foundation

#if canImport(CoreSpotlight)
import CoreSpotlight
import UniformTypeIdentifiers
#endif

enum AppDiscoveryCoordinator {
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static func configure(activity: NSUserActivity, for nasa: NASA, destination: AppDestination) {
        let route = AppRoute(destination: destination, apodDate: nasa.date)

        activity.title = nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture")
        activity.userInfo = userInfo(for: route)
        activity.isEligibleForSearch = true
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForPublicIndexing = false
        activity.persistentIdentifier = NSUserActivityPersistentIdentifier(nasa.id)
        activity.targetContentIdentifier = nasa.id
        activity.requiredUserInfoKeys = Set(["destination", "apodDate", "routeData"])
        activity.webpageURL = AppDeepLink.publicWebURL(for: route)
        activity.contentAttributeSet = attributeSet(for: nasa)
    }

    static func refreshSearchIndex(archive: [NASA], favorites: [NASA]) {
#if canImport(CoreSpotlight)
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let savedIDs = Set(favorites.map(\.id))
        let archiveSlice = archive.sorted { ($0.date ?? "") > ($1.date ?? "") }.prefix(120)
        let favoritesSlice = favorites.sorted { ($0.date ?? "") > ($1.date ?? "") }.prefix(60)

        let archiveItems = archiveSlice.map {
            searchableItem(for: $0, destination: savedIDs.contains($0.id) ? .saved : .archive)
        }
        let favoriteItems = favoritesSlice.map {
            searchableItem(for: $0, destination: .saved)
        }

        let allItems = deduplicatedSearchItems(from: archiveItems + favoriteItems)

        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["apod.archive", "apod.saved"]) { _ in
            CSSearchableIndex.default().indexSearchableItems(allItems)
        }
#endif
    }

    static func userInfo(for route: AppRoute) -> [AnyHashable: Any] {
        let encodedRoute = try? JSONEncoder().encode(route)
        return [
            "destination": route.destination.rawValue,
            "apodDate": route.apodDate as Any,
            "routeData": encodedRoute as Any
        ]
    }

#if canImport(CoreSpotlight)
    private static func searchableItem(for nasa: NASA, destination: AppDestination) -> CSSearchableItem {
        let route = AppRoute(destination: destination, apodDate: nasa.date)
        let attributeSet = attributeSet(for: nasa)
        let uniqueIdentifier = "\(destination.rawValue)|\(nasa.id)"

        if let contentURL = AppDeepLink.url(for: route) {
            attributeSet.contentURL = contentURL
        }

        return CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: destination == .saved ? "apod.saved" : "apod.archive",
            attributeSet: attributeSet
        )
    }

    private static func deduplicatedSearchItems(from items: [CSSearchableItem]) -> [CSSearchableItem] {
        var seen = Set<String>()
        var result = [CSSearchableItem]()

        for item in items {
            if seen.insert(item.uniqueIdentifier).inserted {
                result.append(item)
            }
        }

        return result
    }
#endif

    private static func attributeSet(for nasa: NASA) -> CSSearchableItemAttributeSet {
#if canImport(CoreSpotlight)
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture")
        attributeSet.contentDescription = nasa.explanation
        attributeSet.subject = APODAttributionPolicy.creditLine(for: nasa)
        attributeSet.creator = APODAttributionPolicy.creditLine(for: nasa)
        attributeSet.displayName = nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture")
        if let rawDate = nasa.date,
           let creationDate = apiDateFormatter.date(from: rawDate) {
            attributeSet.contentCreationDate = creationDate
        }
        attributeSet.keywords = [
            L10n.text("Today", default: "Today"),
            L10n.text("Archive", default: "Archive"),
            L10n.text("Saved", default: "Saved"),
            L10n.text("Astronomy Picture of the Day", default: "Astronomy Picture of the Day"),
            L10n.text("Space Briefing", default: "Space Briefing"),
            nasa.date ?? "",
            APODAttributionPolicy.creditLine(for: nasa)
        ].filter { !$0.isEmpty }
        return attributeSet
#else
        fatalError("CoreSpotlight is unavailable on this platform.")
#endif
    }
}
