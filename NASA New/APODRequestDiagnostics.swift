import Foundation

struct RequestDiagnostic: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let endpoint: String
    let statusCode: Int?
    let result: String
    let transportError: String?
    let usedCache: Bool
}

enum APODRequestDiagnosticsPolicy {
    static let historyLimit = 20

    static func appending(
        _ item: RequestDiagnostic,
        to history: [RequestDiagnostic]
    ) -> [RequestDiagnostic] {
        var updatedHistory = history
        updatedHistory.insert(item, at: 0)
        if updatedHistory.count > historyLimit {
            updatedHistory.removeLast(updatedHistory.count - historyLimit)
        }
        return updatedHistory
    }

    static func sanitizedEndpoint(from url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.queryItems = components.queryItems?.map { item in
            if item.name == "api_key" {
                return URLQueryItem(name: item.name, value: "REDACTED")
            }
            return item
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    static func retryAfterDate(
        from response: HTTPURLResponse,
        referenceDate: Date,
        formatter: DateFormatter
    ) -> Date? {
        guard let rawValue = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(rawValue), seconds >= 0 {
            return referenceDate.addingTimeInterval(seconds)
        }

        return formatter.date(from: rawValue)
    }
}
