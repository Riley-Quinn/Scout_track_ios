import CoreData
import SwiftUI
import UIKit

// MARK: - Login View

struct LoginView: View {
    @State private var email = "testemp@gmail.com"
    @State private var password = "Password123!"
    @State private var rememberMe = false
    @State private var navigateToDashboard = false
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    @AppStorage("sessionActive") private var sessionActive: Bool = false

    private let BASE_URL = "http://localhost:4200"

    // Core Data context
    private let context = PersistenceController.shared.container.viewContext

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .zIndex(0)

                ScrollView {
                    VStack {
                        Spacer().frame(height: 60)

                        // Logo
                        Image("logo")
                            .resizable()
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())

                        Text("Welcome Back!")
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

                        // Button or loader
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
                            .padding(.horizontal)
                            .padding(.top)
                        }

                        // Navigation
                        NavigationLink(destination: DashboardView(), isActive: $navigateToDashboard) {
                            EmptyView()
                        }
                        .hidden()

                        // Remember Me + Forgot Password
                        HStack {
                            Toggle(isOn: $rememberMe) {
                                Text("Remember Me")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(CheckboxToggleStyle())

                            Spacer()

                            Button("Forgot Password?") {}
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .underline()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        Spacer()
                    }
                    .padding(.bottom, 60)
                }
                .zIndex(1)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Message"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertMessage.contains("successful") {
                            navigateToDashboard = true
                        }
                    }
                )
            }
        }
    }

    // MARK: - Login API Call with Core Data Fallback

    private func handleLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please enter email and password"
            showAlert = true
            return
        }

        isLoading = true

        let url = URL(string: "\(BASE_URL)/api/auth/admin/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "rememberMe": rememberMe,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                checkOfflineLogin()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                checkOfflineLogin()
                return
            }

            if httpResponse.statusCode == 200, let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let empData = json["empData"] as? [String: Any]
                {
                    // Save to UserDefaults
                    UserDefaults.standard.set(empData["userId"], forKey: "userId")
                    UserDefaults.standard.set(empData["name"], forKey: "name")
                    UserDefaults.standard.set(empData["Role"], forKey: "Role")
                    UserDefaults.standard.set(empData["client_id"], forKey: "clientId")

                    if rememberMe { sessionActive = true }

                    // Save to Core Data
                    let newUser = User(context: context)
                    newUser.userId = empData["userId"] as? String ?? ""
                    newUser.name = empData["name"] as? String ?? ""
                    newUser.role = empData["Role"] as? String ?? ""
                    newUser.clientId = empData["client_id"] as? String ?? ""
                    newUser.email = email
                    newUser.password = password

                    do {
                        try context.save()
                    } catch {}

                    DispatchQueue.main.async {
                        self.alertMessage = "Login successful"
                        self.showAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "Invalid email or password"
                    self.showAlert = true
                }
            }
        }.resume()
    }

    // MARK: - Offline Login Fallback

    private func checkOfflineLogin() {
        let request = User.fetchRequest()
        if let savedUser = try? context.fetch(request).first {
            if savedUser.email == email && savedUser.password == password {
                DispatchQueue.main.async {
                    self.alertMessage = "Offline login successful"
                    self.showAlert = true
                    self.navigateToDashboard = true
                }
                return
            }
        }
        DispatchQueue.main.async {
            self.alertMessage = "Login failed (offline mode)"
            self.showAlert = true
        }
    }
}

// MARK: - UI Components

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

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                    .foregroundColor(configuration.isOn ? Color(hex: "#FF6B00") : .gray)
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
