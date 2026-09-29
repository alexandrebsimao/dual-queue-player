import Foundation

enum PerformanceProjectKind: String, Codable, CaseIterable, Identifiable {
    case theater
    case dance
    case sketch
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theater: "Teatro"
        case .dance: "Dança"
        case .sketch: "Esquete"
        case .other: "Outro"
        }
    }

    var symbolName: String {
        switch self {
        case .theater: "theatermasks"
        case .dance: "figure.dance"
        case .sketch: "film"
        case .other: "sparkles"
        }
    }
}

enum PerformanceDisplayMode: String, Codable, CaseIterable, Identifiable {
    case list
    case cues

    var id: String { rawValue }
    var title: String { self == .list ? "Lista" : "Cues" }
    var symbolName: String { self == .list ? "list.bullet" : "square.grid.2x2" }
}

enum PerformanceStopScope: String, Codable, CaseIterable, Identifiable {
    case performanceOnly
    case allAudio

    var id: String { rawValue }
    var title: String { self == .performanceOnly ? "Somente Performance" : "Todo o áudio" }
}

enum PerformanceMixMode: String, Codable, CaseIterable, Identifiable {
    case overlay
    case singleActive

    var id: String { rawValue }
    var title: String { self == .overlay ? "Permitir sobreposição" : "Uma mídia por vez" }
}

enum PerformanceClassification: String, Codable, CaseIterable, Identifiable {
    case track
    case effect
    case voice
    case ambience
    case transition
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .track: "Trilha"
        case .effect: "Efeito"
        case .voice: "Voz"
        case .ambience: "Ambiente"
        case .transition: "Transição"
        case .other: "Outro"
        }
    }

    var symbolName: String {
        switch self {
        case .track: "music.note"
        case .effect: "waveform"
        case .voice: "person.wave.2"
        case .ambience: "cloud"
        case .transition: "arrow.right"
        case .other: "circle.dotted"
        }
    }

    var color: AppColor {
        switch self {
        case .track: .blue
        case .effect: .orange
        case .voice: .pink
        case .ambience: .green
        case .transition: .purple
        case .other: .orange
        }
    }
}

enum PerformancePlayback: String, Codable, CaseIterable, Identifiable {
    case once
    case loop

    var id: String { rawValue }
    var title: String { self == .once ? "Uma vez" : "Loop" }
}

enum PerformanceTransition: String, Codable, CaseIterable, Identifiable {
    case stopOnSceneChange
    case keepOnSceneChange

    var id: String { rawValue }
    var title: String { self == .stopOnSceneChange ? "Parar na troca de cena" : "Continuar na troca de cena" }
}

enum PerformanceItemState: Equatable {
    case playing
    case paused
    case stopped
}

struct PerformanceProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: PerformanceProjectKind
    var scenes: [PerformanceScene]
    var selectedSceneID: UUID?
    var defaultDisplayMode: PerformanceDisplayMode
    var stopAllScope: PerformanceStopScope
    var keepActiveItemsOnSceneChange: Bool
    var mixMode: PerformanceMixMode

    init(
        id: UUID = UUID(),
        name: String,
        kind: PerformanceProjectKind = .theater,
        scenes: [PerformanceScene] = [],
        selectedSceneID: UUID? = nil,
        defaultDisplayMode: PerformanceDisplayMode = .list,
        stopAllScope: PerformanceStopScope = .performanceOnly,
        keepActiveItemsOnSceneChange: Bool = false,
        mixMode: PerformanceMixMode = .overlay
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.scenes = scenes
        self.selectedSceneID = selectedSceneID ?? scenes.first?.id
        self.defaultDisplayMode = defaultDisplayMode
        self.stopAllScope = stopAllScope
        self.keepActiveItemsOnSceneChange = keepActiveItemsOnSceneChange
        self.mixMode = mixMode
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, scenes, selectedSceneID, defaultDisplayMode, stopAllScope, keepActiveItemsOnSceneChange, mixMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        kind = try values.decodeIfPresent(PerformanceProjectKind.self, forKey: .kind) ?? .other
        scenes = try values.decodeIfPresent([PerformanceScene].self, forKey: .scenes) ?? []
        selectedSceneID = try values.decodeIfPresent(UUID.self, forKey: .selectedSceneID)
        defaultDisplayMode = try values.decodeIfPresent(PerformanceDisplayMode.self, forKey: .defaultDisplayMode) ?? .list
        stopAllScope = try values.decodeIfPresent(PerformanceStopScope.self, forKey: .stopAllScope) ?? .performanceOnly
        keepActiveItemsOnSceneChange = try values.decodeIfPresent(Bool.self, forKey: .keepActiveItemsOnSceneChange) ?? false
        mixMode = try values.decodeIfPresent(PerformanceMixMode.self, forKey: .mixMode) ?? .overlay
        if let selectedSceneID, scenes.contains(where: { $0.id == selectedSceneID }) == false {
            self.selectedSceneID = scenes.first?.id
        } else if self.selectedSceneID == nil {
            self.selectedSceneID = scenes.first?.id
        }
    }
}

struct PerformanceScene: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [PerformanceItem]
    var expectedDuration: TimeInterval?

    init(id: UUID = UUID(), name: String, items: [PerformanceItem] = [], expectedDuration: TimeInterval? = nil) {
        self.id = id
        self.name = name
        self.items = items
        self.expectedDuration = expectedDuration
    }

    var calculatedDuration: TimeInterval {
        items.map { $0.duration }.max() ?? 0
    }
}

struct PerformanceItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var classification: PerformanceClassification
    var fileURL: URL?
    var duration: TimeInterval
    var volume: Double
    var playback: PerformancePlayback
    var transition: PerformanceTransition
    var keyboardShortcut: String?
    var isMissing: Bool

    init(
        id: UUID = UUID(),
        name: String,
        classification: PerformanceClassification = .track,
        fileURL: URL? = nil,
        duration: TimeInterval = 0,
        volume: Double = 1,
        playback: PerformancePlayback = .once,
        transition: PerformanceTransition = .stopOnSceneChange,
        keyboardShortcut: String? = nil,
        isMissing: Bool = false
    ) {
        self.id = id
        self.name = name
        self.classification = classification
        self.fileURL = fileURL
        self.duration = duration
        self.volume = volume
        self.playback = playback
        self.transition = transition
        self.keyboardShortcut = keyboardShortcut
        self.isMissing = isMissing
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, classification, fileURL, duration, volume, playback, transition, keyboardShortcut, isMissing
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        classification = try values.decodeIfPresent(PerformanceClassification.self, forKey: .classification) ?? .track
        fileURL = try values.decodeIfPresent(URL.self, forKey: .fileURL)
        duration = try values.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        volume = try values.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        playback = try values.decodeIfPresent(PerformancePlayback.self, forKey: .playback) ?? .once
        transition = try values.decodeIfPresent(PerformanceTransition.self, forKey: .transition) ?? .stopOnSceneChange
        keyboardShortcut = try values.decodeIfPresent(String.self, forKey: .keyboardShortcut)
        isMissing = try values.decodeIfPresent(Bool.self, forKey: .isMissing) ?? (fileURL == nil)
    }

    var formattedDuration: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    mutating func refreshAvailability() {
        isMissing = fileURL.map { !FileManager.default.fileExists(atPath: $0.path) } ?? true
    }
}

struct ActivePerformanceItem: Identifiable, Equatable {
    let id: UUID
    var itemID: UUID { id }
    var state: PerformanceItemState
    var currentTime: TimeInterval
    var duration: TimeInterval
}

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case player
    case performance

    var id: String { rawValue }
    var title: String { self == .player ? "Modo Playlist" : "Modo Performance" }
    var symbolName: String { self == .player ? "music.note" : "theatermasks" }
}
