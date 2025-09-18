// DashboardViewModel.swift
import Combine
import CoreData
import Foundation

class DashboardViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading: Bool = false
    @Published var todoCount: Int = 0
    @Published var inProgressCount: Int = 0
    @Published var pendingCount: Int = 0
    @Published var onHoldCount: Int = 0
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
    @Published var weeklyToDoCounts: [String: Int] = [:] // ← Add this
    private var cancellables = Set<AnyCancellable>()
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

    func fetchTickets(onlyToday: Bool = false) {
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

                func parseDate(_ dateString: String?) -> Date? {
                    guard let str = dateString else { return nil }
                    return isoFormatter.date(from: str) ?? isoFormatterNoMillis.date(from: str)
                }

                let allTickets = response.list
                let today = Calendar.current.startOfDay(for: Date())
                let now = Date()

                // Step 1: Apply onlyToday filter
                var filteredTickets = allTickets
                if onlyToday {
                    filteredTickets = allTickets.filter { ticket in
                        if let arrivalDate = parseDate(ticket.employee_arrival_date) {
                            return Calendar.current.isDate(arrivalDate, inSameDayAs: today)
                        }
                        return false
                    }
                }

                // Step 2: Remove tickets if time passed AND status_id != 2
                filteredTickets = filteredTickets.filter { ticket in
                    if let arrivalDate = parseDate(ticket.employee_arrival_date) {
                        if arrivalDate < now && ticket.status_id != 2 {
                            return false // remove it
                        }
                    }
                    return true
                }

                // Step 3: Sort tickets
                return filteredTickets.sorted { t1, t2 in
                    let date1 = parseDate(t1.employee_arrival_date)
                    let date2 = parseDate(t2.employee_arrival_date)

                    // Case 1: Both have dates → sort by date
                    if let d1 = date1, let d2 = date2 {
                        return d1 < d2
                    }

                    // Case 2: One has date → date comes first
                    if let _ = date1, date2 == nil { return true }
                    if date1 == nil, let _ = date2 { return false }

                    // Case 3: Both missing dates → Only status_id == 2 tickets sorted by urgency
                    if t1.status_id == 2 && t2.status_id == 2 {
                        return (t1.urgency ?? Int.max) < (t2.urgency ?? Int.max)
                    }

                    // Case 4: status_id == 2 comes before others with no date
                    if t1.status_id == 2 && t2.status_id != 2 { return true }
                    if t1.status_id != 2 && t2.status_id == 2 { return false }

                    // Case 5: Otherwise → keep same order
                    return false
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.loadOfflineTickets()
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] (tickets: [Ticket]) in
                var dayWiseToDo: [String: Int] = [:]

                for ticket in tickets {
                    guard let trackerStr = ticket.status_tracker,
                          let data = trackerStr.data(using: .utf8),
                          let trackerArrayAny = try? JSONSerialization.jsonObject(with: data),
                          let trackerArray = trackerArrayAny as? [[String: Any]]
                    else { continue }

                    if let todoEntry = trackerArray.first(where: {
                        ($0["status"] as? String)?.lowercased() == "todo" || ($0["status"] as? String)?.lowercased() == "to do"
                    }) {
                        if let dateStr = (todoEntry["timestamp"] as? String) ?? (todoEntry["Date"] as? String) {
                            let isoFormatter = ISO8601DateFormatter()
                            let dateFormatter = DateFormatter()
                            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                            dateFormatter.dateFormat = "MMM dd, yyyy, hh:mm a"

                            if let date = isoFormatter.date(from: dateStr) ?? dateFormatter.date(from: dateStr) {
                                let dayKey = DateFormatter.shortDate.string(from: date)
                                dayWiseToDo[dayKey, default: 0] += 1
                            }
                        }
                    }
                }

                let todayKey = DateFormatter.shortDate.string(from: Date())
                self?.tickets = tickets
                self?.todoCount = dayWiseToDo[todayKey] ?? 0
                self?.weeklyToDoCounts = dayWiseToDo
                self?.isLoading = false
                self?.saveTicketsOffline(tickets)
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
                var dayWiseToDo: [String: Int] = [:]

                for ticket in tickets {
                    guard let trackerStr = ticket.status_tracker,
                          let data = trackerStr.data(using: .utf8),
                          let trackerArrayAny = try? JSONSerialization.jsonObject(with: data),
                          let trackerArray = trackerArrayAny as? [[String: Any]]
                    else {
                        continue
                    }
                    if let todoEntry = trackerArray.first(where: {
                        guard let status = $0["status"] as? String else { return false }
                        return status.lowercased() == "todo" || status.lowercased() == "to do"
                    }) {
                        // ✅ Try timestamp first, then fallback to "Date"
                        if let dateStr = (todoEntry["timestamp"] as? String) ?? (todoEntry["Date"] as? String) {
                            let isoFormatter = ISO8601DateFormatter()
                            let dateFormatter = DateFormatter()
                            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                            dateFormatter.dateFormat = "MMM dd, yyyy, hh:mm a"

                            if let date = isoFormatter.date(from: dateStr) ?? dateFormatter.date(from: dateStr) {
                                let dayKey = DateFormatter.shortDate.string(from: date)
                                dayWiseToDo[dayKey, default: 0] += 1
                            } 
                        } 
                    } 
                }
                let todayKey = DateFormatter.shortDate.string(from: Date())
                self?.tickets = tickets
                self?.todoCount = dayWiseToDo[todayKey] ?? 0
                self?.weeklyToDoCounts = dayWiseToDo
                self?.isLoading = false

                self?.saveTicketsOffline(tickets)
            })
            .store(in: &cancellables)
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

        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: TicketCountsResponse.self, decoder: JSONDecoder())
            .replaceError(with: TicketCountsResponse(list: [:], total_count: 0))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.pendingCount = response.list["Pending"]?.total_count ?? 0
                self?.todoCount = response.list["ToDo"]?.total_count ?? 0
                self?.inProgressCount = response.list["In-Progress"]?.total_count ?? 0
                self?.onHoldCount = response.list["On-Hold"]?.total_count ?? 0
            }
            .store(in: &cancellables)
    }

    // MARK: - Start Work

    func startWork(ticket: Ticket) {
        let message = "Work started"
        let tracker = createStatusTracker(
            previousData: ticket.status_tracker,
            message: message,
            statusName: "In-Progress",
            statusId: 3
        )

        guard let url = URL(string: "\(Config.baseURL)/api/tickets/\(ticket.ticket_id)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "ticketData": [
                "status_id": 3, // In-Progress
                "status_tracker": tracker,
            ],
        ]

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = bodyData
        } catch {
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    self?.fetchTickets()
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

    func updateTicketStatus() {
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
        var message: String
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
                    self?.fetchTickets()
                    self?.showEditSheet = false
                    self?.editStatus = ""
                    self?.editReason = ""
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
