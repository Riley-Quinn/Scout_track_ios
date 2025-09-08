import SwiftUI

struct TicketResponse: Codable {
    let list: [Tickets]
}

struct Tickets: Identifiable, Codable {
    let id: Int
    let ticket_service_id: String
    let category_name: String
    let address: String
    let state_name: String
    let city_name: String
    let region_name: String
    let customer_name: String
    let customer_phone: String
    let employee_arrival_date: String?
    let title: String?
    let urgency: Int?

    var fullAddress: String {
        "\(address), \(state_name), \(city_name), \(region_name)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "ticket_id"
        case ticket_service_id, category_name, address, state_name, city_name, region_name, customer_name, customer_phone, employee_arrival_date, title, urgency
    }
}

struct EventView: View {
    @State private var selectedStatus = "Scheduled"
    let statusOptions = ["Scheduled", "Unscheduled"]

    @State private var tickets: [Tickets] = []
    @State private var loading = false
    @State private var errorMessage: String? = nil
    @State private var userId: String = "0" // store actual ID here

    var filteredTickets: [Tickets] {
        tickets.filter { ticket in
            if selectedStatus == "Scheduled" {
                return ticket.employee_arrival_date != nil && !(ticket.employee_arrival_date?.isEmpty ?? true)
            } else {
                return ticket.employee_arrival_date == nil || (ticket.employee_arrival_date?.isEmpty ?? true)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $selectedStatus) {
                ForEach(statusOptions, id: \.self) { status in
                    Text(status)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(8)
            .padding(.horizontal)
            .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)

            if loading {
                ProgressView("Loading...")
                    .padding()
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red).padding()
            } else if filteredTickets.isEmpty {
                Text("No tickets found")
                    .padding()
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredTickets) { ticket in
                            ticketCard(ticket)
                        }
                    }
                    .padding()
                }
            }

            Spacer()

            Divider()
            HStack {
                NavigationLink(destination: DashboardView()) {
                    FooterTab(icon: "house", label: "Home")
                }
                Spacer()
                NavigationLink(destination: CalendarView()) {
                    FooterTab(icon: "calendar", label: "Calendar")
                }
                Spacer()
                FooterTab(icon: "calendar.badge.plus", label: "Events", selected: true)
                Spacer()
                NavigationLink(destination: ProfileView()) {
                    FooterTab(icon: "person", label: "Profile")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadUserIdAndFetch()
        }
    }

    @ViewBuilder
    func ticketCard(_ ticket: Tickets) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "ticket")
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
                    .font(.title2)
                Text("#\(ticket.ticket_service_id)")
                    .font(.headline)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
                Spacer()
            }
            HStack(alignment: .top) {
                Text("Category:").bold()
                Text(ticket.category_name)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
            }
            HStack(alignment: .top) {
                Text("Address:").bold()
                Text(ticket.fullAddress)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
            }
            HStack {
                Text("Customer:").bold()
                Text(ticket.customer_name)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
            }
            HStack {
                Text("Phone:").bold()
                Link(ticket.customer_phone, destination: URL(string: "tel:\(ticket.customer_phone)")!)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    func loadUserIdAndFetch() {
        // Fetch the userId dynamically from UserDefaults (or any secure storage)
        let storedId = UserDefaults.standard.string(forKey: "userId") ?? "0"
        userId = storedId

        fetchTickets()
    }

    func fetchTickets() {
        loading = true
        errorMessage = nil

        guard let url = URL(string: "http://localhost:4200/api/tickets/employee/\(userId)?status_id=2") else {
            errorMessage = "Invalid URL"
            loading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                loading = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {}

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                if let rawString = String(data: data, encoding: .utf8) {}

                do {
                    let decoded = try JSONDecoder().decode(TicketResponse.self, from: data)
                    tickets = decoded.list
                } catch {
                    errorMessage = "Failed to parse tickets"
                }
            }
        }.resume()
    }
}

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventView()
        }
    }
}
