import Foundation

struct AppProject: Codable {
    var queueA: PlaylistQueue
    var queueB: PlaylistQueue
    var activeQueue: QueueIdentifier
    var masterVolume: Double
    var padPages: [SoundPadPage]
    var duckVolume: Double
    var duckFadeDown: Double
    var duckFadeUp: Double
    var playlistPlaybackSettings: PlaylistPlaybackSettings
    var audioOutputSettings: AudioOutputSettings
    var performanceProjects: [PerformanceProject]
    var selectedPerformanceProjectID: UUID?

    private enum CodingKeys: String, CodingKey {
        case queueA, queueB, activeQueue, masterVolume, padPages, duckVolume, duckFadeDown, duckFadeUp, playlistPlaybackSettings, audioOutputSettings
        case performanceProjects, selectedPerformanceProjectID
    }

    init(
        queueA: PlaylistQueue,
        queueB: PlaylistQueue,
        activeQueue: QueueIdentifier,
        masterVolume: Double,
        padPages: [SoundPadPage],
        duckVolume: Double,
        duckFadeDown: Double,
        duckFadeUp: Double,
        playlistPlaybackSettings: PlaylistPlaybackSettings = .default,
        audioOutputSettings: AudioOutputSettings = .default,
        performanceProjects: [PerformanceProject] = [],
        selectedPerformanceProjectID: UUID? = nil
    ) {
        self.queueA = queueA
        self.queueB = queueB
        self.activeQueue = activeQueue
        self.masterVolume = masterVolume
        self.padPages = padPages
        self.duckVolume = duckVolume
        self.duckFadeDown = duckFadeDown
        self.duckFadeUp = duckFadeUp
        self.playlistPlaybackSettings = playlistPlaybackSettings
        self.audioOutputSettings = audioOutputSettings
        self.performanceProjects = performanceProjects
        self.selectedPerformanceProjectID = selectedPerformanceProjectID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        queueA = try values.decodeIfPresent(PlaylistQueue.self, forKey: .queueA) ?? PlaylistQueue(name: "Fila A")
        queueB = try values.decodeIfPresent(PlaylistQueue.self, forKey: .queueB) ?? PlaylistQueue(name: "Fila B")
        activeQueue = try values.decodeIfPresent(QueueIdentifier.self, forKey: .activeQueue) ?? .queueA
        masterVolume = try values.decodeIfPresent(Double.self, forKey: .masterVolume) ?? 0.8
        padPages = try values.decodeIfPresent([SoundPadPage].self, forKey: .padPages) ?? []
        duckVolume = try values.decodeIfPresent(Double.self, forKey: .duckVolume) ?? 0.25
        duckFadeDown = try values.decodeIfPresent(Double.self, forKey: .duckFadeDown) ?? 0.3
        duckFadeUp = try values.decodeIfPresent(Double.self, forKey: .duckFadeUp) ?? 0.5
        playlistPlaybackSettings = try values.decodeIfPresent(PlaylistPlaybackSettings.self, forKey: .playlistPlaybackSettings) ?? .default
        audioOutputSettings = try values.decodeIfPresent(AudioOutputSettings.self, forKey: .audioOutputSettings) ?? .default
        performanceProjects = try values.decodeIfPresent([PerformanceProject].self, forKey: .performanceProjects) ?? []
        selectedPerformanceProjectID = try values.decodeIfPresent(UUID.self, forKey: .selectedPerformanceProjectID)
        if let selectedPerformanceProjectID,
           performanceProjects.contains(where: { $0.id == selectedPerformanceProjectID }) == false {
            self.selectedPerformanceProjectID = performanceProjects.first?.id
        }
    }

    static var empty: AppProject {
        AppProject(
            queueA: PlaylistQueue(name: "Fila A"),
            queueB: PlaylistQueue(name: "Fila B"),
            activeQueue: .queueA,
            masterVolume: 0.8,
            padPages: [SoundPadPage(name: "Vinhetas")],
            duckVolume: 0.25,
            duckFadeDown: 0.3,
            duckFadeUp: 0.5,
            playlistPlaybackSettings: .default,
            audioOutputSettings: .default,
            performanceProjects: [],
            selectedPerformanceProjectID: nil
        )
    }
}
