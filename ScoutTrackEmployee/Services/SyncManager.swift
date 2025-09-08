import Foundation
import UIKit

class SyncManager {
    static let shared = SyncManager()
    private var isSyncing = false

    private init() {}

    func startSync() {
        guard !isSyncing else { return }
        isSyncing = true

        let pendingUploads = UploadStore.shared.pending
        print("🔄 Found \(pendingUploads.count) pending uploads")

        for upload in pendingUploads {
            uploadToServer(upload) { success in
                if success {
                    UploadStore.shared.markAsSynced(upload)
                } else {
                    UploadStore.shared.markAsFailed(upload)
                }
            }
        }

        isSyncing = false
    }

    private func uploadToServer(_ upload: LocalUpload, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "http://localhost:4200/api/employee-uploads")! // replace with your backend

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // multipart form
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        append("ticket_id", "\(upload.ticketId)")
        append("uploaded_by", upload.uploadedBy)
        append("media_stage", upload.mediaStage)
        append("latitude", "\(upload.latitude)")
        append("longitude", "\(upload.longitude)")
        append("offline_employee_id", upload.offlineEmployeeId)

        // file
        if let data = try? Data(contentsOf: URL(fileURLWithPath: upload.localFilePath)) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("❌ Upload failed: \(error)")
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Upload success for \(upload.offlineEmployeeId)")
                completion(true)
            } else {
                print("⚠️ Upload failed, server error")
                completion(false)
            }
        }.resume()
    }
}
