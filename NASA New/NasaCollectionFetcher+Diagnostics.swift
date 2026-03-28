import Foundation

extension NasaCollectionFetcher {
    func appendDiagnostic(
        endpoint: String,
        statusCode: Int?,
        result: String,
        transportError: String?,
        usedCache: Bool
    ) {
        let item = RequestDiagnostic(
            timestamp: nowProvider(),
            endpoint: endpoint,
            statusCode: statusCode,
            result: result,
            transportError: transportError,
            usedCache: usedCache
        )
        requestDiagnostics = APODRequestDiagnosticsPolicy.appending(item, to: requestDiagnostics)
    }

    func sanitizedEndpoint(from url: URL) -> String {
        APODRequestDiagnosticsPolicy.sanitizedEndpoint(from: url)
    }

    func retryAfterDate(from response: HTTPURLResponse, referenceDate: Date) -> Date? {
        APODRequestDiagnosticsPolicy.retryAfterDate(
            from: response,
            referenceDate: referenceDate,
            formatter: retryAfterDateFormatter
        )
    }
}
