import Foundation

struct PlaylistQueue: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var selectedTrackID: UUID?
    var playbackMode: PlaybackMode
    var shuffleBag: [UUID]
    var shuffleHistory: [UUID]

    init(id: UUID = UUID(), name: String, tracks: [Track] = [], selectedTrackID: UUID? = nil, playbackMode: PlaybackMode = .sequential) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.selectedTrackID = selectedTrackID
        self.playbackMode = playbackMode
        self.shuffleBag = []
        self.shuffleHistory = []
    }

    var selectedIndex: Int? {
        guard let selectedTrackID else { return nil }
        return tracks.firstIndex { $0.id == selectedTrackID }
    }

    var selectedTrack: Track? {
        guard let selectedIndex else { return nil }
        return tracks[selectedIndex]
    }

    mutating func select(_ trackID: UUID?) {
        selectedTrackID = trackID
    }

    mutating func normalizeSelection() {
        if let selectedTrackID, tracks.contains(where: { $0.id == selectedTrackID }) { return }
        selectedTrackID = tracks.first?.id
    }
}
