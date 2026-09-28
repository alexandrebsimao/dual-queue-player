import Foundation
import Combine

@MainActor
final class DuckingController: ObservableObject {
    @Published private(set) var activePadCount = 0
    var duckVolume: Double = 0.25
    var fadeDownDuration: Double = 0.3
    var fadeUpDuration: Double = 0.5

    private var savedVolume: Double = 1

    func begin(currentVolume: Double) -> Double {
        if activePadCount == 0 { savedVolume = currentVolume }
        activePadCount += 1
        return duckVolume
    }

    func end() -> Double? {
        activePadCount = max(0, activePadCount - 1)
        return activePadCount == 0 ? savedVolume : nil
    }

    func reset() { activePadCount = 0 }
}
