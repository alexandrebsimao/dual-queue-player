import AVFoundation
import Combine
import Foundation

@MainActor
final class PerformanceViewModel: ObservableObject {
    @Published var projects: [PerformanceProject]
    @Published var selectedProjectID: UUID?
    @Published var displayMode: PerformanceDisplayMode = .list
    @Published private(set) var activeItems: [UUID: ActivePerformanceItem] = [:]
    @Published private(set) var executedItemIDs: Set<UUID> = []
    @Published private(set) var sceneElapsedTime: TimeInterval = 0
    @Published private(set) var sceneClockState: SceneClockState = .stopped
    @Published var message: String?

    let audio: AudioEngineManager
    var onChange: (() -> Void)?

    private var clockTimer: Timer?
    private var clockReferenceDate: Date?
    private var activeItemsTimer: Timer?

    init(audio: AudioEngineManager, projects: [PerformanceProject] = [], selectedProjectID: UUID? = nil) {
        self.audio = audio
        self.projects = projects
        self.selectedProjectID = selectedProjectID
        normalizeAll()
        self.selectedProjectID = self.selectedProjectID ?? self.projects.first?.id
        self.displayMode = selectedProject?.defaultDisplayMode ?? .list
        configureAudioCallbacks()
    }

    deinit {
        clockTimer?.invalidate()
        activeItemsTimer?.invalidate()
    }

    var selectedProject: PerformanceProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    var selectedScene: PerformanceScene? {
        guard let project = selectedProject, let sceneID = project.selectedSceneID else { return nil }
        return project.scenes.first { $0.id == sceneID }
    }

    var selectedSceneID: UUID? { selectedProject?.selectedSceneID }

    var groupedItems: [(classification: PerformanceClassification, items: [PerformanceItem])] {
        guard let scene = selectedScene else { return [] }
        return PerformanceClassification.allCases.compactMap { classification in
            let items = scene.items.filter { $0.classification == classification }
            return items.isEmpty ? nil : (classification, items)
        }
    }

    var sceneExpectedDuration: TimeInterval? { selectedScene?.expectedDuration }

    var sceneProgress: Double {
        guard let expected = sceneExpectedDuration, expected > 0 else { return 0 }
        return min(1, max(0, sceneElapsedTime / expected))
    }

    func load(projects: [PerformanceProject], selectedProjectID: UUID?) {
        stopAll()
        executedItemIDs.removeAll()
        resetSceneClock()
        self.projects = projects
        normalizeAll()
        self.selectedProjectID = selectedProjectID.flatMap { id in
            self.projects.contains(where: { $0.id == id }) ? id : self.projects.first?.id
        } ?? self.projects.first?.id
        displayMode = selectedProject?.defaultDisplayMode ?? .list
    }

    func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }), selectedProjectID != id else { return }
        stopItemsForSceneChange(from: selectedScene)
        resetSceneClock()
        selectedProjectID = id
        normalizeSelectedProject()
        displayMode = selectedProject?.defaultDisplayMode ?? .list
        onChange?()
    }

    func createProject(named name: String, kind: PerformanceProjectKind = .theater) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = PerformanceProject(name: cleanName.isEmpty ? "Novo espetáculo" : cleanName, kind: kind)
        projects.append(project)
        selectedProjectID = project.id
        displayMode = project.defaultDisplayMode
        onChange?()
    }

    func renameProject(_ id: UUID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        projects[index].name = cleanName
        onChange?()
    }

    func removeProject(_ id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        if selectedProjectID == id { stopAll() }
        projects.remove(at: index)
        selectedProjectID = projects.indices.contains(index) ? projects[index].id : projects.last?.id
        displayMode = selectedProject?.defaultDisplayMode ?? .list
        onChange?()
    }

    func selectScene(_ id: UUID) {
        guard let projectIndex = selectedProjectIndex,
              projects[projectIndex].scenes.contains(where: { $0.id == id }),
              projects[projectIndex].selectedSceneID != id else { return }
        stopItemsForSceneChange(from: selectedScene)
        resetSceneClock()
        projects[projectIndex].selectedSceneID = id
        onChange?()
    }

    func addScene(named name: String) {
        guard let projectIndex = selectedProjectIndex else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scene = PerformanceScene(name: cleanName.isEmpty ? "Nova cena" : cleanName)
        projects[projectIndex].scenes.append(scene)
        projects[projectIndex].selectedSceneID = scene.id
        resetSceneClock()
        onChange?()
    }

    func renameScene(_ id: UUID, to name: String) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == id }) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        projects[projectIndex].scenes[sceneIndex].name = cleanName
        onChange?()
    }

    func removeScene(_ id: UUID) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == id }) else { return }
        let removingSelected = projects[projectIndex].selectedSceneID == id
        if removingSelected { stopAll(); resetSceneClock() }
        projects[projectIndex].scenes.remove(at: sceneIndex)
        if removingSelected {
            projects[projectIndex].selectedSceneID = projects[projectIndex].scenes.indices.contains(sceneIndex)
                ? projects[projectIndex].scenes[sceneIndex].id
                : projects[projectIndex].scenes.last?.id
        }
        onChange?()
    }

    func moveScene(_ id: UUID, before targetID: UUID) {
        guard let projectIndex = selectedProjectIndex,
              id != targetID,
              let sourceIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == id }),
              let targetIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == targetID }) else { return }
        let scene = projects[projectIndex].scenes.remove(at: sourceIndex)
        let destination = projects[projectIndex].scenes.firstIndex(where: { $0.id == targetID }) ?? targetIndex
        projects[projectIndex].scenes.insert(scene, at: destination)
        onChange?()
    }

    func addItem(to sceneID: UUID? = nil) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == (sceneID ?? selectedSceneID) }) else { return }
        let itemNumber = projects[projectIndex].scenes[sceneIndex].items.count + 1
        projects[projectIndex].scenes[sceneIndex].items.append(PerformanceItem(name: "Cue \(itemNumber)"))
        onChange?()
    }

    func importItems(from urls: [URL], into sceneID: UUID? = nil) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == (sceneID ?? selectedSceneID) }) else {
            showMessage("Crie ou selecione uma cena antes de importar áudios.")
            return
        }

        let existingURLs = Set(projects[projectIndex].scenes[sceneIndex].items.compactMap { $0.fileURL?.standardizedFileURL })
        let supportedURLs = urls.filter { isSupportedAudio($0) }
        for url in supportedURLs where !existingURLs.contains(url.standardizedFileURL) {
            var item = PerformanceItem(
                name: url.deletingPathExtension().lastPathComponent,
                classification: .other,
                fileURL: url,
                duration: duration(for: url),
                isMissing: !FileManager.default.fileExists(atPath: url.path)
            )
            item.refreshAvailability()
            projects[projectIndex].scenes[sceneIndex].items.append(item)
        }
        if !supportedURLs.isEmpty { onChange?() }
    }

    func updateItemSettings(
        _ itemID: UUID,
        classification: PerformanceClassification? = nil,
        playback: PerformancePlayback? = nil,
        transition: PerformanceTransition? = nil,
        mixBehavior: PerformanceMixBehavior? = nil,
        volume: Double? = nil
    ) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = selectedSceneIndex,
              let itemIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == itemID }) else { return }
        if let classification { projects[projectIndex].scenes[sceneIndex].items[itemIndex].classification = classification }
        if let playback { projects[projectIndex].scenes[sceneIndex].items[itemIndex].playback = playback }
        if let transition { projects[projectIndex].scenes[sceneIndex].items[itemIndex].transition = transition }
        if let mixBehavior { projects[projectIndex].scenes[sceneIndex].items[itemIndex].mixBehavior = mixBehavior }
        if let volume { projects[projectIndex].scenes[sceneIndex].items[itemIndex].volume = min(1, max(0, volume)) }
        onChange?()
    }

    func updateItem(_ item: PerformanceItem) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == selectedSceneID }),
              let itemIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        if let url = updated.fileURL {
            updated.duration = duration(for: url)
            updated.isMissing = !FileManager.default.fileExists(atPath: url.path)
        } else {
            updated.duration = 0
            updated.isMissing = true
        }
        projects[projectIndex].scenes[sceneIndex].items[itemIndex] = updated
        onChange?()
    }

    func removeItem(_ id: UUID, from sceneID: UUID? = nil) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == (sceneID ?? selectedSceneID) }) else { return }
        audio.stopPerformanceItem(id: id)
        activeItems[id] = nil
        executedItemIDs.remove(id)
        projects[projectIndex].scenes[sceneIndex].items.removeAll { $0.id == id }
        onChange?()
    }

    func moveItem(_ id: UUID, before targetID: UUID, in sceneID: UUID? = nil) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == (sceneID ?? selectedSceneID) }),
              id != targetID,
              let sourceIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == id }),
              let targetIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == targetID }) else { return }
        let item = projects[projectIndex].scenes[sceneIndex].items.remove(at: sourceIndex)
        let destination = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == targetID }) ?? targetIndex
        projects[projectIndex].scenes[sceneIndex].items.insert(item, at: destination)
        onChange?()
    }

    func trigger(_ itemID: UUID) {
        guard let item = item(withID: itemID) else { return }
        var playableItem = item
        playableItem.refreshAvailability()
        updateStoredItem(playableItem)
        guard !playableItem.isMissing, let url = playableItem.fileURL else {
            showMessage("O arquivo de \(playableItem.name) não está disponível.")
            return
        }
        do {
            if playableItem.mixBehavior == .interruptOthers {
                for activeID in Array(activeItems.keys) where activeID != itemID {
                    stop(activeID)
                }
            }
            let duration = try audio.playPerformanceItem(id: itemID, url: url, volume: Float(playableItem.volume), loops: playableItem.playback == .loop)
            executedItemIDs.insert(itemID)
            activeItems[itemID] = ActivePerformanceItem(itemID: itemID, state: .playing, currentTime: 0, duration: playableItem.duration > 0 ? playableItem.duration : duration)
            startActiveItemsTimer()
        } catch {
            showMessage("Não foi possível reproduzir \(playableItem.name).")
        }
    }

    func pause(_ itemID: UUID) {
        guard var active = activeItems[itemID], active.state == .playing else { return }
        audio.pausePerformanceItem(id: itemID)
        active.currentTime = audio.performanceCurrentTime(id: itemID)
        active.state = .paused
        activeItems[itemID] = active
    }

    func resume(_ itemID: UUID) {
        guard var active = activeItems[itemID], active.state == .paused else { return }
        audio.resumePerformanceItem(id: itemID)
        active.state = .playing
        activeItems[itemID] = active
    }

    func stop(_ itemID: UUID) {
        audio.stopPerformanceItem(id: itemID)
        activeItems[itemID] = nil
        if activeItems.isEmpty { stopActiveItemsTimer() }
    }

    func seek(_ itemID: UUID, to time: TimeInterval) {
        guard var active = activeItems[itemID], active.duration > 0 else { return }
        let clamped = min(max(time, 0), active.duration)
        audio.seekPerformanceItem(id: itemID, to: clamped, resume: active.state == .playing)
        active.currentTime = clamped
        activeItems[itemID] = active
    }

    func pauseAll() { activeItems.keys.forEach { pause($0) } }

    func resumeAll() { activeItems.keys.forEach { resume($0) } }

    func stopAll() {
        audio.stopAllPerformanceItems()
        activeItems.removeAll()
        stopActiveItemsTimer()
    }

    func startSceneClock() {
        guard sceneClockState != .running else { return }
        clockReferenceDate = Date().addingTimeInterval(-sceneElapsedTime)
        sceneClockState = .running
        startClockTimer()
    }

    func pauseSceneClock() {
        guard sceneClockState == .running else { return }
        tickClock()
        sceneClockState = .paused
        stopClockTimer()
    }

    func resetSceneClock() {
        stopClockTimer()
        clockReferenceDate = nil
        sceneElapsedTime = 0
        sceneClockState = .stopped
    }

    func seekSceneClock(to time: TimeInterval) {
        let maximum = sceneExpectedDuration.map { max(0, $0) }
        sceneElapsedTime = max(0, min(time, maximum ?? max(time, 0)))
        if sceneClockState == .running { clockReferenceDate = Date().addingTimeInterval(-sceneElapsedTime) }
    }

    func setExpectedDuration(_ duration: TimeInterval?, for sceneID: UUID? = nil) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == (sceneID ?? selectedSceneID) }) else { return }
        projects[projectIndex].scenes[sceneIndex].expectedDuration = duration.map { max(0, $0) }
        if let expected = projects[projectIndex].scenes[sceneIndex].expectedDuration, sceneElapsedTime > expected {
            sceneElapsedTime = expected
        }
        onChange?()
    }

    func updatePerformanceSettings(displayMode: PerformanceDisplayMode? = nil, keepActiveItemsOnSceneChange: Bool? = nil) {
        guard let index = selectedProjectIndex else { return }
        if let displayMode {
            self.displayMode = displayMode
            projects[index].defaultDisplayMode = displayMode
        }
        if let keepActiveItemsOnSceneChange {
            projects[index].keepActiveItemsOnSceneChange = keepActiveItemsOnSceneChange
        }
        onChange?()
    }

    func triggerConfiguredShortcut(_ key: String) -> Bool {
        guard let item = selectedScene?.items.first(where: { $0.keyboardShortcut?.lowercased() == key.lowercased() }) else { return false }
        trigger(item.id)
        return true
    }

    func selectAdjacentItem(direction: Int) {
        guard let scene = selectedScene, !scene.items.isEmpty else { return }
        let activeID = activeItems.keys.first
        let currentIndex = activeID.flatMap { id in scene.items.firstIndex(where: { $0.id == id }) } ?? -1
        let nextIndex = min(max(currentIndex + direction, 0), scene.items.count - 1)
        trigger(scene.items[nextIndex].id)
    }

    func selectAdjacentScene(direction: Int) {
        guard let projectIndex = selectedProjectIndex,
              let currentID = projects[projectIndex].selectedSceneID,
              let currentIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIndex = currentIndex + direction
        guard projects[projectIndex].scenes.indices.contains(nextIndex) else { return }
        selectScene(projects[projectIndex].scenes[nextIndex].id)
    }

    private var selectedProjectIndex: Int? {
        guard let selectedProjectID else { return nil }
        return projects.firstIndex(where: { $0.id == selectedProjectID })
    }

    private var selectedSceneIndex: Int? {
        guard let projectIndex = selectedProjectIndex, let sceneID = projects[projectIndex].selectedSceneID else { return nil }
        return projects[projectIndex].scenes.firstIndex(where: { $0.id == sceneID })
    }

    func item(withID id: UUID) -> PerformanceItem? {
        selectedScene?.items.first { $0.id == id }
    }

    func itemAnywhere(withID id: UUID) -> PerformanceItem? {
        for project in projects {
            for scene in project.scenes where scene.items.contains(where: { $0.id == id }) {
                return scene.items.first { $0.id == id }
            }
        }
        return nil
    }

    private func updateStoredItem(_ item: PerformanceItem) {
        guard let projectIndex = selectedProjectIndex,
              let sceneIndex = selectedSceneIndex,
              let itemIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        projects[projectIndex].scenes[sceneIndex].items[itemIndex] = item
    }

    private func normalizeAll() {
        for projectIndex in projects.indices {
            projects[projectIndex].normalizeSelection()
            for sceneIndex in projects[projectIndex].scenes.indices {
                for itemIndex in projects[projectIndex].scenes[sceneIndex].items.indices {
                    projects[projectIndex].scenes[sceneIndex].items[itemIndex].refreshAvailability()
                }
            }
        }
    }

    private func normalizeSelectedProject() {
        guard let projectIndex = selectedProjectIndex else { return }
        projects[projectIndex].normalizeSelection()
    }

    private func stopItemsForSceneChange(from scene: PerformanceScene?) {
        guard let scene else { return }
        let shouldKeep = selectedProject?.keepActiveItemsOnSceneChange == true
        for item in scene.items where activeItems[item.id] != nil {
            if !shouldKeep || item.transition == .stopOnSceneChange { stop(item.id) }
        }
    }

    private func configureAudioCallbacks() {
        audio.onPerformanceFinished = { [weak self] id in
            guard let self else { return }
            self.activeItems[id] = nil
            if self.activeItems.isEmpty { self.stopActiveItemsTimer() }
        }
    }

    private func duration(for url: URL) -> TimeInterval {
        let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    private func isSupportedAudio(_ url: URL) -> Bool {
        ["mp3", "wav", "m4a", "aac", "aiff", "aif"].contains(url.pathExtension.lowercased())
    }

    private func startClockTimer() {
        stopClockTimer()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickClock() }
        }
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func startActiveItemsTimer() {
        guard activeItemsTimer == nil else { return }
        activeItemsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateActiveItemTimes() }
        }
    }

    private func stopActiveItemsTimer() {
        activeItemsTimer?.invalidate()
        activeItemsTimer = nil
    }

    private func updateActiveItemTimes() {
        for id in Array(activeItems.keys) {
            guard var active = activeItems[id], active.state == .playing else { continue }
            active.currentTime = audio.performanceCurrentTime(id: id)
            activeItems[id] = active
        }
    }

    private func tickClock() {
        guard sceneClockState == .running, let clockReferenceDate else { return }
        let elapsed = Date().timeIntervalSince(clockReferenceDate)
        sceneElapsedTime = sceneExpectedDuration.map { min($0, elapsed) } ?? max(0, elapsed)
    }

    private func showMessage(_ text: String) {
        message = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.message == text { self?.message = nil }
        }
    }
}
