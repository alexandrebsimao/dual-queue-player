import Foundation

struct AudioOutputSettings: Codable, Equatable {
    var playlistOutputUID: String?
    var padOutputUID: String?
    var performanceOutputUID: String?
    var monitorOutputUID: String?
    var playlistMonitorEnabled: Bool
    var padMonitorEnabled: Bool
    var performanceMonitorEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case playlistOutputUID, padOutputUID, performanceOutputUID, monitorOutputUID
        case playlistMonitorEnabled, padMonitorEnabled, performanceMonitorEnabled
        case playlistMonitorOutputUID, padMonitorOutputUID, performanceMonitorOutputUID
    }

    static let `default` = AudioOutputSettings(
        playlistOutputUID: nil,
        padOutputUID: nil,
        performanceOutputUID: nil,
        monitorOutputUID: nil,
        playlistMonitorEnabled: false,
        padMonitorEnabled: false,
        performanceMonitorEnabled: false
    )

    init(
        playlistOutputUID: String?,
        padOutputUID: String?,
        performanceOutputUID: String?,
        monitorOutputUID: String?,
        playlistMonitorEnabled: Bool,
        padMonitorEnabled: Bool,
        performanceMonitorEnabled: Bool
    ) {
        self.playlistOutputUID = playlistOutputUID
        self.padOutputUID = padOutputUID
        self.performanceOutputUID = performanceOutputUID
        self.monitorOutputUID = monitorOutputUID
        self.playlistMonitorEnabled = playlistMonitorEnabled
        self.padMonitorEnabled = padMonitorEnabled
        self.performanceMonitorEnabled = performanceMonitorEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playlistOutputUID = try values.decodeIfPresent(String.self, forKey: .playlistOutputUID)
        padOutputUID = try values.decodeIfPresent(String.self, forKey: .padOutputUID)
        performanceOutputUID = try values.decodeIfPresent(String.self, forKey: .performanceOutputUID)
        // Migra projetos que salvaram uma saída de monitor diferente por grupo.
        monitorOutputUID = try values.decodeIfPresent(String.self, forKey: .monitorOutputUID)
            ?? values.decodeIfPresent(String.self, forKey: .playlistMonitorOutputUID)
            ?? values.decodeIfPresent(String.self, forKey: .padMonitorOutputUID)
            ?? values.decodeIfPresent(String.self, forKey: .performanceMonitorOutputUID)
        playlistMonitorEnabled = try values.decodeIfPresent(Bool.self, forKey: .playlistMonitorEnabled) ?? false
        padMonitorEnabled = try values.decodeIfPresent(Bool.self, forKey: .padMonitorEnabled) ?? false
        performanceMonitorEnabled = try values.decodeIfPresent(Bool.self, forKey: .performanceMonitorEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(playlistOutputUID, forKey: .playlistOutputUID)
        try values.encodeIfPresent(padOutputUID, forKey: .padOutputUID)
        try values.encodeIfPresent(performanceOutputUID, forKey: .performanceOutputUID)
        try values.encodeIfPresent(monitorOutputUID, forKey: .monitorOutputUID)
        try values.encode(playlistMonitorEnabled, forKey: .playlistMonitorEnabled)
        try values.encode(padMonitorEnabled, forKey: .padMonitorEnabled)
        try values.encode(performanceMonitorEnabled, forKey: .performanceMonitorEnabled)
    }
}
