import SwiftUI
import CoreData
import UIKit

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var email = "testemp@gmail.com"
    @State private var password = "Password123!"
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showPermissionDialog = false

    @AppStorage("sessionActive") private var sessionActive: Bool = false

    private let context = PersistenceController.shared.container.viewContext

    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer(minLength: geo.size.height * 0.1) // Top spacing

                        // Logo
                        Image("logo")
                            .resizable()
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())

                        Text("Welcome!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 10)

                        // Input fields
                        VStack(spacing: 16) {
                            CustomTextField(icon: "envelope", placeholder: "Email", text: $email)
                            CustomTextField(icon: "lock", placeholder: "Password", text: $password, isSecure: true)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Button / Loader
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FF6B00")))
                                .padding()
                        } else {
                            Button(action: handleLogin) {
                                Text("Login")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "#FF6B00"))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            .padding(.top)
                            .padding(.horizontal)
                        }
                        Spacer(minLength: geo.size.height * 0.1) // Bottom spacing
                    }
                    .frame(minHeight: geo.size.height)
                }
            }

            if showPermissionDialog {
                PermissionDialogView(
                    isPresented: $showPermissionDialog,
                    onAllow: { handlePermissionAllow() },
                    onDeny: { handlePermissionDeny() }
                )
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.contains("successful") {
                        sessionActive = true
                    }
                }
            )
        }
    }

    // MARK: - Login Logic (Online + Offline)
    private func handleLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please enter email and password"
            showAlert = true
            return
        }

        isLoading = true
        let url = URL(string: "\(Config.baseURL)/api/auth/admin/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": email, "password": password, "rememberMe": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                print("⚠️ Login error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Try offline login if no internet
                    self.handleOfflineLogin()
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let empData = json["empData"] as? [String: Any] else {
                DispatchQueue.main.async {
                    self.alertMessage = "Invalid email or password"
                    self.showAlert = true
                }
                return
            }

DispatchQueue.main.async {
    saveUserData(empData)
    appDelegate.requestNotificationPermission {
        // Wait a bit for APNs registration to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            appDelegate.fetchFCMTokenIfReady()
            navigateToDashboard()
        }
    }
}

        }.resume()
    }

    // MARK: - Offline Login
    private func handleOfflineLogin() {
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ AND password == %@", email, password)

        do {
            let results = try context.fetch(fetchRequest)
            if let _ = results.first {
                print("✅ Offline login success")
                navigateToDashboard()
            } else {
                self.alertMessage = "Offline login failed. Please connect to the internet."
                self.showAlert = true
            }
        } catch {
            self.alertMessage = "Error checking offline login"
            self.showAlert = true
        }
    }

    // MARK: - Save User to CoreData + Defaults
    private func saveUserData(_ empData: [String: Any]) {
        UserDefaults.standard.set(empData["userId"], forKey: "userId")
        UserDefaults.standard.set(empData["name"], forKey: "name")
        UserDefaults.standard.set(empData["Role"], forKey: "Role")
        UserDefaults.standard.set(empData["client_id"], forKey: "clientId")

        let newUser = User(context: context)
        newUser.userId = empData["userId"] as? String ?? ""
        newUser.name = empData["name"] as? String ?? ""
        newUser.role = empData["Role"] as? String ?? ""
        newUser.clientId = empData["client_id"] as? String ?? ""
        newUser.email = email
        newUser.password = password

        do {
            try context.save()
            print("💾 User saved to CoreData")
        } catch {
            print("❌ Failed to save user: \(error)")
        }
    }

    // MARK: - Permission Dialog Handling
    private func handlePermissionAllow() {
        showPermissionDialog = false
        appDelegate.requestNotificationPermission {
            appDelegate.fetchFCMTokenIfReady()
            navigateToDashboard()
        }
    }

    private func handlePermissionDeny() {
        showPermissionDialog = false
        navigateToDashboard()
    }

    private func navigateToDashboard() {
        sessionActive = true
        print("🚀 Navigated to dashboard")
    }
}

// MARK: - Custom TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.black)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.black)
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Permission Dialog View
struct PermissionDialogView: View {
    @Binding var isPresented: Bool
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#FF6B00"))
                Text("Enable Notifications")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text("Stay updated with important alerts and messages. You can change this anytime in Settings.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Button("Allow", action: onAllow)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FF6B00"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    Button("Don't Allow", action: onDeny)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 320)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }

        let uiColor = UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )

        self = Color(uiColor)
    }
}
