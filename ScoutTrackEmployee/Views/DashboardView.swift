import SwiftUI

struct DashboardView: View {
    @State private var navigateToAllTickets = false
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Dashboard")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                ScrollView {
                    VStack(spacing: 16) {
                        // ✅ Status Grid
                        HStack(spacing: 12) {
                            StatusCard(title: "ToDo", count: viewModel.todoCount, color: .orange, icon: "exclamationmark.triangle")
                            StatusCard(title: "In Progress", count: viewModel.inProgressCount, color: .blue, icon: "shield")
                        }
                        HStack(spacing: 12) {
                            StatusCard(title: "Pending", count: viewModel.pendingCount, color: .purple, icon: "clock")
                            StatusCard(title: "On Hold", count: viewModel.onHoldCount, color: .pink, icon: "clock")
                        }

                        // ✅ Tickets Section
                        HStack {
                            Text("Today Tickets")
                                .font(.headline)
                            Spacer()
                            Button("View All") {
                                navigateToAllTickets = true
                            }
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        .padding(.horizontal)
                        NavigationLink(destination: AllTicketsView(viewModel: viewModel), isActive: $navigateToAllTickets) {
                            EmptyView()
                        }
                        .hidden()

                        if viewModel.isLoading {
                            ProgressView("Loading tickets...")
                        } else if viewModel.tickets.isEmpty {
                            Text("No ToDo tickets today")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.tickets.prefix(3)) { ticket in
                                    NavigationLink(destination: TicketDetailView(ticketId: ticket.ticket_id)) {
                                        TicketCard(
                                            ticket: ticket,
                                            onAssign: {
                                                // Add your "Assign to Me" logic here if needed
                                            },
                                            onSetArrival: {
                                                viewModel.selectedTicket = ticket
                                                viewModel.arrivalDate = Date()
                                                viewModel.showArrivalSheet = true
                                            },
                                            onStartWork: {
                                                viewModel.startWork(ticket: ticket)
                                            },
                                            onServiceUpdate: {
                                                viewModel.selectedTicket = ticket
                                                viewModel.showServiceUpdateSheet = true
                                            },
                                            onEdit: {
                                                viewModel.selectedTicket = ticket
                                                viewModel.editStatus = ""
                                                viewModel.editReason = ""
                                                viewModel.showEditSheet = true
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Footer Tabs
                Divider()
                HStack {
                    FooterTab(icon: "house", label: "Home", selected: true)
                    Spacer()
                    NavigationLink(destination: CalendarView()) {
                        FooterTab(icon: "calendar", label: "Calendar")
                    }
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
                viewModel.fetchTickets()
                viewModel.fetchAllStatusCounts()
            }
            // 🔹 Arrival Date Sheet Integration
            .sheet(isPresented: $viewModel.showArrivalSheet) {
                ArrivalDateSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showServiceUpdateSheet) {
                ServiceUpdateSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showEditSheet) {
                EditTicketSheet(viewModel: viewModel)
            }
        }
    }
}

// 🔹 Date & Time Picker Sheet
struct ArrivalDateSheet: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Arrival Date & Time")
                .font(.headline)

            DatePicker("Arrival Date & Time", selection: $viewModel.arrivalDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()

            // ✅ Show Reason TextField ONLY if there is already an arrival date
            if let existingDate = viewModel.selectedTicket?.employee_arrival_date,
               !existingDate.isEmpty
            {
                TextField("Reason for Delay (Optional)", text: $viewModel.arrivalReason)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }

            HStack {
                Button("Cancel") { viewModel.showArrivalSheet = false }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                Button("Save") { viewModel.updateArrivalDate() }
                    .buttonStyle(ActionButtonStyle(color: .teal))
            }
        }
        .padding()
    }
}

// 🔹 Service Update Sheet
struct ServiceUpdateSheet: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Service Update")
                .font(.headline)

            // Dropdown using Picker
            Picker("Select Reason", selection: $viewModel.serviceReason) {
                ForEach(viewModel.serviceReasons, id: \.self) { reason in
                    Text(reason).tag(reason)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Custom reason if 'Other' selected
            if viewModel.serviceReason == "Other" {
                TextField("Enter custom reason", text: $viewModel.customServiceReason)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }

            HStack {
                Button("Cancel") {
                    viewModel.showServiceUpdateSheet = false
                }
                .buttonStyle(ActionButtonStyle(color: .gray))

                Button("Save") {
                    viewModel.handleServiceUpdate()
                }
                .buttonStyle(ActionButtonStyle(color: .teal))
            }
        }
        .padding()
    }
}

// 🔹 Edit Status Sheet
struct EditTicketSheet: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Update Ticket Status")
                .font(.headline)

            Picker("Select Status", selection: $viewModel.editStatus) {
                ForEach(viewModel.editStatuses, id: \.self) { status in
                    Text(status).tag(status)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Show reason only for On Hold or Pending
            if viewModel.editStatus == "On Hold" || viewModel.editStatus == "Pending" {
                TextField("Enter reason", text: $viewModel.editReason)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }

            HStack {
                Button("Cancel") { viewModel.showEditSheet = false }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                Button("Save") { viewModel.updateTicketStatus() }
                    .buttonStyle(ActionButtonStyle(color: .teal))
                    .disabled(viewModel.editStatus.isEmpty || ((viewModel.editStatus == "On Hold" || viewModel.editStatus == "Pending") && viewModel.editReason.isEmpty))
            }
        }
        .padding()
    }
}

// MARK: - Status Card

struct StatusCard: View {
    var title: String
    var count: Int
    var color: Color
    var icon: String

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text("\(count)")
                        .font(.title)
                        .bold()
                }
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(color.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Ticket Card

struct TicketCard: View {
    var ticket: Ticket
    var onAssign: (() -> Void)?
    var onSetArrival: (() -> Void)?
    var onStartWork: (() -> Void)?
    var onServiceUpdate: (() -> Void)?
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 🔹 Header
            HStack {
                Text(ticket.ticket_service_id ?? "Ticket #\(ticket.ticket_id)")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text(ticket.status_name)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(ticket.status_name))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
            .cornerRadius(12, corners: [.topLeft, .topRight])

            // 🔹 Body
            VStack(alignment: .leading, spacing: 6) {
                Text(ticket.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .bold()
                Text(ticket.description)
                    .font(.system(size: 13))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    HStack {
                        Text("Category:")
                        Text(ticket.category_name)
                            .bold()
                            .foregroundColor(.teal)
                    }
                    Spacer()
                    HStack {
                        Text("Region:")
                        Text(ticket.region_name)
                            .bold()
                            .foregroundColor(.teal)
                    }
                }
                .font(.subheadline)

                Divider()

                let arrivalDateText: String = {
                    if let raw = ticket.employee_arrival_date {
                        return raw.split(separator: "T").first.map(String.init) ?? "N/A"
                    }
                    return "N/A"
                }()

                HStack {
                    Label("Customer: \(ticket.customer_name)", systemImage: "person")
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.gray)

                // 🔹 Status-based Actions
                HStack {
                    if ticket.status_id == 1 {
                        Button("Assign to Me") { onAssign?() }
                            .buttonStyle(ActionButtonStyle(color: .teal))
                    } else if ticket.status_id == 2 {
                        // Added Arrival Date button logic here
                        Button("Arrival Date") { onSetArrival?() }
                            .buttonStyle(ActionButtonStyle(color: .orange))
                        if let arrivalDate = ticket.employee_arrival_date, !arrivalDate.isEmpty {
                            Button("Start") { onStartWork?() }
                                .buttonStyle(ActionButtonStyle(color: .blue))
                        }

                    } else if ticket.status_id == 3 {
                        Button("Service Update") { onServiceUpdate?() }
                            .buttonStyle(ActionButtonStyle(color: .purple))
                        Button("Edit") { onEdit?() }
                            .buttonStyle(ActionButtonStyle(color: .pink))
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "todo", "to do":
            return .orange.opacity(0.7)
        case "in-progress", "in progress":
            return .blue.opacity(0.7)
        case "on-hold", "on hold":
            return .pink.opacity(0.7)
        case "pending", "open":
            return .purple.opacity(0.7)
        case "done":
            return .green.opacity(0.7)
        default:
            return .gray.opacity(0.7)
        }
    }
}

// 🔹 Reusable Button Style
struct ActionButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// 🔹 Rounded Corner Helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 0.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Footer Tab

struct FooterTab: View {
    var icon: String
    var label: String
    var selected: Bool = false

    var body: some View {
        VStack {
            Image(systemName: icon)
            Text(label)
                .font(.caption)
        }
        .foregroundColor(
            selected ? Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255) : .gray
        )
    }
}
