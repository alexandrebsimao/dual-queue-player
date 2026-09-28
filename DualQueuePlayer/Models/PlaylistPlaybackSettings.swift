import Foundation

enum PlaylistStopBehavior: String, Codable, CaseIterable, Identifiable {
    case immediate
    case afterCurrentTrack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediate: "Parar imediatamente"
        case .afterCurrentTrack: "Parar ao terminar a faixa"
        }
    }
}

enum PlaylistQueueSwitchMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Manual"
        case .automatic: "Automática"
        }
    }

    var subtitle: String {
        switch self {
        case .manual: "Troca a fila e aguarda Play"
        case .automatic: "Fade e inicia a faixa selecionada"
        }
    }
}

struct PlaylistPlaybackSettings: Codable, Equatable {
    var pauseWithFade: Bool
    var stopWithFade: Bool
    var stopBehavior: PlaylistStopBehavior
    var queueSwitchMode: PlaylistQueueSwitchMode
    var fadeDuration: TimeInterval

    static let `default` = PlaylistPlaybackSettings(
        pauseWithFade: false,
        stopWithFade: false,
        stopBehavior: .immediate,
        queueSwitchMode: .manual,
        fadeDuration: 0.8
    )

    init(
        pauseWithFade: Bool = false,
        stopWithFade: Bool = false,
        stopBehavior: PlaylistStopBehavior = .immediate,
        queueSwitchMode: PlaylistQueueSwitchMode = .manual,
        fadeDuration: TimeInterval = 0.8
    ) {
        self.pauseWithFade = pauseWithFade
        self.stopWithFade = stopWithFade
        self.stopBehavior = stopBehavior
        self.queueSwitchMode = queueSwitchMode
        self.fadeDuration = min(max(fadeDuration, 0.1), 10)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pauseWithFade = try values.decodeIfPresent(Bool.self, forKey: .pauseWithFade) ?? false
        stopWithFade = try values.decodeIfPresent(Bool.self, forKey: .stopWithFade) ?? false
        stopBehavior = try values.decodeIfPresent(PlaylistStopBehavior.self, forKey: .stopBehavior) ?? .immediate
        queueSwitchMode = try values.decodeIfPresent(PlaylistQueueSwitchMode.self, forKey: .queueSwitchMode) ?? .manual
        let decodedDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .fadeDuration) ?? 0.8
        fadeDuration = min(max(decodedDuration, 0.1), 10)
    }
}
