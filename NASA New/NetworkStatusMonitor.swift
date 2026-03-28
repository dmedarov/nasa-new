import Foundation
import Network
import SwiftUI

enum NetworkConnectionKind: Equatable {
    case wifi
    case cellular
    case wiredEthernet
    case loopback
    case other
    case unavailable

    var displayName: String {
        switch self {
        case .wifi:
            return L10n.text("Wi-Fi", default: "Wi-Fi")
        case .cellular:
            return L10n.text("Cellular", default: "Cellular")
        case .wiredEthernet:
            return L10n.text("Ethernet", default: "Ethernet")
        case .loopback:
            return L10n.text("Loopback", default: "Loopback")
        case .other:
            return L10n.text("Other", default: "Other")
        case .unavailable:
            return L10n.text("Unavailable", default: "Unavailable")
        }
    }
}

private struct NetworkFixtureState {
    let connectionKind: NetworkConnectionKind
    let isSatisfied: Bool
    let isExpensive: Bool
    let isConstrained: Bool

    static func fromEnvironment(_ environment: [String: String]) -> NetworkFixtureState? {
        guard environment["UITEST_USE_FIXTURE"] == "1" else { return nil }
        guard let rawKind = environment["UITEST_NETWORK_KIND"]?.lowercased() else { return nil }

        let connectionKind: NetworkConnectionKind
        switch rawKind {
        case "wifi":
            connectionKind = .wifi
        case "cellular":
            connectionKind = .cellular
        case "ethernet":
            connectionKind = .wiredEthernet
        case "loopback":
            connectionKind = .loopback
        case "other":
            connectionKind = .other
        case "offline", "unavailable":
            connectionKind = .unavailable
        default:
            return nil
        }

        return NetworkFixtureState(
            connectionKind: connectionKind,
            isSatisfied: connectionKind != .unavailable,
            isExpensive: environment["UITEST_NETWORK_EXPENSIVE"] == "1",
            isConstrained: environment["UITEST_NETWORK_CONSTRAINED"] == "1"
        )
    }
}

@MainActor
final class NetworkStatusMonitor: ObservableObject {
    @Published private(set) var connectionKind: NetworkConnectionKind = .unavailable
    @Published private(set) var isSatisfied = false
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NASA.NetworkStatusMonitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        if let fixtureState = NetworkFixtureState.fromEnvironment(ProcessInfo.processInfo.environment) {
            connectionKind = fixtureState.connectionKind
            isSatisfied = fixtureState.isSatisfied
            isExpensive = fixtureState.isExpensive
            isConstrained = fixtureState.isConstrained
            return
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path: path)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    private func apply(path: NWPath) {
        isSatisfied = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        guard isSatisfied else {
            connectionKind = .unavailable
            return
        }

        if path.usesInterfaceType(.wifi) {
            connectionKind = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionKind = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionKind = .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            connectionKind = .loopback
        } else {
            connectionKind = .other
        }
    }
}
