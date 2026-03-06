import Foundation

/// Enum representing the media types supported by NASA's APOD API.
enum MediaType: String, Codable {
    case image
    case video
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = MediaType(rawValue: value) ?? .other
    }
}

/// Struct representing a NASA Astronomy Picture of the Day (APOD) entry.
struct NASA: Codable, Identifiable {
    var id: String {
        if
            let date, !date.isEmpty,
            let url, !url.absoluteString.isEmpty
        {
            return "date:\(date)|url:\(url.absoluteString)"
        }
        if let date, !date.isEmpty { return "date:\(date)" }
        if let url, !url.absoluteString.isEmpty { return "url:\(url.absoluteString)" }
        if let explanation, !explanation.isEmpty { return "explanation:\(explanation.prefix(64))" }
        if let title, !title.isEmpty { return "title:\(title)" }
        return "unknown-apod"
    }
    let copyright: String?
    let date: String?
    let explanation: String?
    let hdurl: URL?
    let mediaType: MediaType
    let serviceVersion: String?
    let title: String?
    let url: URL?
    
    private enum CodingKeys: String, CodingKey {
        case copyright
        case date
        case explanation
        case hdurl
        case mediaType = "media_type"
        case serviceVersion = "service_version"
        case title
        case url
    }

    init(
        copyright: String? = nil,
        date: String? = nil,
        explanation: String? = nil,
        hdurl: URL? = nil,
        mediaType: MediaType = .image,
        serviceVersion: String? = nil,
        title: String? = nil,
        url: URL? = nil
    ) {
        self.copyright = copyright
        self.date = date
        self.explanation = explanation
        self.hdurl = hdurl
        self.mediaType = mediaType
        self.serviceVersion = serviceVersion
        self.title = title
        self.url = url
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func validDateString(from value: String?) -> String? {
        guard let value, apiDateFormatter.date(from: value) != nil else { return nil }
        return value
    }

    private static func validHTTPURL(from value: String?) -> URL? {
        guard
            let value,
            let parsedURL = URL(string: value),
            let scheme = parsedURL.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return parsedURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
        self.date = NASA.validDateString(from: try container.decodeIfPresent(String.self, forKey: .date))
        self.explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? "No explanation available."
        self.hdurl = NASA.validHTTPURL(from: try container.decodeIfPresent(String.self, forKey: .hdurl))
        self.mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType) ?? .other
        self.serviceVersion = try container.decodeIfPresent(String.self, forKey: .serviceVersion) ?? "v1"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        self.url = NASA.validHTTPURL(from: try container.decodeIfPresent(String.self, forKey: .url))
    }
}

extension NASA {
    static let `default` = NASA(
        copyright: nil,
        date: nil,
        explanation: "No data available.",
        hdurl: nil,
        mediaType: .image,
        serviceVersion: "v1",
        title: "No Image Available",
        url: nil
    )
}
