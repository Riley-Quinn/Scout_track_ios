import SwiftUI

struct CalendarView: View {
    @State private var selectedDate: Date? = Date() // Default to today
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
        let employee_arrival_time: String?
        let address: String?
        let city_name: String?
        let ticket_service_id: String?
        let title: String?
        var id: String { ticket_id }
        var date: Date {
            guard let dateStr = employee_arrival_date else {
                print("❌ No employee_arrival_date for ticket \(ticket_id)")
                return Date.distantFuture
            }

            var baseDate: Date?

            // Case 1: ISO8601 with time (UTC)
            if dateStr.contains("T") {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                isoFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC input
                baseDate = isoFormatter.date(from: dateStr)
            }

            // Case 2: Just a date "yyyy-MM-dd" (Local)
            if baseDate == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = .current // Local
                baseDate = dateFormatter.date(from: dateStr)
            }

            guard let parsedDate = baseDate else {
                print("❌ Failed to parse date: \(dateStr) for ticket \(ticket_id)")
                return Date.distantFuture
            }

            // If time exists, apply it in local timezone
            if let timeStr = employee_arrival_time {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                timeFormatter.locale = Locale(identifier: "en_US_POSIX")
                timeFormatter.timeZone = .current

                if let timeDate = timeFormatter.date(from: timeStr) {
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
                    return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                         minute: timeComponents.minute ?? 0,
                                         second: timeComponents.second ?? 0,
                                         of: parsedDate) ?? parsedDate
                }
            }

            return parsedDate
        }

        var localDay: Date {
            Calendar.current.startOfDay(for: date)
        }

        private enum CodingKeys: String, CodingKey {
            case ticket_id, employee_arrival_date, employee_arrival_time, address, city_name, ticket_service_id, title
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let intValue = try? container.decode(Int.self, forKey: .ticket_id) {
                ticket_id = String(intValue)
            } else {
                ticket_id = try container.decode(String.self, forKey: .ticket_id)
            }

            employee_arrival_date = try? container.decodeIfPresent(String.self, forKey: .employee_arrival_date)
            employee_arrival_time = try? container.decodeIfPresent(String.self, forKey: .employee_arrival_time)
            address = try? container.decodeIfPresent(String.self, forKey: .address)
            city_name = try? container.decodeIfPresent(String.self, forKey: .city_name)
            ticket_service_id = try? container.decodeIfPresent(String.self, forKey: .ticket_service_id)
            title = try? container.decodeIfPresent(String.self, forKey: .title)
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
            headerView

            ScrollView {
                VStack(spacing: 0) {
                    viewModePicker
                    Divider()

                    switch viewMode {
                    case .month: monthView
                    case .week: weekView
                    case .day: dayView
                    case .agenda: agendaView
                    }

                    // Use the extracted property
                    filteredTicketsGroupedView
                }
            }

            Divider()

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

    @State private var showPastEvents = false

    // Replace allTicketsGroupedView with this:
    private var filteredTicketsGroupedView: some View {
        let cutoffDate = selectedDate ?? Date() // Use selected date or today
        let filteredTickets = tickets.filter { $0.date >= Calendar.current.startOfDay(for: cutoffDate) }

        let groupedTickets = Dictionary(grouping: filteredTickets.sorted(by: { $0.date < $1.date })) {
            Calendar.current.startOfDay(for: $0.date)
        }
        let sortedDates = groupedTickets.keys.sorted()

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(sortedDates, id: \.self) { date in
                VStack(alignment: .leading, spacing: 6) {
                    // Date Header
                    Text("Tickets for \(dateString(from: date))")
                        .font(.headline)
                        .padding(.bottom, 4)

                    // Tickets for that day
                    if let dayTickets = groupedTickets[date], !dayTickets.isEmpty {
                        ForEach(dayTickets) { ticket in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    // Date
                                    Text(dateString(from: ticket.date))
                                        .font(.caption)
                                        .foregroundColor(.black)

                                    // Separator
                                    Text("|")
                                        .foregroundColor(.black)
                                        .fontWeight(.bold)

                                    // Title
                                    Text(ticket.title ?? "No Title")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)

                                    Spacer()
                                }

                                // Time in teal color
                                Text(timeString(from: ticket.date))
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    } else {
                        Text("No tickets for this date.")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.white)
            }
        }
        .padding()
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy" // Example: Sep 13, 2025
        formatter.timeZone = .current
        return formatter.string(from: date)
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
                    print("✅ Fetched \(decoded.list.count) tickets")

                    for ticket in decoded.list {
                        print("Ticket \(ticket.ticket_id): Date = \(ticket.employee_arrival_date ?? "nil"), Time = \(ticket.employee_arrival_time ?? "nil"), Parsed = \(ticket.date)")
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

        return VStack(spacing: 4) { // reduce spacing between header and rows
            // Weekday headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 1) // smaller header height
                }
            }

            // Full month grid with reduced row gap
            ForEach(0 ..< days.count / 7, id: \.self) { weekIndex in
                HStack(spacing: 2) { // less column spacing
                    ForEach(0 ..< 7, id: \.self) { dayIndex in
                        let day = days[weekIndex * 7 + dayIndex]

                        DayCell(
                            day: day,
                            tickets: tickets.map { (id: $0.id, date: $0.localDay, title: $0.title) },
                            selectedDate: selectedDate,
                            onDateSelected: { date in
                                selectedDate = date
                                currentDate = date
                            }
                        )
                        .frame(maxWidth: .infinity, minHeight: 45) // smaller height
                    }
                }
                .padding(.vertical, 0) // no extra gap between rows
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    // MARK: - Week View

    private var weekView: some View {
        let days = generateContinuousDays(centeredOn: currentDate, range: 12)

        return VStack(spacing: 0) {
            // Sticky month label
            Text(weekMonthLabel(for: currentDate))
                .font(.subheadline)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .shadow(radius: 1)

            // ✅ Wrap ScrollView in ScrollViewReader for auto-scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(days, id: \.self) { day in
                            DayCell(
                                day: day,
                                tickets: tickets.map { (id: $0.id, date: $0.localDay, title: $0.title) },
                                selectedDate: selectedDate,
                                onDateSelected: { date in
                                    selectedDate = date
                                    currentDate = date // Sync selected date
                                }
                            )
                            .frame(width: 50, height: 80)
                            .id(day.date) // ✅ Important for scrollTo
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // ✅ Scroll to today's date when view appears
                    if let today = days.first(where: { $0.isToday })?.date {
                        proxy.scrollTo(today, anchor: .center)
                    }
                }
            }
            .frame(height: 90)
        }
    }

    private func weekMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Day View

    private var dayView: some View {
        VStack {
            Text("Events for \(formattedDate(currentDate))")
                .font(.headline)
                .padding()
            if let ticket = tickets.first(where: { calendar.isDate($0.localDay, inSameDayAs: currentDate) }) {
                // Text("Ticket #\(ticket.ticket_service_id)")
                //     .padding()
                //     .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                //     .foregroundColor(.white)
                //     .cornerRadius(6)
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
            days.append(DayInfo(date: startDate, number: dayNumber, isToday: isToday))
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
            days.append(DayInfo(date: startDate, number: dayNumber, isToday: isToday))
            startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }
        return days
    }

    private func generateMultipleWeeks(centeredOn date: Date, range: Int) -> [[DayInfo]] {
        var weeks: [[DayInfo]] = []
        let calendar = Calendar.current

        for i in -range ... range {
            if let weekDate = calendar.date(byAdding: .weekOfYear, value: i, to: date) {
                let weekDays = generateWeekDays(for: weekDate)
                weeks.append(weekDays)
            }
        }

        return weeks
    }

    private func generateContinuousDays(centeredOn date: Date, range: Int) -> [DayInfo] {
        var days: [DayInfo] = []
        let calendar = Calendar.current
        let totalDays = (range * 7)

        if let startDate = calendar.date(byAdding: .day, value: -totalDays, to: date),
           let endDate = calendar.date(byAdding: .day, value: totalDays, to: date)
        {
            var current = startDate
            while current <= endDate {
                days.append(dayInfo(for: current))
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
        }

        return days
    }

    struct DayInfo: Hashable {
        let date: Date?
        let number: Int

        let isToday: Bool
    }

    private func dayInfo(for date: Date) -> DayInfo {
        let calendar = Calendar.current
        return DayInfo(
            date: date,
            number: calendar.component(.day, from: date),
            isToday: calendar.isDateInToday(date)
        )
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = .current // ✅ Convert to user’s local time
        return formatter.string(from: date)
    }
}

struct DayCell: View {
    let day: CalendarView.DayInfo
    let tickets: [(id: String, date: Date, title: String?)]
    let selectedDate: Date? // ✅ Added
    let onDateSelected: (Date) -> Void

    private let calendar = Calendar.current
    @State private var selectedTickets: [(id: String, title: String?)] = []
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                if let date = day.date {
                    onDateSelected(date)
                }
            }) {
                Text(day.number > 0 ? "\(day.number)" : "")
                    .font(.system(size: 12, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(foregroundColor)
                    .frame(width: 28, height: 28)
                    .background(backgroundColor)
                    .clipShape(Circle())
            }

            if let date = day.date {
                let todaysTickets = tickets.filter { calendar.isDate($0.date, inSameDayAs: date) }

                if !todaysTickets.isEmpty {
                    VStack(spacing: 3) {
                        ForEach(todaysTickets.prefix(2), id: \.id) { ticket in
                            Button(action: {
                                selectedTickets = todaysTickets.map { ($0.id, $0.title) }
                                showDetails = true
                            }) {
                                Text(ticket.title?.prefix(6) ?? "Event")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }

                        if todaysTickets.count > 2 {
                            Button(action: {
                                selectedTickets = todaysTickets.map { ($0.id, $0.title) }
                                showDetails = true
                            }) {
                                Text("+\(todaysTickets.count - 2) more")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } else {
                    Spacer().frame(height: 16)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .sheet(isPresented: $showDetails) {
            TicketDetailsView(tickets: selectedTickets)
        }
    }

    // ✅ Highlight colors
    private var backgroundColor: Color {
        if let selectedDate = selectedDate, let date = day.date, calendar.isDate(selectedDate, inSameDayAs: date) {
            return Color.blue.opacity(0.7) // Selected day background
        } else if day.isToday {
            return Color.red // Today
        } else {
            return Color.clear
        }
    }

    private var foregroundColor: Color {
        if let selectedDate = selectedDate, let date = day.date, calendar.isDate(selectedDate, inSameDayAs: date) {
            return .white // White text for selected
        } else {
            return day.isToday ? .white : .primary
        }
    }
}

struct TicketDetailsView: View {
    let tickets: [(id: String, title: String?)]

    var body: some View {
        NavigationView {
            List(tickets, id: \.id) { ticket in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.title ?? "No Title")
                        .font(.headline)
                    Text("Ticket ID: \(ticket.id)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
