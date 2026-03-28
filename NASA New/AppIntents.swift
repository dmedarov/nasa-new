import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct OpenTodayAPODIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today"
    static var description = IntentDescription("Open the current APOD briefing.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .today))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenArchiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Archive"
    static var description = IntentDescription("Open the APOD archive browser.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .archive))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenSavedIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Saved"
    static var description = IntentDescription("Open the saved APOD collection.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .saved))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenDateAPODIntent: AppIntent {
    static var title: LocalizedStringResource = "Open APOD by Date"
    static var description = IntentDescription("Open a specific APOD date in the app.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Date")
    var date: Date

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(targetRoute)
        return .result()
    }

    private var targetRoute: AppRoute {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return AppRoute(destination: .today, apodDate: formatter.string(from: date))
    }
}

@available(iOS 16.0, *)
struct NASAAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .navy }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTodayAPODIntent(),
            phrases: [
                "Open today's APOD in \(.applicationName)",
                "Show today's astronomy picture in \(.applicationName)"
            ],
            shortTitle: "Today",
            systemImageName: "sparkles.tv"
        )

        AppShortcut(
            intent: OpenArchiveIntent(),
            phrases: [
                "Open the archive in \(.applicationName)",
                "Browse the APOD archive in \(.applicationName)"
            ],
            shortTitle: "Archive",
            systemImageName: "books.vertical"
        )

        AppShortcut(
            intent: OpenSavedIntent(),
            phrases: [
                "Open saved APODs in \(.applicationName)",
                "Show my saved astronomy pictures in \(.applicationName)"
            ],
            shortTitle: "Saved",
            systemImageName: "bookmark"
        )
    }
}
#endif
