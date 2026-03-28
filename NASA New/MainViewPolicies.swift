import Foundation
import SwiftUI

enum AppTheme {
    enum Palette {
        static let spaceTop = Color(red: 0.04, green: 0.05, blue: 0.12)
        static let spaceBottom = Color(red: 0.09, green: 0.12, blue: 0.24)
        static let skyTop = Color(red: 0.93, green: 0.97, blue: 1.0)
        static let skyBottom = Color(red: 0.86, green: 0.92, blue: 0.99)
        static let accentDark = Color.white
        static let accentLight = Color.indigo
        static let orbDarkPrimary = Color.cyan.opacity(0.16)
        static let orbLightPrimary = Color.blue.opacity(0.16)
        static let orbDarkSecondary = Color.indigo.opacity(0.14)
        static let orbLightSecondary = Color.teal.opacity(0.14)
        static let glassDarkFallback = Color(red: 0.12, green: 0.14, blue: 0.2).opacity(0.96)
        static let glassLightFallback = Color.white.opacity(0.94)
        static let warning = Color.orange
        static let favorite = Color.red
        static let subtleFill = Color.secondary.opacity(0.08)
        static let splashText = Color.white.opacity(0.82)
    }

    enum Typography {
        static let splashTitle = Font.system(size: 26, weight: .bold, design: .serif)
        static let splashCaption = Font.system(size: 16, weight: .semibold, design: .serif)
        static let screenTitle = Font.system(.title2, design: .serif).weight(.bold)
        static let sectionTitle = Font.system(.headline, design: .rounded)
        static let actionLabel = Font.system(.subheadline, design: .rounded).weight(.semibold)
        static let metadata = Font.system(.caption, design: .rounded).weight(.semibold)
        static let footnote = Font.system(.footnote, design: .rounded)
        static let footnoteStrong = Font.system(.footnote, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let cardTitle = Font.system(.title3, design: .serif).weight(.semibold)
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 18
        static let compactCornerRadius: CGFloat = 12
    }

    static func backgroundGradient(isDarkMode: Bool) -> LinearGradient {
        LinearGradient(
            colors: isDarkMode ? [Palette.spaceTop, Palette.spaceBottom] : [Palette.skyTop, Palette.skyBottom],
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

    static func glassSurface(reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Palette.glassLightFallback)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    static func adaptiveSurface(isDarkMode: Bool, reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(isDarkMode ? Palette.glassDarkFallback : Palette.glassLightFallback)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}

struct DataSaverPreferencePolicy {
    static func resolvedPreferHDImages(dataSaverMode: Bool, preferHDImages: Bool) -> Bool {
        dataSaverMode ? false : preferHDImages
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
    static func creditLine(for nasa: NASA) -> String {
        if let copyright = nasa.copyright?.trimmingCharacters(in: .whitespacesAndNewlines),
           !copyright.isEmpty {
            return copyright
        }
        return L10n.text("credit.nasa", default: "NASA")
    }

    static func rightsNotice(for nasa: NASA) -> String? {
        if let copyright = nasa.copyright?.trimmingCharacters(in: .whitespacesAndNewlines),
           !copyright.isEmpty {
            return L10n.text(
                "rights.named_copyright",
                default: "This APOD includes a named copyright holder. Open the NASA page to review the original credit line and permissions context before reuse."
            )
        }

        guard nasa.url != nil || nasa.hdurl != nil else { return nil }
        return L10n.text(
            "rights.general_notice",
            default: "NASA imagery is often public domain, but APOD can also feature third-party content. Verify the original credit line on the NASA page before reuse."
        )
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
