import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class QueueViewModel: ObservableObject {
    @Published var queue: PlaylistQueue
    let identifier: QueueIdentifier
    var onChange: (() -> Void)?

    init(identifier: QueueIdentifier, queue: PlaylistQueue) {
        self.identifier = identifier
        self.queue = queue
    }

    func select(_ track: Track) {
        queue.select(track.id)
        onChange?()
    }

    func setMode(_ mode: PlaybackMode) {
        queue.playbackMode = mode
        queue.shuffleBag.removeAll()
        queue.shuffleHistory.removeAll()
        onChange?()
    }

    func remove(_ track: Track) {
        queue.tracks.removeAll { $0.id == track.id }
        queue.shuffleBag.removeAll { $0 == track.id }
        queue.shuffleHistory.removeAll { $0 == track.id }
        queue.normalizeSelection()
        onChange?()
    }

    func clearAll() {
        queue.tracks.removeAll()
        queue.selectedTrackID = nil
        queue.shuffleBag.removeAll()
        queue.shuffleHistory.removeAll()
        onChange?()
    }

    func reorder(from offsets: IndexSet, to destination: Int) {
        queue.tracks.move(fromOffsets: offsets, toOffset: destination)
        onChange?()
    }

    func moveTrack(_ trackID: UUID, before targetID: UUID) {
        guard trackID != targetID,
              let sourceIndex = queue.tracks.firstIndex(where: { $0.id == trackID }),
              let targetIndex = queue.tracks.firstIndex(where: { $0.id == targetID }) else { return }

        if sourceIndex + 1 == targetIndex { return }

        let track = queue.tracks.remove(at: sourceIndex)
        let destinationIndex = queue.tracks.firstIndex(where: { $0.id == targetID }) ?? targetIndex
        queue.tracks.insert(track, at: destinationIndex)
        onChange?()
    }

    func nextTrack() -> Track? {
        guard !queue.tracks.isEmpty else { return nil }
        switch queue.playbackMode {
        case .sequential, .manual:
            let current = queue.selectedIndex ?? -1
            let index = current + 1
            guard queue.tracks.indices.contains(index) else { return nil }
            queue.select(queue.tracks[index].id)
            onChange?()
            return queue.tracks[index]
        case .shuffle:
            refillShuffleBagIfNeeded()
            guard let id = queue.shuffleBag.first, let track = queue.tracks.first(where: { $0.id == id }) else { return nil }
            queue.shuffleBag.removeFirst()
            if let current = queue.selectedTrackID { queue.shuffleHistory.append(current) }
            queue.select(track.id)
            onChange?()
            return track
        }
    }

    func previousTrack() -> Track? {
        guard !queue.tracks.isEmpty else { return nil }
        if queue.playbackMode == .shuffle, let id = queue.shuffleHistory.popLast(), let track = queue.tracks.first(where: { $0.id == id }) {
            queue.select(id)
            onChange?()
            return track
        }
        let current = queue.selectedIndex ?? 0
        let index = max(current - 1, 0)
        queue.select(queue.tracks[index].id)
        onChange?()
        return queue.tracks[index]
    }

    func addFiles(_ urls: [URL]) {
        let supported = urls.filter(Self.isSupportedAudio)
        for url in supported {
            guard !queue.tracks.contains(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) else { continue }
            let duration = Self.duration(for: url)
            let title = Self.title(for: url)
            queue.tracks.append(Track(title: title, fileURL: url, duration: duration))
        }
        queue.normalizeSelection()
        if !supported.isEmpty { onChange?() }
    }

    func presentAddPanel() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aac", "aiff"]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    func handleDrop(_ providers: [NSItemProvider]) async {
        let urls = await withTaskGroup(of: URL?.self, returning: [URL].self) { group in
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.addTask { await Self.loadURL(from: provider) }
            }
            var result: [URL] = []
            for await url in group { if let url { result.append(url) } }
            return result
        }
        addFiles(urls)
    }

    private nonisolated static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                    continuation.resume(returning: NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func refillShuffleBagIfNeeded() {
        guard queue.shuffleBag.isEmpty else { return }
        let currentID = queue.selectedTrackID
        var candidates = queue.tracks.map(\.id).filter { $0 != currentID }
        candidates.shuffle()
        if candidates.isEmpty { candidates = queue.tracks.map(\.id) }
        queue.shuffleBag = candidates
    }

    private static func isSupportedAudio(_ url: URL) -> Bool {
        ["mp3", "wav", "m4a", "aac", "aiff", "aif"].contains(url.pathExtension.lowercased())
    }

    private static func title(for url: URL) -> String {
        let asset = AVURLAsset(url: url)
        if let item = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "title" }), let value = item.stringValue, !value.isEmpty { return value }
        return url.deletingPathExtension().lastPathComponent
    }

    private static func duration(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration).isFinite ? CMTimeGetSeconds(asset.duration) : 0
    }
}
