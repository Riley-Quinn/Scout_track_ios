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
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "http://localhost:4200"
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

    func fetchTickets() {
        guard let url = URL(string: "\(baseURL)/api/tickets/employee/\(userId)") else { return }

        isLoading = true
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: TicketListResponse.self, decoder: JSONDecoder())
            .map { response in
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let isoFormatterNoMillis = ISO8601DateFormatter()
                isoFormatterNoMillis.formatOptions = [.withInternetDateTime]

                // Sort tickets: first by arrival date (if present), else by urgency
                let sortedTickets = response.list.sorted { t1, t2 in
                    let date1 = t1.employee_arrival_date.flatMap { isoFormatter.date(from: $0) ?? isoFormatterNoMillis.date(from: $0) }
                    let date2 = t2.employee_arrival_date.flatMap { isoFormatter.date(from: $0) ?? isoFormatterNoMillis.date(from: $0) }

                    if let d1 = date1, let d2 = date2 {
                        return d1 < d2 // earlier arrival date first
                    } else if date1 != nil {
                        return true // tickets with arrival date come first
                    } else if date2 != nil {
                        return false
                    } else {
                        return (t1.urgency ?? Int.max) < (t2.urgency ?? Int.max)
                    }
                }

                return sortedTickets
            }

            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    self?.loadOfflineTickets()
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] tickets in
                self?.tickets = tickets
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
        guard let url = URL(string: "\(baseURL)/api/tickets/employee/ticket-counts/\(userId)") else { return }

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

    // MARK: - Update Arrival Date

    func updateArrivalDate() {
        guard let ticket = selectedTicket else {
            return
        }

        // Build DB-friendly string: "yyyy-MM-dd'T'HH:mm:ss" (NO Z, NO millis)
        let formattedDate = Self.mysqlDateTimeNoZ(from: arrivalDate)
        let isFirstArrival = (selectedTicket?.employee_arrival_date?.isEmpty ?? true)
        // Build message (human readable)
        let timeString = DateFormatter.localizedString(from: arrivalDate, dateStyle: .medium, timeStyle: .short)
        let message = isFirstArrival
            ? "Engineer will arrive on \(timeString)"
            : "Engineer will arrive on \(timeString) due to \(arrivalReason)"

        // Prepare status tracker JSON (if you later add previous data, pass it here)
        let tracker = createStatusTracker(previousData: ticket.status_tracker, message: message, statusName: "Todo", statusId: 3)

        // Prepare API request
        guard let url = URL(string: "\(baseURL)/api/tickets/\(ticket.ticket_id)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "ticketData": [
                "employee_arrival_date": formattedDate, // <-- NO Z, NO millis
                "status_tracker": tracker,
            ],
        ]

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
            request.httpBody = bodyData

            // 🔎 LOG: Request
            if let headers = request.allHTTPHeaderFields { print("🧾 Headers:", headers) }
        } catch {
            return
        }

        // Send request
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let error = error {}
            DispatchQueue.main.async {
                // consider checking status code 200..299
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    self?.fetchTickets()
                    self?.showArrivalSheet = false
                }
            }
        }.resume()
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

        guard let url = URL(string: "\(baseURL)/api/tickets/\(ticket.ticket_id)") else {
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
            print("JSON Error:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                    self?.fetchTickets()
                } else {
                    print("Failed to update status")
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
        guard let url = URL(string: "\(baseURL)/api/tickets/\(ticket.ticket_id)") else { return }
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
                } else {
                    print("❌ Service update failed")
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

        guard let url = URL(string: "\(baseURL)/api/tickets/\(ticket.ticket_id)") else { return }
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
        // If your server expects local time, set to .current
        // If your server expects UTC (but still without Z), use GMT.
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0) // UTC, NO Z
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

        let newEntry: [String: Any] = [
            "message": message,
            "status": statusName,
            "statusId": statusId,
            "changedBy": name,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
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
