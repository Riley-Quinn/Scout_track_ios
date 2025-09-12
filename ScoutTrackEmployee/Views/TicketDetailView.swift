import Combine
import CoreData
import CoreLocation
import Foundation
import Network
import Photos
import SwiftUI
import UIKit

// MARK: - Model

struct LocalTicket: Codable, Identifiable {
    var id: Int { ticket_id }
    let ticket_id: Int
    let ticket_service_id: String
    let description: String
    let status_name: String
    let priority_rank: String?
    let category_name: String
    let created_at: String
    let customer_name: String
    let customer_email: String?
    let customer_phone: String
    let region_name: String
    let address: String
    let state_name: String?
    let city_name: String?
    let address_type: String?
    let multimedia: [Multimedia]?
    let status_tracker: String?
    let customer_comments: String?
    let customer_type: String?
    let customer_division: String?
    let title: String
    let employee_arrival_date: String?
    let status_id: Int
}

final class PhotoAlbumManager {
    static let shared = PhotoAlbumManager()

    func saveImage(_ image: UIImage, ticketId: Int, completion: @escaping (Bool, PHAsset?) -> Void) {
        let albumName = "Ticket_\(ticketId)"
        print("📌 [PhotoAlbumManager] Saving image to album: \(albumName)")

        func createAlbumIfNeeded(albumName: String, completion: @escaping (PHAssetCollection?) -> Void) {
            let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            var album: PHAssetCollection?
            fetch.enumerateObjects { collection, _, stop in
                if collection.localizedTitle == albumName {
                    album = collection
                    stop.pointee = true
                }
            }

            if let album = album {
                print("✅ [PhotoAlbumManager] Album exists: \(album.localizedTitle ?? "")")
                completion(album)
            } else {
                print("⚠️ [PhotoAlbumManager] Album not found. Creating...")
                var albumPlaceholder: PHObjectPlaceholder?
                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    albumPlaceholder = request.placeholderForCreatedAssetCollection
                }) { _, error in
                    if let error = error {
                        print("❌ [PhotoAlbumManager] Failed to create album: \(error.localizedDescription)")
                        completion(nil)
                    } else {
                        print("✅ [PhotoAlbumManager] Album created successfully")
                        if let placeholder = albumPlaceholder {
                            let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                            completion(fetchResult.firstObject)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        }

        createAlbumIfNeeded(albumName: albumName) { album in
            guard let album = album else { print("❌ [PhotoAlbumManager] Album unavailable"); completion(false, nil); return }

            var assetPlaceholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                assetPlaceholder = creationRequest.placeholderForCreatedAsset
                if let albumChange = PHAssetCollectionChangeRequest(for: album),
                   let placeholder = assetPlaceholder
                {
                    albumChange.addAssets([placeholder] as NSArray)
                }
            }) { success, error in
                if let error = error { print("❌ [PhotoAlbumManager] Failed to save image: \(error.localizedDescription)") }
                print("📌 [PhotoAlbumManager] Image save success: \(success)")
                completion(success, assetPlaceholder.flatMap { PHAsset.fetchAssets(withLocalIdentifiers: [$0.localIdentifier], options: nil).firstObject })
            }
        }
    }

    func deleteImage(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            if let error = error { print("❌ [PhotoAlbumManager] Failed to delete asset: \(error.localizedDescription)") }
            print("📌 [PhotoAlbumManager] Delete success: \(success)")
            completion(success)
        }
    }
}

final class CoreDataManager {
    static let shared = CoreDataManager()
    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData load error: \(error)") }
        }
    }

    var context: NSManagedObjectContext { container.viewContext }

    // MARK: - Save ticket

    func save(ticket: TicketDetail) {
        let fetch: NSFetchRequest<CDTicket> = CDTicket.fetchRequest()
        fetch.predicate = NSPredicate(format: "ticketId == %d", ticket.ticket_id)

        let cdTicket: CDTicket
        if let existing = try? context.fetch(fetch).first {
            cdTicket = existing
        } else {
            cdTicket = CDTicket(context: context)
        }

        cdTicket.ticketId = Int32(ticket.ticket_id)
        cdTicket.ticketServiceId = ticket.ticket_service_id
        cdTicket.ticketDescription = ticket.description
        cdTicket.statusName = ticket.status_name
        cdTicket.priorityRank = ticket.priority_rank
        cdTicket.categoryName = ticket.category_name
        cdTicket.createdAt = ticket.created_at
        cdTicket.customerName = ticket.customer_name
        cdTicket.customerEmail = ticket.customer_email
        cdTicket.customerPhone = ticket.customer_phone
        cdTicket.regionName = ticket.region_name
        cdTicket.address = ticket.address
        cdTicket.stateName = ticket.state_name
        cdTicket.cityName = ticket.city_name
        cdTicket.addressType = ticket.address_type
        cdTicket.title = ticket.title
        cdTicket.employeeArrivalDate = ticket.employee_arrival_date
        cdTicket.multimediaData = try? JSONEncoder().encode(ticket.multimedia)
        cdTicket.statusTrackerData = ticket.status_tracker?.data(using: .utf8)
        cdTicket.customerCommentsData = ticket.customer_comments?.data(using: .utf8)
        cdTicket.status_id = Int64(ticket.status_id)
        // cdTicket.customerCommentsData = try? JSONEncoder().encode(ticket.customer_comments)
        try? context.save()
    }

    // MARK: - Load ticket

    func load(ticketId: Int) -> TicketDetail? {
        let fetch: NSFetchRequest<CDTicket> = CDTicket.fetchRequest()
        fetch.predicate = NSPredicate(format: "ticketId == %d", ticketId)
        guard let cdTicket = try? context.fetch(fetch).first else { return nil }

        return TicketDetail(
            ticket_id: Int(cdTicket.ticketId),
            ticket_service_id: cdTicket.ticketServiceId ?? "",
            description: cdTicket.ticketDescription ?? "",
            status_name: cdTicket.statusName ?? "",
            priority_rank: cdTicket.priorityRank,
            category_name: cdTicket.categoryName ?? "",
            created_at: cdTicket.createdAt ?? "",
            customer_name: cdTicket.customerName ?? "",
            customer_email: cdTicket.customerEmail,
            customer_phone: cdTicket.customerPhone ?? "",
            region_name: cdTicket.regionName ?? "",
            address: cdTicket.address ?? "",
            state_name: cdTicket.stateName,
            city_name: cdTicket.cityName,
            address_type: cdTicket.addressType,
            title: cdTicket.title ?? "",
            multimedia: (cdTicket.multimediaData != nil ? try? JSONDecoder().decode([Multimedia].self, from: cdTicket.multimediaData!) : nil),
            status_tracker: cdTicket.statusTrackerData.flatMap { String(data: $0, encoding: .utf8) },
            customer_comments: cdTicket.customerCommentsData.flatMap { String(data: $0, encoding: .utf8) },
            customer_type: nil,
            customer_division: nil,
            employee_arrival_date: cdTicket.employeeArrivalDate ?? "",
            status_id: Int(Int64(cdTicket.status_id))
        )
    }

    func loadAllTickets() -> [TicketDetail] {
        let fetch: NSFetchRequest<CDTicket> = CDTicket.fetchRequest()
        guard let results = try? context.fetch(fetch) else { return [] }
        return results.compactMap { load(ticketId: Int($0.ticketId)) }
    }
}

class TicketListViewModel: ObservableObject {
    @Published var tickets: [TicketDetail] = []
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    let baseURL = "http://localhost:4200"

    func fetchAllTickets() {
        isLoading = true
        guard let url = URL(string: "\(baseURL)/api/tickets") else { return }

        if NetworkMonitor.shared.isConnected {
            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: [TicketDetail].self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink { _ in self.isLoading = false } receiveValue: { tickets in
                    self.tickets = tickets
                    tickets.forEach { CoreDataManager.shared.save(ticket: $0) }
                }
                .store(in: &cancellables)
        } else {
            tickets = CoreDataManager.shared.loadAllTickets()
            isLoading = false
        }
    }
}

struct TicketListView: View {
    @StateObject private var viewModel = TicketListViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.tickets) { ticket in
                NavigationLink(destination: TicketDetailView(ticketId: ticket.ticket_id)) {
                    VStack(alignment: .leading) {
                        Text("#\(ticket.ticket_service_id)").bold()
                        Text(ticket.description).font(.subheadline).foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Tickets")
            .onAppear {
                viewModel.fetchAllTickets()
            }
        }
    }
}

extension TicketDetail: Identifiable {
    var id: Int { ticket_id }
}

extension String: Identifiable {
    public var id: String { self }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension Notification.Name {
    static let syncStatusChanged = Notification.Name("syncStatusChanged")
}

struct TicketDetailResponse: Decodable {
    let list: TicketDetail?
}

struct Multimedia: Codable {
    let file_name: String
    let file_type: String
    let file_path: String
    let multimedia_id: Int
    let media_stage: String?
    let uploaded_by: Int
    let longitude: String
    let latitude: String
}

struct TicketDetail: Codable {
    let ticket_id: Int
    let ticket_service_id: String
    let description: String
    let status_name: String
    let priority_rank: String?
    let category_name: String
    let created_at: String
    let customer_name: String
    let customer_email: String?
    let customer_phone: String
    let region_name: String
    let address: String
    let state_name: String?
    let city_name: String?
    let address_type: String?
    let title: String
    let multimedia: [Multimedia]?
    let status_tracker: String?
    let customer_comments: String?
    let customer_type: String?
    let customer_division: String?
    let employee_arrival_date: String
    var employee_pre_uploads: [Multimedia] {
        multimedia?.filter { ($0.media_stage ?? "").lowercased() == "pre" } ?? []
    }

    var employee_post_uploads: [Multimedia] {
        multimedia?.filter { ($0.media_stage ?? "").lowercased() == "post" } ?? []
    }

    var customer_uploads: [Multimedia] {
        multimedia?.filter { ($0.media_stage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    let status_id: Int
}

struct StatusTracker: Decodable {
    let message: String
    let status: String
    let changedBy: String?
    let employeeName: String?
    let employeePhone: String?
    let Date: String?
    let timestamp: String?
}

struct CustomerCommentWrapper: Codable {
    let message: CustomerComment
}

struct CustomerComment: Codable, Identifiable {
    let id: String
    let text: String
    let sender_id: String
    let sender_role: String
    let sender_name: String
    let date: String
}

// MARK: - ViewModel

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published private(set) var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}

class TicketDetailViewModel: ObservableObject {
    @Published var ticket: TicketDetail?
    @Published var history: [StatusTracker] = []
    @Published var chatMessages: [CustomerComment] = []
    @Published var isLoading = false
    @Published var refreshFlag = false
    @Published var isUploading = false
    private var cancellables = Set<AnyCancellable>()
    let baseURL = "http://localhost:4200"
    private var userId: String {
        UserDefaults.standard.string(forKey: "userId") ?? "0"
    }

    // keep location manager alive
    private let locationManager = LocationManager()
    func getLocalUploads() -> [LocalUpload] {
        return UploadStore.shared.getAll()
            .filter { $0.ticketId == ticket?.ticket_id }
    }

    func fetchTicketDetail(ticketId: Int) {
        isLoading = true
        if NetworkMonitor.shared.isConnected {
            guard let url = URL(string: "\(baseURL)/api/tickets/\(ticketId)") else { return }
            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: TicketDetailResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    self.isLoading = false
                    if case let .failure(error) = completion {
                        self.loadTicketFromCache(ticketId: ticketId)
                    }
                }) { [weak self] response in
                    guard let self = self else { return }

                    guard let ticket = response.list else {
                        self.loadTicketFromCache(ticketId: ticketId)
                        self.isLoading = false
                        return
                    }

                    self.ticket = ticket

                    CoreDataManager.shared.save(ticket: ticket)

                    // Decode status tracker JSON
                    if let jsonData = ticket.status_tracker?.data(using: .utf8) {
                        self.history = (try? JSONDecoder().decode([StatusTracker].self, from: jsonData)) ?? []
                    } else {
                        self.history = []
                    }

                    // Decode customer comments JSON
                    if let jsonData = ticket.customer_comments?.data(using: .utf8) {
                        let wrapper = (try? JSONDecoder().decode([CustomerCommentWrapper].self, from: jsonData)) ?? []
                        self.chatMessages = wrapper.map { $0.message }
                    } else {
                        self.chatMessages = []
                    }

                    // Optional: Pretty print JSON for debugging
                    do {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                        let jsonData = try encoder.encode(ticket)

                    } catch {}

                    self.isLoading = false
                }
                .store(in: &cancellables)

        } else {
            // Offline mode → load from local Core Data
            loadTicketFromCache(ticketId: ticketId)
        }
    }

    // Helper to load from Core Data and decode history & comments
    private func loadTicketFromCache(ticketId: Int) {
        guard let cached = CoreDataManager.shared.load(ticketId: ticketId) else {
            ticket = nil
            history = []
            chatMessages = []
            return
        }

        ticket = cached

        if let jsonData = cached.status_tracker?.data(using: .utf8) {
            history = (try? JSONDecoder().decode([StatusTracker].self, from: jsonData)) ?? []
        } else {
            history = []
        }

        if let jsonData = cached.customer_comments?.data(using: .utf8) {
            let wrapper = (try? JSONDecoder().decode([CustomerCommentWrapper].self, from: jsonData)) ?? []
            chatMessages = wrapper.map { $0.message }
        } else {
            chatMessages = []
        }

        print("📦 Loaded ticket \(ticketId) from CoreData with \(cached.multimedia?.count ?? 0) media items")
        isLoading = false
    }

    func uploadImage(_ image: UIImage, type: String, completion: @escaping () -> Void) {
        guard let ticketId = ticket?.ticket_id else { return }

        isUploading = true // 👈 Start loading indicator

        locationManager.requestLocation { [weak self] coordinates in
            guard let self = self else { return }
            let latitude = coordinates?.latitude ?? 0
            let longitude = coordinates?.longitude ?? 0

            if NetworkMonitor.shared.isConnected {
                self.performUpload(image: image, ticketId: ticketId, type: type, latitude: latitude, longitude: longitude) {
                    DispatchQueue.main.async {
                        self.isUploading = false // 👈 Stop after upload finishes
                        completion()
                    }
                }
            } else {
                self.uploadImageOffline(image: image, type: type, latitude: latitude, longitude: longitude)
                DispatchQueue.main.async {
                    self.isUploading = false // 👈 Stop after offline save
                    completion()
                }
            }
        }
    }

    private func uploadImageData(
        _ data: Data,
        ticketId: Int,
        type: String,
        latitude: Double,
        longitude: Double
    ) {
        guard let uiImage = UIImage(data: data) else { return }

        performUpload(
            image: uiImage,
            ticketId: ticketId,
            type: type,
            latitude: latitude,
            longitude: longitude
        ) {
            print("✅ Image data uploaded successfully: \(type)")
        }
    }

    private func uploadImageOffline(image: UIImage, type: String, latitude: Double, longitude: Double) {
        guard let ticketId = ticket?.ticket_id else { return }
        print("📌 [TicketDetailViewModel] Starting offline upload for ticket: \(ticketId), type: \(type)")

        PhotoAlbumManager.shared.saveImage(image, ticketId: ticketId) { success, asset in
            guard success, let asset = asset else {
                print("❌ [TicketDetailViewModel] Offline image save failed")
                return
            }
            print("✅ [TicketDetailViewModel] Image saved offline, asset id: \(asset.localIdentifier)")

            // Save local upload record (mark as pending)
            let localUpload = LocalUpload(
                ticketId: ticketId,
                localFilePath: asset.localIdentifier, // PHAsset identifier
                mediaStage: type,
                latitude: latitude,
                longitude: longitude,
                uploadedBy: self.userId,
                offlineEmployeeId: self.userId,
                syncStatus: .pending
            )
            UploadStore.shared.add(localUpload)

            // Notify UI (sync icon will show as pending ⏳)
            NotificationCenter.default.post(name: .syncStatusChanged, object: nil)

            // ❌ Removed immediate upload logic
            // Upload will be retried later by retryPendingUploads()
        }
    }

    private func performUpload(image: UIImage,
                               ticketId: Int,
                               type: String,
                               latitude: Double,
                               longitude: Double,
                               completion: @escaping () -> Void)
    {
        guard let url = URL(string: "\(baseURL)/api/employee-uploads") else {
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        // Some servers expect `ticket_id` instead of `ticket`
        let fields: [String: String] = [
            "ticket_id": "\(ticketId)",
            "ticket": "\(ticketId)",
            "media_stage": type,
            "latitude": "\(latitude)",
            "longitude": "\(longitude)",
            "uploaded_by": userId,
        ]

        var body = Data()
        let lb = "\r\n"

        // text fields
        for (key, value) in fields {
            body.append("--\(boundary)\(lb)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lb)\(lb)")
            body.append("\(value)\(lb)")
        }

        // file
        body.append("--\(boundary)\(lb)")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\(lb)")
        body.append("Content-Type: image/jpeg\(lb)\(lb)")
        body.append(imageData)
        body.append(lb)

        // close
        body.append("--\(boundary)--\(lb)")

        request.httpBody = body

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) {
                DispatchQueue.main.async {
                    // ✅ Just refresh ticket details so UI shows server images
                    self.fetchTicketDetail(ticketId: ticketId)

                    NotificationCenter.default.post(name: .syncStatusChanged, object: nil)
                    completion()
                }
            } else {
                // Optionally log server error
                if let data = data, !data.isEmpty {
                    let text = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                    print("Upload failed response:", text)
                }
                DispatchQueue.main.async {
                    completion()
                }
            }
        }.resume()
    }

    func retryPendingUploads() {
        let items = UploadStore.shared.getAll()
            .filter { $0.syncStatus == .pending || $0.syncStatus == .failed }

        for upload in items {
            // Fetch PHAsset instead of treating path as file
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localFilePath], options: nil)
            guard let asset = fetchResult.firstObject else {
                print("❌ No PHAsset found for id \(upload.localFilePath)")
                UploadStore.shared.markAsFailed(upload)
                continue
            }

            // Request UIImage from PHAsset
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            PHImageManager.default().requestImageData(for: asset, options: options) { data, _, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    self.performUpload(
                        image: image,
                        ticketId: upload.ticketId,
                        type: upload.mediaStage,
                        latitude: upload.latitude,
                        longitude: upload.longitude
                    ) {
                        // ✅ Mark as synced in local DB
                        UploadStore.shared.markAsSynced(upload)

                        // ✅ Delete the actual photo from gallery
                        PhotoAlbumManager.shared.deleteImage(asset) { success in
                            print(success ? "🗑️ Deleted asset from gallery" : "❌ Failed to delete asset")
                        }

                        self.fetchTicketDetail(ticketId: upload.ticketId)
                    }
                } else {
                    print("❌ Could not read image data from asset")
                    UploadStore.shared.markAsFailed(upload)
                }
            }
        }
    }

    func sendMessage(ticketId: Int, message: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tickets/\(ticketId)") else {
            completion(false)
            return
        }

        // 1. Start with the existing chat messages
        var updatedMessages = chatMessages

        // 2. Create a new message
        let newMsg = CustomerComment(
            id: UUID().uuidString,
            text: message,
            sender_id: userId,
            sender_role: "employee",
            sender_name: "Me",
            date: ISO8601DateFormatter().string(from: Date())
        )
        updatedMessages.append(newMsg)

        // 3. Encode the chat payload
        let wrappedMessages = updatedMessages.map { CustomerCommentWrapper(message: $0) }
        guard let encoded = try? JSONEncoder().encode(wrappedMessages),
              let jsonString = String(data: encoded, encoding: .utf8)
        else {
            completion(false)
            return
        }

        let ticketData: [String: Any] = [
            "customer_comments": jsonString,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["ticketData": ticketData])

        // 4. Perform API call
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Update the local messages so UI refreshes instantly
                    self.chatMessages = updatedMessages
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - View

struct TicketDetailView: View {
    let ticketId: Int
    @StateObject private var viewModel = TicketDetailViewModel()
    @StateObject private var viewModelticket = DashboardViewModel()
    @State private var showCustomerDetails = false
    @State private var isUploading = false
    @State private var showUploadDialog = false
    @State private var uploadType: String?
    @State private var isCamera = false
    @State private var pickedImage: UIImage?
    @State private var showImagePicker = false
    @State private var newMessage: String = ""
    @State private var showArrivalSheet = false
    @State private var arrivalDate = Date()
    @State private var arrivalReason = ""
    @State private var selectedTicketForArrival: Ticket? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading Ticket...")
                } else if let ticket = viewModel.ticket {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            TicketHeader(ticket: ticket)
                            // Ticket Info
                            TicketInfo(ticket: ticket)
                            // Customer Info with clickable map address
                            CustomerInfoView(ticket: ticket,
                                             showCustomerDetails: $showCustomerDetails,
                                             openInMaps: openInMaps,
                                             viewModelticket: viewModelticket)

                            // Customer Uploads
                            SectionHeader(title: "Customer Uploads")
                            UploadsGrid(
                                serverMedia: ticket.customer_uploads,
                                localMedia: viewModel.getLocalUploads().filter { $0.mediaStage == nil }
                            )

                            // Employee Uploads
                            SectionHeader(title: "Employee Uploads")
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Pre Uploads", showPlus: true)
                                    .onTapGesture { uploadType = "pre"; showUploadDialog = true }
                                UploadsGrid(
                                    serverMedia: ticket.employee_pre_uploads,
                                    localMedia: viewModel.getLocalUploads().filter { $0.mediaStage == "pre" }
                                )

                                SectionHeader(title: "Post Uploads", showPlus: true)
                                    .onTapGesture { uploadType = "post"; showUploadDialog = true }
                                UploadsGrid(
                                    serverMedia: ticket.employee_post_uploads,
                                    localMedia: viewModel.getLocalUploads().filter { $0.mediaStage == "post" }
                                )
                            }.padding(.horizontal)
                            Button("Retry Pending Uploads") {
                                viewModel.retryPendingUploads()
                            }
                            SectionHeader(title: "History")
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(viewModel.history.enumerated()), id: \.offset) { index, item in
                                        HistoryRow(status: item.message,
                                                   employee: item.employeeName ?? (item.changedBy ?? ""),
                                                   time: item.Date ?? item.timestamp ?? "",
                                                   isLast: index == viewModel.history.count - 1)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 350) // allows scrolling if content exceeds 350

                            // Chat
                            if ["in-progress", "on-hold", "pending"].contains(ticket.status_name.lowercased()) {
                                SectionHeader(title: "Chat with customer", showClose: true)

                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(viewModel.chatMessages, id: \.id) { msg in
                                        ChatBubble(text: msg.text,
                                                   time: msg.date,
                                                   isSender: msg.sender_role == "employee")
                                    }
                                }
                                .padding(.horizontal)

                                HStack {
                                    TextField("Type your message...", text: $newMessage)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())

                                    Button("Send") {
                                        let text = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !text.isEmpty else { return }
                                        viewModel.sendMessage(ticketId: ticketId, message: text) { success in
                                            if success {
                                                newMessage = ""
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(newMessage.isEmpty ? Color.gray : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .disabled(newMessage.isEmpty)
                                }
                                .padding()
                            }
                        }
                    }
                } else {
                    Text("No Ticket Found")
                }
            }
            .onAppear {
                viewModel.fetchTicketDetail(ticketId: ticketId)
                viewModel.retryPendingUploads()
            }
            .confirmationDialog("Choose Upload Option", isPresented: $showUploadDialog) {
                Button("Camera") {
                    isCamera = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showImagePicker = true }
                }
                Button("Gallery") {
                    isCamera = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showImagePicker = true }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: isCamera ? .camera : .photoLibrary, selectedImage: $pickedImage)
            }
            .onChange(of: pickedImage) { newImage in
                if let img = newImage, let type = uploadType {
                    viewModel.uploadImage(img, type: type) {
                        viewModel.fetchTicketDetail(ticketId: ticketId)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .syncStatusChanged)) { _ in
                viewModel.refreshFlag.toggle()
            }

            // This is inside the ZStack now
            if viewModel.isUploading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Uploading...")
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        // Both sheets stay attached to ZStack root
        .sheet(isPresented: $viewModelticket.showArrivalSheet) {
            ArrivalDateSheetTicket(viewModel: viewModelticket)
        }
        .sheet(isPresented: $viewModelticket.showServiceUpdateSheet) {
            ServiceUpdateSheetTicket(viewModel: viewModelticket)
        }
        .sheet(isPresented: $viewModelticket.showEditSheet) {
            EditTicketSheetTicket(viewModel: viewModelticket)
        }
    }
}

struct ArrivalDateSheetTicket: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Arrival Date & Time")
                .font(.headline)

            DatePicker("Arrival Date & Time", selection: $viewModel.arrivalDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()

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
                    .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                    ))
            }
        }
        .padding()
    }
}

struct ServiceUpdateSheetTicket: View {
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
                .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                ))
            }
        }
        .padding()
    }
}

struct EditTicketSheetTicket: View {
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
                    .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)
                    ))
                    .disabled(viewModel.editStatus.isEmpty || ((viewModel.editStatus == "On Hold" || viewModel.editStatus == "Pending") && viewModel.editReason.isEmpty))
            }
        }
        .padding()
    }
}

struct TicketActionButtons: View {
    let ticket: TicketDetail
    @ObservedObject var viewModelticket: DashboardViewModel
    var onSetArrival: (() -> Void)?
    var onStartWork: (() -> Void)?
    var onServiceUpdate: (() -> Void)?
    var onEdit: (() -> Void)?
    var body: some View {
        HStack(spacing: 12) {
            if ticket.status_id == 1 {
                Button("Assign to Me") {
                    // Handle Assign action here
                }
                .buttonStyle(ActionButtonStyle(color: Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255)))
            } else if ticket.status_id == 2 {
                Button("Arrival Date") { onSetArrival?() }

                    .buttonStyle(ActionButtonStyle(color: .orange))

                if !ticket.employee_arrival_date.isEmpty {
                    Button("Start") { onStartWork?() }
                        .buttonStyle(ActionButtonStyle(color: .blue))
                }
            } else if ticket.status_id == 3 {
                Button("Service Update") { onServiceUpdate?() }
                    .buttonStyle(ActionButtonStyle(color: .purple))

                Button("Edit") { onEdit?() }
                    .buttonStyle(ActionButtonStyle(color: .pink))
            }
            Spacer() // Push buttons to the left
        }
    }
}

struct TicketHeader: View {
    let ticket: TicketDetail
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(ticket.title).font(.headline).foregroundColor(.white)
                Spacer()
                Text(ticket.status_name)
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColor(ticket.status_name)).cornerRadius(10).foregroundColor(.white)
            }
        }
        .padding()
        .background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
        .ignoresSafeArea(edges: .top)
    }
}

struct TicketInfo: View {
    let ticket: TicketDetail
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("#\(ticket.ticket_service_id)").font(.subheadline).fontWeight(.semibold)
            Text(ticket.description).font(.body).foregroundColor(.gray)
        }.padding(.horizontal)
    }
}

struct CustomerInfoView: View {
    let ticket: TicketDetail
    @Binding var showCustomerDetails: Bool
    var openInMaps: (String) -> Void
    @ObservedObject var viewModelticket: DashboardViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Customer / Company
            HStack(alignment: .top) {
                Image(systemName: "person")
                    .foregroundColor(.gray)
                    .frame(width: 24) // fixed width for alignment
                Text("Customer")
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading) // fixed width for labels
                Text(" : \(ticket.customer_name ?? "")")
                    .font(.subheadline)
                Spacer()
                Button("Details") { showCustomerDetails = true }
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Priority
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                Text("Priority")
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)
                Text(": \(ticket.priority_rank ?? "NA")")
                    .font(.subheadline)
                    .foregroundColor(.red)
                Spacer()
            }

            // Category
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                Text("Category")
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)
                Text(" : \(ticket.category_name)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                Spacer()
            }

            // Created on
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                    .frame(width: 24)

                Text("Created")
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)

                Text(": \(ticket.created_at.split(separator: "T").first ?? "")")
                    .font(.subheadline)

                Spacer()
            }

            // Location
            HStack(alignment: .top) {
                Image(systemName: "map.fill")
                    .foregroundColor(.gray)
                    .frame(width: 24)
                Text("Location")
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(" : \(ticket.region_name)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255))
                    Text("View on Google Maps")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .onTapGesture {
                            let fullAddress = "\(ticket.address), \(ticket.city_name ?? ""), \(ticket.state_name ?? ""), \(ticket.region_name)"
                            openInMaps(fullAddress)
                        }
                }
                Spacer()
            }
            TicketActionButtons(
                ticket: ticket,
                viewModelticket: viewModelticket,
                onSetArrival: {
                    viewModelticket.selectedTicket = Ticket(from: ticket)
                    viewModelticket.arrivalDate = Date()
                    viewModelticket.showArrivalSheet = true
                },
                onStartWork: { viewModelticket.selectedTicket = Ticket(from: ticket) },
                onServiceUpdate: {
                    viewModelticket.selectedTicket = Ticket(from: ticket)
                    viewModelticket.showServiceUpdateSheet = true
                },
                onEdit: {
                    viewModelticket.selectedTicket = Ticket(from: ticket)
                    viewModelticket.editStatus = ""
                    viewModelticket.editReason = ""
                    viewModelticket.showEditSheet = true
                }
            )
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.gray.opacity(0.2), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showCustomerDetails) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with title and Close button
                HStack {
                    Text(ticket.customer_type?.lowercased() == "company" ? "Company Details" : "Customer Details")
                        .font(.headline)
                    Spacer()
                    Button("Close") { showCustomerDetails = false }
                }
                Divider()

                // Details Section
                TicketDetailSection(ticket: ticket)
                    .font(.subheadline)
                Spacer()
            }
            .padding()
        }
    }
}

struct TicketDetailSection: View {
    let ticket: TicketDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailRow(label: "Name", value: ticket.customer_name)
            DetailRow(label: "Email", value: ticket.customer_email ?? "N/A")
            DetailRow(label: "Phone", value: ticket.customer_phone)
            if ticket.customer_type?.lowercased() == "company" {
                DetailRow(label: "Division", value: ticket.customer_division ?? "N/A")
            }
            DetailRow(label: "State", value: ticket.state_name ?? "N/A")
            DetailRow(label: "City", value: ticket.city_name ?? "N/A")
            DetailRow(label: "Region", value: ticket.region_name)
            DetailRow(label: "Address Type", value: ticket.address_type ?? "N/A")
            DetailRow(label: "Address", value: ticket.address)
        }
    }
}

// MARK: - Helper Views and Functions

func statusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "todo", "to do": return .orange
    case "in-progress", "in progress": return .blue
    case "on-hold", "on hold": return .pink
    case "pending", "open": return .purple
    case "done", "completed": return .green
    default: return .gray
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .leading)
            Text(":  \(value)")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct UploadsGrid: View {
    var serverMedia: [Multimedia]
    var localMedia: [LocalUpload]
    @State private var addresses: [Int: String] = [:]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
            // 🔹 Server media
            ForEach(serverMedia, id: \.multimedia_id) { media in
                RemoteImageView(url: media.file_name)
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
            }

            // 🔹 Local offline uploads
            ForEach(localMedia) { local in
                ZStack(alignment: .topTrailing) {
                    if let uiImage = UIImage(contentsOfFile: local.localFilePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }

                    // 🔹 Status overlay
                    Group {
                        if local.syncStatus == .pending {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.yellow)
                        } else if local.syncStatus == .failed {
                            // Retry button
                            Button(action: {
                                UploadStore.shared.retryUpload(local)
                            }) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                }

                Text(local.mediaStage.capitalized)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical)
    }
}

struct SectionHeader: View {
    var title: String
    var showPlus: Bool = false
    var showClose: Bool = false
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if showPlus { Image(systemName: "plus.circle.fill").foregroundColor(.green) }
            if showClose { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
        }
        .padding().background(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255).opacity(0.9))
        .foregroundColor(.white)
    }
}

struct HistoryRow: View {
    var status: String
    var employee: String
    var time: String
    var isLast: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Circle().fill(Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255).opacity(0.9))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status).font(.subheadline).bold()
                    Text(employee).font(.caption)
                    Text(time).font(.caption2).foregroundColor(.gray)
                }
            }
            if !isLast { Divider() }
        }
    }
}

struct ChatBubble: View {
    var text: String
    var time: String
    var isSender: Bool
    var body: some View {
        HStack(alignment: .bottom) {
            if isSender { Spacer() }
            VStack(alignment: isSender ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding()
                    .background(isSender ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(12)
                Text(time).font(.caption2).foregroundColor(.gray)
            }
            if !isSender { Spacer() }
        }
    }
}

func openInMaps(address: String) {
    // Encode the address for URL
    let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let googleURL = URL(string: "comgooglemaps://?q=\(query)"),
       UIApplication.shared.canOpenURL(googleURL)
    {
        UIApplication.shared.open(googleURL)
        return
    }
    if let appleURL = URL(string: "http://maps.apple.com/?q=\(query)") {
        UIApplication.shared.open(appleURL)
    }
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Request single-shot location. Completion will be called once (or nil on failure).
    func requestLocation(_ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion

        // If authorization not determined, request it. The delegate will handle subsequent requestLocation.
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // requestLocation will be triggered from authorization change delegate if granted.
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            // if denied/restricted, return nil but still attempt to call completion to allow upload fallback
            completion(nil)
            self.completion = nil
        }
    }

    // Delegate: got locations
    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.first?.coordinate else {
            completion?(nil)
            completion = nil
            return
        }
        completion?(coord)
        completion = nil
    }

    // Delegate: failed
    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        completion?(nil)
        completion = nil
    }

    // Called when authorization changes (iOS 14+)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // If someone requested location, go get it
            if completion != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            // Immediately return nil if denied
            completion?(nil)
            completion = nil
        case .notDetermined:
            break
        @unknown default:
            completion?(nil)
            completion = nil
        }
    }
}

struct RemoteImageView: View {
    let url: String
    private let baseURL = "https://d3shribgms6bz4.cloudfront.net/"

    var body: some View {
        AsyncImage(
            url: URL(string: url.hasPrefix("http") ? url : baseURL + url)
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ProgressView()
        }
        .onAppear {}
    }
}
