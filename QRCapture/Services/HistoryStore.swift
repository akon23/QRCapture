import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [ScanRecord] = []
    private let fileURL: URL

    init() throws {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("QRCapture", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            records = Array(try JSONDecoder().decode([ScanRecord].self, from: data).prefix(100))
        }
    }

    func append(_ text: String) throws {
        let record = ScanRecord(id: UUID(), text: text, scannedAt: Date())
        try save(Array(([record] + records).prefix(100)))
    }

    func remove(_ record: ScanRecord) throws {
        try save(records.filter { $0.id != record.id })
    }

    func clear() throws {
        try save([])
    }

    private func save(_ updatedRecords: [ScanRecord]) throws {
        let data = try JSONEncoder().encode(updatedRecords)
        try data.write(to: fileURL, options: .atomic)
        records = updatedRecords
    }
}
