// Models/Ticket.swift
import Foundation

struct Ticket: Identifiable, Codable {
    var id: Int { ticket_id }
    let ticket_id: Int
    let ticket_service_id: String?
    let status_id: Int
    let status_name: String
    let category_name: String
    let region_name: String
    let city_name: String
    let customer_name: String
    let created_at: String
    let employee_arrival_date: String?
    let description: String
    let urgency: Int?
    let priority_rank: String?
    let status_tracker: String?
    let title: String
}

struct TicketListResponse: Decodable {
    let list: [Ticket]
}

struct StatusCount: Decodable {
    let status_id: Int
    let total_count: Int
}

struct TicketCountsResponse: Decodable {
    let list: [String: StatusCount]
    let total_count: Int
}
