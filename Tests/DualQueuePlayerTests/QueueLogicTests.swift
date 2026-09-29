import XCTest
@testable import DualQueuePlayer

@MainActor
final class QueueLogicTests: XCTestCase {
    func testSequentialAdvancesAndStopsAtEnd() {
        let tracks = makeTracks(3)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id, playbackMode: .sequential))

        XCTAssertEqual(vm.nextTrack()?.id, tracks[1].id)
        XCTAssertEqual(vm.nextTrack()?.id, tracks[2].id)
        XCTAssertNil(vm.nextTrack())
    }

    func testManualAdvancesSelectionWithoutAutomaticPlaybackContract() {
        let tracks = makeTracks(2)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id, playbackMode: .manual))

        XCTAssertEqual(vm.nextTrack()?.id, tracks[1].id)
        XCTAssertEqual(vm.queue.selectedTrackID, tracks[1].id)
    }

    func testShuffleBagDoesNotRepeatBeforeCycle() {
        let tracks = makeTracks(5)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id, playbackMode: .shuffle))
        var ids: [UUID] = []
        for _ in 0..<4 { if let track = vm.nextTrack() { ids.append(track.id) } }

        XCTAssertEqual(Set(ids).count, 4)
        XCTAssertFalse(ids.contains(tracks[0].id))
    }

    func testShufflePreviousUsesHistory() {
        let tracks = makeTracks(3)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id, playbackMode: .shuffle))
        let first = vm.nextTrack()
        let second = vm.nextTrack()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(vm.previousTrack()?.id, first?.id)
    }

    func testShuffleUpcomingTrackUsesShuffleBagOrder() {
        let tracks = makeTracks(3)
        var queue = PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id, playbackMode: .shuffle)
        queue.shuffleBag = [tracks[2].id, tracks[1].id]
        let vm = QueueViewModel(identifier: .queueA, queue: queue)

        XCTAssertEqual(vm.upcomingTrack()?.id, tracks[2].id)
    }

    func testRemovingSelectedTrackNormalizesSelection() {
        let tracks = makeTracks(2)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks, selectedTrackID: tracks[0].id))

        vm.remove(tracks[0])

        XCTAssertEqual(vm.queue.selectedTrackID, tracks[1].id)
    }

    func testMovingTrackBeforeAnotherTrack() {
        let tracks = makeTracks(3)
        let vm = QueueViewModel(identifier: .queueA, queue: PlaylistQueue(name: "A", tracks: tracks))

        vm.moveTrack(tracks[2].id, before: tracks[0].id)

        XCTAssertEqual(vm.queue.tracks.map(\.id), [tracks[2].id, tracks[0].id, tracks[1].id])
    }

    private func makeTracks(_ count: Int) -> [Track] {
        (0..<count).map { Track(title: "Track \($0)", fileURL: URL(fileURLWithPath: "/tmp/track\($0).mp3"), duration: 10) }
    }
}
