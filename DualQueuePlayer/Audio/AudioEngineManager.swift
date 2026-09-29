import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioEngineManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 0.8 {
        didSet {
            playlistBus.primary.mixer.outputVolume = volume
            playlistBus.monitor.mixer.outputVolume = playlistBus.monitorEnabled ? volume : 0
        }
    }

    var onMusicFinished: (() -> Void)?
    var onPadFinished: ((UUID) -> Void)?
    var onPerformanceItemFinished: ((UUID) -> Void)?
    var onPerformanceItemProgress: ((UUID, TimeInterval, TimeInterval) -> Void)?

    private let playlistBus = AudioOutputBusPair(label: "Playlist")
    private let padBus = AudioOutputBusPair(label: "Pad")
    private let performanceBus = AudioOutputBusPair(label: "Performance")
    private lazy var musicPlayers = RoutedAudioPlayers(
        primary: playlistBus.primary.makePlayer(),
        monitor: playlistBus.monitor.makePlayer()
    )
    private var padPlayers: [UUID: RoutedAudioPlayers] = [:]
    private var performancePlayers: [UUID: RoutedAudioPlayers] = [:]
    private var performanceFiles: [UUID: AVAudioFile] = [:]
    private var performanceDurations: [UUID: TimeInterval] = [:]
    private var performanceOffsets: [UUID: TimeInterval] = [:]
    private var performanceStartDates: [UUID: Date] = [:]
    private var performanceLoops: Set<UUID> = []
    private var performancePlaying = Set<UUID>()
    private var performanceTokens: [UUID: UUID] = [:]
    private var performanceProgressTimer: Timer?
    private var scheduledFile: AVAudioFile?
    private var playbackStartTime: TimeInterval = 0
    private var progressTimer: Timer?
    private var musicFadeTask: Task<Void, Never>?
    private var musicFadeToken = UUID()
    private var musicURL: URL?
    private var playbackToken = UUID()

    override init() {
        super.init()
        playlistBus.primary.mixer.outputVolume = volume
        playlistBus.monitor.mixer.outputVolume = 0
    }

    deinit {
        progressTimer?.invalidate()
        performanceProgressTimer?.invalidate()
        musicFadeTask?.cancel()
    }

    func applyOutputSettings(_ settings: AudioOutputSettings) {
        playlistBus.apply(
            outputUID: settings.playlistOutputUID,
            monitorEnabled: settings.playlistMonitorEnabled,
            monitorUID: settings.monitorOutputUID
        )
        playlistBus.monitor.mixer.outputVolume = settings.playlistMonitorEnabled ? volume : 0
        padBus.apply(
            outputUID: settings.padOutputUID,
            monitorEnabled: settings.padMonitorEnabled,
            monitorUID: settings.monitorOutputUID
        )
        performanceBus.apply(
            outputUID: settings.performanceOutputUID,
            monitorEnabled: settings.performanceMonitorEnabled,
            monitorUID: settings.monitorOutputUID
        )
    }

    func play(trackURL: URL) throws {
        let file = try AVAudioFile(forReading: trackURL)
        guard file.length > 0 else { throw AudioError.emptyFile }

        stop()
        scheduledFile = file
        musicURL = trackURL
        let token = UUID()
        playbackToken = token
        duration = Double(file.length) / file.fileFormat.sampleRate
        currentTime = 0
        playbackStartTime = 0

        playlistBus.startIfNeeded()
        scheduleMusicFile(file, token: token, includeMonitor: playlistBus.monitorEnabled)
        musicPlayers.play(monitorEnabled: playlistBus.monitorEnabled)
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        guard isPlaying else { return }
        cancelMusicFade(restoreVolume: true)
        updateProgress()
        musicPlayers.pause(monitorEnabled: playlistBus.monitorEnabled)
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        guard scheduledFile != nil else { return }
        cancelMusicFade(restoreVolume: true)
        playlistBus.startIfNeeded()
        musicPlayers.play(monitorEnabled: playlistBus.monitorEnabled)
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        cancelMusicFade(restoreVolume: true)
        playbackToken = UUID()
        musicPlayers.stop()
        isPlaying = false
        currentTime = 0
        playbackStartTime = 0
        scheduledFile = nil
        musicURL = nil
        stopProgressTimer()
    }

    func pauseWithFade(duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard isPlaying else { completion?(); return }
        fadeMusicVolume(to: 0, duration: duration) { [weak self] in
            guard let self else { return }
            self.pause()
            completion?()
        }
    }

    func stopWithFade(duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard isPlaying else { stop(); completion?(); return }
        fadeMusicVolume(to: 0, duration: duration) { [weak self] in
            guard let self else { return }
            self.stop()
            completion?()
        }
    }

    func seek(to time: TimeInterval) {
        guard let file = scheduledFile else { return }
        let clamped = min(max(time, 0), duration)
        let frame = AVAudioFramePosition(clamped * file.fileFormat.sampleRate)
        guard frame < file.length else { return }

        let wasPlaying = isPlaying
        playbackToken = UUID()
        let token = playbackToken
        musicPlayers.stop()
        scheduleMusicFile(file, token: token, startTime: clamped, includeMonitor: playlistBus.monitorEnabled)
        currentTime = clamped
        playbackStartTime = clamped
        if wasPlaying {
            musicPlayers.play(monitorEnabled: playlistBus.monitorEnabled)
            isPlaying = true
            startProgressTimer()
        }
    }

    func playPad(_ pad: SoundPad) throws {
        guard let url = pad.fileURL else { throw AudioError.missingFile }
        let file = try AVAudioFile(forReading: url)

        if pad.stopsOtherPads {
            padPlayers.values.forEach { $0.stop() }
        }

        let players = padPlayers[pad.id] ?? makePadPlayers(for: pad.id)
        players.primary.volume = Float(pad.volume)
        players.monitor.volume = Float(pad.volume)
        if pad.loops {
            schedulePadLoop(file, player: players.primary)
            if padBus.monitorEnabled { schedulePadLoop(file, player: players.monitor) }
        } else {
            players.primary.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in self?.onPadFinished?(pad.id) }
            }
            if padBus.monitorEnabled {
                players.monitor.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in }
            }
        }
        padBus.startIfNeeded()
        players.play(monitorEnabled: padBus.monitorEnabled)
    }

    func stopPad(_ id: UUID) {
        releasePad(id)
    }

    func releasePad(_ id: UUID) {
        guard let players = padPlayers.removeValue(forKey: id) else { return }
        padBus.primary.removePlayer(players.primary)
        padBus.monitor.removePlayer(players.monitor)
        onPadFinished?(id)
    }

    func releaseAllPads() {
        Array(padPlayers.keys).forEach { releasePad($0) }
    }

    @discardableResult
    func playPerformanceItem(id: UUID, url: URL, volume: Float, loops: Bool) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { throw AudioError.emptyFile }

        stopPerformanceItem(id: id, notify: false)
        let players = performancePlayers[id] ?? makePerformancePlayers(for: id)
        let duration = Double(file.length) / file.fileFormat.sampleRate
        let token = UUID()

        performanceFiles[id] = file
        performanceDurations[id] = duration
        performanceOffsets[id] = 0
        performanceStartDates[id] = Date()
        performanceTokens[id] = token
        if loops { performanceLoops.insert(id) } else { performanceLoops.remove(id) }
        performancePlaying.insert(id)
        players.primary.volume = volume
        players.monitor.volume = volume

        schedulePerformanceFile(id: id, file: file, token: token, includeMonitor: performanceBus.monitorEnabled)
        performanceBus.startIfNeeded()
        players.play(monitorEnabled: performanceBus.monitorEnabled)
        startPerformanceProgressTimer()
        return duration
    }

    func pausePerformanceItem(id: UUID) {
        guard performancePlaying.contains(id), let players = performancePlayers[id] else { return }
        updatePerformanceProgress(for: id)
        players.pause(monitorEnabled: performanceBus.monitorEnabled)
        performancePlaying.remove(id)
        if performancePlaying.isEmpty { stopPerformanceProgressTimer() }
    }

    func resumePerformanceItem(id: UUID) {
        guard !performancePlaying.contains(id), let players = performancePlayers[id], performanceFiles[id] != nil else { return }
        performanceBus.startIfNeeded()
        performanceStartDates[id] = Date()
        performancePlaying.insert(id)
        players.play(monitorEnabled: performanceBus.monitorEnabled)
        startPerformanceProgressTimer()
    }

    func seekPerformanceItem(id: UUID, to time: TimeInterval) {
        guard let file = performanceFiles[id], let duration = performanceDurations[id], let players = performancePlayers[id] else { return }
        let clamped = min(max(time, 0), duration)
        let wasPlaying = performancePlaying.contains(id)
        let token = UUID()

        performanceTokens[id] = token
        players.stop()
        performanceOffsets[id] = clamped
        performanceStartDates[id] = wasPlaying ? Date() : nil

        guard clamped < duration else {
            performancePlaying.remove(id)
            if performancePlaying.isEmpty { stopPerformanceProgressTimer() }
            onPerformanceItemProgress?(id, duration, duration)
            return
        }

        schedulePerformanceFile(id: id, file: file, token: token, startTime: clamped, includeMonitor: performanceBus.monitorEnabled)
        if wasPlaying {
            performanceBus.startIfNeeded()
            players.play(monitorEnabled: performanceBus.monitorEnabled)
            startPerformanceProgressTimer()
        }
    }

    func stopPerformanceItem(id: UUID) {
        stopPerformanceItem(id: id, notify: true)
    }

    func stopAllPerformanceItems() {
        Array(performancePlayers.keys).forEach { stopPerformanceItem(id: $0, notify: true) }
    }

    func performanceItemCurrentTime(id: UUID) -> TimeInterval {
        updatePerformanceProgress(for: id)
        return performanceOffsets[id] ?? 0
    }

    func fadeMusicVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        musicFadeTask?.cancel()
        musicFadeToken = UUID()
        let token = musicFadeToken
        let start = playlistBus.primary.mixer.outputVolume
        guard duration > 0 else {
            setPlaylistVolume(target)
            completion?()
            return
        }
        musicFadeTask = Task { @MainActor [weak self] in
            let steps = max(1, Int(duration * 30))
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self, !Task.isCancelled, self.musicFadeToken == token else { return }
                let progress = Float(step) / Float(steps)
                self.setPlaylistVolume(start + ((target - start) * progress))
            }
            guard let self, self.musicFadeToken == token else { return }
            self.setPlaylistVolume(target)
            self.musicFadeTask = nil
            completion?()
        }
    }

    private func setPlaylistVolume(_ value: Float) {
        playlistBus.primary.mixer.outputVolume = value
        playlistBus.monitor.mixer.outputVolume = playlistBus.monitorEnabled ? value : 0
    }

    private func cancelMusicFade(restoreVolume: Bool) {
        musicFadeTask?.cancel()
        musicFadeTask = nil
        musicFadeToken = UUID()
        if restoreVolume { setPlaylistVolume(volume) }
    }

    private func makePadPlayers(for id: UUID) -> RoutedAudioPlayers {
        let players = RoutedAudioPlayers(primary: padBus.primary.makePlayer(), monitor: padBus.monitor.makePlayer())
        padPlayers[id] = players
        return players
    }

    private func makePerformancePlayers(for id: UUID) -> RoutedAudioPlayers {
        let players = RoutedAudioPlayers(primary: performanceBus.primary.makePlayer(), monitor: performanceBus.monitor.makePlayer())
        performancePlayers[id] = players
        return players
    }

    private func scheduleMusicFile(
        _ file: AVAudioFile,
        token: UUID,
        startTime: TimeInterval = 0,
        includeMonitor: Bool
    ) {
        let sampleRate = file.fileFormat.sampleRate
        let startingFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let completion: @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.playbackToken == token, self.isPlaying else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                self.stopProgressTimer()
                self.onMusicFinished?()
            }
        }
        if startingFrame > 0 {
            let frameCount = AVAudioFrameCount(max(0, file.length - startingFrame))
            musicPlayers.primary.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: completion)
            if includeMonitor {
                musicPlayers.monitor.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { _ in })
            }
        } else {
            musicPlayers.primary.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: completion)
            if includeMonitor {
                musicPlayers.monitor.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { _ in })
            }
        }
    }

    private func schedulePadLoop(_ file: AVAudioFile, player: AVAudioPlayerNode) {
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self, weak player] _ in
            guard let player else { return }
            Task { @MainActor [weak self, weak player] in
                guard let self, let player else { return }
                self.schedulePadLoop(file, player: player)
            }
        }
    }

    private func schedulePerformanceFile(
        id: UUID,
        file: AVAudioFile,
        token: UUID,
        startTime: TimeInterval = 0,
        includeMonitor: Bool
    ) {
        guard let players = performancePlayers[id] else { return }
        let sampleRate = file.fileFormat.sampleRate
        let startingFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let completion: @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.performanceTokens[id] == token, self.performancePlaying.contains(id) else { return }
                if self.performanceLoops.contains(id) {
                    self.performanceOffsets[id] = 0
                    self.performanceStartDates[id] = Date()
                    self.schedulePerformanceFile(id: id, file: file, token: token, includeMonitor: self.performanceBus.monitorEnabled)
                } else {
                    self.performanceOffsets[id] = self.performanceDurations[id] ?? 0
                    self.performancePlaying.remove(id)
                    self.performanceStartDates[id] = nil
                    self.performanceFiles[id] = nil
                    self.performanceDurations[id] = nil
                    self.performanceLoops.remove(id)
                    self.performanceTokens.removeValue(forKey: id)
                    self.releasePerformancePlayers(id)
                    if self.performancePlaying.isEmpty { self.stopPerformanceProgressTimer() }
                    self.onPerformanceItemFinished?(id)
                }
            }
        }
        if startingFrame > 0 {
            let frameCount = AVAudioFrameCount(max(0, file.length - startingFrame))
            players.primary.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: completion)
            if includeMonitor {
                players.monitor.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { _ in })
            }
        } else {
            players.primary.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: completion)
            if includeMonitor {
                players.monitor.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: { _ in })
            }
        }
    }

    private func stopPerformanceItem(id: UUID, notify: Bool) {
        let hadItem = performanceFiles[id] != nil || performancePlayers[id] != nil
        performanceTokens[id] = UUID()
        releasePerformancePlayers(id)
        performancePlaying.remove(id)
        performanceFiles[id] = nil
        performanceDurations[id] = nil
        performanceOffsets[id] = 0
        performanceStartDates[id] = nil
        performanceLoops.remove(id)
        performanceTokens.removeValue(forKey: id)
        if performancePlaying.isEmpty { stopPerformanceProgressTimer() }
        if notify, hadItem { onPerformanceItemFinished?(id) }
    }

    private func releasePerformancePlayers(_ id: UUID) {
        guard let players = performancePlayers.removeValue(forKey: id) else { return }
        performanceBus.primary.removePlayer(players.primary)
        performanceBus.monitor.removePlayer(players.monitor)
    }

    private func startPerformanceProgressTimer() {
        guard performanceProgressTimer == nil else { return }
        performanceProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for id in self.performancePlaying { self.updatePerformanceProgress(for: id) }
            }
        }
    }

    private func stopPerformanceProgressTimer() {
        performanceProgressTimer?.invalidate()
        performanceProgressTimer = nil
    }

    private func updatePerformanceProgress(for id: UUID) {
        guard let duration = performanceDurations[id] else { return }
        if performancePlaying.contains(id), let startDate = performanceStartDates[id] {
            let now = Date()
            let elapsed = max(0, now.timeIntervalSince(startDate))
            let offset = (performanceOffsets[id] ?? 0) + elapsed
            performanceOffsets[id] = performanceLoops.contains(id) ? offset.truncatingRemainder(dividingBy: duration) : min(offset, duration)
            performanceStartDates[id] = now
        }
        onPerformanceItemProgress?(id, performanceOffsets[id] ?? 0, duration)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateProgress() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying else { return }
        let nodeTime = musicPlayers.primary.lastRenderTime.flatMap { musicPlayers.primary.playerTime(forNodeTime: $0) }
        if let nodeTime, nodeTime.sampleRate > 0 {
            currentTime = min(duration, playbackStartTime + Double(nodeTime.sampleTime) / nodeTime.sampleRate)
        } else {
            currentTime = min(duration, currentTime + 0.1)
        }
    }
}

enum AudioError: LocalizedError {
    case missingFile
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .missingFile: "O arquivo de áudio não está disponível."
        case .emptyFile: "O arquivo de áudio está vazio."
        }
    }
}
