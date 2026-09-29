import AVFoundation
import AudioToolbox
import Foundation

@MainActor
final class AudioOutputBus {
    let engine = AVAudioEngine()
    let mixer = AVAudioMixerNode()

    init(label: String) {
        engine.attach(mixer)
        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)
    }

    func makePlayer() -> AVAudioPlayerNode {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let format = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(player, to: mixer, format: format)
        return player
    }

    func startIfNeeded() {
        guard !engine.isRunning else { return }
        do { try engine.start() }
        catch { NSLog("DualQueue: não foi possível reiniciar o barramento: %@", error.localizedDescription) }
    }

    func stop() {
        engine.stop()
    }

    func removePlayer(_ player: AVAudioPlayerNode) {
        player.stop()
        engine.detach(player)
    }

    func setOutputDevice(uid: String?) {
        guard let deviceID = AudioOutputDeviceCatalog.deviceID(for: uid),
              let audioUnit = engine.outputNode.audioUnit else { return }

        var selectedDevice = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDevice,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            NSLog("DualQueue: não foi possível selecionar a saída de áudio: %d", status)
        }
    }
}

@MainActor
final class AudioOutputBusPair {
    let primary: AudioOutputBus
    let monitor: AudioOutputBus

    private(set) var primaryEnabled = true
    private(set) var monitorEnabled = false

    init(label: String) {
        primary = AudioOutputBus(label: label)
        monitor = AudioOutputBus(label: "\(label) Monitor")
        monitor.mixer.outputVolume = 0
    }

    func apply(outputUID: String?, primaryEnabled: Bool, monitorEnabled: Bool, monitorUID: String?) {
        primary.setOutputDevice(uid: outputUID)
        monitor.setOutputDevice(uid: monitorUID)
        self.primaryEnabled = primaryEnabled || !monitorEnabled
        self.monitorEnabled = monitorEnabled
        primary.mixer.outputVolume = self.primaryEnabled ? 1 : 0
        monitor.mixer.outputVolume = monitorEnabled ? 1 : 0
        if !monitorEnabled { monitor.stop() }
    }

    func startIfNeeded() {
        primary.startIfNeeded()
        if monitorEnabled { monitor.startIfNeeded() }
    }

    func stop() {
        primary.stop()
        monitor.stop()
    }
}

struct RoutedAudioPlayers {
    let primary: AVAudioPlayerNode
    let monitor: AVAudioPlayerNode

    func play(primaryEnabled: Bool, monitorEnabled: Bool) {
        if primaryEnabled { primary.play() } else { primary.stop() }
        if monitorEnabled { monitor.play() } else { monitor.stop() }
    }

    func pause(primaryEnabled: Bool, monitorEnabled: Bool) {
        if primaryEnabled { primary.pause() } else { primary.stop() }
        if monitorEnabled { monitor.pause() } else { monitor.stop() }
    }

    func stop() {
        primary.stop()
        monitor.stop()
    }
}
