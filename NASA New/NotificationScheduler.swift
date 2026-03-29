import Foundation
import UserNotifications

struct NotificationSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    init(isEnabled: Bool, hour: Int, minute: Int) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
    }

    func normalized() -> NotificationSettings {
        NotificationSettingsPolicy.normalized(
            isEnabled: isEnabled,
            hour: hour,
            minute: minute
        )
    }

    var dateComponents: DateComponents {
        NotificationSettingsPolicy.dateComponents(
            isEnabled: isEnabled,
            hour: hour,
            minute: minute
        )
    }
}

enum NotificationSettingsPolicy {
    static func normalized(isEnabled: Bool, hour: Int, minute: Int) -> NotificationSettings {
        NotificationSettings(
            isEnabled: isEnabled,
            hour: max(0, min(23, hour)),
            minute: max(0, min(59, minute))
        )
    }

    static func dateComponents(isEnabled: Bool, hour: Int, minute: Int) -> DateComponents {
        let normalizedSettings = normalized(isEnabled: isEnabled, hour: hour, minute: minute)
        return DateComponents(hour: normalizedSettings.hour, minute: normalizedSettings.minute)
    }
}

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center: UNUserNotificationCenter
    private let requestIdentifier = "daily_apod_notification"

    private var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] == "1"
    }

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        if status == .authorized || status == .provisional || status == .ephemeral {
            return true
        }
        guard status == .notDetermined else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func cancelDailyNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        if isRunningUITests {
            center.removeAllDeliveredNotifications()
        }
    }

    func nextPendingNotificationDate() async -> Date? {
        let requests = await center.pendingNotificationRequests()
        guard
            let request = requests.first(where: { $0.identifier == requestIdentifier }),
            let trigger = request.trigger as? UNCalendarNotificationTrigger,
            let nextDate = trigger.nextTriggerDate()
        else {
            return nil
        }
        return nextDate
    }

    func scheduleDailyAPODNotification(settings: NotificationSettings) async {
        cancelDailyNotification()
        guard settings.isEnabled else { return }
        guard !isRunningUITests else { return }

        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.text("notification.new_apod_title", default: "Daily APOD briefing ready")
        content.body = L10n.text(
            "notification.new_apod_body",
            default: "Open Space Briefing to review today's Astronomy Picture of the Day and source details."
        )
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: settings.dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
