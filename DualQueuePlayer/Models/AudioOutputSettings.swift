import Foundation

enum AudioRouteMode: String, Codable, CaseIterable, Identifiable {
    case mainAndMonitor
    case main
    case monitor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainAndMonitor: "Saída principal + monitor"
        case .main: "Somente saída principal"
        case .monitor: "Somente monitor"
        }
    }

    var includesPrimary: Bool { self != .monitor }
    var includesMonitor: Bool { self != .main }
}

struct AudioOutputSettings: Codable, Equatable {
    var playlistOutputUID: String?
    var padOutputUID: String?
    var performanceOutputUID: String?
    var monitorOutputUID: String?
    var playlistRoute: AudioRouteMode
    var padRoute: AudioRouteMode
    var performanceRoute: AudioRouteMode

    var playlistMonitorEnabled: Bool {
        get { playlistRoute.includesMonitor }
        set { playlistRoute = newValue ? .mainAndMonitor : .main }
    }

    var padMonitorEnabled: Bool {
        get { padRoute.includesMonitor }
        set { padRoute = newValue ? .mainAndMonitor : .main }
    }

    var performanceMonitorEnabled: Bool {
        get { performanceRoute.includesMonitor }
        set { performanceRoute = newValue ? .mainAndMonitor : .main }
    }

    private enum CodingKeys: String, CodingKey {
        case playlistOutputUID, padOutputUID, performanceOutputUID, monitorOutputUID
        case playlistRoute, padRoute, performanceRoute
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
        playlistRoute = playlistMonitorEnabled ? .mainAndMonitor : .main
        padRoute = padMonitorEnabled ? .mainAndMonitor : .main
        performanceRoute = performanceMonitorEnabled ? .mainAndMonitor : .main
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
        let legacyPlaylistMonitor = try values.decodeIfPresent(Bool.self, forKey: .playlistMonitorEnabled) ?? false
        let legacyPadMonitor = try values.decodeIfPresent(Bool.self, forKey: .padMonitorEnabled) ?? false
        let legacyPerformanceMonitor = try values.decodeIfPresent(Bool.self, forKey: .performanceMonitorEnabled) ?? false
        playlistRoute = try values.decodeIfPresent(AudioRouteMode.self, forKey: .playlistRoute)
            ?? (legacyPlaylistMonitor ? .mainAndMonitor : .main)
        padRoute = try values.decodeIfPresent(AudioRouteMode.self, forKey: .padRoute)
            ?? (legacyPadMonitor ? .mainAndMonitor : .main)
        performanceRoute = try values.decodeIfPresent(AudioRouteMode.self, forKey: .performanceRoute)
            ?? (legacyPerformanceMonitor ? .mainAndMonitor : .main)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(playlistOutputUID, forKey: .playlistOutputUID)
        try values.encodeIfPresent(padOutputUID, forKey: .padOutputUID)
        try values.encodeIfPresent(performanceOutputUID, forKey: .performanceOutputUID)
        try values.encodeIfPresent(monitorOutputUID, forKey: .monitorOutputUID)
        try values.encode(playlistRoute, forKey: .playlistRoute)
        try values.encode(padRoute, forKey: .padRoute)
        try values.encode(performanceRoute, forKey: .performanceRoute)
        try values.encode(playlistMonitorEnabled, forKey: .playlistMonitorEnabled)
        try values.encode(padMonitorEnabled, forKey: .padMonitorEnabled)
        try values.encode(performanceMonitorEnabled, forKey: .performanceMonitorEnabled)
    }
}
