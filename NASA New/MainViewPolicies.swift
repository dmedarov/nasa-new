import Foundation
import SwiftUI

enum APODArchiveStoragePolicy {
    static let storageKey = "cacheItemLimit"
    static let migrationKey = "archiveLimitMigration.v1"
    static let defaultArchiveLimit = 365
    static let legacyDefaultLimit = 90

    static func migrateLegacyLimitIfNeeded(userDefaults: UserDefaults = .standard) {
        guard !userDefaults.bool(forKey: migrationKey) else { return }

        let existingValue = userDefaults.object(forKey: storageKey) as? Int
        if existingValue == nil || existingValue == legacyDefaultLimit {
            userDefaults.set(defaultArchiveLimit, forKey: storageKey)
        }

        userDefaults.set(true, forKey: migrationKey)
    }
}

enum AppTheme {
    enum Palette {
        static let spaceTop = Color(red: 0.02, green: 0.03, blue: 0.1)
        static let spaceMid = Color(red: 0.05, green: 0.08, blue: 0.18)
        static let spaceBottom = Color(red: 0.08, green: 0.13, blue: 0.27)
        static let skyTop = Color(red: 0.96, green: 0.98, blue: 1.0)
        static let skyMid = Color(red: 0.89, green: 0.94, blue: 0.99)
        static let skyBottom = Color(red: 0.79, green: 0.87, blue: 0.97)
        static let accentDark = Color(red: 0.67, green: 0.86, blue: 1.0)
        static let accentLight = Color(red: 0.14, green: 0.32, blue: 0.66)
        static let accentHighlight = Color(red: 0.99, green: 0.78, blue: 0.34)
        static let orbDarkPrimary = Color(red: 0.23, green: 0.6, blue: 0.98).opacity(0.32)
        static let orbLightPrimary = Color(red: 0.33, green: 0.56, blue: 0.96).opacity(0.22)
        static let orbDarkSecondary = Color(red: 0.98, green: 0.61, blue: 0.2).opacity(0.18)
        static let orbLightSecondary = Color(red: 0.98, green: 0.78, blue: 0.35).opacity(0.16)
        static let glassDarkFallback = Color(red: 0.08, green: 0.1, blue: 0.16).opacity(0.94)
        static let glassLightFallback = Color.white.opacity(0.92)
        static let cardDarkFallback = Color(red: 0.07, green: 0.1, blue: 0.16).opacity(0.98)
        static let cardLightFallback = Color(red: 0.98, green: 0.99, blue: 1.0).opacity(0.95)
        static let overlayDark = Color.white.opacity(0.16)
        static let overlayLight = Color.white.opacity(0.62)
        static let strokeDark = Color.white.opacity(0.24)
        static let strokeLight = Color.black.opacity(0.14)
        static let inkDark = Color.white.opacity(0.95)
        static let inkLight = Color(red: 0.08, green: 0.11, blue: 0.2)
        static let secondaryInkDark = Color.white.opacity(0.82)
        static let secondaryInkLight = Color(red: 0.2, green: 0.24, blue: 0.34)
        static let warning = Color.orange
        static let favorite = Color(red: 0.95, green: 0.29, blue: 0.39)
        static let subtleFill = Color.secondary.opacity(0.08)
        static let splashText = Color.white.opacity(0.82)
    }

    enum Typography {
        static let splashTitle = Font.system(size: 30, weight: .bold, design: .serif)
        static let splashCaption = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let heroEyebrow = Font.system(.caption, design: .rounded).weight(.bold)
        static let heroTitle = Font.system(size: 32, weight: .bold, design: .serif)
        static let heroSubtitle = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let screenTitle = Font.system(.title, design: .serif).weight(.bold)
        static let cardTitle = Font.system(.title3, design: .serif).weight(.semibold)
        static let sectionEyebrow = Font.system(.caption2, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let actionLabel = Font.system(.subheadline, design: .rounded).weight(.semibold)
        static let buttonLabel = Font.system(.callout, design: .rounded).weight(.semibold)
        static let metadata = Font.system(.caption, design: .rounded).weight(.semibold)
        static let footnote = Font.system(.footnote, design: .rounded)
        static let footnoteStrong = Font.system(.footnote, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let monoDetail = Font.system(.caption, design: .monospaced).weight(.semibold)
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 24
        static let compactCornerRadius: CGFloat = 14
        static let heroCornerRadius: CGFloat = 30
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum SurfaceTone {
        case neutral
        case accent
        case warning
        case favorite
    }

    enum Motion {
        static func reveal(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.86)
        }

        static func emphasis(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)
        }

        static func standard(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeInOut(duration: 0.28)
        }
    }

    static func backgroundGradient(isDarkMode: Bool) -> LinearGradient {
        LinearGradient(
            colors: isDarkMode
                ? [Palette.spaceTop, Palette.spaceMid, Palette.spaceBottom]
                : [Palette.skyTop, Palette.skyMid, Palette.skyBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func primaryOrbColor(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.orbDarkPrimary : Palette.orbLightPrimary
    }

    static func secondaryOrbColor(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.orbDarkSecondary : Palette.orbLightSecondary
    }

    static func accentColor(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.accentDark : Palette.accentLight
    }

    static func inkPrimary(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.inkDark : Palette.inkLight
    }

    static func inkSecondary(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.secondaryInkDark : Palette.secondaryInkLight
    }

    static func glassSurface(reduceTransparency: Bool, isDarkMode: Bool = true) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(isDarkMode ? Palette.glassDarkFallback : Palette.glassLightFallback)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    static func adaptiveSurface(isDarkMode: Bool, reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(isDarkMode ? Palette.glassDarkFallback : Palette.glassLightFallback)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    static func panelOverlayGradient(isDarkMode: Bool, tone: SurfaceTone) -> LinearGradient {
        let accent: Color
        switch tone {
        case .neutral:
            accent = isDarkMode ? Palette.accentDark.opacity(0.12) : Palette.accentLight.opacity(0.08)
        case .accent:
            accent = accentColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.25 : 0.14)
        case .warning:
            accent = Palette.warning.opacity(isDarkMode ? 0.24 : 0.14)
        case .favorite:
            accent = Palette.favorite.opacity(isDarkMode ? 0.22 : 0.14)
        }

        return LinearGradient(
            colors: [
                accent,
                .clear,
                (isDarkMode ? Palette.overlayDark : Palette.overlayLight).opacity(0.35)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func panelFallbackColor(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.cardDarkFallback : Palette.cardLightFallback
    }

    static func panelStroke(isDarkMode: Bool) -> Color {
        isDarkMode ? Palette.strokeDark : Palette.strokeLight
    }

    static func toneColor(_ tone: SurfaceTone, isDarkMode: Bool) -> Color {
        switch tone {
        case .neutral:
            return accentColor(isDarkMode: isDarkMode)
        case .accent:
            return accentColor(isDarkMode: isDarkMode)
        case .warning:
            return Palette.warning
        case .favorite:
            return Palette.favorite
        }
    }

    static func panelShadow(isDarkMode: Bool, tone: SurfaceTone) -> Color {
        switch tone {
        case .neutral:
            return Color.black.opacity(isDarkMode ? 0.22 : 0.1)
        case .accent:
            return accentColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 0.22 : 0.14)
        case .warning:
            return Palette.warning.opacity(isDarkMode ? 0.22 : 0.14)
        case .favorite:
            return Palette.favorite.opacity(isDarkMode ? 0.2 : 0.14)
        }
    }
}

enum AppAppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var isDarkModeOverride: Bool? {
        switch self {
        case .system:
            return nil
        case .light:
            return false
        case .dark:
            return true
        }
    }

    var systemImageName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system:
            return L10n.text("appearance.system", default: "System")
        case .light:
            return L10n.text("appearance.light", default: "Light")
        case .dark:
            return L10n.text("appearance.dark", default: "Dark")
        }
    }
}

struct AppAppearancePolicy {
    static let storageKey = "appearancePreference"
    static let legacyStorageKey = "isDarkMode"

    static func resolvedPreference(from rawValue: String?) -> AppAppearancePreference {
        guard let rawValue else { return .system }
        return AppAppearancePreference(rawValue: rawValue) ?? .system
    }

    static func effectiveIsDarkMode(
        preference: AppAppearancePreference,
        systemColorScheme: ColorScheme
    ) -> Bool {
        preference.isDarkModeOverride ?? (systemColorScheme == .dark)
    }

    static func explicitPreference(matching systemColorScheme: ColorScheme) -> AppAppearancePreference {
        systemColorScheme == .dark ? .dark : .light
    }

    static func explicitPreference(forDarkMode isDarkMode: Bool) -> AppAppearancePreference {
        isDarkMode ? .dark : .light
    }

    static func nextPreference(after preference: AppAppearancePreference) -> AppAppearancePreference {
        switch preference {
        case .system:
            return .light
        case .light:
            return .dark
        case .dark:
            return .system
        }
    }

    static func migrateLegacyPreferenceIfNeeded(in userDefaults: UserDefaults = .standard) {
        guard userDefaults.string(forKey: storageKey) == nil else { return }
        guard userDefaults.object(forKey: legacyStorageKey) != nil else { return }

        let legacyIsDarkMode = userDefaults.bool(forKey: legacyStorageKey)
        userDefaults.set(
            legacyIsDarkMode ? AppAppearancePreference.dark.rawValue : AppAppearancePreference.light.rawValue,
            forKey: storageKey
        )
    }
}

struct DataSaverPreferencePolicy {
    static func resolvedPreferHDImages(dataSaverMode: Bool, preferHDImages: Bool) -> Bool {
        dataSaverMode ? false : preferHDImages
    }
}

struct AppBrandingPolicy {
    private static let officialAPODHomeURLString = "https://apod.nasa.gov/apod/astropix.html"

    static func independentNotice() -> String {
        L10n.text(
            "brand.independent_notice",
            default: "Independent app using NASA's public APOD service. Not affiliated with or endorsed by NASA."
        )
    }

    static func dataSourceNotice() -> String {
        L10n.text(
            "brand.data_source_notice",
            default: "APOD imagery, captions, and metadata come from NASA's Astronomy Picture of the Day service. Rights for non-NASA material stay with the credited creator."
        )
    }

    static func rightsGuidance() -> String {
        L10n.text(
            "brand.rights_notice",
            default: "Some APOD entries credit third-party creators. Review the original APOD page before reuse, and contact the named rights holder when one is listed."
        )
    }

    static func compliancePanelTitle() -> String {
        L10n.text("brand.panel_title", default: "Independent APOD companion")
    }

    static func compliancePanelEyebrow() -> String {
        L10n.text("brand.panel_eyebrow", default: "About, Source & Rights")
    }

    static func officialSourceLinkTitle() -> String {
        L10n.text("brand.source_link_title", default: "Open official APOD source")
    }

    static func officialSourceLinkSummary() -> String {
        L10n.text(
            "brand.source_link_summary",
            default: "Review the original APOD story, caption, and credit context in NASA's Astronomy Picture of the Day archive."
        )
    }

    static func entrySourceLinkSummary() -> String {
        L10n.text(
            "brand.entry_source_link_summary",
            default: "Open this APOD's original archive page to verify the full story, source credit, and reuse context."
        )
    }

    static func shareSourceNotice() -> String {
        L10n.text(
            "share.source_notice",
            default: "Shared from Space Briefing, an independent app using NASA's public APOD service."
        )
    }

    static func shareRightsNotice() -> String {
        L10n.text(
            "share.rights_notice",
            default: "Review the official APOD page for credit and reuse context before redistributing any media."
        )
    }

    static func officialAPODHomeURL() -> URL? {
        URL(string: officialAPODHomeURLString)
    }
}

struct APODSharePolicy {
    static func shareItems(
        for nasa: NASA,
        sourceURL: URL?,
        mediaItem: Any? = nil,
        explanationMaxLength: Int = 140
    ) -> [Any] {
        let items: [Any?] = [
            shareTitle(for: nasa),
            shareMessage(for: nasa, sourceURL: sourceURL, explanationMaxLength: explanationMaxLength),
            sourceURL,
            mediaItem
        ]
        return items.compactMap { $0 }
    }

    static func shareTitle(for nasa: NASA) -> String {
        nasa.title ?? L10n.text("Astronomy Picture", default: "Astronomy Picture")
    }

    static func shareMessage(
        for nasa: NASA,
        sourceURL: URL?,
        explanationMaxLength: Int = 140
    ) -> String {
        let explanationSnippet = summarizedExplanation(
            nasa.explanation,
            maxLength: explanationMaxLength
        )

        var sections = [String]()

        if let explanationSnippet {
            sections.append(explanationSnippet)
        }

        sections.append(AppBrandingPolicy.shareSourceNotice())
        sections.append(AppBrandingPolicy.shareRightsNotice())

        if let sourceURL {
            sections.append(
                L10n.format(
                    "share.source_url_line",
                    default: "Official APOD source: %@",
                    sourceURL.absoluteString
                )
            )
        }

        return sections.joined(separator: "\n\n")
    }

    private static func summarizedExplanation(_ text: String?, maxLength: Int) -> String? {
        guard let text else { return nil }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }

        let words = trimmedText.split(separator: " ")
        var result = ""

        for word in words {
            let candidate = result.isEmpty ? String(word) : "\(result) \(word)"
            if candidate.count <= maxLength {
                result = candidate
            } else {
                break
            }
        }

        guard !result.isEmpty else { return String(trimmedText.prefix(maxLength)) }
        return result.count < trimmedText.count ? "\(result)..." : result
    }
}

struct APODDateNavigationPolicy {
    static func shiftedDate(
        from selectedDate: Date,
        dayOffset: Int,
        calendar: Calendar,
        minimumDate: Date,
        maximumDate: Date
    ) -> Date {
        let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
        return min(max(candidateDate, minimumDate), maximumDate)
    }

    static func latestDate(maximumDate: Date) -> Date {
        maximumDate
    }
}

struct APODDateDisplayPolicy {
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    private static func displayFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMMM d yyyy")
        return formatter
    }

    static func displayString(for apiDateString: String?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let apiDateString else {
            return L10n.text("date.unknown", default: "Unknown date")
        }

        let trimmedDate = apiDateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty else {
            return L10n.text("date.unknown", default: "Unknown date")
        }
        guard let parsedDate = apiDateFormatter.date(from: trimmedDate) else { return trimmedDate }
        return displayFormatter(locale: locale).string(from: parsedDate)
    }
}

struct APODExplanationDisplayPolicy {
    static let collapsedLineLimit = 5
    private static let expandableCharacterThreshold = 220
    private static let expandableLineThreshold = 4

    static func shouldOfferExpansion(for text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        let lineCount = trimmedText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        return trimmedText.count > expandableCharacterThreshold || lineCount >= expandableLineThreshold
    }
}

struct APODMediaInteractionPolicy {
    static func allowsImagePanning(atScale scale: CGFloat) -> Bool {
        scale > 1.01
    }
}

struct APODSourceLinkPolicy {
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    static func nasaPageURL(for dateString: String?, fallbackURL: URL?) -> URL? {
        guard
            let dateString,
            let trimmedDate = trimmedAPODDateString(from: dateString)
        else {
            return fallbackURL
        }

        let formattedDate = trimmedDate.replacingOccurrences(of: "-", with: "").dropFirst(2)
        return URL(string: "https://apod.nasa.gov/apod/ap\(formattedDate).html")
    }

    static func hostLabel(for url: URL?) -> String? {
        guard var host = url?.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            return nil
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    static func archiveEntryTitle(for dateString: String?) -> String {
        guard let trimmedDate = dateString.flatMap(trimmedAPODDateString(from:)) else {
            return L10n.text("source.apod_archive_story", default: "APOD Archive Story")
        }

        return L10n.format(
            "source.archive_entry",
            default: "APOD Archive Entry %@",
            APODDateDisplayPolicy.displayString(for: trimmedDate)
        )
    }

    static func archiveEntrySummary() -> String {
        L10n.text(
            "source.archive_summary",
            default: "Review the original APOD explanation, caption, and credit line in the official archive entry."
        )
    }

    private static func trimmedAPODDateString(from rawValue: String) -> String? {
        let trimmedDate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty, apiDateFormatter.date(from: trimmedDate) != nil else {
            return nil
        }
        return trimmedDate
    }

    static func preferredMediaURL(for nasa: NASA, dataSaverMode: Bool, preferHDImages: Bool) -> URL? {
        switch nasa.mediaType {
        case .image:
            if dataSaverMode {
                return nasa.url ?? nasa.hdurl
            }
            if preferHDImages {
                return nasa.hdurl ?? nasa.url
            }
            return nasa.url ?? nasa.hdurl
        case .video, .other:
            return nasa.url ?? nasa.hdurl
        }
    }

    static func preferredMediaTitle(for nasa: NASA, dataSaverMode: Bool, preferHDImages: Bool) -> String {
        switch nasa.mediaType {
        case .image:
            let preferredURL = preferredMediaURL(for: nasa, dataSaverMode: dataSaverMode, preferHDImages: preferHDImages)
            if preferredURL == nasa.hdurl, nasa.hdurl != nil {
                return L10n.text("media.open_hd_image", default: "Open HD Image")
            }
            return L10n.text("media.open_image", default: "Open Image")
        case .video:
            return L10n.text("media.open_video", default: "Open Video")
        case .other:
            return L10n.text("media.open_source", default: "Open Source")
        }
    }

    static func preferredMediaDescription(for nasa: NASA, dataSaverMode: Bool, preferHDImages: Bool) -> String {
        switch nasa.mediaType {
        case .image:
            let preferredURL = preferredMediaURL(for: nasa, dataSaverMode: dataSaverMode, preferHDImages: preferHDImages)
            if preferredURL == nasa.hdurl, nasa.hdurl != nil {
                return L10n.text(
                    "source.hd_media_summary",
                    default: "Direct high-resolution image file referenced by the APOD entry."
                )
            }
            if dataSaverMode {
                return L10n.text(
                    "source.standard_media_summary",
                    default: "Standard-resolution image file chosen to keep media use lighter."
                )
            }
            return L10n.text(
                "source.image_media_summary",
                default: "Direct image file referenced by the APOD archive story."
            )
        case .video:
            return L10n.text(
                "source.video_media_summary",
                default: "Original video source referenced by the APOD story. Playback rights can depend on the host."
            )
        case .other:
            return L10n.text(
                "source.generic_media_summary",
                default: "Original media source referenced by the APOD story."
            )
        }
    }

    static func mediaIntegritySummary(for nasa: NASA, dataSaverMode: Bool, preferHDImages: Bool) -> String {
        switch nasa.mediaType {
        case .image:
            return L10n.text(
                "media.integrity_image",
                default: "Use the APOD story for the original caption and credit line, then open the direct image only when you need the asset itself."
            )
        case .video:
            return L10n.text(
                "media.integrity_video",
                default: "Video entries often point to external hosts. Use the APOD story for editorial context and the source host for playback-specific rights."
            )
        case .other:
            return preferredMediaDescription(for: nasa, dataSaverMode: dataSaverMode, preferHDImages: preferHDImages)
        }
    }

    static func mediaInteractionHint(for nasa: NASA) -> String? {
        switch nasa.mediaType {
        case .image:
            return L10n.text(
                "media.zoom_scroll_hint",
                default: "Double-tap or pinch to inspect details. Vertical scrolling stays available until you zoom in."
            )
        case .video:
            return L10n.text(
                "media.video_context_hint",
                default: "Open the APOD story if you need the full explanation, original caption, or source context."
            )
        case .other:
            return nil
        }
    }

    static func preferredMediaSystemImage(for nasa: NASA) -> String {
        switch nasa.mediaType {
        case .image:
            return "photo"
        case .video:
            return "play.rectangle"
        case .other:
            return "arrow.up.forward.square"
        }
    }
}

struct APODAttributionPolicy {
    enum RightsStatus: Equatable {
        case nasaContentLikely
        case copyrightProtected
        case reviewOriginalCredit
    }

    private static func trimmedRightsHolder(for nasa: NASA) -> String? {
        guard let copyright = nasa.copyright?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copyright.isEmpty else {
            return nil
        }
        return copyright
    }

    static func rightsHolder(for nasa: NASA) -> String? {
        trimmedRightsHolder(for: nasa)
    }

    static func rightsStatus(for nasa: NASA) -> RightsStatus {
        if let rightsHolder = trimmedRightsHolder(for: nasa) {
            if rightsHolder.compare("NASA", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                return .nasaContentLikely
            }
            return .copyrightProtected
        }

        if nasa.url != nil || nasa.hdurl != nil {
            return .nasaContentLikely
        }

        return .reviewOriginalCredit
    }

    static func creditLine(for nasa: NASA) -> String {
        if let rightsHolder = trimmedRightsHolder(for: nasa) {
            return rightsHolder
        }
        return L10n.text("credit.nasa", default: "NASA")
    }

    static func creditTitle(for nasa: NASA) -> String {
        switch rightsStatus(for: nasa) {
        case .copyrightProtected:
            return L10n.text("credit.rights_holder", default: "Rights Holder")
        case .nasaContentLikely, .reviewOriginalCredit:
            return L10n.text("Credit", default: "Credit")
        }
    }

    static func rightsBadgeTitle(for nasa: NASA) -> String {
        switch rightsStatus(for: nasa) {
        case .nasaContentLikely:
            return L10n.text("rights.status_nasa", default: "NASA source likely")
        case .copyrightProtected:
            return L10n.text("rights.status_review", default: "Rights holder named")
        case .reviewOriginalCredit:
            return L10n.text("rights.status_verify", default: "Verify original credit")
        }
    }

    static func rightsTitle(for nasa: NASA) -> String {
        switch rightsStatus(for: nasa) {
        case .nasaContentLikely:
            return L10n.text("rights.nasa_title", default: "NASA source context")
        case .copyrightProtected:
            return L10n.text("rights.copyright_title", default: "Third-party rights review")
        case .reviewOriginalCredit:
            return L10n.text("rights.verify_title", default: "Review the original credit line")
        }
    }

    static func rightsMessage(for nasa: NASA) -> String {
        switch rightsStatus(for: nasa) {
        case .nasaContentLikely:
            return L10n.text(
                "rights.general_notice",
                default: "NASA content is generally usable for educational or informational purposes, but APOD archive entries should still be checked for the original caption and reuse context."
            )
        case .copyrightProtected:
            return L10n.format(
                "rights.copyright_notice",
                default: "APOD identifies %@ as the rights holder. NASA and APOD do not grant reuse permission for copyrighted third-party material; contact the rights holder directly.",
                creditLine(for: nasa)
            )
        case .reviewOriginalCredit:
            return L10n.text(
                "rights.verify_notice",
                default: "Open the official APOD story to review the original caption, credit line, and any linked rights context before reuse."
            )
        }
    }

    static func rightsSystemImage(for nasa: NASA) -> String {
        switch rightsStatus(for: nasa) {
        case .nasaContentLikely:
            return "checkmark.shield"
        case .copyrightProtected:
            return "exclamationmark.shield.fill"
        case .reviewOriginalCredit:
            return "doc.text.magnifyingglass"
        }
    }

    static func rightsTone(for nasa: NASA) -> AppTheme.SurfaceTone {
        switch rightsStatus(for: nasa) {
        case .nasaContentLikely:
            return .accent
        case .copyrightProtected, .reviewOriginalCredit:
            return .warning
        }
    }

    static func rightsNotice(for nasa: NASA) -> String? {
        rightsMessage(for: nasa)
    }

    static func sourceLabel(for nasa: NASA) -> String {
        switch nasa.mediaType {
        case .image:
            return L10n.text("source.apod_image", default: "APOD Image")
        case .video:
            return L10n.text("source.apod_video", default: "APOD Video")
        case .other:
            return L10n.text("source.apod_media", default: "APOD Media")
        }
    }
}
