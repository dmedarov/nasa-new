import SwiftUI

@MainActor
final class NasaCollectionFetcher: ObservableObject {
    @Published private(set) var apodData = [NASA]()
    @Published var currentNasa = NASA.default
    @Published var error: FetchError?
    @Published private(set) var isFetching = false
    @Published private(set) var isUsingFixtureData = false

    private let session: URLSession
    private let apiKey: String
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let minimumAPODDate: Date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1995, month: 6, day: 16)) ?? .distantPast

    init(
        session: URLSession = .shared,
        apiKey: String = ProcessInfo.processInfo.environment["NASA_API_KEY"] ?? "DEMO_KEY",
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.apiKey = apiKey
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    private func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: max(date, minimumAPODDate))
    }

    private func buildURL(for date: Date? = nil) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        if let date {
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: normalizedDate(date))))
        } else {
            let now = nowProvider()
            let endDate = dateFormatter.string(from: now)
            let startDate = normalizedDate(calendar.date(byAdding: .day, value: -90, to: now) ?? now)
            let startDateString = dateFormatter.string(from: startDate)
            queryItems.append(URLQueryItem(name: "start_date", value: startDateString))
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    @available(iOS 15.0, *)
    func fetchData() async {
        await fetchData(for: nil)
    }

    @available(iOS 15.0, *)
    func fetchData(for date: Date?) async {
        guard !isUsingFixtureData else { return }
        guard !isFetching else { return }
        isFetching = true
        error = nil
        defer { isFetching = false }

        guard let url = buildURL(for: date) else {
            error = .badRequest
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw FetchError.httpStatus(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()

            if date != nil {
                let item = try decoder.decode(NASA.self, from: data)
                currentNasa = item
                if let index = apodData.firstIndex(where: { $0.id == item.id }) {
                    apodData[index] = item
                } else {
                    apodData.append(item)
                }
                apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
            } else {
                let decoded = try decoder.decode([NASA].self, from: data)
                    .sorted { ($0.date ?? "") < ($1.date ?? "") }
                guard !decoded.isEmpty else {
                    throw FetchError.emptyResponse
                }
                apodData = decoded
                currentNasa = decoded.last ?? .default
            }
        } catch is CancellationError {
            return
        } catch let fetchError as FetchError {
            error = fetchError
        } catch let urlError as URLError {
            if urlError.code != .cancelled {
                error = .network(urlError)
            }
        } catch let decodeError as DecodingError {
            error = .decoding(decodeError)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    func selectRandom(preferImagesOnly: Bool) {
        let candidates = preferImagesOnly ? apodData.filter { $0.mediaType == .image } : apodData
        guard let random = candidates.randomElement() else { return }
        currentNasa = random
    }

    func clearError() {
        error = nil
    }

    func configureFixtureModeIfNeeded() {
        guard ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] == "1" else { return }
        isUsingFixtureData = true
        error = nil

        let fixture = NASA(
            copyright: "NASA",
            date: "2025-01-15",
            explanation: "This is deterministic fixture content used for UI testing.",
            hdurl: URL(string: "https://example.com/apod_hd.jpg"),
            mediaType: .image,
            serviceVersion: "v1",
            title: "Fixture APOD",
            url: URL(string: "https://example.com/apod.jpg")
        )

        apodData = [fixture]
        currentNasa = fixture
    }

    enum FetchError: LocalizedError {
        case badRequest
        case invalidResponse
        case httpStatus(Int)
        case emptyResponse
        case decoding(DecodingError)
        case network(URLError)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .badRequest:
                return "Unable to load APOD data right now. Please try again."
            case .invalidResponse:
                return "NASA API returned an invalid response."
            case let .httpStatus(statusCode):
                return "NASA API request failed with status code \(statusCode)."
            case .emptyResponse:
                return "NASA API returned no APOD items."
            case .decoding:
                return "Received APOD data in an unexpected format."
            case .network:
                return "Network request failed. Check your connection and try again."
            case let .unknown(message):
                return "Unexpected error: \(message)"
            }
        }
    }
}
