import AVFoundation
import Combine
import Foundation

/// Player de escuta prévia, deliberadamente separado do player principal.
///
/// O macOS permite trocar o dispositivo padrão do sistema, mas o routing por
/// dispositivo individual exige uma camada Core Audio dedicada. Por isso esta
/// primeira versão mantém a saída padrão e não altera a música principal.
@MainActor
final class PreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrack: Track?
    @Published private(set) var availableOutputNames: [String] = ["Dispositivo padrão do macOS"]
    @Published var selectedOutputName = "Dispositivo padrão do macOS"

    private var player: AVAudioPlayer?

    func preview(_ track: Track) {
        stop()
        guard FileManager.default.fileExists(atPath: track.fileURL.path) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: track.fileURL)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            currentTrack = track
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            self?.currentTrack = nil
            self?.player = nil
        }
    }
}
