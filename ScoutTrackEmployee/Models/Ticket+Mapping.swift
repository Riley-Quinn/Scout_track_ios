extension Ticket {
    init(from detail: TicketDetail) {
        ticket_id = detail.ticket_id
        ticket_service_id = detail.ticket_service_id // optional -> optional
        status_id = detail.status_id
        status_name = detail.status_name // non-optional
        category_name = detail.category_name // non-optional
        region_name = detail.region_name // non-optional
        city_name = detail.city_name ?? "" // optional -> non-optional
        customer_name = detail.customer_name // non-optional
        created_at = detail.created_at // non-optional
        employee_arrival_date = detail.employee_arrival_date // non-optional -> optional
        description = detail.description // non-optional
        urgency = nil // not in TicketDetail, assign default nil
        priority_rank = detail.priority_rank // optional -> optional
        status_tracker = detail.status_tracker // optional -> optional
        title = detail.title // non-optional
        employee_arrival_time = nil
    }
}
