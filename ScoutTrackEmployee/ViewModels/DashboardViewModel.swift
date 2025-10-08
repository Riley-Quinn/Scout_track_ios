// DashboardViewModel.swift
import Combine
import CoreData
import Foundation
import SwiftUICore

class DashboardViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading: Bool = false
    @Published var selectedTicketDetail: TicketDetail?
    @Published var showArrivalSheet: Bool = false
    @Published var selectedTicket: Ticket?
    @Published var arrivalDate = Date()
    @Published var arrivalReason = ""
    @Published var showServiceUpdateSheet: Bool = false
    @Published var serviceReason: String = ""
    @Published var customServiceReason: String = ""
    @Published var showEditSheet = false
    @Published var editStatus: String = ""
    @Published var editReason: String = ""
    @Published var weeklyToDoCounts: [String: Int] = [:]
    private var cancellables = Set<AnyCancellable>()
    @Published var statusCounts: [String: Int] = [:] // ✅ This will hold all status counts

    // ✅ ADD computed properties for individual status counts
    var todoCount: Int {
        return statusCounts["ToDo"] ?? statusCounts["To Do"] ?? statusCounts["todo"] ?? statusCounts["to do"] ?? 0
    }

    var inProgressCount: Int {
        return statusCounts["In-Progress"] ?? statusCounts["In Progress"] ?? statusCounts["in-progress"] ?? statusCounts["in progress"] ?? 0
    }

    var pendingCount: Int {
        return statusCounts["Pending"] ?? statusCounts["pending"] ?? 0
    }

    var onHoldCount: Int {
        return statusCounts["On-Hold"] ?? statusCounts["On Hold"] ?? statusCounts["on-hold"] ?? statusCounts["on hold"] ?? 0
    }

    private var userId: String {
        UserDefaults.standard.string(forKey: "userId") ?? "0"
    }

    private var name: String {
        UserDefaults.standard.string(forKey: "name") ?? "-"
    }

    private let context = PersistenceController.shared.container.viewContext
    // Possible statuses for edit
    let editStatuses = ["Done", "On Hold", "Pending"]
    // Predefined service reasons
    let serviceReasons = [
        "Power Supply Issues",
        "Electrical Components Failure",
        "Overheating",
        "Loose or Damaged Wiring",
        "Software/Firmware Issues",
        "Physical Damage",
        "Remote Control or Interface Issues",
        "Voltage Fluctuations",
        "Spare Parts Replacement",
        "Other",
    ]

    // MARK: - Fetch Tickets (API + Core Data)

    func fetchTickets(onlyToday: Bool = true) {
        guard let url = URL(string: "\(Config.baseURL)/api/tickets/employee/\(userId)") else {
            print("❌ Invalid URL")
            return
        }

        isLoading = true
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: TicketListResponse.self, decoder: JSONDecoder())
            .map { response -> [Ticket] in
                let now = Date()
                let today = Calendar.current.startOfDay(for: now)

                // Step 1: Filter tickets
                var filteredTickets = response.list.filter { ticket in
                    // 1️⃣ OnlyToday filter
                    if onlyToday {
                        guard let arrivalDate = self.parseDateTime(dateStr: ticket.employee_arrival_date,
                                                                   timeStr: ticket.employee_arrival_time),
                            Calendar.current.isDate(arrivalDate, inSameDayAs: today)
                        else {
                            return false
                        }
                    }

                    // 2️⃣ Only ToDo status
                    if ticket.status_id != 2 {
                        return false
                    }

                    // 3️⃣ Arrival time logic
                    if let arrivalDate = self.parseDateTime(dateStr: ticket.employee_arrival_date,
                                                            timeStr: ticket.employee_arrival_time)
                    {
                        if arrivalDate < now && ticket.status_id != 2 {
                            return false
                        }
                    } else {
                        return false
                    }

                    return true
                }

                // Step 2: Sort tickets by arrival time
                return filteredTickets.sorted {
                    let date1 = self.parseDateTime(dateStr: $0.employee_arrival_date, timeStr: $0.employee_arrival_time) ?? Date.distantFuture
                    let date2 = self.parseDateTime(dateStr: $1.employee_arrival_date, timeStr: $1.employee_arrival_time) ?? Date.distantFuture
                    return date1 < date2
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.loadOfflineTickets()
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] (tickets: [Ticket]) in
                // ✅ REMOVED: Don't calculate counts here - use API counts instead
                self?.tickets = tickets
                self?.isLoading = false
                self?.saveTicketsOffline(tickets)
                print("📥 Final tickets assigned: \(tickets.count)")
            })
            .store(in: &cancellables)
    }

    func fetchAllTickets() {
        guard let url = URL(string: "\(Config.baseURL)/api/tickets/employee/\(userId)") else {
            return
        }

        isLoading = true

        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: TicketListResponse.self, decoder: JSONDecoder())
            .map { response -> [Ticket] in
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let isoFormatterNoMillis = ISO8601DateFormatter()
                isoFormatterNoMillis.formatOptions = [.withInternetDateTime]

                return response.list.sorted { t1, t2 in
                    let date1 = t1.employee_arrival_date.flatMap { isoFormatter.date(from: $0) ?? isoFormatterNoMillis.date(from: $0) }
                    let date2 = t2.employee_arrival_date.flatMap { isoFormatter.date(from: $0) ?? isoFormatterNoMillis.date(from: $0) }

                    if let d1 = date1, let d2 = date2 {
                        return d1 < d2
                    } else if date1 != nil {
                        return true
                    } else if date2 != nil {
                        return false
                    } else {
                        return (t1.urgency ?? Int.max) < (t2.urgency ?? Int.max)
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.loadOfflineTickets()
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] (tickets: [Ticket]) in
                // ✅ REMOVED: Don't calculate counts here either - use API counts
                self?.tickets = tickets
                self?.isLoading = false
                self?.saveTicketsOffline(tickets)
            })
            .store(in: &cancellables)
    }

    func parseDateTime(dateStr: String?, timeStr: String?) -> Date? {
        guard let dateStr = dateStr else { return nil }

        // Step 1: Handle ISO8601 for date part
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFormatterNoMillis = ISO8601DateFormatter()
        isoFormatterNoMillis.formatOptions = [.withInternetDateTime]

        var datePart: Date? = isoFormatter.date(from: dateStr) ?? isoFormatterNoMillis.date(from: dateStr)

        // Step 2: If time is provided, merge with date
        if let timeStr = timeStr, let dateOnly = datePart {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            timeFormatter.timeZone = TimeZone.current

            if let time = timeFormatter.date(from: timeStr) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
                datePart = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                         minute: timeComponents.minute ?? 0,
                                         second: timeComponents.second ?? 0,
                                         of: dateOnly)
            }
        }

        return datePart
    }

    // MARK: - Save Tickets in Core Data

    private func saveTicketsOffline(_ tickets: [Ticket]) {
        do {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TicketEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)

            for ticket in tickets {
                _ = ticket.toEntity(context: context)
            }
            try context.save()
        } catch {}
    }

    // MARK: - Load Tickets from Core Data

    private func loadOfflineTickets() {
        let request: NSFetchRequest<TicketEntity> = TicketEntity.fetchRequest()
        do {
            let entities = try context.fetch(request)
            tickets = entities.map { $0.toTicket() }
        } catch {
            tickets = []
        }
    }

    // MARK: - Fetch Status Counts

    func fetchAllStatusCounts() {
        guard let url = URL(string: "\(Config.baseURL)/api/tickets/employee/ticket-counts/\(userId)") else { return }

        // Read clientId from UserDefaults
        let clientId = UserDefaults.standard.string(forKey: "clientId") ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "x-client-id") // <-- Add client ID header

        URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { output in
                if let jsonString = String(data: output.data, encoding: .utf8) {
                    print("Raw Response: \(jsonString)")
                }
            })
            .map { $0.data }
            .decode(type: TicketCountsResponse.self, decoder: JSONDecoder())
            .replaceError(with: TicketCountsResponse(list: [:], total_count: 0))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                guard let self = self else { return }

                // ✅ ONLY set statusCounts - computed properties will handle the rest
                var counts: [String: Int] = [:]
                for (status, value) in response.list {
                    counts[status] = value.total_count
                }
                self.statusCounts = counts
            }
            .store(in: &cancellables)
    }

    // MARK: - Start Work

    func startWork(ticket: Ticket, completion: ((TicketDetail?) -> Void)? = nil) {
        let tracker = createStatusTracker(
            previousData: ticket.status_tracker,
            message: "Work started",
            statusName: "In-Progress",
            statusId: 3
        )

        guard let url = URL(string: "\(Config.baseURL)/api/tickets/\(ticket.ticket_id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "ticketData": [
                "status_id": 3,
                "status_tracker": tracker,
            ],
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch { return }

        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    // Update local ticket immediately
                    var updatedTicket = ticket.toTicketDetail()
                    updatedTicket.status_id = 3
                    updatedTicket.status_name = "In-Progress"
                    updatedTicket.status_tracker = tracker

                    // Call completion only if it was provided
                    completion?(updatedTicket)

                    self.fetchTickets() // Optional: refresh dashboard
                } else {
                    completion?(nil) // ❌ in case of failure
                }
            }
        }.resume()
    }

    // MARK: - Service Update

    func handleServiceUpdate() {
        guard let ticket = selectedTicket else { return }

        // If 'Other' is selected, use custom reason, otherwise use selected reason
        let reason = (serviceReason == "Other" && !customServiceReason.isEmpty)
            ? customServiceReason
            : (serviceReason.isEmpty ? "Service Update" : serviceReason)

        // Create status tracker
        let tracker = createStatusTracker(
            previousData: ticket.status_tracker,
            message: reason,
            statusName: "In-Progress",
            statusId: 3
        )

        // API Call
        guard let url = URL(string: "\(Config.baseURL)/api/tickets/\(ticket.ticket_id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "ticketData": [
                "status_tracker": tracker,
                "status_id": 3,
            ],
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch { return }

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    self?.fetchTickets()
                    self?.showServiceUpdateSheet = false
                    self?.serviceReason = ""
                    self?.customServiceReason = ""
                }
            }
        }.resume()
    }

    // MARK: - Edit Status

    func updateTicketStatus(completion: ((TicketDetail?) -> Void)? = nil) {
        guard let ticket = selectedTicket else { return }

        // Map status text to IDs
        let statusId: Int
        switch editStatus {
        case "Done": statusId = 6
        case "On Hold": statusId = 4
        case "Pending": statusId = 5
        default: statusId = ticket.status_id
        }

        // Reason is required for On Hold / Pending
        let message: String
        if editStatus == "Done" {
            message = "Service Completed"
        } else {
            message = "\(editStatus) - \(editReason)"
        }

        let tracker = createStatusTracker(
            previousData: ticket.status_tracker,
            message: message,
            statusName: editStatus,
            statusId: statusId
        )

        guard let url = URL(string: "\(Config.baseURL)/api/tickets/\(ticket.ticket_id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "ticketData": [
                "status_id": statusId,
                "status_tracker": tracker,
            ],
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch { return }

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    // ✅ Update local copy
                    var updatedTicket = ticket.toTicketDetail()
                    updatedTicket.status_id = statusId
                    updatedTicket.status_name = self?.editStatus ?? updatedTicket.status_name
                    updatedTicket.status_tracker = tracker

                    // ✅ Save to Core Data
                    CoreDataManager.shared.save(ticket: updatedTicket)

                    // ✅ Call completion handler
                    completion?(updatedTicket)

                    // ✅ Reset UI
                    self?.fetchTickets()
                    self?.showEditSheet = false
                    self?.editStatus = ""
                    self?.editReason = ""
                } else {
                    completion?(nil)
                }
            }
        }.resume()
    }

    // MARK: - Helper: format for MySQL DATETIME (no Z, no millis)

    private static func mysqlDateTimeNoZ(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current // ✅ Use local timezone, not UTC
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.string(from: date)
    }

    // MARK: - Status Tracker JSON Builder

    private func createStatusTracker(previousData: String?, message: String, statusName: String, statusId: Int) -> String {
        var history: [[String: Any]] = []
        if let prev = previousData,
           let data = prev.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            history = parsed
        }
        // ✅ Custom date + time format with comma
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "MMM dd, yyyy, hh:mm a" // Example: "Sep 16, 2025, 09:03 AM"
        let formattedDate = df.string(from: Date())
        let newEntry: [String: Any] = [
            "message": message,
            "status": statusName,
            "statusId": statusId,
            "changedBy": name,
            "timestamp": formattedDate, // ✅ Nice readable timestamp
        ]
        history.append(newEntry)
        let jsonData = try? JSONSerialization.data(withJSONObject: history)
        return String(data: jsonData ?? Data(), encoding: .utf8) ?? "[]"
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

extension DashboardViewModel {
    var pieChartData: [StatusPieData] {
        let total = max(statusCounts.values.reduce(0, +), 1) // total of all statuses
        var data: [StatusPieData] = []

        for (status, count) in statusCounts {
            guard count > 0 else { continue }
            data.append(
                StatusPieData(
                    status: status,
                    count: count,
                    percentage: Double(count) / Double(total),
                    color: colorForStatus(status)
                )
            )
        }
        return data
    }

    // Helper: assign color for each status
    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "todo", "to do": return .orange
        case "in-progress", "in progress": return .blue
        case "pending", "open": return .purple
        case "on-hold", "on hold": return .pink
        case "done": return .green
        default: return .gray // any unknown status
        }
    }
}
