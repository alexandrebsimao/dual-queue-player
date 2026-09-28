import AppKit
import Combine
import Foundation

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case player
    case performance

    var id: String { rawValue }
    var title: String { self == .player ? "Player" : "Performance" }
    var symbolName: String { self == .player ? "music.note.list" : "theatermasks.fill" }
}

@MainActor
final class MainViewModel: ObservableObject {
    @Published var queueA: QueueViewModel
    @Published var queueB: QueueViewModel
    @Published var activeQueue: QueueIdentifier
    @Published var currentTrack: Track?
    @Published var currentQueue: QueueIdentifier?
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var masterVolume: Double = 0.8 {
        didSet { audio.volume = Float(masterVolume) }
    }
    @Published var padPages: [SoundPadPage]
    @Published var selectedPadPageIndex = 0
    @Published var message: String?
    @Published var workspaceMode: WorkspaceMode = .player
    @Published private(set) var currentProjectURL: URL?

    let audio: AudioEngineManager
    let performance: PerformanceViewModel
    let previewPlayer = PreviewPlayer()
    let duckingController = DuckingController()
    private let store = ProjectStore.shared
    private let shortcutManager = KeyboardShortcutManager()
    private var localEventMonitor: Any?
    private var activeDuckPads = Set<UUID>()

    init() {
        let project = ProjectStore.shared.loadLastProject() ?? .empty
        queueA = QueueViewModel(identifier: .queueA, queue: project.queueA)
        queueB = QueueViewModel(identifier: .queueB, queue: project.queueB)
        activeQueue = project.activeQueue
        currentProjectURL = nil
        masterVolume = project.masterVolume
        padPages = project.padPages
        let audioManager = AudioEngineManager()
        audio = audioManager
        audio.volume = Float(project.masterVolume)
        performance = PerformanceViewModel(
            audio: audioManager,
            projects: project.performanceProjects,
            selectedProjectID: project.selectedPerformanceProjectID
        )
        wireViewModels()
        configureAudioCallbacks()
        configureShortcuts()
    }

    deinit {
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
    }

    var activeQueueViewModel: QueueViewModel { viewModel(for: activeQueue) }

    var nextTrack: Track? {
        guard let currentTrack, let queue = currentQueue else { return nil }
        let vm = viewModel(for: queue)
        guard let index = vm.queue.tracks.firstIndex(where: { $0.id == currentTrack.id }) else { return nil }
        let nextIndex = index + 1
        return vm.queue.tracks.indices.contains(nextIndex) ? vm.queue.tracks[nextIndex] : nil
    }

    func viewModel(for identifier: QueueIdentifier) -> QueueViewModel {
        identifier == .queueA ? queueA : queueB
    }

    func selectQueue(_ identifier: QueueIdentifier) {
        guard identifier != activeQueue else { return }
        audio.stop()
        playbackState = .stopped
        currentTrack = nil
        currentQueue = nil
        activeQueue = identifier
        persist()
    }

    func selectTrack(_ track: Track, in queue: QueueIdentifier) {
        viewModel(for: queue).select(track)
        if queue == activeQueue, playbackState == .stopped { currentTrack = track }
    }

    func togglePlayPause() {
        if playbackState == .playing {
            audio.pause()
            playbackState = .paused
            return
        }
        if playbackState == .paused, currentTrack != nil {
            audio.resume()
            playbackState = .playing
            return
        }
        playSelected()
    }

    func playSelected() {
        let vm = activeQueueViewModel
        var track = vm.queue.selectedTrack
        if track == nil, let first = vm.queue.tracks.first {
            vm.select(first)
            track = first
        }
        guard let track else {
            showMessage("Adicione uma música à \(activeQueue.title) antes de reproduzir.")
            return
        }
        play(track, from: activeQueue)
    }

    func play(_ track: Track, from queue: QueueIdentifier) {
        if queue != activeQueue { selectQueue(queue) }
        guard !track.isMissing, FileManager.default.fileExists(atPath: track.fileURL.path) else {
            showMessage("O arquivo de \(track.title) não foi encontrado.")
            return
        }
        do {
            viewModel(for: queue).select(track)
            try audio.play(trackURL: track.fileURL)
            currentTrack = track
            currentQueue = queue
            playbackState = .playing
            duration = track.duration > 0 ? track.duration : audio.duration
            persist()
        } catch {
            playbackState = .stopped
            showMessage("Não foi possível reproduzir \(track.title).")
        }
    }

    func stop() {
        audio.stop()
        playbackState = .stopped
        currentTime = 0
    }

    func stopPerformance() {
        performance.stopAll()
    }

    func clearQueue(_ identifier: QueueIdentifier) {
        let queue = viewModel(for: identifier)
        if identifier == activeQueue, currentQueue == identifier {
            stop()
            currentTrack = nil
            currentQueue = nil
        }
        queue.clearAll()
    }

    func next() {
        let vm = activeQueueViewModel
        let wasPlaying = playbackState == .playing
        if vm.queue.playbackMode == .manual {
            stop()
            _ = vm.nextTrack()
            currentTrack = vm.queue.selectedTrack
            return
        }
        guard let track = vm.nextTrack() else { return }
        if wasPlaying { play(track, from: activeQueue) }
        else { currentTrack = track }
    }

    func previous() {
        let vm = activeQueueViewModel
        let wasPlaying = playbackState == .playing
        if vm.queue.playbackMode == .manual { stop() }
        guard let track = vm.previousTrack() else { return }
        if wasPlaying && vm.queue.playbackMode != .manual { play(track, from: activeQueue) }
        else { currentTrack = track }
    }

    func seek(to time: TimeInterval) {
        audio.seek(to: time)
        currentTime = time
    }

    func triggerPad(_ pad: SoundPad) {
        do { try audio.playPad(pad) }
        catch { showMessage("Configure um arquivo de áudio para este pad."); return }

        switch pad.mode {
        case .overlay:
            break
        case .interrupt:
            if playbackState == .playing { stop() }
        case .duck:
            if playbackState == .playing {
                let volume = duckingController.begin(currentVolume: masterVolume)
                activeDuckPads.insert(pad.id)
                audio.fadeMusicVolume(to: Float(volume), duration: duckingController.fadeDownDuration)
            }
        }
    }

    func preview(_ track: Track) {
        previewPlayer.preview(track)
    }

    func setKeyboardShortcutsEnabled(_ enabled: Bool) {
        shortcutManager.isEnabled = enabled
    }

    func saveProject() {
        if currentProjectURL == nil { saveProjectAs() }
        else { persist() }
    }

    func autosaveProject() {
        persist()
    }

    func saveProjectAs() {
        guard let url = store.saveAs(makeProject()) else { return }
        currentProjectURL = url
        persist()
    }

    func openProject() {
        guard let opened = store.open() else { return }
        load(opened.project, projectURL: opened.url)
    }

    func newProject() {
        audio.stop()
        performance.stopAll()
        playbackState = .stopped
        load(.empty, projectURL: nil)
    }

    func addPadPage(named name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        padPages.append(SoundPadPage(name: cleanName.isEmpty ? "Nova página" : cleanName))
        selectedPadPageIndex = padPages.count - 1
        persist()
    }

    func renameSelectedPadPage(to name: String) {
        guard padPages.indices.contains(selectedPadPageIndex) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        padPages[selectedPadPageIndex].name = cleanName
        persist()
    }

    func deleteSelectedPadPage() {
        guard padPages.count > 1, padPages.indices.contains(selectedPadPageIndex) else { return }
        padPages.remove(at: selectedPadPageIndex)
        selectedPadPageIndex = min(selectedPadPageIndex, padPages.count - 1)
        persist()
    }

    func updatePad(_ pad: SoundPad) {
        guard padPages.indices.contains(selectedPadPageIndex), let index = padPages[selectedPadPageIndex].pads.firstIndex(where: { $0.id == pad.id }) else { return }
        padPages[selectedPadPageIndex].pads[index] = pad
        persist()
    }

    func removePad(id: UUID) {
        guard padPages.indices.contains(selectedPadPageIndex) else { return }
        padPages[selectedPadPageIndex].pads.removeAll { $0.id == id }
        persist()
    }

    private func wireViewModels() {
        queueA.onChange = { [weak self] in self?.persist() }
        queueB.onChange = { [weak self] in self?.persist() }
        performance.onChange = { [weak self] in self?.persist() }
    }

    private func configureAudioCallbacks() {
        audio.onMusicFinished = { [weak self] in self?.handleMusicFinished() }
        audio.onPadFinished = { [weak self] id in self?.handlePadFinished(id) }
    }

    private func configureShortcuts() {
        shortcutManager.onKey = { [weak self] key in self?.handleShortcut(key) }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.shortcutManager.handle(event) ? nil : event
        }
    }

    private func handleShortcut(_ key: String) {
        if workspaceMode == .performance {
            handlePerformanceShortcut(key)
            return
        }
        switch key {
        case "space": togglePlayPause()
        case "escape": stop()
        case "a": selectQueue(.queueA)
        case "b": selectQueue(.queueB)
        case "left": previous()
        case "right": next()
        default:
            let index = key == "0" ? 9 : (Int(key).map { $0 - 1 } ?? -1)
            guard padPages.indices.contains(selectedPadPageIndex), padPages[selectedPadPageIndex].pads.indices.contains(index) else { return }
            triggerPad(padPages[selectedPadPageIndex].pads[index])
        }
    }

    private func handlePerformanceShortcut(_ key: String) {
        switch key {
        case "space":
            if performance.activeItems.values.contains(where: { $0.state == .playing }) { performance.pauseAll() }
            else { performance.resumeAll() }
        case "escape": performance.stopAll()
        case "left": performance.selectAdjacentItem(direction: -1)
        case "right": performance.selectAdjacentItem(direction: 1)
        case "shift+left": performance.selectAdjacentScene(direction: -1)
        case "shift+right": performance.selectAdjacentScene(direction: 1)
        default: _ = performance.triggerConfiguredShortcut(key)
        }
    }

    private func handleMusicFinished() {
        guard let queue = currentQueue else { return }
        let vm = viewModel(for: queue)
        if vm.queue.playbackMode == .manual {
            playbackState = .stopped
            currentTime = duration
            return
        }
        guard let track = vm.nextTrack() else {
            playbackState = .stopped
            currentTime = duration
            return
        }
        play(track, from: queue)
    }

    private func handlePadFinished(_ id: UUID) {
        guard activeDuckPads.remove(id) != nil else { return }
        if let restored = duckingController.end() {
            audio.fadeMusicVolume(to: Float(restored), duration: duckingController.fadeUpDuration)
        }
    }

    private func showMessage(_ text: String) {
        message = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.message == text { self?.message = nil }
        }
    }

    private func makeProject() -> AppProject {
        AppProject(
            queueA: queueA.queue,
            queueB: queueB.queue,
            activeQueue: activeQueue,
            masterVolume: masterVolume,
            padPages: padPages,
            duckVolume: duckingController.duckVolume,
            duckFadeDown: duckingController.fadeDownDuration,
            duckFadeUp: duckingController.fadeUpDuration,
            performanceProjects: performance.projects,
            selectedPerformanceProjectID: performance.selectedProjectID
        )
    }

    private func persist() {
        let project = makeProject()
        store.saveAutosave(project)
        if let currentProjectURL {
            _ = store.save(project, to: currentProjectURL)
        }
    }

    private func load(_ project: AppProject, projectURL: URL? = nil) {
        queueA.queue = project.queueA
        queueB.queue = project.queueB
        queueA.queue.tracks.indices.forEach { queueA.queue.tracks[$0].refreshAvailability() }
        queueB.queue.tracks.indices.forEach { queueB.queue.tracks[$0].refreshAvailability() }
        activeQueue = project.activeQueue
        currentProjectURL = projectURL
        masterVolume = project.masterVolume
        padPages = project.padPages.isEmpty ? [SoundPadPage(name: "Vinhetas")] : project.padPages
        duckingController.duckVolume = project.duckVolume
        duckingController.fadeDownDuration = project.duckFadeDown
        duckingController.fadeUpDuration = project.duckFadeUp
        performance.load(projects: project.performanceProjects, selectedProjectID: project.selectedPerformanceProjectID)
        currentTrack = nil
        currentQueue = nil
        playbackState = .stopped
        wireViewModels()
        persist()
    }
}
