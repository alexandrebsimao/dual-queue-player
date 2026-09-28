import XCTest
@testable import DualQueuePlayer

@MainActor
final class PerformanceLogicTests: XCTestCase {
    func testGroupedCuesDeriveFromOrderedItemsWithoutChangingSequence() {
        let items = [
            PerformanceItem(name: "Trilha", classification: .track),
            PerformanceItem(name: "Voz", classification: .voice),
            PerformanceItem(name: "Efeito", classification: .effect),
            PerformanceItem(name: "Outra trilha", classification: .track)
        ]
        let scene = PerformanceScene(name: "Cena 1", items: items)
        let project = PerformanceProject(name: "Espetáculo", scenes: [scene], selectedSceneID: scene.id)
        let vm = PerformanceViewModel(audio: AudioEngineManager(), projects: [project], selectedProjectID: project.id)

        XCTAssertEqual(vm.selectedScene?.items.map(\.id), items.map(\.id))
        XCTAssertEqual(vm.groupedItems.flatMap(\.items).map(\.id).count, items.count)
        XCTAssertEqual(Set(vm.groupedItems.flatMap(\.items).map(\.id)), Set(items.map(\.id)))
        XCTAssertEqual(vm.groupedItems.first?.items.map(\.id), [items[0].id, items[3].id])
    }

    func testReorderingItemsKeepsSingleSourceOfTruth() {
        let first = PerformanceItem(name: "Primeira")
        let second = PerformanceItem(name: "Segunda")
        let third = PerformanceItem(name: "Terceira")
        let scene = PerformanceScene(name: "Cena", items: [first, second, third])
        let project = PerformanceProject(name: "Espetáculo", scenes: [scene], selectedSceneID: scene.id)
        let vm = PerformanceViewModel(audio: AudioEngineManager(), projects: [project], selectedProjectID: project.id)

        vm.moveItem(third.id, before: first.id)

        XCTAssertEqual(vm.selectedScene?.items.map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(vm.groupedItems.flatMap(\.items).map(\.id), [third.id, first.id, second.id])
    }

    func testSceneClockClampsToExpectedDurationAndCanReset() {
        let scene = PerformanceScene(name: "Cena", expectedDuration: 20)
        let project = PerformanceProject(name: "Espetáculo", scenes: [scene], selectedSceneID: scene.id)
        let vm = PerformanceViewModel(audio: AudioEngineManager(), projects: [project], selectedProjectID: project.id)

        vm.seekSceneClock(to: 99)
        XCTAssertEqual(vm.sceneElapsedTime, 20)
        vm.startSceneClock()
        XCTAssertEqual(vm.sceneClockState, .running)
        vm.pauseSceneClock()
        XCTAssertEqual(vm.sceneClockState, .paused)
        vm.resetSceneClock()
        XCTAssertEqual(vm.sceneElapsedTime, 0)
        XCTAssertEqual(vm.sceneClockState, .stopped)
    }

    func testMissingFileIsMarkedAndCannotBecomeActive() {
        let item = PerformanceItem(name: "Arquivo", fileURL: URL(fileURLWithPath: "/tmp/arquivo-inexistente.dualqueue-audio"))
        let scene = PerformanceScene(name: "Cena", items: [item])
        let project = PerformanceProject(name: "Espetáculo", scenes: [scene], selectedSceneID: scene.id)
        let vm = PerformanceViewModel(audio: AudioEngineManager(), projects: [project], selectedProjectID: project.id)

        XCTAssertTrue(vm.selectedScene?.items.first?.isMissing == true)
        vm.trigger(item.id)
        XCTAssertTrue(vm.activeItems.isEmpty)
    }

    func testOldProjectWithoutPerformanceFieldsStillLoads() throws {
        let data = try JSONEncoder().encode(AppProject.empty)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "performanceProjects")
        object.removeValue(forKey: "selectedPerformanceProjectID")
        let oldData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(AppProject.self, from: oldData)

        XCTAssertTrue(decoded.performanceProjects.isEmpty)
        XCTAssertNil(decoded.selectedPerformanceProjectID)
    }

    func testPerformanceProjectRoundTripsScenesItemsAndSettings() throws {
        let item = PerformanceItem(
            name: "Ambiente",
            classification: .ambience,
            fileURL: URL(fileURLWithPath: "/tmp/ambiente.wav"),
            duration: 12,
            volume: 0.4,
            playback: .loop,
            transition: .keepOnSceneChange,
            keyboardShortcut: "q",
            isMissing: true
        )
        let scene = PerformanceScene(name: "Abertura", items: [item], expectedDuration: 90)
        let project = PerformanceProject(
            name: "Peça",
            kind: .theater,
            scenes: [scene],
            selectedSceneID: scene.id,
            defaultDisplayMode: .groupedCues,
            keepActiveItemsOnSceneChange: true
        )
        let appProject = AppProject(
            queueA: PlaylistQueue(name: "A"),
            queueB: PlaylistQueue(name: "B"),
            activeQueue: .queueA,
            masterVolume: 0.8,
            padPages: [SoundPadPage(name: "Pads")],
            duckVolume: 0.25,
            duckFadeDown: 0.3,
            duckFadeUp: 0.5,
            performanceProjects: [project],
            selectedPerformanceProjectID: project.id
        )

        let data = try JSONEncoder().encode(appProject)
        let decoded = try JSONDecoder().decode(AppProject.self, from: data)

        XCTAssertEqual(decoded.performanceProjects.first?.scenes.first?.items.first?.name, "Ambiente")
        XCTAssertEqual(decoded.performanceProjects.first?.defaultDisplayMode, .groupedCues)
        XCTAssertTrue(decoded.performanceProjects.first?.keepActiveItemsOnSceneChange == true)
        XCTAssertEqual(decoded.selectedPerformanceProjectID, project.id)
    }
}
