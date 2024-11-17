import SwiftUI
import UserNotifications



class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let medicationName = response.notification.request.content.userInfo["medicationName"] as? String {
            NotificationCenter.default.post(name: Notification.Name("MedicationNotification"), object: nil, userInfo: ["medicationName": medicationName])
        }
        completionHandler()
    }
}
