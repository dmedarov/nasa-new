import Foundation

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

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    static func displayString(for apiDateString: String?) -> String {
        guard let apiDateString else { return "Unknown date" }

        let trimmedDate = apiDateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty else { return "Unknown date" }
        guard let parsedDate = apiDateFormatter.date(from: trimmedDate) else { return trimmedDate }
        return displayFormatter.string(from: parsedDate)
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

struct APODSourceLinkPolicy {
    static func nasaPageURL(for dateString: String?, fallbackURL: URL?) -> URL? {
        guard
            let dateString,
            dateString.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        else {
            return fallbackURL
        }

        let formattedDate = dateString.replacingOccurrences(of: "-", with: "").dropFirst(2)
        return URL(string: "https://apod.nasa.gov/apod/ap\(formattedDate).html")
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
                return "Open HD Image"
            }
            return "Open Image"
        case .video:
            return "Open Video"
        case .other:
            return "Open Source"
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
