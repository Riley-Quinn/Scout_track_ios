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
        let status_name: String?
        let region_name: String?
        var id: String { ticket_id }
        var date: Date {
            guard let dateStr = employee_arrival_date else {
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
            case ticket_id, employee_arrival_date, employee_arrival_time, address, city_name, ticket_service_id, title, status_name, region_name
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
            status_name = try? container.decodeIfPresent(String.self, forKey: .status_name)
            region_name = try? container.decodeIfPresent(String.self, forKey: .region_name)
        }
    }

    @State private var currentDate = Date()
    @State private var viewMode: ViewMode = .month
    @State private var tickets: [CalendarTicket] = []
    private let calendar = Calendar.current

    private let debugFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            // Fixed View Mode Picker
            viewModePicker
            Divider()

            // Fixed Calendar View
            VStack(spacing: 0) {
                switch viewMode {
                case .month: monthView
                case .week: weekView
                case .day: dayView
                case .agenda: EmptyView() // No calendar for agenda view
                }
            }
            .background(Color.white)

            if viewMode != .agenda {
                Divider()
            }

            // <-- IMPORTANT: use the filteredTicketsGroupedView directly (it contains its own ScrollView).
            filteredTicketsGroupedView
                .padding(.top, viewMode == .agenda ? 0 : 16)

            // Fixed Footer
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
            .padding()
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // ensure we start with the start of today selected
            let todayStart = calendar.startOfDay(for: Date())
            selectedDate = todayStart
            currentDate = todayStart
            fetchTickets()
        }
    }

    @State private var showPastEvents = false

    // PreferenceKey used to report section minY positions
    struct DateSectionPreferenceKey: PreferenceKey {
        static var defaultValue: [Date: CGFloat] = [:]
        static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    // Enhanced tickets view with automatic date selection while scrolling
    private var filteredTicketsGroupedView: some View {
        let today = Calendar.current.startOfDay(for: Date())

        // Split tickets into past and present+future
        let pastTickets = tickets.filter { $0.date < today }
        let presentAndFuture = tickets.filter { $0.date >= today }

        // Group by day
        let groupedPast = Dictionary(grouping: pastTickets.sorted(by: { $0.date < $1.date })) {
            Calendar.current.startOfDay(for: $0.date)
        }
        let groupedFuture = Dictionary(grouping: presentAndFuture.sorted(by: { $0.date < $1.date })) {
            Calendar.current.startOfDay(for: $0.date)
        }

        // Sorted keys
        let sortedPastDates = groupedPast.keys.sorted() // oldest → newest
        let sortedFutureDates = groupedFuture.keys.sorted() // today → future

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // --- PAST TICKETS ---
                // Show button first, then expand if user wants
                if !sortedPastDates.isEmpty {
                    if showPastEvents {
                        ForEach(sortedPastDates, id: \.self) { date in
                            ticketSection(date: date, tickets: groupedPast[date] ?? [])
                        }
                    } else {
                        Button {
                            withAnimation { showPastEvents = true }
                        } label: {
                            Text(" Show Earlier Tickets")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                // --- TODAY + FUTURE TICKETS (shown by default) ---
                ForEach(sortedFutureDates, id: \.self) { date in
                    ticketSection(date: date, tickets: groupedFuture[date] ?? [])
                }
            }
            .padding(.horizontal)
        }
        .coordinateSpace(name: "TicketsScrollView")
        .onPreferenceChange(DateSectionPreferenceKey.self) { values in
            // Only consider sections visible in viewport
            let visibleSections = values.filter { $0.value >= -50 }
            if let closest = visibleSections.min(by: { $0.value < $1.value }) {
                if closest.key != selectedDate {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedDate = closest.key
                        currentDate = closest.key
                    }
                }
            }
        }
    }

    private func ticketSection(date: Date, tickets: [CalendarTicket]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(dateString(from: date))")
                .font(.system(size: 14))
                .padding(.bottom, 4)

            if tickets.isEmpty {
                Text("No tickets for this date.")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
            } else {
                ForEach(tickets) { ticket in
                    ticketRow(ticket)
                    if ticket.id != tickets.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DateSectionPreferenceKey.self,
                    value: [date: geo.frame(in: .named("TicketsScrollView")).minY]
                )
            }
        )
    }

    private func stickyDateHeader(for date: Date) -> some View {
        Text(dateString(from: date))
            .font(.headline)
            .padding(.vertical, 6)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.shadow(color: .black.opacity(0.1), radius: 2, y: 2))
    }

    private func ticketRow(_ ticket: CalendarTicket) -> some View {
        HStack(spacing: 8) {
            // Left column (time / status)
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(from: ticket.date))
                    .font(.caption)
                    .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                Text(ticket.status_name ?? "")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color(for: ticket.status_name))
            }
            .frame(width: 60, alignment: .leading)

            // Middle divider (single for both lines)
            Rectangle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 3)
                .padding(.vertical, 0) // spans full height of HStack automatically

            // Right column (title / region)
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.title ?? "No Title")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(ticket.region_name ?? "")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }

    // Helper function to get color based on status
    private func color(for status: String?) -> Color {
        switch status?.lowercased() {
        case "open": return .blue
        case "todo": return .red
        case "in-progress": return .orange
        case "done": return .green
        case "closed": return .teal
        case "on hold": return .yellow
        case "pending": return .purple
        default: return .black
        }
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
              let url = URL(string: "\(Config.baseURL)/api/tickets/employee/\(userId)")
        else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Fetch error: \(error)")
                return
            }
            guard let data = data else {
                print("No data")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(TicketResponse.self, from: data)
                DispatchQueue.main.async {
                    // 🚀 Filter out tickets without employee_arrival_date
                    self.tickets = decoded.list.filter { ticket in
                        if let dateStr = ticket.employee_arrival_date,
                           !dateStr.trimmingCharacters(in: .whitespaces).isEmpty
                        {
                            return true
                        }
                        return false
                    }

                    print("✅ Fetched \(self.tickets.count) tickets with arrival dates")

                    for ticket in self.tickets {
                        print("Ticket \(ticket.ticket_id): Date = \(ticket.employee_arrival_date ?? "nil"), Time = \(ticket.employee_arrival_time ?? "nil"), Parsed = \(ticket.date)")
                    }

                    // ensure selectedDate is on a day that exists in tickets (if not already)
                    let todayStart = calendar.startOfDay(for: Date())
                    if let firstTicketDate = self.tickets.map({ Calendar.current.startOfDay(for: $0.date) }).sorted().first,
                       !Calendar.current.isDate(firstTicketDate, inSameDayAs: selectedDate ?? todayStart)
                    {
                        selectedDate = firstTicketDate
                        currentDate = firstTicketDate
                    }
                }
            } catch {
                if let str = String(data: data, encoding: .utf8) {
                    print("Decode error: \(error). Server response: \(str)")
                } else {
                    print("Decode error: \(error)")
                }
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
                Button(action: {
                    let today = calendar.startOfDay(for: Date())
                    selectedDate = today
                    currentDate = today
                }) {
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
        .background(Color.white)
    }

    // MARK: - Month View

    private var monthView: some View {
        let days = generateMonthDays(for: currentDate)

        return VStack(spacing: 4) {
            // Weekday headers
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 1)
                }
            }

            // Full month grid with reduced row gap
            ForEach(0 ..< days.count / 7, id: \.self) { weekIndex in
                HStack(spacing: 2) {
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
                        .frame(maxWidth: .infinity, minHeight: 45)
                    }
                }
                .padding(.vertical, 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Week View

    private var weekView: some View {
        // Calculate start of the current week (Sunday)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!

        // Build multiple weeks (e.g., 6 weeks: 3 before, 3 after)
        let weekOffsets = (-5 ... 5)
        let ticketsForCells = tickets.map { (id: $0.id, date: $0.localDay, title: $0.title) }

        // Day width = screen width / 7 to show exactly 7 days
        let dayWidth = UIScreen.main.bounds.width / 7

        return VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(weekOffsets, id: \.self) { offset in
                            if let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: startOfWeek) {
                                let weekDays: [DayInfo] = (0 ..< 7).compactMap { dayOffset in
                                    if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                                        return dayInfo(for: date)
                                    }
                                    return nil
                                }

                                VStack(spacing: 4) {
                                    // Weekday labels
                                    HStack(spacing: 0) {
                                        ForEach(weekDays, id: \.self) { day in
                                            Text(shortWeekday(for: day.date))
                                                .font(.caption2)
                                                .frame(width: dayWidth)
                                        }
                                    }

                                    // Day cells
                                    HStack(spacing: 0) {
                                        ForEach(weekDays, id: \.self) { day in
                                            DayCell(
                                                day: day,
                                                tickets: ticketsForCells,
                                                selectedDate: selectedDate,
                                                onDateSelected: { date in
                                                    selectedDate = date
                                                    currentDate = date
                                                    withAnimation { proxy.scrollTo(weekStart, anchor: .center) }
                                                }
                                            )
                                            .frame(width: dayWidth, height: 70)
                                        }
                                    }
                                }
                                .id(weekStart)
                            }
                        }
                    }
                }
                .onAppear {
                    withAnimation { proxy.scrollTo(startOfWeek, anchor: .center) }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func shortWeekday(for date: Date) -> String {
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = Calendar.current.timeZone
        let formatter = DateFormatter()
        formatter.calendar = isoCalendar
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(3)) // Mon, Tue, ...
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
                // Show selected day info
            } else {
                Text("No events")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Agenda View (Calendar hidden, only tickets shown)

    private var agendaView: some View {
        EmptyView() // No calendar view for agenda mode
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
        var isoCalendar = Calendar(identifier: .iso8601) // Monday-based weeks
        isoCalendar.timeZone = Calendar.current.timeZone
        let alignedDate = isoCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let totalDays = (range * 7)

        if let startDate = isoCalendar.date(byAdding: .day, value: -totalDays, to: alignedDate),
           let endDate = isoCalendar.date(byAdding: .day, value: totalDays, to: alignedDate)
        {
            var current = startDate
            while current <= endDate {
                days.append(dayInfo(for: current))
                current = isoCalendar.date(byAdding: .day, value: 1, to: current)!
            }
        }

        return days
    }

    struct DayInfo: Hashable {
        let date: Date
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
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// DayCell and TicketDetailsView unchanged (kept as in your original code)
struct DayCell: View {
    let day: CalendarView.DayInfo
    let tickets: [(id: String, date: Date, title: String?)]
    let selectedDate: Date?
    let onDateSelected: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            // Day number
            Button(action: { onDateSelected(day.date) }) {
                Text(day.number > 0 ? "\(day.number)" : "")
                    .font(.system(size: 12, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(foregroundColor)
                    .frame(width: 28, height: 28)
                    .background(backgroundColor)
                    .clipShape(Circle())
            }

            // Reserve fixed height for ticket area (empty)
            Color.clear
                .frame(height: 20) // 🔹 same for all cells, keeps alignment
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        if let selectedDate = selectedDate, calendar.isDate(selectedDate, inSameDayAs: day.date) {
            return Color.blue.opacity(0.7)
        } else if day.isToday {
            return Color.red
        } else {
            return Color.clear
        }
    }

    private var foregroundColor: Color {
        if let selectedDate = selectedDate, calendar.isDate(selectedDate, inSameDayAs: day.date) {
            return .white
        } else {
            return day.isToday ? .white : .primary
        }
    }
}
