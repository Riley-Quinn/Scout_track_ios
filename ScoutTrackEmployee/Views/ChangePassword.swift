import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var showCurrent = false
    @State private var showNew = false
    @State private var showConfirm = false

    @State private var errorCurrent = ""
    @State private var errorNew = ""
    @State private var errorConfirm = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                    .ignoresSafeArea(edges: .top)

                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.leading, 8)
                    }
                    Spacer()
                    Text("Change Password")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
                    .first ?? 20)
                .padding(.horizontal)
            }
            .frame(height: 100) // Increased height

            ScrollView {
                VStack(spacing: 20) {
                    // Profile Circle
                    Circle()
                        .fill(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .padding(.top, 30)

                    // Current Password
                    passwordField(
                        title: "Current Password",
                        text: $currentPassword,
                        isSecure: !showCurrent,
                        showToggle: $showCurrent,
                        errorText: errorCurrent
                    )

                    // New Password
                    passwordField(
                        title: "New Password",
                        text: $newPassword,
                        isSecure: !showNew,
                        showToggle: $showNew,
                        errorText: errorNew
                    )

                    // Confirm Password
                    passwordField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: !showConfirm,
                        showToggle: $showConfirm,
                        errorText: errorConfirm
                    )

                    // Update Button
                    Button(action: {
                        validateAndSubmit()
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Update Password")
                            }
                            .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.top, 20)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .edgesIgnoringSafeArea(.top)
    }

    // MARK: - Validation & API

    private func validateAndSubmit() {
        errorCurrent = ""
        errorNew = ""
        errorConfirm = ""

        if currentPassword.isEmpty {
            errorCurrent = "Current password is required"
        }
        if newPassword.isEmpty {
            errorNew = "New password is required"
        } else if !isValidPassword(newPassword) {
            errorNew = "Must have 8+ chars, uppercase, lowercase, number & symbol"
        }
        if confirmPassword != newPassword {
            errorConfirm = "Passwords must match"
        }

        guard errorCurrent.isEmpty && errorNew.isEmpty && errorConfirm.isEmpty else { return }

        // Simulate API call
        isLoading = true
        // Retrieve userId dynamically (for demo, using a mock)
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "123"

        // Make an async API request (replace URL with your backend)
        let url = URL(string: "\(Config.baseURL)/api/employee/password/\(userId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "password": currentPassword,
            "newPassword": newPassword,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if error != nil {
                    return
                }
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    dismiss()
                } else {
                    errorCurrent = "Failed to update password. Try again."
                }
            }
        }.resume()
    }

    private func isValidPassword(_ password: String) -> Bool {
        let regex = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{8,}$")
        return regex.evaluate(with: password)
    }

    // MARK: - Custom Field

    private func passwordField(
        title: String,
        text: Binding<String>,
        isSecure: Bool,
        showToggle: Binding<Bool>,
        errorText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1)
                HStack {
                    if isSecure {
                        SecureField(title, text: text)
                            .padding(.leading, 10)
                            .padding(.vertical, 12)
                    } else {
                        TextField(title, text: text)
                            .padding(.leading, 10)
                            .padding(.vertical, 12)
                    }

                    Button(action: { showToggle.wrappedValue.toggle() }) {
                        Image(systemName: showToggle.wrappedValue ? "eye" : "eye.slash")
                            .foregroundColor(.gray)
                            .padding(.trailing, 10)
                    }
                }
            }
            if !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasswordView()
    }
}
