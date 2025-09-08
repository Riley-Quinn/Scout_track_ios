import Foundation
import UIKit

class UploadStore: ObservableObject {
    static let shared = UploadStore()
    private let storageKey = "local_uploads"

    @Published private(set) var uploads: [LocalUpload] = []

    private init() {
        load()
    }

    // MARK: - Filter Helpers

    var pending: [LocalUpload] { uploads.filter { $0.syncStatus == .pending } }
    var failed: [LocalUpload] { uploads.filter { $0.syncStatus == .failed } }
    var successful: [LocalUpload] { uploads.filter { $0.syncStatus == .success } }

    // MARK: - Public APIs

    func getAll() -> [LocalUpload] {
        uploads
    }

    func add(_ upload: LocalUpload) {
        uploads.append(upload)
        saveAndRefresh()
    }

    func markAsSynced(_ upload: LocalUpload) {
        if let idx = uploads.firstIndex(where: { $0.id == upload.id }) {
            uploads[idx].syncStatus = .success
            saveAndRefresh()
        }
    }

    func markAsFailed(_ upload: LocalUpload) {
        if let idx = uploads.firstIndex(where: { $0.id == upload.id }) {
            uploads[idx].syncStatus = .failed
            saveAndRefresh()
        }
    }

    func retryUpload(_ upload: LocalUpload) {
        // Post a notification to trigger retry
        NotificationCenter.default.post(name: .syncStatusChanged, object: upload)
    }

    func cleanupSynced() {
        uploads.removeAll { $0.syncStatus == .success }
        saveAndRefresh()
    }

    // MARK: - Private Helpers

    private func saveAndRefresh() {
        save()
        // Force SwiftUI to refresh by reassigning the array
        uploads = Array(uploads)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(uploads) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LocalUpload].self, from: data)
        {
            uploads = decoded
        }
    }
}
