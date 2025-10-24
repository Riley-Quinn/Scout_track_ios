import Charts
import SwiftUI

struct DashboardView: View {
    @State private var navigateToAllTickets = false
    @StateObject private var viewModel = DashboardViewModel()
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
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
                        VStack(spacing: 8) {
                            // ✅ Status Grid
                            HStack(spacing: 12) {
                                StatusCard(title: "ToDo", count: viewModel.todoCount, color: .orange, icon: "exclamationmark.triangle")
                                StatusCard(title: "In Progress", count: viewModel.inProgressCount, color: .blue, icon: "shield")
                            }
                            HStack(spacing: 12) {
                                StatusCard(title: "Pending", count: viewModel.pendingCount, color: .purple, icon: "clock")
                                StatusCard(title: "On Hold", count: viewModel.onHoldCount, color: .pink, icon: "clock")
                            }

                            if !viewModel.pieChartData.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Ticket Status Distribution")
                                        .font(.headline)
                                        .padding(.top, 16)
                                        .padding(.horizontal, 4)
                                        .foregroundColor(.black)

                                    HStack(alignment: .top, spacing: 16) {
                                        PieChartView(data: viewModel.pieChartData)
                                            .frame(width: 150, height: 170)
                                            .padding(.leading, 4)

                                        // 📋 Scrollable Status Legend
                                        ScrollView(.vertical, showsIndicators: true) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ForEach(viewModel.pieChartData) { data in
                                                    HStack(spacing: 8) {
                                                        Circle()
                                                            .fill(data.color)
                                                            .frame(width: 12, height: 12)
                                                        Text("\(data.status) - \(Int(data.percentage * 100))%")
                                                            .font(.subheadline)
                                                            .foregroundColor(.black)
                                                        Spacer()
                                                        Text("(\(data.count))")
                                                            .font(.subheadline)
                                                            .foregroundColor(.black)
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .frame(height: 170) // Match pie chart height
                                    }
                                    .padding(.horizontal, 4) // ✅ Aligns with StatusCards
                                    .padding(.bottom, 8)
                                }
                            }
                            // ✅ Today Tickets Section
                            HStack {
                                Text("Today Tickets")
                                    .font(.headline)
                                    .padding(.horizontal, 4)
                                    .foregroundColor(.black)
                                Spacer()
                                Button("View All") {
                                    navigateToAllTickets = true
                                }
                                .font(.subheadline)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                            NavigationLink(destination: AllTicketsView(viewModel: viewModel), isActive: $navigateToAllTickets) {
                                EmptyView()
                            }
                            .hidden()

                            // ✅ Today Tickets Grid
                            if viewModel.isLoading {
                                ProgressView("Loading tickets...")
                            } else if viewModel.tickets.isEmpty {
                                Text("No ToDo tickets today")
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 4)
                            } else {
                                let columns: [GridItem] = Array(
                                    repeating: GridItem(.flexible(), spacing: 12),
                                    count: UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
                                )

                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(viewModel.tickets.prefix(6)) { ticket in
                                        NavigationLink(destination: TicketDetailView(ticketId: ticket.ticket_id)) {
                                            TicketCard(
                                                ticket: ticket,
                                                onAssign: { /* Logic */ },
                                                onSetArrival: { /* Logic */ },
                                                onStartWork: { viewModel.startWork(ticket: ticket) },
                                                onServiceUpdate: { viewModel.selectedTicket = ticket; viewModel.showServiceUpdateSheet = true },
                                                onEdit: { viewModel.selectedTicket = ticket; viewModel.showEditSheet = true }
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                    }

                    // Footer Tabs
                    Divider()
                        .padding(.vertical, 4)
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
                    .background(Color.white)
                }
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    viewModel.fetchTickets(onlyToday: true)
                    viewModel.fetchAllStatusCounts()
                }
                .sheet(isPresented: $viewModel.showServiceUpdateSheet) {
                    ServiceUpdateSheet(viewModel: viewModel)
                        .presentationDetents([.fraction(0.35)]) // partial height
                        .presentationDragIndicator(.visible)
                        .presentationBackground(Color.white) // makes full sheet background white
                }

                .sheet(isPresented: $viewModel.showEditSheet) {
                    EditTicketSheet(viewModel: viewModel)
                        .presentationDetents([.fraction(0.35)]) // partial height
                        .presentationDragIndicator(.visible)
                        .presentationBackground(Color.white)
                }
            }
        }
    }
}

struct BlinkingText: View {
    let text: String
    @State private var isVisible = true
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .opacity(isVisible ? 1 : 0) // Blink by changing opacity
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                ) {
                    isVisible.toggle()
                }
            }
    }
}

struct StatusPieData: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
    var percentage: Double
    let color: Color
}

// 🔹 Service Update Sheet
struct ServiceUpdateSheet: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Service Update")
                .font(.headline)
                .foregroundColor(.black)
            // Dropdown using Menu (text box style)
            Menu {
                ForEach(viewModel.serviceReasons, id: \.self) { reason in
                    Button(reason) {
                        viewModel.serviceReason = reason
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.serviceReason.isEmpty ? "Select Reason" : viewModel.serviceReason)
                        .foregroundColor(viewModel.serviceReason.isEmpty ? .gray : .black)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

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
                .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
}

// 🔹 Edit Status Sheet
struct EditTicketSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    var body: some View {
        VStack(spacing: 20) {
            Text("Update Ticket Status")
                .font(.headline)
                .foregroundColor(.black)
            Picker("Select Status", selection: $viewModel.editStatus) {
                ForEach(viewModel.editStatuses, id: \.self) { status in
                    Text(status).tag(status)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(
                Color(UIColor.systemGray5)
                    .cornerRadius(8)
            )
            .accentColor(.white) // This sets the color of the selected segment
            // Show reason only for On Hold or Pending
            if viewModel.editStatus == "On Hold" || viewModel.editStatus == "Pending" {
                TextField("Enter reason", text: $viewModel.editReason)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .background(Color.white)
            }
            HStack {
                Button("Cancel") { viewModel.showEditSheet = false }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                Button("Save") { viewModel.updateTicketStatus() }
                    .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                    ))
                    .disabled(viewModel.editStatus.isEmpty || ((viewModel.editStatus == "On Hold" || viewModel.editStatus == "Pending") && viewModel.editReason.isEmpty))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
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
                        .foregroundColor(.black)
                    Text("\(count)")
                        .font(.title)
                        .foregroundColor(.black)
                        .bold()
                }
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(color.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 4) { // Set spacing to 0 for tight layout
            // 🔹 Header
            HStack {
                Text(ticket.ticket_service_id ?? "Ticket #\(ticket.ticket_id)")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                if isToday(ticket.employee_arrival_date) && ticket.status_name.lowercased() == "todo" {
                    VStack(alignment: .trailing, spacing: 2) {
                        BlinkingText(text: formatDate(ticket.employee_arrival_date))
                        BlinkingText(text: formatTime(ticket.employee_arrival_time))
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDate(ticket.employee_arrival_date))
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                        Text(formatTime(ticket.employee_arrival_time))
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                    }
                }
                Text(ticket.status_name)
                    .font(.caption)
                    .padding(.horizontal, 8) // Reduced horizontal padding
                    .padding(.vertical, 2) // Reduced vertical padding
                    .background(statusColor(ticket.status_name))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4) // Reduced vertical padding
            .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
            .cornerRadius(12, corners: [.topLeft, .topRight])
            // 🔹 Body
            VStack(alignment: .leading, spacing: 6) { // reduced spacing between text elements
                Text(ticket.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                Text(ticket.description)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    HStack {
                        Text("Category:")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                        Text(ticket.category_name)
                            .bold()
                            .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                            )
                            .font(.system(size: 12))
                    }
                    Spacer()
                    HStack {
                        Text("Location:")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                        Text(ticket.region_name)
                            .bold()
                            .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                            )
                            .font(.system(size: 12))
                    }
                }
                .font(.subheadline)
                Divider()
                HStack {
                    // Customer Info on the left
                    Label("Customer: \(ticket.customer_name)", systemImage: "person")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer() // Pushes buttons to the right
                    // Status-based Actions on the right
                    if ticket.status_id == 1 {
                        Button("Assign to Me") { onAssign?() }
                            .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)))
                    } else if ticket.status_id == 2 {
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
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func isToday(_ dateString: String?) -> Bool {
        guard let dateString = dateString else {
            return false
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            let result = Calendar.current.isDateInToday(date)
            return result
        } else {
            return false
        }
    }

    private func formatTime(_ timeString: String?) -> String {
        guard let timeString = timeString else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm:ss"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        }
        return timeString
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, yyyy" // 👉 Example: Sep 20, 2025
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
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

struct PieSliceData {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    var percentage: Double
}

struct PieChartView: View {
    var data: [StatusPieData]

    private func calculateSlices() -> [PieSliceData] {
        var slices: [PieSliceData] = []
        var startAngle = Angle(degrees: 0)
        for item in data {
            let endAngle = startAngle + Angle(degrees: item.percentage * 360)
            slices.append(PieSliceData(startAngle: startAngle, endAngle: endAngle, color: item.color, percentage: item.percentage))
            startAngle = endAngle
        }
        return slices
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(calculateSlices().enumerated()), id: \.offset) { _, slice in
                    PieSliceView(slice: slice)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.5)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct PieSliceView: View {
    var slice: PieSliceData

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: min(geometry.size.width, geometry.size.height) / 2,
                    startAngle: slice.startAngle,
                    endAngle: slice.endAngle,
                    clockwise: false
                )
            }
            .fill(slice.color)
        }
    }
}
