import SwiftUI

struct AllTicketsView: View {
    @ObservedObject var viewModel: DashboardViewModel // Reuse Dashboard's ViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("All Tickets")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))

            ScrollView {
                VStack(spacing: 16) {
                    // ✅ Tickets Section

                    if viewModel.isLoading {
                        ProgressView("Loading tickets...")
                    } else {
                        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.tickets) { ticket in
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
                        .frame(maxWidth: .infinity) // ✅ Important for full width
                    }
                }
                .padding()
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $viewModel.showServiceUpdateSheet) {
            ServiceUpdateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditTicketSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchAllTickets()
        }
    }
}

struct AllTicketsView_Previews: PreviewProvider {
    static var previews: some View {
        AllTicketsView(viewModel: DashboardViewModel()) // Pass dummy VM for preview
    }
}
