import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {

    @Published var fcmToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: - Notification Permission & Remote Registration

    func requestNotificationPermission(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                completion()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        // After APNs token is set, fetch FCM token
        fetchFCMTokenIfReady()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Fetch & Send FCM Token

    func fetchFCMTokenIfReady() {
        guard let _ = UserDefaults.standard.string(forKey: "userId"),
              let _ = UserDefaults.standard.string(forKey: "clientId") else {
            return
        }

        Messaging.messaging().token { token, error in
            if let error = error {
                print("⚠️ Error fetching FCM token: \(error.localizedDescription)")
                return
            }
            guard let token = token else {
                print("⚠️ FCM token is nil")
                return
            }
            self.fcmToken = token
            self.sendFCMTokenToBackend(token: token)
        }
    }

private func sendFCMTokenToBackend(token: String) {
    guard let employeeId = UserDefaults.standard.string(forKey: "userId") else {
        return
    }

    let body: [String: Any] = [
        "fcm_token": token,       // <-- corrected key
        "employee_id": employeeId
    ]

    let url = URL(string: "\(Config.baseURL)/api/fcm-tokens/store-token")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    print("🔄 Sending FCM token to backend with body: \(body)")

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ Failed to send FCM token: \(error.localizedDescription)")
            return
        }

        if let httpResp = response as? HTTPURLResponse {
            print("📤 Backend response code: \(httpResp.statusCode)")
            if httpResp.statusCode == 200 {
                print("✅ FCM token sent successfully")
            } else {
                if let data = data, let msg = String(data: data, encoding: .utf8) {
                    print("⚠️ Backend error: \(msg)")
                }
                print("❌ Failed to send token to backend")
            }
        }
    }.resume()
}



    // MARK: - Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        // Send token to backend if user already logged in
        fetchFCMTokenIfReady()
    }
}
