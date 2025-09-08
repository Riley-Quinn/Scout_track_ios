// Models/TicketEntity+Mapping.swift
import CoreData

extension TicketEntity {
    func toTicket() -> Ticket {
        Ticket(
            ticket_id: Int(ticket_id),
            ticket_service_id: ticket_service_id,
            status_id: Int(status_id),
            status_name: status_name ?? "",
            category_name: category_name ?? "",
            region_name: region_name ?? "",
            city_name: city_name ?? "",
            customer_name: customer_name ?? "",
            created_at: created_at ?? "",
            employee_arrival_date: employee_arrival_date ?? "",
            description: descriptionText ?? "",
            urgency: urgency == 0 ? nil : Int(urgency),
            priority_rank: priority_rank,
            status_tracker: status_tracker,
            title: title ?? ""
        )
    }
}

extension Ticket {
    func toEntity(context: NSManagedObjectContext) -> TicketEntity {
        let entity = TicketEntity(context: context)
        entity.ticket_id = Int64(ticket_id)
        entity.ticket_service_id = ticket_service_id
        entity.status_id = Int64(status_id)
        entity.status_name = status_name
        entity.category_name = category_name
        entity.region_name = region_name
        entity.city_name = city_name
        entity.customer_name = customer_name
        entity.created_at = created_at
        // entity.employee_arrival_date = employee_arrival_date
        entity.descriptionText = description
        if let urgency = urgency {
            entity.urgency = Int64(urgency)
        }
        entity.priority_rank = priority_rank
        entity.status_tracker = status_tracker
        entity.title = title
        return entity
    }
}
