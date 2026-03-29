import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct OpenTodayAPODIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today"
    static var description = IntentDescription("Open today's APOD briefing in Space Briefing.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .today))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenArchiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Archive"
    static var description = IntentDescription("Open the APOD archive browser in Space Briefing.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .archive))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenSavedIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Saved"
    static var description = IntentDescription("Open the saved APOD collection in Space Briefing.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(AppRoute(destination: .saved))
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenDateAPODIntent: AppIntent {
    static var title: LocalizedStringResource = "Open APOD by Date"
    static var description = IntentDescription("Open a specific APOD date in Space Briefing.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Date")
    var date: Date

    func perform() async throws -> some IntentResult {
        PendingAppRouteStore.save(SharedAPODContentProvider().route(for: .today, date: date))
        return .result()
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

        AppShortcut(
            intent: OpenDateAPODIntent(),
            phrases: [
                "Open an APOD date in \(.applicationName)",
                "Show an astronomy picture by date in \(.applicationName)"
            ],
            shortTitle: "By Date",
            systemImageName: "calendar"
        )
    }
}
#endif
