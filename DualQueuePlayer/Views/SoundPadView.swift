import SwiftUI

struct SoundPadView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var editingPad: SoundPad?
    @State private var isPageEditorPresented = false
    @State private var isCreatingPage = true
    @State private var pageNameDraft = ""
    @State private var isDeleteConfirmationPresented = false
    @State private var padPendingDeletion: SoundPad?
    @State private var isPadDeleteConfirmationPresented = false

    private var page: SoundPadPage {
        guard viewModel.padPages.indices.contains(viewModel.selectedPadPageIndex) else { return SoundPadPage(name: "Vinhetas") }
        return viewModel.padPages[viewModel.selectedPadPageIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.purple)
                    .font(.system(size: 20))
                Text("Sound Pad").font(.system(size: 20, weight: .bold))
                Spacer()
                Picker("Página", selection: $viewModel.selectedPadPageIndex) {
                    ForEach(Array(viewModel.padPages.enumerated()), id: \.element.id) { index, page in
                        Text(page.name).tag(index)
                    }
                }
                .frame(width: 140)
                Button { presentPageEditor(forNewPage: true) } label: { Image(systemName: "plus") }
                    .buttonStyle(.bordered)
                    .help("Criar página")
                Button { presentPageEditor(forNewPage: false) } label: { Image(systemName: "pencil") }
                    .buttonStyle(.bordered)
                    .help("Renomear página")
                Button { isDeleteConfirmationPresented = true } label: { Image(systemName: "trash") }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.padPages.count <= 1)
                    .help("Excluir página")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<12, id: \.self) { index in
                    if page.pads.indices.contains(index) {
                        let pad = page.pads[index]
                        SoundPadCell(pad: pad) {
                            viewModel.triggerPad(pad)
                        } edit: {
                            editingPad = pad
                        }
                    } else {
                        Button { addPad() } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 20))
                                Text("Adicionar Pad").font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity, minHeight: 78)
                            .foregroundStyle(Color.dqMuted)
                            .background(Color.dqRow.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .dqPanel()
        .sheet(isPresented: $isPageEditorPresented) {
            PageNameEditorView(
                title: isCreatingPage ? "Nova página" : "Renomear página",
                name: $pageNameDraft,
                onCancel: { isPageEditorPresented = false },
                onSave: savePageName
            )
            .onAppear { viewModel.setKeyboardShortcutsEnabled(false) }
            .onDisappear { viewModel.setKeyboardShortcutsEnabled(true) }
        }
        .alert("Excluir página?", isPresented: $isDeleteConfirmationPresented) {
            Button("Excluir", role: .destructive) {
                viewModel.deleteSelectedPadPage()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A página \"\(page.name)\" e todos os pads configurados nela serão removidos.")
        }
        .alert("Excluir pad?", isPresented: $isPadDeleteConfirmationPresented) {
            Button("Excluir", role: .destructive) {
                if let padPendingDeletion {
                    viewModel.removePad(id: padPendingDeletion.id)
                }
                padPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                padPendingDeletion = nil
            }
        } message: {
            Text("O pad \"\(padPendingDeletion?.name ?? "")\" será removido desta página.")
        }
        .sheet(item: $editingPad) { pad in
            SoundPadEditorView(
                pad: pad,
                onSave: { updated in
                    viewModel.updatePad(updated)
                    editingPad = nil
                },
                onDelete: {
                    padPendingDeletion = pad
                    isPadDeleteConfirmationPresented = true
                    editingPad = nil
                }
            )
            .onAppear { viewModel.setKeyboardShortcutsEnabled(false) }
            .onDisappear { viewModel.setKeyboardShortcutsEnabled(true) }
        }
    }

    private func addPad() {
        guard viewModel.padPages.indices.contains(viewModel.selectedPadPageIndex), viewModel.padPages[viewModel.selectedPadPageIndex].pads.count < 12 else { return }
        let number = viewModel.padPages[viewModel.selectedPadPageIndex].pads.count + 1
        viewModel.padPages[viewModel.selectedPadPageIndex].pads.append(SoundPad(name: "Pad \(number)"))
        viewModel.autosaveProject()
    }

    private func presentPageEditor(forNewPage isNewPage: Bool) {
        isCreatingPage = isNewPage
        pageNameDraft = isNewPage ? "" : page.name
        isPageEditorPresented = true
    }

    private func savePageName() {
        if isCreatingPage {
            viewModel.addPadPage(named: pageNameDraft)
        } else {
            viewModel.renameSelectedPadPage(to: pageNameDraft)
        }
        isPageEditorPresented = false
    }
}

private struct PageNameEditorView: View {
    let title: String
    @Binding var name: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            TextField("Nome da página", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSave() } }
            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                Button("Salvar", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct SoundPadCell: View {
    let pad: SoundPad
    let play: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: play) {
            HStack(alignment: .top, spacing: 9) {
                Text(String(pad.name.split(separator: " ").last ?? "1"))
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 25, height: 25)
                    .background(Color.purple.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: pad.iconName).font(.system(size: 17)).foregroundStyle(.purple)
                    Text(pad.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(pad.mode.title).font(.system(size: 10)).foregroundStyle(Color.dqMuted)
                }
                Spacer()
            }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)

            Button(action: edit) {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
                .buttonStyle(.plain)
                .foregroundStyle(Color.dqMuted)
        }
        .padding(10)
        .background(Color.dqRow)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.purple.opacity(0.2)))
        }

}

struct SoundPadEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pad: SoundPad
    let onSave: (SoundPad) -> Void
    let onDelete: () -> Void

    init(pad: SoundPad, onSave: @escaping (SoundPad) -> Void, onDelete: @escaping () -> Void) {
        _pad = State(initialValue: pad)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuração do Pad").font(.title2.bold())
            TextField("Nome", text: $pad.name)
            HStack {
                Text(pad.fileURL?.lastPathComponent ?? "Nenhum arquivo selecionado")
                    .foregroundStyle(Color.dqMuted).lineLimit(1)
                Spacer()
                Button("Escolher…") { chooseFile() }
            }
            Picker("Ícone", selection: $pad.iconName) {
                ForEach(soundPadIconOptions, id: \.self) { icon in
                    Label(icon, systemImage: icon).tag(icon)
                }
            }
            Picker("Modo", selection: $pad.mode) { ForEach(SoundPadMode.allCases) { Text($0.title).tag($0) } }
            HStack { Text("Volume"); Slider(value: $pad.volume, in: 0...1); Text("\(Int(pad.volume * 100))%") }
            Toggle("Parar outros pads ao tocar", isOn: $pad.stopsOtherPads)
            Toggle("Loop", isOn: $pad.loops)
            TextField("Atalho opcional", text: Binding(get: { pad.keyboardShortcut ?? "" }, set: { pad.keyboardShortcut = $0.isEmpty ? nil : $0 }))
            HStack {
                Button("Excluir", role: .destructive, action: onDelete)
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar") { onSave(pad); dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 430)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aac", "aiff"]
        if panel.runModal() == .OK { pad.fileURL = panel.url }
    }
}

private let soundPadIconOptions = [
    "music.note", "speaker.wave.2.fill", "bell.fill", "star.fill",
    "bolt.fill", "exclamationmark.triangle.fill", "checkmark.circle.fill",
    "person.3.fill", "mic.fill", "wind", "waveform", "party.popper.fill"
]
