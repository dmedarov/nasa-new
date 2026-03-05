import SwiftUI

final class NasaCollectionFetcher: ObservableObject {
    @Published var apodData = [NASA]()
    @Published var currentNasa = NASA.default
    @Published var error: Error?
    @Published var isFetching = false

    private let apiKey = "hrGZ2hLJibw2xXLJDWbYUjuF9YVVzovRufA2XmGJ"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func buildURL(for date: String? = nil) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        if let date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        } else {
            let endDate = dateFormatter.string(from: Date())
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
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
    func fetchData(for date: String?) async {
        let shouldStartFetch = await MainActor.run { () -> Bool in
            guard !isFetching else { return false }
            isFetching = true
            error = nil
            return true
        }

        guard shouldStartFetch else { return }

        guard let url = buildURL(for: date) else {
            await MainActor.run {
                error = FetchError.badRequest
                isFetching = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw FetchError.badRequest
            }

            let decoder = JSONDecoder()

            if let _ = date {
                let item = try decoder.decode(NASA.self, from: data)
                await MainActor.run {
                    currentNasa = item
                    if let index = apodData.firstIndex(where: { $0.date == item.date }) {
                        apodData[index] = item
                    } else {
                        apodData.append(item)
                    }
                    apodData.sort { ($0.date ?? "") < ($1.date ?? "") }
                    isFetching = false
                }
            } else {
                let decoded = try decoder.decode([NASA].self, from: data)
                    .sorted { ($0.date ?? "") < ($1.date ?? "") }
                await MainActor.run {
                    apodData = decoded
                    currentNasa = decoded.last ?? .default
                    isFetching = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                isFetching = false
            }
        }
    }

    @MainActor
    func clearError() {
        error = nil
    }

    enum FetchError: LocalizedError {
        case badRequest

        var errorDescription: String? {
            switch self {
            case .badRequest:
                return "Unable to load APOD data right now. Please try again."
            }
        }
    }
}
