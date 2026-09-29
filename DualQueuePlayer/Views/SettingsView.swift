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
                case .outputs:
                    outputSettings
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
            Label("Mixagem e Ducking", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
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

    private var outputSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Rotas de saída", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 14, weight: .semibold))
                Text("Defina as saídas principais e escolha uma única saída de monitor. Depois marque quais grupos devem ser enviados ao monitor.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dqMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 7) {
                    Label("Monitor", systemImage: "headphones")
                        .font(.system(size: 12, weight: .semibold))
                    Picker("Saída do monitor", selection: Binding(
                        get: { viewModel.audioOutputSettings.monitorOutputUID ?? "" },
                        set: { value in viewModel.updateAudioOutputSettings { $0.monitorOutputUID = value.isEmpty ? nil : value } }
                    )) {
                        Text("Sistema (padrão)").tag("")
                        ForEach(viewModel.outputDevices) { device in
                            Text(device.displayName).tag(device.id)
                        }
                    }
                    .font(.system(size: 11))
                    Text("A saída acima é compartilhada por todos os grupos marcados abaixo.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dqMuted)
                }
                .padding(10)
                .background(Color.dqPanelRaised.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 9))

                AudioOutputRouteSection(
                    title: "Playlist",
                    symbolName: "music.note.list",
                    outputUID: Binding(
                        get: { viewModel.audioOutputSettings.playlistOutputUID },
                        set: { value in viewModel.updateAudioOutputSettings { $0.playlistOutputUID = value } }
                    ),
                    monitorEnabled: Binding(
                        get: { viewModel.audioOutputSettings.playlistMonitorEnabled },
                        set: { value in viewModel.updateAudioOutputSettings { $0.playlistMonitorEnabled = value } }
                    ),
                    devices: viewModel.outputDevices
                )
                AudioOutputRouteSection(
                    title: "Pad",
                    symbolName: "square.grid.3x3.fill",
                    outputUID: Binding(
                        get: { viewModel.audioOutputSettings.padOutputUID },
                        set: { value in viewModel.updateAudioOutputSettings { $0.padOutputUID = value } }
                    ),
                    monitorEnabled: Binding(
                        get: { viewModel.audioOutputSettings.padMonitorEnabled },
                        set: { value in viewModel.updateAudioOutputSettings { $0.padMonitorEnabled = value } }
                    ),
                    devices: viewModel.outputDevices
                )
                AudioOutputRouteSection(
                    title: "Performance",
                    symbolName: "theatermasks.fill",
                    outputUID: Binding(
                        get: { viewModel.audioOutputSettings.performanceOutputUID },
                        set: { value in viewModel.updateAudioOutputSettings { $0.performanceOutputUID = value } }
                    ),
                    monitorEnabled: Binding(
                        get: { viewModel.audioOutputSettings.performanceMonitorEnabled },
                        set: { value in viewModel.updateAudioOutputSettings { $0.performanceMonitorEnabled = value } }
                    ),
                    devices: viewModel.outputDevices
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { viewModel.refreshOutputDevices() }
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
    case outputs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audio: "Áudio"
        case .playlist: "Playlist"
        case .outputs: "Saídas"
        }
    }

    var symbolName: String {
        switch self {
        case .audio: "speaker.wave.2.fill"
        case .playlist: "music.note.list"
        case .outputs: "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct AudioOutputRouteSection: View {
    let title: String
    let symbolName: String
    @Binding var outputUID: String?
    @Binding var monitorEnabled: Bool
    let devices: [AudioOutputDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 12, weight: .semibold))

            Picker("Saída principal", selection: outputSelection) {
                Text("Sistema (padrão)").tag("")
                ForEach(devices) { device in
                    Text(device.displayName).tag(device.id)
                }
            }
            .font(.system(size: 11))

            Toggle("Enviar ao monitor", isOn: $monitorEnabled)
                .font(.system(size: 11))
        }
        .padding(10)
        .background(Color.dqPanelRaised.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { outputUID ?? "" },
            set: { outputUID = $0.isEmpty ? nil : $0 }
        )
    }

}
