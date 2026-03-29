import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

private enum WidgetLocalization {
    static func text(_ key: String, default defaultValue: String) -> String {
        NSLocalizedString(key, bundle: .main, value: defaultValue, comment: "")
    }
}

private struct APODWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let summary: String
    let credit: String
    let apodDate: String
    let imageData: Data?
    let mediaBadge: String
    let deepLinkURL: URL?
    let stateTitle: String?
    let stateMessage: String?

    static let placeholder = APODWidgetEntry(
        date: Date(),
        title: WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
        summary: WidgetLocalization.text(
            "widget.placeholder.summary",
            default: "An independent daily briefing built from NASA's public APOD archive."
        ),
        credit: WidgetLocalization.text("credit.nasa", default: "NASA"),
        apodDate: "",
        imageData: nil,
        mediaBadge: WidgetLocalization.text("widget.media.apod", default: "APOD"),
        deepLinkURL: APODWidgetAPI.widgetDestinationURL(for: nil),
        stateTitle: nil,
        stateMessage: nil
    )
}

private struct APODWidgetPayload: Decodable {
    let copyright: String?
    let date: String?
    let explanation: String?
    let hdurl: URL?
    let mediaType: String?
    let thumbnailURL: URL?
    let title: String?
    let url: URL?

    private enum CodingKeys: String, CodingKey {
        case copyright
        case date
        case explanation
        case hdurl
        case mediaType = "media_type"
        case thumbnailURL = "thumbnail_url"
        case title
        case url
    }
}

private enum APODWidgetAPI {
    static let kind = AppGroupConfiguration.widgetKind
    private static let refreshHours = 4

    static func placeholderEntry() -> APODWidgetEntry {
        .placeholder
    }

    static func snapshot(completion: @escaping (APODWidgetEntry) -> Void) {
        Task {
            completion(await latestEntry())
        }
    }

    static func timeline(completion: @escaping (Timeline<APODWidgetEntry>) -> Void) {
        Task {
            let entry = await latestEntry()
            let refreshDate = Calendar.current.date(byAdding: .hour, value: refreshHours, to: Date())
                ?? Date().addingTimeInterval(TimeInterval(refreshHours * 3600))
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private static func latestEntry() async -> APODWidgetEntry {
        let cachedItem = latestCachedItem()

        if let cachedItem, isCurrentAPODDate(cachedItem.date) {
            return await cachedEntry(for: cachedItem)
        }

        if let liveEntry = await liveNetworkEntry() {
            return liveEntry
        }

        if let cachedItem {
            return await cachedEntry(for: cachedItem)
        }

        return unavailableEntry(
            title: WidgetLocalization.text("widget.unavailable.title", default: "Latest APOD unavailable"),
            message: WidgetLocalization.text(
                "widget.unavailable.message",
                default: "The widget could not prepare today's APOD briefing from NASA's public archive."
            )
        )
    }

    private static func liveNetworkEntry() async -> APODWidgetEntry? {
        guard let requestURL = requestURL() else { return nil }

        do {
            let (payloadData, _) = try await URLSession.shared.data(from: requestURL)
            let payload = try JSONDecoder().decode(APODWidgetPayload.self, from: payloadData)
            let imageData = await loadImageData(for: payload)

            return APODWidgetEntry(
                date: Date(),
                title: payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
                summary: summarize(payload.explanation),
                credit: payload.copyright?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? WidgetLocalization.text("credit.nasa", default: "NASA"),
                apodDate: displayDate(from: payload.date ?? ""),
                imageData: imageData,
                mediaBadge: mediaBadge(for: payload.mediaType),
                deepLinkURL: deepLinkURL(for: payload.date),
                stateTitle: nil,
                stateMessage: nil
            )
        } catch {
            return nil
        }
    }

    private static func latestCachedItem() -> NASA? {
        let storage = APODLibraryStoreFactory.makeDefault()
        let archiveItems = storage.loadCachedAPODItems().sorted { ($0.date ?? "") < ($1.date ?? "") }
        if let latestArchiveItem = archiveItems.last {
            return latestArchiveItem
        }

        return storage.loadFavorites().sorted { ($0.date ?? "") > ($1.date ?? "") }.first
    }

    private static func cachedEntry(for nasa: NASA) async -> APODWidgetEntry {
        let imageData = await loadImageData(for: nasa)

        return APODWidgetEntry(
            date: Date(),
            title: nasa.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
            summary: summarize(nasa.explanation),
            credit: nasa.copyright?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? WidgetLocalization.text("credit.nasa", default: "NASA"),
            apodDate: displayDate(from: nasa.date ?? ""),
            imageData: imageData,
            mediaBadge: mediaBadge(for: nasa.mediaType),
            deepLinkURL: deepLinkURL(for: nasa.date),
            stateTitle: nil,
            stateMessage: nil
        )
    }

    private static func requestURL() -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey()),
            URLQueryItem(name: "thumbs", value: "true")
        ]
        return components?.url
    }

    private static func apiKey() -> String {
        guard let configuredValue = Bundle.main.object(forInfoDictionaryKey: "NASA_API_KEY") as? String else {
            return "DEMO_KEY"
        }

        let trimmedValue = configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? "DEMO_KEY" : trimmedValue
    }

    private static func loadImageData(for payload: APODWidgetPayload) async -> Data? {
        guard let url = preferredImageURL(for: payload) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return data
    }

    private static func loadImageData(for nasa: NASA) async -> Data? {
        guard let url = preferredImageURL(for: nasa) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return data
    }

    private static func preferredImageURL(for payload: APODWidgetPayload) -> URL? {
        let mediaType = (payload.mediaType ?? "").lowercased()
        if mediaType == "image" {
            return payload.url ?? payload.hdurl
        }
        if mediaType == "video" {
            return payload.thumbnailURL
        }
        return payload.url ?? payload.hdurl ?? payload.thumbnailURL
    }

    private static func preferredImageURL(for nasa: NASA) -> URL? {
        switch nasa.mediaType {
        case .image:
            return nasa.url ?? nasa.hdurl
        case .video:
            return nil
        case .other:
            return nasa.url ?? nasa.hdurl
        }
    }

    private static func summarize(_ explanation: String?) -> String {
        guard let explanation = explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !explanation.isEmpty else {
            return WidgetLocalization.text(
                "widget.placeholder.summary",
                default: "An independent daily briefing built from NASA's public APOD archive."
            )
        }

        let words = explanation.split(separator: " ")
        let limitedWords = words.prefix(22)
        let summary = limitedWords.joined(separator: " ")
        return limitedWords.count < words.count ? "\(summary)..." : summary
    }

    private static func mediaBadge(for mediaType: String?) -> String {
        switch (mediaType ?? "").lowercased() {
        case "video":
            return WidgetLocalization.text("widget.media.video", default: "Video")
        case "image":
            return WidgetLocalization.text("widget.media.image", default: "Image")
        default:
            return WidgetLocalization.text("widget.media.apod", default: "APOD")
        }
    }

    private static func mediaBadge(for mediaType: MediaType) -> String {
        mediaBadge(for: mediaType.rawValue)
    }

    private static func displayDate(from rawDate: String) -> String {
        guard let parsedDate = Self.apiDateFormatter.date(from: rawDate) else { return rawDate }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: parsedDate)
    }

    private static func deepLinkURL(for rawDate: String?) -> URL? {
        widgetDestinationURL(for: rawDate)
    }

    fileprivate static func widgetDestinationURL(for rawDate: String?) -> URL? {
        let trimmedDate = rawDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDate = trimmedDate?.isEmpty == false ? trimmedDate : nil

        if let publicBaseURL = configuredPublicBaseURL(),
           var components = URLComponents(url: publicBaseURL, resolvingAgainstBaseURL: false) {
            components.scheme = publicBaseURL.scheme?.lowercased()
            components.host = publicBaseURL.host?.lowercased()
            components.fragment = nil
            components.queryItems = normalizedDate.map { [URLQueryItem(name: "date", value: $0)] }

            let baseComponents = publicBaseURL.pathComponents.filter { $0 != "/" }
            components.path = "/" + (baseComponents + ["today"]).joined(separator: "/")
            return components.url
        }

        var components = URLComponents()
        components.scheme = "nasanew"
        components.host = "today"
        components.queryItems = normalizedDate.map { [URLQueryItem(name: "date", value: $0)] }
        return components.url
    }

    private static func configuredPublicBaseURL(bundle: Bundle = .main) -> URL? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "APOD_PUBLIC_WEB_BASE_URL") as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, !trimmedValue.contains("$(") else { return nil }
        guard var components = URLComponents(string: trimmedValue) else { return nil }
        guard let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else {
            return nil
        }

        components.fragment = nil
        components.query = nil
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }

        return components.url
    }

    private static func isCurrentAPODDate(_ rawDate: String?) -> Bool {
        guard let rawDate else { return false }
        return rawDate == apiDateFormatter.string(from: Date())
    }

    private static func unavailableEntry(title: String, message: String) -> APODWidgetEntry {
        APODWidgetEntry(
            date: Date(),
            title: WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
            summary: WidgetLocalization.text(
                "widget.placeholder.summary",
                default: "An independent daily briefing built from NASA's public APOD archive."
            ),
            credit: WidgetLocalization.text("credit.nasa", default: "NASA"),
            apodDate: "",
            imageData: nil,
            mediaBadge: WidgetLocalization.text("widget.media.apod", default: "APOD"),
            deepLinkURL: APODWidgetAPI.widgetDestinationURL(for: nil),
            stateTitle: title,
            stateMessage: message
        )
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()
}

private struct APODWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> APODWidgetEntry {
        APODWidgetAPI.placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (APODWidgetEntry) -> Void) {
        if context.isPreview {
            completion(APODWidgetAPI.placeholderEntry())
        } else {
            APODWidgetAPI.snapshot(completion: completion)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<APODWidgetEntry>) -> Void) {
        APODWidgetAPI.timeline(completion: completion)
    }
}

@main
struct NASA_New_Widget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: APODWidgetAPI.kind, provider: APODWidgetProvider()) { entry in
            APODWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(
            WidgetLocalization.text("widget.configuration.title", default: "Space Briefing Today")
        )
        .description(
            WidgetLocalization.text(
                "widget.configuration.description",
                default: "Open today's independent APOD briefing from your Home Screen."
            )
        )
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

private struct APODWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: APODWidgetEntry

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                accessoryBody
            } else {
                editorialBody
            }
        }
        .widgetURL(entry.deepLinkURL)
    }

    private var editorialBody: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 10) {
                topRow

                Spacer(minLength: 0)

                if let stateTitle = entry.stateTitle, let stateMessage = entry.stateMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(stateTitle)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(stateMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(family == .systemLarge ? 4 : 3)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(family == .systemSmall ? .headline : .title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(family == .systemLarge ? 3 : 2)

                        Text(entry.summary)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.84))
                            .lineLimit(family == .systemLarge ? 5 : 3)
                    }
                }

                Spacer(minLength: 0)

                bottomRow
            }
            .padding(16)
        }
    }

    private var accessoryBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.mediaBadge.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(entry.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)

            Text(entry.apodDate.isEmpty ? entry.credit : entry.apodDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.18),
                    Color(red: 0.11, green: 0.16, blue: 0.29),
                    Color(red: 0.27, green: 0.15, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let widgetImage {
                Image(uiImage: widgetImage)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.32),
                                Color.black.opacity(0.74)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                RadialGradient(
                    colors: [Color.white.opacity(0.2), Color.clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 180
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            Text(entry.mediaBadge.uppercased())
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())

            Spacer(minLength: 0)

            if !entry.apodDate.isEmpty {
                Text(entry.apodDate)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .center) {
            Text(entry.credit)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(WidgetLocalization.text("widget.open_today", default: "Open briefing"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var widgetImage: UIImage? {
#if canImport(UIKit)
        guard let imageData = entry.imageData else { return nil }
        return UIImage(data: imageData)
#else
        return nil
#endif
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
