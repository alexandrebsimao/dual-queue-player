import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Saídas de Áudio", systemImage: "speaker.wave.2.fill")
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("Saída principal (Música + Pads)").font(.system(size: 12)).foregroundStyle(Color.dqMuted)
                Text("Dispositivo padrão do macOS").padding(9).frame(maxWidth: .infinity, alignment: .leading).background(Color.dqPanelRaised).clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Divider().opacity(0.2)
            Text("Ajustes de Ducking").font(.system(size: 14, weight: .semibold))
            HStack { Text("Volume durante ducking"); Spacer(); Text("\(Int(viewModel.duckingController.duckVolume * 100))%") }
                .font(.system(size: 12))
            Slider(value: Binding(get: { viewModel.duckingController.duckVolume }, set: { viewModel.duckingController.duckVolume = $0; viewModel.autosaveProject() }), in: 0...1)
            HStack { Text("Fade down"); Spacer(); Text("\(viewModel.duckingController.fadeDownDuration, specifier: "%.1f") s") }
                .font(.system(size: 12)).foregroundStyle(Color.dqMuted)
            HStack { Text("Fade up"); Spacer(); Text("\(viewModel.duckingController.fadeUpDuration, specifier: "%.1f") s") }
                .font(.system(size: 12)).foregroundStyle(Color.dqMuted)
            Spacer()
        }
        .padding(16)
        .dqPanel()
    }
}
