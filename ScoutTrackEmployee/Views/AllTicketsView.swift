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
                    HStack {
                        Text("Today Tickets")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)

                    if viewModel.isLoading {
                        ProgressView("Loading tickets...")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.tickets) { ticket in
                                NavigationLink(destination: TicketDetailView(ticketId: ticket.ticket_id)) {
                                    TicketCard(
                                        ticket: ticket,
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
        }
        .edgesIgnoringSafeArea(.bottom)
        // Reuse the same sheets from Dashboard
        .sheet(isPresented: $viewModel.showArrivalSheet) {
            ArrivalDateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showServiceUpdateSheet) {
            ServiceUpdateSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditTicketSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchTickets()
        }
    }
}

struct AllTicketsView_Previews: PreviewProvider {
    static var previews: some View {
        AllTicketsView(viewModel: DashboardViewModel()) // Pass dummy VM for preview
    }
}
