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
        deepLinkURL: AppDeepLink.url(for: AppRoute(destination: .today)),
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
        let contentProvider = SharedAPODContentProvider()
        let cachedEntryResult = await contentProvider.latestStoredEntry()

        if let cachedEntryResult, cachedEntryResult.freshness == .current {
            return await cachedEntry(for: cachedEntryResult, showFallbackState: false)
        }

        if let liveEntry = await liveNetworkEntry(using: contentProvider) {
            return liveEntry
        }

        if let cachedEntryResult {
            return await cachedEntry(for: cachedEntryResult, showFallbackState: true)
        }

        return unavailableEntry(
            title: WidgetLocalization.text("widget.unavailable.title", default: "Latest APOD unavailable"),
            message: WidgetLocalization.text(
                "widget.unavailable.message",
                default: "The widget could not prepare today's APOD briefing from NASA's public archive."
            )
        )
    }

    private static func liveNetworkEntry(using contentProvider: SharedAPODContentProvider) async -> APODWidgetEntry? {
        guard let requestURL = contentProvider.dailyRequestURL(for: Date(), includeThumbnails: true) else {
            return nil
        }

        do {
            let (payloadData, _) = try await URLSession.shared.data(from: requestURL)
            let payload = try JSONDecoder().decode(APODWidgetPayload.self, from: payloadData)
            let storedEntry: APODStoredEntry?
            if let payloadDate = payload.date {
                storedEntry = await contentProvider.storedEntry(forAPODDate: payloadDate)
            } else {
                storedEntry = nil
            }
            let locallyPreferredImageData: Data?
            if let storedEntry {
                locallyPreferredImageData = await loadImageData(for: storedEntry)
            } else {
                locallyPreferredImageData = nil
            }
            let remoteImageData = await loadImageData(for: payload)
            let imageData = locallyPreferredImageData ?? remoteImageData

            return APODWidgetEntry(
                date: Date(),
                title: payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
                summary: APODContentSummaryPolicy.shortSummary(
                    for: payload.explanation,
                    wordLimit: 22,
                    placeholder: WidgetLocalization.text(
                        "widget.placeholder.summary",
                        default: "An independent daily briefing built from NASA's public APOD archive."
                    )
                ),
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

    private static func cachedEntry(
        for storedEntryResult: APODStoredEntryResult,
        showFallbackState: Bool
    ) async -> APODWidgetEntry {
        let storedEntry = storedEntryResult.entry
        let imageData = await loadImageData(for: storedEntry)
        let fallbackState = showFallbackState ? fallbackState(for: storedEntryResult) : nil

        return APODWidgetEntry(
            date: Date(),
            title: storedEntry.nasa.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? WidgetLocalization.text("widget.placeholder.title", default: "Astronomy Picture of the Day"),
            summary: APODContentSummaryPolicy.shortSummary(
                for: storedEntry.nasa.explanation,
                wordLimit: 22,
                placeholder: WidgetLocalization.text(
                    "widget.placeholder.summary",
                    default: "An independent daily briefing built from NASA's public APOD archive."
                )
            ),
            credit: storedEntry.nasa.copyright?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? WidgetLocalization.text("credit.nasa", default: "NASA"),
            apodDate: displayDate(from: storedEntry.nasa.date ?? ""),
            imageData: imageData,
            mediaBadge: mediaBadge(for: storedEntry.nasa.mediaType),
            deepLinkURL: deepLinkURL(for: storedEntry.nasa.date),
            stateTitle: fallbackState?.title,
            stateMessage: fallbackState?.message
        )
    }

    private static func loadImageData(for payload: APODWidgetPayload) async -> Data? {
        guard let url = preferredImageURL(for: payload) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return data
    }

    private static func loadImageData(for storedEntry: APODStoredEntry) async -> Data? {
        if let localPreviewURL = storedEntry.preferredLocalPreviewURL,
           let localData = try? Data(contentsOf: localPreviewURL) {
            return localData
        }

        guard let url = preferredImageURL(for: storedEntry.nasa) else { return nil }
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
        let trimmedDate = rawDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDate = trimmedDate?.isEmpty == false ? trimmedDate : nil
        return AppDeepLink.url(for: AppRoute(destination: .today, apodDate: normalizedDate))
    }

    private static func fallbackState(for storedEntryResult: APODStoredEntryResult) -> (title: String, message: String) {
        let displayedDate = displayDate(from: storedEntryResult.entry.nasa.date ?? "")

        switch storedEntryResult.freshness {
        case .current:
            return (
                title: WidgetLocalization.text("widget.state.local_snapshot.title", default: "On-device snapshot"),
                message: WidgetLocalization.text(
                    "widget.state.local_snapshot.message",
                    default: "Showing the latest locally available APOD while a live refresh is unavailable."
                )
            )
        case .stale:
            return (
                title: WidgetLocalization.text("widget.state.offline_snapshot.title", default: "Offline snapshot"),
                message: String(
                    format: WidgetLocalization.text(
                        "widget.state.offline_snapshot.message",
                        default: "Showing the latest on-device APOD from %@ until the widget can refresh again."
                    ),
                    displayedDate.isEmpty ? WidgetLocalization.text("widget.media.apod", default: "APOD") : displayedDate
                )
            )
        case .undated:
            return (
                title: WidgetLocalization.text("widget.state.offline_snapshot.title", default: "Offline snapshot"),
                message: WidgetLocalization.text(
                    "widget.state.offline_undated.message",
                    default: "Showing the latest on-device APOD snapshot until the widget can refresh again."
                )
            )
        }
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
            deepLinkURL: AppDeepLink.url(for: AppRoute(destination: .today)),
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
