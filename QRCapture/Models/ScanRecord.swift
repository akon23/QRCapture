import Foundation

struct ScanRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let scannedAt: Date
}
