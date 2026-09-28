import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct QueueView: View {
    @ObservedObject var viewModel: QueueViewModel
    @ObservedObject var mainViewModel: MainViewModel
    @State private var isClearConfirmationPresented = false
    @State private var draggedTrackID: UUID?
    @State private var lastAutoScrollAt = Date.distantPast

    private var isActive: Bool { mainViewModel.activeQueue == viewModel.identifier }
    private var isPlaying: Bool { mainViewModel.currentQueue == viewModel.identifier && mainViewModel.playbackState == .playing }
    private var accent: Color { .dqAccent(viewModel.identifier.accent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            actionBar
            trackList
            queueControls
        }
        .padding(14)
        .dqPanel()
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? accent : Color.clear, lineWidth: isActive ? 2 : 0))
        .contentShape(Rectangle())
        .onTapGesture { mainViewModel.selectQueue(viewModel.identifier) }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            Task { await viewModel.handleDrop(providers) }
            return true
        }
        .alert("Limpar \(viewModel.queue.name)?", isPresented: $isClearConfirmationPresented) {
            Button("Limpar tudo", role: .destructive) {
                mainViewModel.clearQueue(viewModel.identifier)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as \(viewModel.queue.tracks.count) músicas desta fila serão removidas. Esta ação não pode ser desfeita.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.identifier.shortTitle)
                .font(.system(size: 23, weight: .bold))
                .frame(width: 48, height: 48)
                .background(accent.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(viewModel.queue.name).font(.system(size: 21, weight: .bold))
                    DQBadge(text: isActive ? (isPlaying ? "Tocando" : "Ativa") : "Inativa", color: isActive ? (isPlaying ? .green : accent) : .gray)
                }
                Text("\(viewModel.queue.tracks.count) músicas • \(totalDuration)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dqMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("Modo de reprodução").font(.system(size: 12)).foregroundStyle(Color.dqMuted)
                Picker("Modo", selection: Binding(get: { viewModel.queue.playbackMode }, set: viewModel.setMode)) {
                    ForEach(PlaybackMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button { viewModel.presentAddPanel() } label: {
                Label("Adicionar", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            Button { removeSelected() } label: {
                Label("Remover", systemImage: "trash.fill")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.queue.selectedTrack == nil)
            Button { isClearConfirmationPresented = true } label: {
                Label("Limpar", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.queue.tracks.isEmpty)
            Spacer()
            Text("Arraste para ordenar • solte arquivos aqui")
                .font(.system(size: 11))
                .foregroundStyle(Color.dqMuted)
        }
    }

    private var trackList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("#").frame(width: 28, alignment: .leading)
                Text("Título")
                Spacer()
                Text("Duração").frame(width: 62, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.dqMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            Divider().opacity(0.2)
            if viewModel.queue.tracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list").font(.system(size: 24)).foregroundStyle(Color.dqMuted)
                    Text("Nenhuma música adicionada").foregroundStyle(Color.dqMuted)
                    Text("Use Adicionar ou arraste arquivos para esta fila")
                        .font(.system(size: 12)).foregroundStyle(Color.dqMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 145)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.queue.tracks.enumerated()), id: \.element.id) { index, track in
                                TrackRow(index: index, track: track, isSelected: viewModel.queue.selectedTrackID == track.id, isPlaying: mainViewModel.currentTrack?.id == track.id && isPlaying, preview: {
                                    mainViewModel.preview(track)
                                }, play: {
                                    mainViewModel.play(track, from: viewModel.identifier)
                                }) {
                                    mainViewModel.selectTrack(track, in: viewModel.identifier)
                                } beginDrag: {
                                    draggedTrackID = track.id
                                    return NSItemProvider(
                                        item: track.id.uuidString as NSString,
                                        typeIdentifier: UTType.utf8PlainText.identifier
                                    )
                                }
                                .id(track.id)
                                .onDrop(of: [UTType.utf8PlainText.identifier], delegate: TrackDropDelegate(targetID: track.id, draggedID: $draggedTrackID) { sourceID, targetID in
                                    viewModel.moveTrack(sourceID, before: targetID)
                                } autoScroll: { targetID, localY in
                                    autoScrollIfNeeded(targetID: targetID, localY: localY, proxy: proxy)
                                })
                                .opacity(draggedTrackID == track.id ? 0.45 : 1)
                            }
                        }
                    }
                    .onChange(of: draggedTrackID) { value in
                        if value == nil { lastAutoScrollAt = .distantPast }
                    }
                }
                .frame(minHeight: 145, maxHeight: 230)
            }
        }
        .background(Color.dqRow.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var queueControls: some View {
        HStack(spacing: 10) {
            DQIconButton(systemName: "backward.end.fill", title: "Anterior") { navigateOrSelect { mainViewModel.previous() } }
            DQIconButton(systemName: isPlaying ? "pause.fill" : "play.fill", title: isPlaying ? "Pausar" : "Play", tint: .white, prominent: isActive) { toggleOrSelect() }
            DQIconButton(systemName: "stop.fill", title: "Parar") { if isActive { mainViewModel.stop() } }
            DQIconButton(systemName: "forward.end.fill", title: "Próxima") { navigateOrSelect { mainViewModel.next() } }
        }
    }

    private var totalDuration: String {
        let seconds = viewModel.queue.tracks.reduce(0) { $0 + $1.duration }
        guard seconds > 0 else { return "--:--" }
        return String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func removeSelected() {
        if let selected = viewModel.queue.selectedTrack { viewModel.remove(selected) }
    }

    private func toggleOrSelect() {
        if isActive { mainViewModel.togglePlayPause() }
        else { mainViewModel.selectQueue(viewModel.identifier) }
    }

    private func navigateOrSelect(_ action: () -> Void) {
        if isActive { action() }
        else { mainViewModel.selectQueue(viewModel.identifier) }
    }

    private func autoScrollIfNeeded(targetID: UUID, localY: CGFloat, proxy: ScrollViewProxy) {
        guard let targetIndex = viewModel.queue.tracks.firstIndex(where: { $0.id == targetID }) else { return }

        let rowHeight: CGFloat = 34
        let edgeDistance: CGFloat = 4
        let direction: Int

        if localY <= edgeDistance {
            direction = -1
        } else if localY >= rowHeight - edgeDistance {
            direction = 1
        } else {
            return
        }

        let destinationIndex = targetIndex + direction
        guard viewModel.queue.tracks.indices.contains(destinationIndex) else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAutoScrollAt) > 0.4 else { return }
        lastAutoScrollAt = now

        let destinationID = viewModel.queue.tracks[destinationIndex].id
        withAnimation(.linear(duration: 0.22)) {
            proxy.scrollTo(destinationID, anchor: direction < 0 ? .top : .bottom)
        }
    }
}

private struct TrackDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let move: (UUID, UUID) -> Void
    let autoScroll: (UUID, CGFloat) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard draggedID != nil else { return nil }
        autoScroll(targetID, info.location.y)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private struct TrackRow: View {
    let index: Int
    let track: Track
    let isSelected: Bool
    let isPlaying: Bool
    let preview: () -> Void
    let play: () -> Void
    let select: () -> Void
    let beginDrag: () -> NSItemProvider

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.dqMuted.opacity(0.8))
                .frame(width: 18, height: 24)
            Text(isPlaying ? "▶" : "\(index + 1)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isPlaying ? .white : Color.dqMuted)
                .frame(width: 28, alignment: .leading)
            Image(systemName: track.isMissing ? "exclamationmark.triangle.fill" : "music.note")
                .foregroundStyle(track.isMissing ? .orange : (isPlaying ? .blue : Color.dqMuted))
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).lineLimit(1)
                if track.isMissing { Text("Arquivo ausente").font(.system(size: 10)).foregroundStyle(.orange) }
            }
            Spacer()
            Text(track.formattedDuration).foregroundStyle(Color.dqMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(isSelected ? Color.blue.opacity(0.75) : Color.clear)
        .onTapGesture { select() }
        .simultaneousGesture(TapGesture(count: 2).onEnded { play() })
        .onDrag { beginDrag() }
        .contextMenu {
            Button("Preview", systemImage: "headphones", action: preview)
        }
    }
}
