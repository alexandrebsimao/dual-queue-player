import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.dqBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            QueueView(viewModel: viewModel.queueA, mainViewModel: viewModel)
                            QueueView(viewModel: viewModel.queueB, mainViewModel: viewModel)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            SoundPadView(viewModel: viewModel)
                            SettingsView(viewModel: viewModel).frame(width: 270)
                        }
                    }
                    VStack(spacing: 12) {
                        PlayerControlsView(viewModel: viewModel, audio: viewModel.audio)
                        upcomingPanel
                    }
                    .frame(width: 285)
                }
            }
            .padding(14)
            if let message = viewModel.message {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.orange.opacity(0.95))
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar { toolbarContent }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Button("Projeto", systemImage: "folder") { viewModel.openProject() }
                Button("Salvar", systemImage: "square.and.arrow.down") { viewModel.saveProject() }
                Button("Novo", systemImage: "plus") { viewModel.newProject() }
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.horizontal, 8)
        .frame(height: 32)
    }

    private var upcomingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Próxima faixa").font(.system(size: 16, weight: .semibold))
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 18)).frame(width: 44, height: 44)
                    .background(Color.dqPanelRaised).clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.nextTrack?.title ?? "Nenhuma faixa na sequência").lineLimit(2)
                    Text(viewModel.nextTrack?.formattedDuration ?? "--:--").font(.system(size: 12)).foregroundStyle(Color.dqMuted)
                }
            }
            Divider().opacity(0.2)
            HStack(spacing: 10) {
                Image(systemName: viewModel.activeQueueViewModel.queue.playbackMode.symbolName).font(.system(size: 23)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.activeQueueViewModel.queue.playbackMode.title)
                    Text(viewModel.activeQueueViewModel.queue.playbackMode == .manual ? "Aguardando comando" : "Tocará automaticamente")
                        .font(.system(size: 11)).foregroundStyle(Color.dqMuted)
                }
            }
        }
        .padding(16)
        .dqPanel()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { EmptyView() }
    }
}
