import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioEngineManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var volume: Float = 0.8 {
        didSet { musicMixer.outputVolume = volume }
    }

    var onMusicFinished: (() -> Void)?
    var onPadFinished: ((UUID) -> Void)?

    private let engine = AVAudioEngine()
    private let musicPlayer = AVAudioPlayerNode()
    private let musicMixer = AVAudioMixerNode()
    private let padMixer = AVAudioMixerNode()
    private var padPlayers: [UUID: AVAudioPlayerNode] = [:]
    private var scheduledFile: AVAudioFile?
    private var playbackStartTime: TimeInterval = 0
    private var progressTimer: Timer?
    private var musicURL: URL?
    private var playbackToken = UUID()

    override init() {
        super.init()
        configureEngine()
    }

    deinit {
        progressTimer?.invalidate()
    }

    private func configureEngine() {
        engine.attach(musicPlayer)
        engine.attach(musicMixer)
        engine.attach(padMixer)

        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(musicPlayer, to: musicMixer, format: format)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: format)
        engine.connect(padMixer, to: engine.mainMixerNode, format: format)
        musicMixer.outputVolume = volume

        do {
            try engine.start()
        } catch {
            NSLog("DualQueue: não foi possível iniciar AVAudioEngine: %@", error.localizedDescription)
        }
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

        if !engine.isRunning { try engine.start() }
        musicPlayer.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.playbackToken == token, self.isPlaying else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                self.stopProgressTimer()
                self.onMusicFinished?()
            }
        }
        musicPlayer.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        guard isPlaying else { return }
        updateProgress()
        musicPlayer.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        guard scheduledFile != nil else { return }
        if !engine.isRunning { try? engine.start() }
        musicPlayer.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        playbackToken = UUID()
        musicPlayer.stop()
        isPlaying = false
        currentTime = 0
        playbackStartTime = 0
        scheduledFile = nil
        musicURL = nil
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        guard let file = scheduledFile else { return }
        let clamped = min(max(time, 0), duration)
        let frame = AVAudioFramePosition(clamped * file.fileFormat.sampleRate)
        guard frame < file.length else { return }

        let wasPlaying = isPlaying
        playbackToken = UUID()
        let token = playbackToken
        musicPlayer.stop()
        musicPlayer.scheduleSegment(file, startingFrame: frame, frameCount: AVAudioFrameCount(file.length - frame), at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.playbackToken == token, self.isPlaying else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                self.stopProgressTimer()
                self.onMusicFinished?()
            }
        }
        currentTime = clamped
        playbackStartTime = clamped
        if wasPlaying {
            musicPlayer.play()
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

        let player = padPlayers[pad.id] ?? makePadPlayer(for: pad.id)
        player.volume = Float(pad.volume)
        if pad.loops {
            player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self, weak player] _ in
                guard let player else { return }
                player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in }
            }
        } else {
            player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in self?.onPadFinished?(pad.id) }
            }
        }
        if !engine.isRunning { try engine.start() }
        player.play()
    }

    func stopPad(_ id: UUID) {
        padPlayers[id]?.stop()
        onPadFinished?(id)
    }

    func fadeMusicVolume(to target: Float, duration: TimeInterval) {
        let start = musicMixer.outputVolume
        guard duration > 0 else { musicMixer.outputVolume = target; return }
        Task { @MainActor [weak self] in
            let steps = max(1, Int(duration * 30))
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self else { return }
                let progress = Float(step) / Float(steps)
                self.musicMixer.outputVolume = start + ((target - start) * progress)
                if step == steps { self.volume = target }
            }
        }
    }

    private func makePadPlayer(for id: UUID) -> AVAudioPlayerNode {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(player, to: padMixer, format: format)
        padPlayers[id] = player
        return player
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
        let nodeTime = musicPlayer.lastRenderTime.flatMap { musicPlayer.playerTime(forNodeTime: $0) }
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
