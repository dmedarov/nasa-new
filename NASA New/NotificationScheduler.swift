import Foundation
import UserNotifications

struct NotificationSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center: UNUserNotificationCenter
    private let requestIdentifier = "daily_apod_notification"

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

        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.text("New NASA APOD", default: "New NASA APOD")
        content.body = L10n.text("A new Astronomy Picture of the Day is available.", default: "A new Astronomy Picture of the Day is available.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: settings.dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
