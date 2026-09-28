import Foundation

enum SoundPadMode: String, Codable, CaseIterable, Identifiable {
    case overlay
    case interrupt
    case duck

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overlay: "Overlay"
        case .interrupt: "Interrupt"
        case .duck: "Duck"
        }
    }
}

struct SoundPad: Identifiable, Codable {
    let id: UUID
    var name: String
    var iconName: String
    var fileURL: URL?
    var volume: Double
    var mode: SoundPadMode
    var keyboardShortcut: String?
    var stopsOtherPads: Bool
    var loops: Bool

    init(id: UUID = UUID(), name: String, iconName: String = "music.note", fileURL: URL? = nil, volume: Double = 1, mode: SoundPadMode = .overlay, keyboardShortcut: String? = nil, stopsOtherPads: Bool = false, loops: Bool = false) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.fileURL = fileURL
        self.volume = volume
        self.mode = mode
        self.keyboardShortcut = keyboardShortcut
        self.stopsOtherPads = stopsOtherPads
        self.loops = loops
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, iconName, fileURL, volume, mode, keyboardShortcut, stopsOtherPads, loops
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        iconName = try values.decodeIfPresent(String.self, forKey: .iconName) ?? "music.note"
        fileURL = try values.decodeIfPresent(URL.self, forKey: .fileURL)
        volume = try values.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        mode = try values.decodeIfPresent(SoundPadMode.self, forKey: .mode) ?? .overlay
        keyboardShortcut = try values.decodeIfPresent(String.self, forKey: .keyboardShortcut)
        stopsOtherPads = try values.decodeIfPresent(Bool.self, forKey: .stopsOtherPads) ?? false
        loops = try values.decodeIfPresent(Bool.self, forKey: .loops) ?? false
    }
}

struct SoundPadPage: Identifiable, Codable {
    let id: UUID
    var name: String
    var pads: [SoundPad]

    init(id: UUID = UUID(), name: String, pads: [SoundPad] = []) {
        self.id = id
        self.name = name
        self.pads = pads
    }
}
