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
}

enum PerformanceDisplayMode: String, Codable, CaseIterable, Identifiable {
    case list
    case groupedCues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: "Lista"
        case .groupedCues: "Cues agrupadas"
        }
    }
}

enum PerformanceStopScope: String, Codable, CaseIterable, Identifiable {
    case performanceOnly

    var id: String { rawValue }
    var title: String { "Somente Performance" }
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
        case .effect: "sparkles"
        case .voice: "mic.fill"
        case .ambience: "wind"
        case .transition: "arrow.right.arrow.left"
        case .other: "waveform"
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

    var title: String {
        self == .stopOnSceneChange ? "Parar ao trocar de cena" : "Continuar na troca de cena"
    }
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

    init(
        id: UUID = UUID(),
        name: String,
        kind: PerformanceProjectKind = .theater,
        scenes: [PerformanceScene] = [],
        selectedSceneID: UUID? = nil,
        defaultDisplayMode: PerformanceDisplayMode = .list,
        stopAllScope: PerformanceStopScope = .performanceOnly,
        keepActiveItemsOnSceneChange: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.scenes = scenes
        self.selectedSceneID = selectedSceneID
        self.defaultDisplayMode = defaultDisplayMode
        self.stopAllScope = stopAllScope
        self.keepActiveItemsOnSceneChange = keepActiveItemsOnSceneChange
    }

    mutating func normalizeSelection() {
        if let selectedSceneID, scenes.contains(where: { $0.id == selectedSceneID }) { return }
        selectedSceneID = scenes.first?.id
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
        classification: PerformanceClassification = .other,
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

    var formattedDuration: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let totalSeconds = Int(duration.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    mutating func refreshAvailability() {
        isMissing = fileURL.map { !FileManager.default.fileExists(atPath: $0.path) } ?? true
    }
}

enum PerformanceItemState: String, Equatable {
    case playing
    case paused
}

struct ActivePerformanceItem: Identifiable, Equatable {
    let itemID: UUID
    var state: PerformanceItemState
    var currentTime: TimeInterval
    var duration: TimeInterval

    var id: UUID { itemID }
}

enum SceneClockState: String, Equatable {
    case stopped
    case running
    case paused
}
