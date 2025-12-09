import Foundation
import UserNotifications

extension Notification.Name {
    static let startScheduledSession = Notification.Name("startScheduledSession")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let routineName = userInfo["routineName"] as? String {
            NotificationCenter.default.post(
                name: .startScheduledSession,
                object: nil,
                userInfo: ["routineName": routineName]
            )
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
