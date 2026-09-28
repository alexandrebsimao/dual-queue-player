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

    func testOldProjectWithoutPerformanceFieldsStillDecodes() throws {
        let data = try JSONEncoder().encode(AppProject.empty)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "performanceProjects")
        object.removeValue(forKey: "selectedPerformanceProjectID")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let project = try JSONDecoder().decode(AppProject.self, from: legacyData)

        XCTAssertTrue(project.performanceProjects.isEmpty)
        XCTAssertNil(project.selectedPerformanceProjectID)
        XCTAssertEqual(project.queueA.name, "Fila A")
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
}
