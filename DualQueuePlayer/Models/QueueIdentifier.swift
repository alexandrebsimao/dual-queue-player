import Foundation

enum QueueIdentifier: String, Codable, CaseIterable, Identifiable {
    case queueA
    case queueB

    var id: String { rawValue }
    var title: String { self == .queueA ? "Fila A" : "Fila B" }
    var shortTitle: String { self == .queueA ? "A" : "B" }
    var accent: AppColor { self == .queueA ? .blue : .orange }
}

enum AppColor: String {
    case blue
    case orange
    case green
    case pink
    case purple
}
