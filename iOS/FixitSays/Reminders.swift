import Foundation
import UserNotifications

/// Optional daily reminder. Notifications are requested ONLY when the user turns the reminder on,
/// so the core app needs zero permissions.
enum Reminders {
    static let identifier = "fixitsays.daily.reminder"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time to hold"
        content.body = "One hold today. Keep your streak going."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
