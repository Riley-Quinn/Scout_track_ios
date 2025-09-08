import Foundation

enum SyncStatus: String, Codable {
    case pending
    case synced
    case failed
    case success
}

struct LocalUpload: Identifiable, Codable {
    var id: UUID = .init()
    let ticketId: Int
    let localFilePath: String
    let mediaStage: String
    let latitude: Double
    let longitude: Double
    let uploadedBy: String
    let offlineEmployeeId: String
    var syncStatus: SyncStatus
}
