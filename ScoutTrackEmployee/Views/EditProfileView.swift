import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss // modern back dismiss for iOS 15+

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false // NEW

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                    .ignoresSafeArea(edges: .top)

                HStack {
                    Button(action: {
                        dismiss() // works for both push and sheet
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.title)
                            .padding(.leading, 8)
                    }
                    Spacer()
                    Text("Edit Profile")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, UIApplication.shared.connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
                    .first ?? 20) // push down from notch
                .padding(.horizontal)
            }
            .frame(height: 100) // taller bar

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Circle
                    Circle()
                        .fill(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(initials(for: name))
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.white)
                        )
                        .padding(.top, 30)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else {
                        // Input Fields
                        Group {
                            TextField("Full Name", text: $name)
                                .textFieldStyleCustom()
                                .foregroundColor(.black)

                            TextField("Phone Number", text: $phone)
                                .keyboardType(.phonePad)
                                .textFieldStyleCustom()
                                .foregroundColor(.black)

                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textFieldStyleCustom()
                                .foregroundColor(.black)
                        }

                        // Update Button
                        Button(action: updateProfile) {
                            Text("Update Profile")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                                .cornerRadius(25)
                        }
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.top)
        .onAppear(perform: fetchProfile)
        .alert(isPresented: $showSuccessAlert) { // NEW ALERT
            Alert(
                title: Text("Success"),
                message: Text("Profile updated successfully!"),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }

    private func initials(for name: String) -> String {
        guard !name.isEmpty else { return "E" }
        let parts = name.split(separator: " ")
        return parts.compactMap { $0.first }.prefix(2).map { String($0) }.joined().uppercased()
    }

    private func fetchProfile() {
        guard let userId = UserDefaults.standard.string(forKey: "userId"),
              let clientId = UserDefaults.standard.string(forKey: "clientId"),
              let url = URL(string: "\(Config.baseURL)/api/employee/\(userId)")
        else {
            errorMessage = "Missing userId or invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(clientId, forHTTPHeaderField: "x-client-id")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
                return
            }
            if let data = data {
                if let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
                    DispatchQueue.main.async {
                        self.name = decoded.name ?? ""
                        self.phone = decoded.phone ?? ""
                        self.email = decoded.email ?? ""
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse profile data"
                    }
                }
            }
        }.resume()
    }

    private func updateProfile() {
        guard !name.isEmpty else { errorMessage = "Name is required"; return }
        guard phone.range(of: #"^\d{10}$"#, options: .regularExpression) != nil else {
            errorMessage = "Phone number must be 10 digits"; return
        }
        guard email.contains("@") else { errorMessage = "Invalid email"; return }
        errorMessage = nil

        guard let userId = UserDefaults.standard.string(forKey: "userId"),
              let url = URL(string: "\(Config.baseURL)/api/employee/\(userId)")
        else {
            errorMessage = "Missing userId or invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "name": name,
            "phone": phone,
            "email": email,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Update failed: \(error.localizedDescription)"
                }
                return
            }
            DispatchQueue.main.async {
                self.showSuccessAlert = true // SHOW SUCCESS ALERT
            }
        }.resume()
    }
}

extension View {
    func textFieldStyleCustom() -> some View {
        padding()
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
    }
}
