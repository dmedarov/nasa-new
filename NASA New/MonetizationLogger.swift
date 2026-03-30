import Foundation
import OSLog

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
