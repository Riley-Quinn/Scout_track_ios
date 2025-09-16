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
    let employee_arrival_time: String?
    let title: String?
    let urgency: Int?
    var fullAddress: String {
        "\(address), \(state_name), \(city_name), \(region_name)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "ticket_id"
        case ticket_service_id, category_name, address, state_name, city_name, region_name, customer_name, customer_phone, employee_arrival_date, employee_arrival_time, title, urgency
    }
}

struct BlinkText: View {
    let text: String
    @State private var isVisible = true

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.red)
            .opacity(isVisible ? 1 : 0) // Blink by changing opacity
            .font(.system(size: 10))
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                ) {
                    isVisible.toggle()
                }
            }
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

    // Helper function to format date from ISO format to "Sep 16, 2025"
    func formatDateOnly(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "Not Available"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        if let date = dateFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }

        // Fallback: try parsing just the date part
        let components = dateString.split(separator: "T")
        if let datePart = components.first {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: String(datePart)) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "MMM d, yyyy"
                return outputFormatter.string(from: date)
            }
        }

        return dateString
    }

    // Helper function to format time from ISO format to "07:30 PM"
    func formatTimeOnly(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "Not Available"
        }

        let dateFormatter = DateFormatter()

        // Try multiple date formats
        let possibleFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "HH:mm:ss",
            "HH:mm",
        ]

        for format in possibleFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                return timeFormatter.string(from: date)
            }
        }

        // If it's just a time string like "18:30", handle it directly
        if dateString.contains(":") && !dateString.contains("T") {
            let components = dateString.split(separator: ":")
            if components.count >= 2,
               let hour = Int(components[0]),
               let minute = Int(components[1])
            {
                let calendar = Calendar.current
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute

                if let date = calendar.date(from: dateComponents) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "h:mm a"
                    return timeFormatter.string(from: date)
                }
            }
        }

        // Debug: print the actual string to see what we're getting
        print("Unable to parse time from: '\(dateString)'")
        return "Not Available"
    }

    @ViewBuilder
    func ticketCard(_ ticket: Tickets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ticket")
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
                    .font(.title2)
                Text(ticket.title ?? "")
                    .font(.headline)
                    .foregroundColor(.black)
                    .font(.system(size: 14))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                ticketRow(label: "Category ", value: " : \(ticket.category_name)")
                ticketRow(label: "Address ", value: " : \(ticket.fullAddress)")
                ticketRow(label: "Customer ", value: " : \(ticket.customer_name)")
                ticketRow(label: "Phone ", value: " : \(ticket.customer_phone)", isLink: true)

                // Only show arrival date and time for scheduled tickets
                if selectedStatus == "Scheduled" {
                    ticketRow(label: "Arrival Date", value: " : \(formatDateOnly(ticket.employee_arrival_date))")
                    if let arrivalTime = ticket.employee_arrival_time {
                        ticketRow(label: "Arrival Time") {
                            BlinkText(text: formatTimeOnly(ticket.employee_arrival_time))
                        }

                    } else {
                        // If we have arrival_date, use it to extract time
                        ticketRow(label: "Arrival Time", value: " : \(formatTimeOnly(ticket.employee_arrival_date))")
                    }
                }
            }
        }

        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1) // subtle border
        )
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    func ticketRow<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .bold()
                .font(.system(size: 10))
                .frame(width: 80, alignment: .leading)

            value() // <-- this will render BlinkText, Link, Text, etc.

            Spacer()
        }
    }

    @ViewBuilder
    func ticketRow(label: String, value: String, isLink: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .bold()
                .font(.system(size: 12))
                .frame(width: 80, alignment: .leading) // fixed width for labels
            if isLink {
                Link(value, destination: URL(string: "tel:\(value)")!)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
                    .font(.system(size: 12))
            } else {
                Text(value)
                    .foregroundColor(Color(red: 0, green: 128 / 255, blue: 128 / 255))
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
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

                // Print the raw response to debug
                if let rawString = String(data: data, encoding: .utf8) {
                    print("API Response: \(rawString)")
                }

                do {
                    // First try to decode as TicketResponse (with "list" key)
                    let decoded = try JSONDecoder().decode(TicketResponse.self, from: data)
                    tickets = decoded.list
                } catch {
                    print("Failed to decode as TicketResponse: \(error)")

                    // If that fails, try to decode directly as array of Tickets
                    do {
                        let directTickets = try JSONDecoder().decode([Tickets].self, from: data)
                        tickets = directTickets
                    } catch {
                        print("Failed to decode as direct array: \(error)")
                        errorMessage = "Failed to parse tickets: \(error.localizedDescription)"
                    }
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
