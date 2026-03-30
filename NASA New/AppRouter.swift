import Foundation
import OSLog
#if canImport(StoreKit)
import StoreKit
#endif
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

enum AppProduct: String, CaseIterable {
    case proLifetime = "eu.medarov.spacebriefing.pro.lifetime"

    var fallbackDisplayName: String {
        switch self {
        case .proLifetime:
            return L10n.text("paywall.product.pro_lifetime", default: "Pro Lifetime")
        }
    }
}

struct StoreProductSnapshot: Equatable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}

enum PurchaseBackendResult: Equatable {
    case purchased
    case pending
    case cancelled
}

protocol PurchaseBackend: Sendable {
    func loadProducts(productIDs: [String]) async throws -> [StoreProductSnapshot]
    func currentEntitlementProductIDs() async -> Set<String>
    func purchase(productID: String) async throws -> PurchaseBackendResult
    func sync() async throws
    func transactionUpdates() async -> AsyncStream<Set<String>>
}

enum PurchaseBackendError: LocalizedError, Equatable {
    case missingProduct
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .missingProduct:
            return L10n.text("paywall.error.product_unavailable", default: "The Pro purchase is not available right now.")
        case .unverifiedTransaction:
            return L10n.text("paywall.error.unverified", default: "The App Store could not verify this purchase.")
        }
    }
}

#if canImport(StoreKit)
actor StoreKitPurchaseBackend: PurchaseBackend {
    private var productsByID = [String: Product]()

    func loadProducts(productIDs: [String]) async throws -> [StoreProductSnapshot] {
        let products = try await Product.products(for: productIDs)
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        return products.map {
            StoreProductSnapshot(
                id: $0.id,
                displayName: $0.displayName,
                description: $0.description,
                displayPrice: $0.displayPrice
            )
        }
    }

    func currentEntitlementProductIDs() async -> Set<String> {
        var productIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            productIDs.insert(transaction.productID)
        }

        return productIDs
    }

    func purchase(productID: String) async throws -> PurchaseBackendResult {
        let product = try await product(for: productID)
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseBackendError.unverifiedTransaction
            }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func transactionUpdates() async -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result else { continue }
                    await transaction.finish()
                    continuation.yield(await currentEntitlementProductIDs())
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func product(for productID: String) async throws -> Product {
        if let product = productsByID[productID] {
            return product
        }

        let loadedProducts = try await Product.products(for: [productID])
        guard let product = loadedProducts.first else {
            throw PurchaseBackendError.missingProduct
        }

        productsByID[productID] = product
        return product
    }
}
#endif

enum MonetizationEvent: Equatable {
    case paywallShown(trigger: PaywallTrigger, feature: PremiumFeature)
    case paywallDismissed(trigger: PaywallTrigger)
    case purchaseStarted(productID: String, trigger: PaywallTrigger?)
    case purchaseSucceeded(productID: String, trigger: PaywallTrigger?)
    case purchasePending(productID: String, trigger: PaywallTrigger?)
    case purchaseCancelled(productID: String, trigger: PaywallTrigger?)
    case purchaseFailed(productID: String, trigger: PaywallTrigger?, message: String)
    case restoreStarted
    case restoreCompleted(foundPro: Bool)
    case restoreFailed(message: String)

    var message: String {
        switch self {
        case let .paywallShown(trigger, feature):
            return "paywall_shown trigger=\(trigger.rawValue) feature=\(feature.rawValue)"
        case let .paywallDismissed(trigger):
            return "paywall_dismissed trigger=\(trigger.rawValue)"
        case let .purchaseStarted(productID, trigger):
            return "purchase_started product_id=\(productID) trigger=\(trigger?.rawValue ?? "none")"
        case let .purchaseSucceeded(productID, trigger):
            return "purchase_succeeded product_id=\(productID) trigger=\(trigger?.rawValue ?? "none")"
        case let .purchasePending(productID, trigger):
            return "purchase_pending product_id=\(productID) trigger=\(trigger?.rawValue ?? "none")"
        case let .purchaseCancelled(productID, trigger):
            return "purchase_cancelled product_id=\(productID) trigger=\(trigger?.rawValue ?? "none")"
        case let .purchaseFailed(productID, trigger, message):
            return "purchase_failed product_id=\(productID) trigger=\(trigger?.rawValue ?? "none") message=\(message)"
        case .restoreStarted:
            return "restore_started"
        case let .restoreCompleted(foundPro):
            return "restore_completed found_pro=\(foundPro)"
        case let .restoreFailed(message):
            return "restore_failed message=\(message)"
        }
    }
}

enum MonetizationLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "eu.medarov.NASA-New",
        category: "Monetization"
    )

    static func log(_ event: MonetizationEvent) {
        logger.info("\(event.message, privacy: .public)")
    }
}

struct PaywallPresentation: Identifiable, Equatable {
    let id = UUID()
    let trigger: PaywallTrigger
    let feature: PremiumFeature
}

@MainActor
final class PurchaseManager: ObservableObject {
    private enum StorageKey {
        static let archiveVisitCount = "monetization.archive.visit_count.v1"
        static let archiveAutoPaywallShown = "monetization.archive.auto_paywall_shown.v1"
        static let lastPaywallTrigger = "monetization.last_paywall_trigger.v1"
    }

    @Published private(set) var hasPro = false
    @Published private(set) var productsByID = [String: StoreProductSnapshot]()
    @Published var activePaywall: PaywallPresentation?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var paywallMessage: String?

    private let backend: any PurchaseBackend
    private let userDefaults: UserDefaults
    private let hasProOverride: Bool
    private var hasStarted = false
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        backend: (any PurchaseBackend)? = nil,
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.userDefaults = userDefaults
        self.hasProOverride = environment["UITEST_HAS_PRO"] == "1"
        self.hasPro = self.hasProOverride
#if canImport(StoreKit)
        self.backend = backend ?? StoreKitPurchaseBackend()
#else
        self.backend = backend ?? UnavailablePurchaseBackend()
#endif
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var proLifetimeProduct: StoreProductSnapshot? {
        productsByID[AppProduct.proLifetime.rawValue]
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }
            let updates = await backend.transactionUpdates()
            for await _ in updates {
                await self.refreshEntitlements()
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let snapshots = try await backend.loadProducts(productIDs: AppProduct.allCases.map(\.rawValue))
            productsByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        } catch {
            paywallMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        if hasProOverride {
            applyEntitlements(productIDs: [AppProduct.proLifetime.rawValue])
            return
        }

        let entitlementIDs = await backend.currentEntitlementProductIDs()
        applyEntitlements(productIDs: entitlementIDs)
    }

    func presentPaywall(trigger: PaywallTrigger, feature: PremiumFeature) {
        activePaywall = PaywallPresentation(trigger: trigger, feature: feature)
        paywallMessage = nil
        userDefaults.set(trigger.rawValue, forKey: StorageKey.lastPaywallTrigger)
        MonetizationLogger.log(.paywallShown(trigger: trigger, feature: feature))
    }

    func dismissPaywall() {
        guard let activePaywall else { return }
        MonetizationLogger.log(.paywallDismissed(trigger: activePaywall.trigger))
        self.activePaywall = nil
    }

    func purchaseLifetimeUnlock() async {
        let productID = AppProduct.proLifetime.rawValue
        let trigger = activePaywall?.trigger
        paywallMessage = nil
        isPurchasing = true
        MonetizationLogger.log(.purchaseStarted(productID: productID, trigger: trigger))

        defer { isPurchasing = false }

        do {
            let result = try await backend.purchase(productID: productID)

            switch result {
            case .purchased:
                await refreshEntitlements()
                MonetizationLogger.log(.purchaseSucceeded(productID: productID, trigger: trigger))
                activePaywall = nil
            case .pending:
                paywallMessage = L10n.text(
                    "paywall.purchase_pending",
                    default: "The App Store is still confirming your purchase."
                )
                MonetizationLogger.log(.purchasePending(productID: productID, trigger: trigger))
            case .cancelled:
                paywallMessage = nil
                MonetizationLogger.log(.purchaseCancelled(productID: productID, trigger: trigger))
            }
        } catch {
            paywallMessage = error.localizedDescription
            MonetizationLogger.log(.purchaseFailed(
                productID: productID,
                trigger: trigger,
                message: error.localizedDescription
            ))
        }
    }

    func restorePurchases() async {
        paywallMessage = nil
        isRestoring = true
        MonetizationLogger.log(.restoreStarted)

        defer { isRestoring = false }

        do {
            try await backend.sync()
            await refreshEntitlements()

            if hasPro {
                paywallMessage = L10n.text(
                    "paywall.restore_found",
                    default: "Your Pro unlock has been restored."
                )
                activePaywall = nil
            } else {
                paywallMessage = L10n.text(
                    "paywall.restore_missing",
                    default: "No past Pro purchase was found for this Apple Account."
                )
            }

            MonetizationLogger.log(.restoreCompleted(foundPro: hasPro))
        } catch {
            paywallMessage = error.localizedDescription
            MonetizationLogger.log(.restoreFailed(message: error.localizedDescription))
        }
    }

    func registerArchiveVisitIfNeeded() {
        guard !hasPro else { return }

        let visitCount = userDefaults.integer(forKey: StorageKey.archiveVisitCount) + 1
        userDefaults.set(visitCount, forKey: StorageKey.archiveVisitCount)

        guard visitCount >= 3 else { return }
        guard !userDefaults.bool(forKey: StorageKey.archiveAutoPaywallShown) else { return }

        userDefaults.set(true, forKey: StorageKey.archiveAutoPaywallShown)
        presentPaywall(trigger: .archiveVisitNudge, feature: .fullArchive)
    }

    func canAccessArchive(date: Date, referenceDate: Date, calendar: Calendar) -> Bool {
        PremiumAccessPolicy.canAccessArchive(
            date: date,
            hasPro: hasPro,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    func canAddFavorite(currentCount: Int, isAlreadyFavorite: Bool) -> Bool {
        isAlreadyFavorite || PremiumAccessPolicy.canAddFavorite(count: currentCount, hasPro: hasPro)
    }

    func canSaveOriginalMedia(apod: NASA) -> Bool {
        PremiumAccessPolicy.canSaveOriginalMedia(apod: apod, hasPro: hasPro)
    }

    private func applyEntitlements(productIDs: Set<String>) {
        hasPro = productIDs.contains(AppProduct.proLifetime.rawValue)
    }
}

private struct UnavailablePurchaseBackend: PurchaseBackend {
    func loadProducts(productIDs: [String]) async throws -> [StoreProductSnapshot] {
        []
    }

    func currentEntitlementProductIDs() async -> Set<String> {
        []
    }

    func purchase(productID: String) async throws -> PurchaseBackendResult {
        throw PurchaseBackendError.missingProduct
    }

    func sync() async throws {}

    func transactionUpdates() async -> AsyncStream<Set<String>> {
        AsyncStream { _ in }
    }
}
