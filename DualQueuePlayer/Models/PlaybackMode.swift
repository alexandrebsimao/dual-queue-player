import Foundation

enum PlaybackMode: String, Codable, CaseIterable, Identifiable {
    case sequential
    case shuffle
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequential: "Sequencial"
        case .shuffle: "Aleatório"
        case .manual: "Manual"
        }
    }

    var subtitle: String {
        switch self {
        case .sequential: "Próxima faixa automática"
        case .shuffle: "Shuffle bag sem repetição"
        case .manual: "Aguarda comando"
        }
    }

    var symbolName: String {
        switch self {
        case .sequential: "arrow.trianglehead.2.clockwise.rotate.90"
        case .shuffle: "shuffle"
        case .manual: "hand.raised"
        }
    }
}
