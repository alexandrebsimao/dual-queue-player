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
    var performanceProjects: [PerformanceProject]
    var selectedPerformanceProjectID: UUID?

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
            performanceProjects: [],
            selectedPerformanceProjectID: nil
        )
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
        self.performanceProjects = performanceProjects
        self.selectedPerformanceProjectID = selectedPerformanceProjectID
    }

    private enum CodingKeys: String, CodingKey {
        case queueA, queueB, activeQueue, masterVolume, padPages
        case duckVolume, duckFadeDown, duckFadeUp
        case performanceProjects, selectedPerformanceProjectID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        queueA = try values.decode(PlaylistQueue.self, forKey: .queueA)
        queueB = try values.decode(PlaylistQueue.self, forKey: .queueB)
        activeQueue = try values.decodeIfPresent(QueueIdentifier.self, forKey: .activeQueue) ?? .queueA
        masterVolume = try values.decodeIfPresent(Double.self, forKey: .masterVolume) ?? 0.8
        padPages = try values.decodeIfPresent([SoundPadPage].self, forKey: .padPages) ?? [SoundPadPage(name: "Vinhetas")]
        duckVolume = try values.decodeIfPresent(Double.self, forKey: .duckVolume) ?? 0.25
        duckFadeDown = try values.decodeIfPresent(Double.self, forKey: .duckFadeDown) ?? 0.3
        duckFadeUp = try values.decodeIfPresent(Double.self, forKey: .duckFadeUp) ?? 0.5
        performanceProjects = try values.decodeIfPresent([PerformanceProject].self, forKey: .performanceProjects) ?? []
        selectedPerformanceProjectID = try values.decodeIfPresent(UUID.self, forKey: .selectedPerformanceProjectID)
    }
}
