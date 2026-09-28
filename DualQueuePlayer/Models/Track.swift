import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var fileURL: URL
    var duration: TimeInterval
    var isMissing: Bool

    init(id: UUID = UUID(), title: String, fileURL: URL, duration: TimeInterval = 0, isMissing: Bool = false) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.duration = duration
        self.isMissing = isMissing
    }

    var formattedDuration: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    mutating func refreshAvailability() {
        isMissing = !FileManager.default.fileExists(atPath: fileURL.path)
    }
}
