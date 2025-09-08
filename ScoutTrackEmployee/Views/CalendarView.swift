import SwiftUI

struct CalendarView: View {
    enum ViewMode: String, CaseIterable {
        case month = "Month"
        case week = "Week"
        case day = "Day"
        case agenda = "Agenda"
    }

    // MARK: - Response Wrapper

    struct TicketResponse: Decodable {
        let list: [CalendarTicket]
    }

    struct CalendarTicket: Identifiable, Decodable {
        let ticket_id: String
        let employee_arrival_date: String?
        let address: String?
        let city_name: String?

        var id: String { ticket_id }

        var date: Date {
            guard let employee_arrival_date else { return Date.distantFuture }

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let parsed = isoFormatter.date(from: employee_arrival_date) {
                return parsed
            }

            // fallback: support "yyyy-MM-dd HH:mm:ss"
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
            fallback.timeZone = .current
            if let parsed = fallback.date(from: employee_arrival_date) {
                return parsed
            }

            return Date.distantFuture
        }

        var localDay: Date {
            Calendar.current.startOfDay(for: date)
        }

        private enum CodingKeys: String, CodingKey {
            case ticket_id, employee_arrival_date, address, city_name
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let intValue = try? container.decode(Int.self, forKey: .ticket_id) {
                ticket_id = String(intValue)
            } else {
                ticket_id = try container.decode(String.self, forKey: .ticket_id)
            }

            employee_arrival_date = try? container.decodeIfPresent(String.self, forKey: .employee_arrival_date)
            address = try? container.decodeIfPresent(String.self, forKey: .address)
            city_name = try? container.decodeIfPresent(String.self, forKey: .city_name)
        }
    }

    @State private var currentDate = Date()
    @State private var viewMode: ViewMode = .month
    @State private var tickets: [CalendarTicket] = []
    private let calendar = Calendar.current

    // ✅ Debug formatter for printing dates in local timezone
    private let debugFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // 🔹 Header
            headerView

            // 🔹 Calendar Content
            VStack(spacing: 0) {
                viewModePicker
                Divider()
                switch viewMode {
                case .month: monthView
                case .week: weekView
                case .day: dayView
                case .agenda: agendaView
                }
            }
            .background(Color.white)

            Spacer()

            Divider()
            // 🔹 Footer
            HStack {
                NavigationLink(destination: DashboardView()) {
                    FooterTab(icon: "house", label: "Home")
                }
                Spacer()
                FooterTab(icon: "calendar", label: "Calendar", selected: true)
                Spacer()
                NavigationLink(destination: EventView()) {
                    FooterTab(icon: "calendar.badge.plus", label: "Events")
                }
                Spacer()
                NavigationLink(destination: ProfileView()) {
                    FooterTab(icon: "person", label: "Profile")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .onAppear { fetchTickets() }
    }

    // MARK: - Fetch Tickets

    private func fetchTickets() {
        guard let userId = UserDefaults.standard.string(forKey: "userId"),
              let url = URL(string: "http://localhost:4200/api/tickets/employee/\(userId)")
        else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                return
            }
            guard let data = data else {
                return
            }

            do {
                let decoded = try JSONDecoder().decode(TicketResponse.self, from: data)
                DispatchQueue.main.async {
                    self.tickets = decoded.list

                    // Today's normalized date
                    let today = Calendar.current.startOfDay(for: Date())

                    // ISO8601 parser
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    // Debug print each ticket's employee_arrival_date
                    for ticket in decoded.list {
                        if let arrivalStr = ticket.employee_arrival_date,
                           let arrivalDate = isoFormatter.date(from: arrivalStr)
                        {
                            let ticketDate = Calendar.current.startOfDay(for: arrivalDate)

                            if ticketDate == today {}
                        }
                    }
                }
            } catch {
                if let str = String(data: data, encoding: .utf8) {}
            }
        }.resume()
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Calendar")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                }
                Button(action: { currentDate = Date() }) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                }
            }
            Text(monthYearString(from: currentDate))
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.top, 10)
        .padding(.horizontal)
        .padding(.bottom, 10)
        .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 10) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: { viewMode = mode }) {
                    Text(mode.rawValue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(viewMode == mode ? Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255) : Color.gray.opacity(0.2))
                        .foregroundColor(viewMode == mode ? .white : .black)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Month View

    private var monthView: some View {
        let days = generateMonthDays(for: currentDate)
        return VStack(spacing: 4) {
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
            }
            ForEach(0 ..< days.count / 7, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0 ..< 7, id: \.self) { dayIndex in
                        let day = days[weekIndex * 7 + dayIndex]
                        // ✅ use localDay instead of raw date
                        DayCell(day: day, tickets: tickets.map { ($0.id, $0.localDay) })
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Week View

    private var weekView: some View {
        let weekDays = generateWeekDays(for: currentDate)
        return HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                // ✅ use localDay
                DayCell(day: day, tickets: tickets.map { ($0.id, $0.localDay) })
            }
        }
    }

    // MARK: - Day View

    private var dayView: some View {
        VStack {
            Text("Events for \(formattedDate(currentDate))")
                .font(.headline)
                .padding()
            if let ticket = tickets.first(where: { calendar.isDate($0.localDay, inSameDayAs: currentDate) }) {
                Text("Ticket #\(ticket.ticket_id)")
                    .padding()
                    .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            } else {
                Text("No events")
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Agenda View

    private var agendaView: some View {
        List {
            ForEach(tickets.sorted(by: { $0.date < $1.date })) { ticket in
                VStack(alignment: .leading) {
                    if ticket.date != Date.distantFuture {
                        Text(formattedDate(ticket.date))
                            .font(.subheadline)
                    } else {
                        Text("No Date")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text("Ticket #\(ticket.ticket_id)")
                        .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                        .font(.headline)
                    if let address = ticket.address, let city = ticket.city_name {
                        Text("\(address), \(city)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        if viewMode == .month {
            currentDate = calendar.date(byAdding: .month, value: value, to: currentDate) ?? currentDate
        } else if viewMode == .week {
            currentDate = calendar.date(byAdding: .weekOfYear, value: value, to: currentDate) ?? currentDate
        } else {
            currentDate = calendar.date(byAdding: .day, value: value, to: currentDate) ?? currentDate
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func generateMonthDays(for date: Date) -> [DayInfo] {
        var days: [DayInfo] = []
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else { return [] }
        var startDate = firstWeekInterval.start
        while startDate < monthInterval.end || calendar.component(.weekOfMonth, from: startDate) != 1 {
            let dayNumber = calendar.component(.day, from: startDate)
            let isToday = calendar.isDateInToday(startDate)
            days.append(DayInfo(number: dayNumber, date: startDate, isToday: isToday))
            startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }
        return days
    }

    private func generateWeekDays(for date: Date) -> [DayInfo] {
        var days: [DayInfo] = []
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var startDate = weekInterval.start
        for _ in 0 ..< 7 {
            let dayNumber = calendar.component(.day, from: startDate)
            let isToday = calendar.isDateInToday(startDate)
            days.append(DayInfo(number: dayNumber, date: startDate, isToday: isToday))
            startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }
        return days
    }

    struct DayInfo: Hashable {
        let number: Int
        let date: Date?
        let isToday: Bool
    }
}

struct DayCell: View {
    let day: CalendarView.DayInfo
    let tickets: [(id: String, date: Date)]
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text(day.number > 0 ? "\(day.number)" : "")
                .foregroundColor(day.isToday ? .white : .primary)
                .frame(width: 30, height: 30)
                .background(day.isToday ? Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255) : Color.clear)
                .clipShape(Circle())
            if let date = day.date {
                let todaysTickets = tickets.filter { calendar.isDate($0.date, inSameDayAs: date) }
                if !todaysTickets.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(todaysTickets.prefix(2), id: \.id) { ticket in
                            Text("#\(ticket.id)")
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(2)
                                .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                        if todaysTickets.count > 2 {
                            Text("+\(todaysTickets.count - 2) more")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Spacer().frame(height: 18)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
