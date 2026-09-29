import XCTest
@testable import DualQueuePlayer

@MainActor
final class PerformanceTests: XCTestCase {
    func testGroupedViewIsDerivedFromTheSameOrderedItems() {
        let first = PerformanceItem(name: "Intro", classification: .track)
        let second = PerformanceItem(name: "Porta", classification: .effect)
        let third = PerformanceItem(name: "Fala", classification: .voice)
        let scene = PerformanceScene(name: "Cena 1", items: [first, second, third])
        let vm = PerformanceViewModel(
            projects: [PerformanceProject(name: "Teatro", scenes: [scene])],
            selectedProjectID: nil,
            audio: AudioEngineManager()
        )

        XCTAssertEqual(vm.currentItems.map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(vm.groupedItems.flatMap(\.items).map(\.id).sorted { $0.uuidString < $1.uuidString }.count, 3)
        XCTAssertEqual(vm.currentItems.map(\.id), [first.id, second.id, third.id])
    }

    func testMovingPerformanceItemPreservesEveryItemExactlyOnce() {
        let items = (0..<3).map { PerformanceItem(name: "Item \($0)") }
        let scene = PerformanceScene(name: "Cena", items: items)
        let vm = PerformanceViewModel(
            projects: [PerformanceProject(name: "Projeto", scenes: [scene])],
            selectedProjectID: nil,
            audio: AudioEngineManager()
        )

        vm.moveItem(items[2].id, before: items[0].id)

        XCTAssertEqual(vm.currentItems.map(\.id), [items[2].id, items[0].id, items[1].id])
        XCTAssertEqual(Set(vm.currentItems.map(\.id)).count, 3)
    }

    func testCueArrowsMoveItemWithinSceneOrder() {
        let items = (0..<3).map { PerformanceItem(name: "Cue \($0)") }
        let scene = PerformanceScene(name: "Cena", items: items)
        let vm = PerformanceViewModel(
            projects: [PerformanceProject(name: "Projeto", scenes: [scene])],
            selectedProjectID: nil,
            audio: AudioEngineManager()
        )

        vm.moveItem(items[1].id, by: -1)
        XCTAssertEqual(vm.currentItems.map(\.id), [items[1].id, items[0].id, items[2].id])

        vm.moveItem(items[1].id, by: 1)
        XCTAssertEqual(vm.currentItems.map(\.id), [items[0].id, items[1].id, items[2].id])
    }

    func testOldProjectWithoutPerformanceFieldsStillDecodes() throws {
        let data = try JSONEncoder().encode(AppProject.empty)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "performanceProjects")
        object.removeValue(forKey: "selectedPerformanceProjectID")
        object.removeValue(forKey: "playlistPlaybackSettings")
        object.removeValue(forKey: "audioOutputSettings")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let project = try JSONDecoder().decode(AppProject.self, from: legacyData)

        XCTAssertTrue(project.performanceProjects.isEmpty)
        XCTAssertNil(project.selectedPerformanceProjectID)
        XCTAssertEqual(project.queueA.name, "Fila A")
        XCTAssertEqual(project.playlistPlaybackSettings, .default)
        XCTAssertEqual(project.audioOutputSettings, .default)
    }

    func testAudioOutputSettingsRoundTrip() throws {
        var settings = AudioOutputSettings.default
        settings.playlistOutputUID = "playlist-device"
        settings.monitorOutputUID = "monitor-device"
        settings.playlistMonitorEnabled = true
        settings.padOutputUID = "pad-device"
        settings.padMonitorEnabled = true
        settings.performanceOutputUID = "performance-device"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AudioOutputSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    func testPlaylistPlaybackSettingsRoundTripAndDurationClamp() throws {
        let settings = PlaylistPlaybackSettings(
            pauseWithFade: true,
            stopWithFade: true,
            stopBehavior: .afterCurrentTrack,
            queueSwitchMode: .automatic,
            fadeDuration: 20
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PlaylistPlaybackSettings.self, from: data)

        XCTAssertTrue(decoded.pauseWithFade)
        XCTAssertTrue(decoded.stopWithFade)
        XCTAssertEqual(decoded.stopBehavior, .afterCurrentTrack)
        XCTAssertEqual(decoded.queueSwitchMode, .automatic)
        XCTAssertEqual(decoded.fadeDuration, 10)
    }

    func testSceneClockSeekIsClampedToExpectedDuration() {
        let scene = PerformanceScene(name: "Cena", expectedDuration: 10)
        let vm = PerformanceViewModel(
            projects: [PerformanceProject(name: "Projeto", scenes: [scene])],
            selectedProjectID: nil,
            audio: AudioEngineManager()
        )

        vm.seekSceneClock(to: 99)
        XCTAssertEqual(vm.sceneElapsedTime, 10)
        vm.seekSceneClock(to: -5)
        XCTAssertEqual(vm.sceneElapsedTime, 0)
    }

    func testSceneExpectedDurationCanBeManualOrUnset() {
        let item = PerformanceItem(name: "Cue", duration: 8)
        let scene = PerformanceScene(name: "Cena", items: [item])
        let vm = PerformanceViewModel(
            projects: [PerformanceProject(name: "Projeto", scenes: [scene])],
            selectedProjectID: nil,
            audio: AudioEngineManager()
        )

        vm.setSceneExpectedDuration(scene.id, duration: 125)
        XCTAssertEqual(vm.currentSceneDuration, 125)

        vm.setSceneExpectedDuration(scene.id, duration: nil)
        XCTAssertEqual(vm.currentSceneDuration, 0)
    }
}
