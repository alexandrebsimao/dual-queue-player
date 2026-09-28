import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedTab: SettingsTab = .audio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ajustes", systemImage: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))

            Picker("Categoria", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbolName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch selectedTab {
                case .audio:
                    audioSettings
                case .playlist:
                    playlistSettings
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(16)
        .dqPanel()
    }

    private var audioSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Saídas de Áudio", systemImage: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("Saída principal (Música + Pads)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
                Text("Dispositivo padrão do macOS")
                    .font(.system(size: 12))
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dqPanelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Divider().opacity(0.2)
            Text("Ajustes de Ducking")
                .font(.system(size: 14, weight: .semibold))
            HStack {
                Text("Volume durante ducking")
                Spacer()
                Text("\(Int(viewModel.duckingController.duckVolume * 100))%")
            }
            .font(.system(size: 12))
            Slider(value: Binding(
                get: { viewModel.duckingController.duckVolume },
                set: {
                    viewModel.duckingController.duckVolume = $0
                    viewModel.autosaveProject()
                }
            ), in: 0...1)
            HStack {
                Text("Fade down")
                Spacer()
                Text("\(viewModel.duckingController.fadeDownDuration, specifier: "%.1f") s")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.dqMuted)
            HStack {
                Text("Fade up")
                Spacer()
                Text("\(viewModel.duckingController.fadeUpDuration, specifier: "%.1f") s")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.dqMuted)
        }
    }

    private var playlistSettings: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Transições da Playlist", systemImage: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .semibold))
            Toggle("Pausa com fade", isOn: Binding(
                get: { viewModel.playlistPlaybackSettings.pauseWithFade },
                set: { value in viewModel.updatePlaylistSettings { $0.pauseWithFade = value } }
            ))
            .font(.system(size: 12))
            Toggle("Stop com fade", isOn: Binding(
                get: { viewModel.playlistPlaybackSettings.stopWithFade },
                set: { value in viewModel.updatePlaylistSettings { $0.stopWithFade = value } }
            ))
            .font(.system(size: 12))
            Picker("Ao parar", selection: Binding(
                get: { viewModel.playlistPlaybackSettings.stopBehavior },
                set: { value in viewModel.updatePlaylistSettings { $0.stopBehavior = value } }
            )) {
                ForEach(PlaylistStopBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .font(.system(size: 12))
            Picker("Troca A/B", selection: Binding(
                get: { viewModel.playlistPlaybackSettings.queueSwitchMode },
                set: { value in viewModel.updatePlaylistSettings { $0.queueSwitchMode = value } }
            )) {
                ForEach(PlaylistQueueSwitchMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .font(.system(size: 12))
            Text(viewModel.playlistPlaybackSettings.queueSwitchMode.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.dqMuted)
            HStack {
                Text("Duração do fade")
                Spacer()
                Text("\(viewModel.playlistPlaybackSettings.fadeDuration, specifier: "%.1f") s")
            }
            .font(.system(size: 12))
            Slider(value: Binding(
                get: { viewModel.playlistPlaybackSettings.fadeDuration },
                set: { value in viewModel.updatePlaylistSettings { $0.fadeDuration = value } }
            ), in: 0.1...5, step: 0.1)
            .tint(.blue)
            Text("O fade é aplicado à pausa, ao stop imediato e às trocas automáticas de fila.")
                .font(.system(size: 11))
                .foregroundStyle(Color.dqMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case audio
    case playlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audio: "Áudio"
        case .playlist: "Playlist"
        }
    }

    var symbolName: String {
        switch self {
        case .audio: "speaker.wave.2.fill"
        case .playlist: "music.note.list"
        }
    }
}
