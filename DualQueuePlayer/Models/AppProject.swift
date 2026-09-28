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

    static var empty: AppProject {
        AppProject(
            queueA: PlaylistQueue(name: "Fila A"),
            queueB: PlaylistQueue(name: "Fila B"),
            activeQueue: .queueA,
            masterVolume: 0.8,
            padPages: [SoundPadPage(name: "Vinhetas")],
            duckVolume: 0.25,
            duckFadeDown: 0.3,
            duckFadeUp: 0.5
        )
    }
}
