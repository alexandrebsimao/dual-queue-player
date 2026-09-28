import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var audio: AudioEngineManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reprodução Atual").font(.system(size: 16, weight: .semibold))
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .frame(width: 48, height: 48)
                    .background(Color.dqPanelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentTrack?.title ?? "Nenhuma música selecionada")
                        .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(viewModel.currentQueue?.title ?? "Aguardando reprodução")
                        .font(.system(size: 12)).foregroundStyle(Color.dqMuted)
                }
                Spacer()
            }
            Slider(value: Binding(get: { audio.currentTime }, set: viewModel.seek(to:)), in: 0...max(audio.duration, 1))
                .tint(.blue)
            HStack {
                Text(format(audio.currentTime))
                Spacer()
                Text(format(audio.duration))
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color.dqMuted)
            HStack(spacing: 10) {
                DQIconButton(systemName: "backward.end.fill", title: nil) { viewModel.previous() }
                DQIconButton(systemName: viewModel.playbackState == .playing ? "pause.fill" : "play.fill", title: nil, tint: .white, prominent: true) { viewModel.togglePlayPause() }
                DQIconButton(systemName: "stop.fill", title: nil) { viewModel.stop() }
                DQIconButton(systemName: "forward.end.fill", title: nil) { viewModel.next() }
            }
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(Color.dqMuted)
                Slider(value: $viewModel.masterVolume, in: 0...1).tint(.blue)
                Text("\(Int(viewModel.masterVolume * 100))%")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.dqMuted)
            }
        }
        .padding(16)
        .dqPanel()
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "00:00" }
        return String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
