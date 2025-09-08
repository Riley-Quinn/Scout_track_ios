import SwiftUI

struct Profile: Codable {
    var name: String?
    var email: String?
    var phone: String?
}

struct ProfileView: View {
    @State private var profile = Profile()
    @State private var userId: String? = nil
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 30) {
                        // Profile Circle with Dynamic Data
                        VStack {
                            Circle()
                                .fill(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    VStack {
                                        Text(profile.name ?? "Employee")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Text(profile.phone ?? "9876543210")
                                            .font(.body)
                                            .foregroundColor(.white)
                                    }
                                )
                                .padding(.top, 30)
                        }

                        // Menu Items
                        VStack(spacing: 0) {
                            NavigationLink(destination: EditProfileView()
                                .navigationBarBackButtonHidden(true)
                                .navigationBarHidden(true))
                            {
                                menuItem(icon: "person.fill", title: "Edit Profile")
                            }
                            Divider()
                            NavigationLink(destination: ChangePasswordView()
                                .navigationBarBackButtonHidden(true)
                                .navigationBarHidden(true))
                            {
                                menuItem(icon: "lock.fill", title: "Change Password")
                            }
                            Divider()
                            Button(action: handleLogout) {
                                menuItem(icon: "rectangle.portrait.and.arrow.right", title: "Logout")
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                }

                Spacer()
                Divider()

                // Bottom Tabs
                HStack {
                    NavigationLink(destination: DashboardView()
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true))
                    {
                        FooterTab(icon: "house", label: "Home")
                    }
                    Spacer()
                    NavigationLink(destination: CalendarView()
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true))
                    {
                        FooterTab(icon: "calendar", label: "Calendar")
                    }
                    Spacer()
                    NavigationLink(destination: EventView()
                        .navigationBarBackButtonHidden(true)
                        .navigationBarHidden(true))
                    {
                        FooterTab(icon: "calendar.badge.plus", label: "Events")
                    }
                    Spacer()
                    FooterTab(icon: "person", label: "Profile", selected: true)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            loadUserIdAndProfile()
        }
    }

    func menuItem(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                .frame(width: 30)
            Text(title)
                .foregroundColor(.black)
                .font(.body)
            Spacer()
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Load userId from storage and fetch profile

    func loadUserIdAndProfile() {
        if let savedId = UserDefaults.standard.string(forKey: "userId") {
            userId = savedId
            fetchProfile(userId: savedId)
        } else {
            isLoading = false
        }
    }

    func fetchProfile(userId: String) {
        guard let url = URL(string: "http://localhost:4200/api/employee/\(userId)") else {
            isLoading = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let data = data {
                if let decoded = try? JSONDecoder().decode(Profile.self, from: data) {
                    DispatchQueue.main.async {
                        self.profile = decoded
                    }
                }
            }
        }.resume()
    }

    // MARK: - Logout Action

    func handleLogout() {
        UserDefaults.standard.removeObject(forKey: "userId")
        // Navigate back to login screen logic here (depends on your app flow)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
        }
    }
}
