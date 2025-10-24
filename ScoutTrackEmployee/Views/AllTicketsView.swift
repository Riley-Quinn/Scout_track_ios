import SwiftUI

struct AllTicketsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedFilter: TicketFilter = .all
    @State private var showFilterSheet = false
    
    // Define available filters
    enum TicketFilter: String, CaseIterable {
        case all = "All"
        case open = "Open"
        case todo = "ToDo"
        case inProgress = "In-Progress"
        case done = "Done"
        case onHold = "On-Hold"
        case closed = "Closed"
        case pending = "Pending"
        case reopen = "Reopen"
        
        var displayName: String {
            return self.rawValue
        }
        
        var statusId: Int? {
            switch self {
            case .all: return nil
            case .open: return 1
            case .todo: return 2
            case .inProgress: return 3
            case .onHold: return 4
            case .pending: return 5
            case .done: return 6
            case .closed: return 7
            case .reopen: return 8
            }
        }
    }
    
    // Filter tickets based on selected filter
    var filteredTickets: [Ticket] {
        guard selectedFilter != .all else { return viewModel.tickets }
        
        return viewModel.tickets.filter { ticket in
            if let statusId = selectedFilter.statusId {
                return ticket.status_id == statusId
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("All Tickets")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                // Filter Button
                Button(action: {
                    showFilterSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18))
                        Text("Filter")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
            
            // Active Filter Display
            if selectedFilter != .all {
                HStack {
                    Text("Filtered by: \(selectedFilter.displayName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: {
                        selectedFilter = .all
                    }) {
                        HStack(spacing: 4) {
                            Text("Clear")
                                .font(.caption)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
            }

            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView("Loading tickets...")
                            .padding(.top, 40)
                    } else if filteredTickets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text(selectedFilter == .all ? "No tickets found" : "No tickets match the selected filter")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 60)
                    } else {
                        // Ticket Count
                        HStack {
                            Text("\(filteredTickets.count) ticket\(filteredTickets.count != 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredTickets) { ticket in
                                NavigationLink(destination: TicketDetailView(ticketId: ticket.ticket_id)) {
                                    TicketCard(
                                        ticket: ticket,
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
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .background(Color.white)
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $viewModel.showServiceUpdateSheet) {
            ServiceUpdateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditTicketSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSelectionSheet(selectedFilter: $selectedFilter, showSheet: $showFilterSheet)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.fetchAllTickets()
        }
    }
}

// Filter Selection Sheet
struct FilterSelectionSheet: View {
    @Binding var selectedFilter: AllTicketsView.TicketFilter
    @Binding var showSheet: Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Filter Tickets")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showSheet = false
                    }
                    .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                }
                .padding()
                
                Divider()
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AllTicketsView.TicketFilter.allCases, id: \.self) { filter in
                            FilterOptionButton(
                                filter: filter,
                                isSelected: selectedFilter == filter,
                                action: {
                                    selectedFilter = filter
                                    showSheet = false
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .background(Color.white)
        }
    }
}

// Individual Filter Button
struct FilterOptionButton: View {
    let filter: AllTicketsView.TicketFilter
    let isSelected: Bool
    let action: () -> Void
    
    var filterColor: Color {
        switch filter {
        case .all: return .gray
        case .open: return .blue
        case .todo: return .orange
        case .inProgress: return .blue
        case .done: return .green
        case .onHold: return .pink
        case .closed: return .gray
        case .pending: return .purple
        case .reopen: return .yellow
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255) : .gray)
                
                Text(filter.displayName)
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Circle()
                    .fill(filterColor)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? filterColor.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255) : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AllTicketsView_Previews: PreviewProvider {
    static var previews: some View {
        AllTicketsView(viewModel: DashboardViewModel())
    }
}