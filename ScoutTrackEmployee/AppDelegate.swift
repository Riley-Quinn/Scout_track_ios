import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
    {
        print("🚀 AppDelegate didFinishLaunchingWithOptions")

        FirebaseApp.configure()
        print("✅ Firebase configured")

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        return true
    }

    // ✅ Call this after login
    func setupFCM() {
        print("🔔 setupFCM called")
        requestNotificationPermission()
        DispatchQueue.main.async {
            print("📲 Registering for remote notifications")
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func requestNotificationPermission() {
        print("📢 Asking for notification permission...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Error requesting permission: \(error.localizedDescription)")
                return
            }
            print("🔑 Permission response received: \(granted ? "GRANTED ✅" : "DENIED ❌")")
        }
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📲 APNs device token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("⚠️ No FCM token received")
            return
        }
        print("✅ FCM Token received: \(token)")

        sendFCMTokenToBackend(token: token)
    }

    func sendFCMTokenToBackend(token: String) {
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            print("❌ No logged-in user found in UserDefaults")
            return
        }

        let clientId = UserDefaults.standard.string(forKey: "clientId") ?? "0"
        print("📤 Preparing to send FCM token. employee_id=\(userId), client_id=\(clientId)")

        guard let url = URL(string: "\(Config.baseURL)/fcm_tokens/store-token") else {
            print("❌ Invalid URL for backend")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "employee_id": Int(userId) ?? 0,
            "client_id": Int(clientId) ?? 0,
            "fcm_token": token,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("📤 Sending body: \(body)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error sending FCM token: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Backend responded with status: \(httpResponse.statusCode)")
            }

            if let data = data, let json = String(data: data, encoding: .utf8) {
                print("📩 Backend response body: \(json)")
            }
        }.resume()
    }
}
