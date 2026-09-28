import AppKit
import AVFoundation
import Combine
import Foundation

@MainActor
final class PerformanceViewModel: ObservableObject {
    @Published private(set) var projects: [PerformanceProject]
    @Published var selectedProjectID: UUID?
    @Published var selectedSceneID: UUID?
    @Published var selectedItemID: UUID?
    @Published var displayMode: PerformanceDisplayMode
    @Published private(set) var activeItems: [UUID: ActivePerformanceItem] = [:]
    @Published private(set) var sceneElapsedTime: TimeInterval = 0
    @Published private(set) var sceneClockState: SceneClockState = .stopped
    @Published var message: String?

    let audio: AudioEngineManager
    var onChange: (() -> Void)?

    private var sceneClockTimer: Timer?
    private var sceneClockAnchor: Date?

    init(projects: [PerformanceProject], selectedProjectID: UUID?, audio: AudioEngineManager) {
        self.projects = projects
        self.audio = audio
        let initialProjectID = selectedProjectID ?? projects.first?.id
        let project = projects.first(where: { $0.id == initialProjectID })
        self.selectedProjectID = initialProjectID
        self.selectedSceneID = project?.selectedSceneID ?? project?.scenes.first?.id
        self.displayMode = project?.defaultDisplayMode ?? .list
        wireAudioCallbacks()
        normalizeSelection()
    }

    deinit {
        sceneClockTimer?.invalidate()
    }

    var selectedProject: PerformanceProject? {
        projects.first(where: { $0.id == selectedProjectID })
    }

    var selectedScene: PerformanceScene? {
        guard let selectedProject, let selectedSceneID else { return nil }
        return selectedProject.scenes.first(where: { $0.id == selectedSceneID })
    }

    var currentItems: [PerformanceItem] { selectedScene?.items ?? [] }

    var currentSceneDuration: TimeInterval {
        selectedScene?.expectedDuration ?? selectedScene?.calculatedDuration ?? 0
    }

    var activeItemsList: [ActivePerformanceItem] {
        activeItems.values.sorted { lhs, rhs in
            currentItems.firstIndex(where: { $0.id == lhs.id }) ?? .max < currentItems.firstIndex(where: { $0.id == rhs.id }) ?? .max
        }
    }

    var groupedItems: [(classification: PerformanceClassification, items: [PerformanceItem])] {
        PerformanceClassification.allCases.compactMap { classification in
            let items = currentItems.filter { $0.classification == classification }
            return items.isEmpty ? nil : (classification, items)
        }
    }

    func createProject(named name: String, kind: PerformanceProjectKind = .theater) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = PerformanceProject(name: cleanName.isEmpty ? "Novo espetáculo" : cleanName, kind: kind)
        projects.append(project)
        selectedProjectID = project.id
        selectedSceneID = nil
        selectedItemID = nil
        displayMode = project.defaultDisplayMode
        resetSceneClock()
        onChange?()
    }

    func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        stopAll()
        selectedProjectID = id
        selectedSceneID = projects.first(where: { $0.id == id })?.selectedSceneID
            ?? projects.first(where: { $0.id == id })?.scenes.first?.id
        selectedItemID = nil
        displayMode = projects.first(where: { $0.id == id })?.defaultDisplayMode ?? .list
        resetSceneClock()
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
        if id == selectedProjectID { stopAll() }
        projects.remove(at: index)
        selectedProjectID = projects.first?.id
        selectedSceneID = selectedProject?.selectedSceneID ?? selectedProject?.scenes.first?.id
        selectedItemID = nil
        displayMode = selectedProject?.defaultDisplayMode ?? .list
        resetSceneClock()
        onChange?()
    }

    func addScene(named name: String = "Nova cena") {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scene = PerformanceScene(name: cleanName.isEmpty ? "Nova cena" : cleanName)
        projects[projectIndex].scenes.append(scene)
        projects[projectIndex].selectedSceneID = scene.id
        selectedSceneID = scene.id
        selectedItemID = nil
        resetSceneClock()
        onChange?()
    }

    func renameScene(_ id: UUID, to name: String) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == id }) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        projects[projectIndex].scenes[sceneIndex].name = cleanName
        onChange?()
    }

    func removeScene(_ id: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              projects[projectIndex].scenes.contains(where: { $0.id == id }) else { return }
        stopAll()
        projects[projectIndex].scenes.removeAll { $0.id == id }
        selectedSceneID = projects[projectIndex].scenes.first?.id
        projects[projectIndex].selectedSceneID = selectedSceneID
        selectedItemID = nil
        resetSceneClock()
        onChange?()
    }

    func selectScene(_ id: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              projects[projectIndex].scenes.contains(where: { $0.id == id }), id != selectedSceneID else { return }

        let oldIDs = Set(currentItems.map(\.id))
        let keepActive = projects[projectIndex].keepActiveItemsOnSceneChange
        if keepActive {
            for item in currentItems where item.transition == .stopOnSceneChange { stop(item.id) }
        } else {
            for id in oldIDs { stop(id) }
        }
        selectedSceneID = id
        projects[projectIndex].selectedSceneID = id
        selectedItemID = nil
        resetSceneClock()
        onChange?()
    }

    func addItem(to sceneID: UUID, item: PerformanceItem) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        projects[projectIndex].scenes[sceneIndex].items.append(item)
        selectedSceneID = sceneID
        selectedItemID = item.id
        onChange?()
    }

    func presentAddItemPanel() {
        guard let sceneID = selectedSceneID else {
            showMessage("Crie uma cena antes de adicionar uma faixa.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aac", "aiff", "aif"]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { addItem(to: sceneID, item: makeItem(for: url)) }
    }

    func updateItem(_ item: PerformanceItem) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == selectedSceneID }),
              let itemIndex = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == item.id }) else { return }
        projects[projectIndex].scenes[sceneIndex].items[itemIndex] = item
        onChange?()
    }

    func removeItem(_ id: UUID) {
        stop(id)
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == selectedSceneID }) else { return }
        projects[projectIndex].scenes[sceneIndex].items.removeAll { $0.id == id }
        if selectedItemID == id { selectedItemID = nil }
        onChange?()
    }

    func moveItem(_ id: UUID, before targetID: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == selectedProjectID }),
              let sceneIndex = projects[projectIndex].scenes.firstIndex(where: { $0.id == selectedSceneID }),
              id != targetID,
              let source = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == id }),
              projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == targetID }) != nil else { return }
        let item = projects[projectIndex].scenes[sceneIndex].items.remove(at: source)
        let destination = projects[projectIndex].scenes[sceneIndex].items.firstIndex(where: { $0.id == targetID }) ?? 0
        projects[projectIndex].scenes[sceneIndex].items.insert(item, at: destination)
        onChange?()
    }

    func trigger(_ itemID: UUID) {
        guard let item = currentItems.first(where: { $0.id == itemID }) else { return }
        guard let url = item.fileURL, FileManager.default.fileExists(atPath: url.path), !item.isMissing else {
            showMessage("O arquivo de \(item.name) não foi encontrado.")
            return
        }
        if selectedProject?.mixMode == .singleActive {
            stopAll()
        }
        do {
            let duration = try audio.playPerformanceItem(id: item.id, url: url, volume: Float(item.volume), loops: item.playback == .loop)
            activeItems[item.id] = ActivePerformanceItem(id: item.id, state: .playing, currentTime: 0, duration: duration)
            selectedItemID = item.id
        } catch {
            showMessage("Não foi possível reproduzir \(item.name).")
        }
    }

    func pause(_ itemID: UUID) {
        audio.pausePerformanceItem(id: itemID)
        updateActiveState(itemID, state: .paused, currentTime: audio.performanceItemCurrentTime(id: itemID))
    }

    func resume(_ itemID: UUID) {
        audio.resumePerformanceItem(id: itemID)
        updateActiveState(itemID, state: .playing, currentTime: audio.performanceItemCurrentTime(id: itemID))
    }

    func stop(_ itemID: UUID) {
        audio.stopPerformanceItem(id: itemID)
        activeItems.removeValue(forKey: itemID)
    }

    func seek(_ itemID: UUID, to time: TimeInterval) {
        guard let active = activeItems[itemID] else { return }
        if time >= active.duration {
            stop(itemID)
            return
        }
        audio.seekPerformanceItem(id: itemID, to: time)
        activeItems[itemID]?.currentTime = min(max(time, 0), active.duration)
    }

    func pauseAll() {
        for id in activeItems.keys { pause(id) }
    }

    func resumeAll() {
        for id in activeItems.keys where activeItems[id]?.state == .paused { resume(id) }
    }

    func stopAll() {
        audio.stopAllPerformanceItems()
        activeItems.removeAll()
    }

    func selectItem(_ id: UUID) {
        guard currentItems.contains(where: { $0.id == id }) else { return }
        selectedItemID = id
    }

    func startSceneClock() {
        guard sceneClockState != .running else { return }
        sceneClockState = .running
        sceneClockAnchor = Date()
        sceneClockTimer?.invalidate()
        sceneClockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateSceneClock() }
        }
    }

    func pauseSceneClock() {
        guard sceneClockState == .running else { return }
        updateSceneClock()
        sceneClockState = .paused
        sceneClockAnchor = nil
        sceneClockTimer?.invalidate()
        sceneClockTimer = nil
    }

    func resetSceneClock() {
        sceneClockTimer?.invalidate()
        sceneClockTimer = nil
        sceneClockAnchor = nil
        sceneClockState = .stopped
        sceneElapsedTime = 0
    }

    func seekSceneClock(to time: TimeInterval) {
        let limit = currentSceneDuration
        sceneElapsedTime = limit > 0 ? min(max(0, time), limit) : max(0, time)
        if sceneClockState == .running { sceneClockAnchor = Date() }
    }

    func setDisplayMode(_ mode: PerformanceDisplayMode) {
        displayMode = mode
        guard let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        projects[index].defaultDisplayMode = mode
        onChange?()
    }

    func setMixMode(_ mode: PerformanceMixMode) {
        guard let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else { return }
        projects[index].mixMode = mode
        if mode == .singleActive, activeItems.count > 1 {
            let keepID = selectedItemID ?? activeItems.keys.first
            for id in Array(activeItems.keys) where id != keepID { stop(id) }
        }
        onChange?()
    }

    func handleShortcut(_ key: String) {
        switch key {
        case "space":
            if activeItems.values.contains(where: { $0.state == .playing }) { pauseAll() }
            else if activeItems.values.contains(where: { $0.state == .paused }) { resumeAll() }
        case "escape": stopAll()
        case "left": moveSelection(offset: -1)
        case "right": moveSelection(offset: 1)
        default:
            if let item = currentItems.first(where: { $0.keyboardShortcut?.lowercased() == key.lowercased() }) { trigger(item.id) }
        }
    }

    func load(projects: [PerformanceProject], selectedProjectID: UUID?) {
        stopAll()
        self.projects = projects
        self.selectedProjectID = selectedProjectID
        selectedSceneID = nil
        selectedItemID = nil
        displayMode = .list
        normalizeSelection()
        resetSceneClock()
    }

    private func wireAudioCallbacks() {
        audio.onPerformanceItemFinished = { [weak self] id in
            guard let self else { return }
            self.activeItems.removeValue(forKey: id)
        }
        audio.onPerformanceItemProgress = { [weak self] id, time, duration in
            guard let self, self.activeItems[id] != nil else { return }
            self.activeItems[id]?.currentTime = time
            self.activeItems[id]?.duration = duration
        }
    }

    private func updateActiveState(_ id: UUID, state: PerformanceItemState, currentTime: TimeInterval) {
        guard var active = activeItems[id] else { return }
        active.state = state
        active.currentTime = currentTime
        activeItems[id] = active
    }

    private func updateSceneClock() {
        guard sceneClockState == .running, let sceneClockAnchor else { return }
        let elapsed = sceneElapsedTime + Date().timeIntervalSince(sceneClockAnchor)
        let limit = currentSceneDuration
        sceneElapsedTime = limit > 0 ? min(elapsed, limit) : elapsed
        self.sceneClockAnchor = Date()
    }

    private func moveSelection(offset: Int) {
        guard !currentItems.isEmpty else { return }
        let currentIndex = selectedItemID.flatMap { itemID in
            currentItems.firstIndex { item in item.id == itemID }
        } ?? 0
        let index = min(max(currentIndex + offset, 0), currentItems.count - 1)
        selectedItemID = currentItems[index].id
    }

    private func normalizeSelection() {
        if selectedProjectID == nil || !projects.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = projects.first?.id
        }
        guard let project = selectedProject else {
            selectedSceneID = nil
            displayMode = .list
            return
        }
        if selectedSceneID == nil || !project.scenes.contains(where: { $0.id == selectedSceneID }) {
            selectedSceneID = project.selectedSceneID ?? project.scenes.first?.id
        }
        displayMode = project.defaultDisplayMode
    }

    private func makeItem(for url: URL) -> PerformanceItem {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        var item = PerformanceItem(
            name: url.deletingPathExtension().lastPathComponent,
            fileURL: url,
            duration: seconds.isFinite ? seconds : 0
        )
        item.refreshAvailability()
        return item
    }

    private func showMessage(_ text: String) {
        message = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.message == text { self?.message = nil }
        }
    }
}

enum SceneClockState: Equatable {
    case stopped
    case running
    case paused
}
