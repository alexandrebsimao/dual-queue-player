import SwiftUI
import UniformTypeIdentifiers

struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    @ObservedObject var mainViewModel: MainViewModel
    @ObservedObject var audio: AudioEngineManager
    @State private var projectToDelete: PerformanceProject?
    @State private var sceneToDelete: PerformanceScene?
    @State private var isRenamingProject = false
    @State private var projectNameDraft = ""
    @State private var draggedItemID: UUID?
    @State private var isSceneEditorPresented = false
    @State private var sceneBeingEdited: PerformanceScene?
    @State private var isCreatingScene = false

    var body: some View {
        HStack(spacing: 12) {
            projectSidebar
                .frame(width: 250)
            if viewModel.selectedProject != nil {
                mainPanel
            } else {
                emptyPerformanceState
            }
            VStack(spacing: 12) {
                inspector
                playlistPanel
                    .frame(height: 178)
            }
                .frame(width: 330)
        }
        .frame(maxHeight: .infinity)
        .confirmationDialog(
            "Remover espetáculo?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remover espetáculo", role: .destructive) {
                if let projectToDelete { viewModel.removeProject(projectToDelete.id) }
                projectToDelete = nil
            }
            Button("Cancelar", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("O espetáculo \(projectToDelete?.name ?? "") e todas as suas cenas serão removidos.")
        }
        .confirmationDialog(
            "Remover cena?",
            isPresented: Binding(
                get: { sceneToDelete != nil },
                set: { if !$0 { sceneToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remover cena", role: .destructive) {
                if let sceneToDelete { viewModel.removeScene(sceneToDelete.id) }
                sceneToDelete = nil
            }
            Button("Cancelar", role: .cancel) { sceneToDelete = nil }
        } message: {
            Text("A cena \(sceneToDelete?.name ?? "") e seus itens serão removidos.")
        }
        .alert("Renomear espetáculo", isPresented: $isRenamingProject) {
            TextField("Nome do espetáculo", text: $projectNameDraft)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                if let project = viewModel.selectedProject { viewModel.renameProject(project.id, to: projectNameDraft) }
            }
        }
        .sheet(isPresented: $isSceneEditorPresented) {
            PerformanceSceneEditorView(
                scene: sceneBeingEdited,
                onCancel: { isSceneEditorPresented = false },
                onSave: { name, duration in
                    if isCreatingScene {
                        viewModel.addScene(named: name, expectedDuration: duration)
                    } else if let sceneBeingEdited {
                        viewModel.updateScene(sceneBeingEdited.id, name: name, expectedDuration: duration)
                    }
                    isSceneEditorPresented = false
                }
            )
        }
    }

    private var projectSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Espetáculos")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button {
                    viewModel.createProject(named: "Novo espetáculo")
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(DQPerformanceButtonStyle())
                .controlSize(.small)
            }

            if viewModel.projects.isEmpty {
                Text("Crie um espetáculo para preparar cenas e cues.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(viewModel.projects) { project in
                            HStack(spacing: 5) {
                                Button {
                                    viewModel.selectProject(project.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: project.kind.symbolName)
                                            .frame(width: 28, height: 28)
                                            .foregroundStyle(.blue)
                                            .background(Color.blue.opacity(0.16))
                                            .clipShape(RoundedRectangle(cornerRadius: 7))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(project.name).lineLimit(1)
                                            Text("\(project.scenes.count) cenas")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.dqMuted)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                if project.id == viewModel.selectedProjectID {
                                    Button {
                                        projectNameDraft = project.name
                                        isRenamingProject = true
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(DQPerformanceButtonStyle())
                                    Button(role: .destructive) {
                                        projectToDelete = project
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(DQPerformanceButtonStyle(tint: .red))
                                }
                            }
                            .padding(7)
                            .background(project.id == viewModel.selectedProjectID ? Color.blue.opacity(0.35) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Divider().opacity(0.2)
            if viewModel.selectedProject != nil {
                HStack {
                    Text("Cenas")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button {
                        sceneBeingEdited = nil
                        isCreatingScene = true
                        isSceneEditorPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(DQPerformanceButtonStyle())
                }
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(viewModel.selectedProject?.scenes ?? []) { scene in
                            HStack(spacing: 5) {
                                Button {
                                    viewModel.selectScene(scene.id)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\((viewModel.selectedProject?.scenes.firstIndex(where: { $0.id == scene.id }) ?? 0) + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 22, height: 22)
                                            .background(Color.dqPanelRaised)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                        Text(scene.name).lineLimit(1)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                if scene.id == viewModel.selectedSceneID {
                                    Button {
                                        sceneBeingEdited = scene
                                        isCreatingScene = false
                                        isSceneEditorPresented = true
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(DQPerformanceButtonStyle())
                                    Button(role: .destructive) {
                                        sceneToDelete = scene
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(DQPerformanceButtonStyle(tint: .red))
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 5)
                            .background(scene.id == viewModel.selectedSceneID ? Color.white.opacity(0.1) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Spacer()
        }
        .padding(14)
        .dqPanel()
        .frame(maxHeight: .infinity)
    }

    private var mainPanel: some View {
        VStack(spacing: 12) {
            sceneHeader
            sceneItems
            activeItemsPanel
        }
        .frame(maxHeight: .infinity)
    }

    private var sceneHeader: some View {
        VStack(spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.selectedProject?.kind.symbolName ?? "theatermasks")
                    .font(.system(size: 23, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Color.blue.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(viewModel.selectedProject?.name ?? "Performance")
                            .font(.system(size: 21, weight: .bold))
                        DQBadge(text: "Performance", color: .blue)
                    }
                    Text(viewModel.selectedScene?.name ?? "Selecione ou crie uma cena")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.dqMuted)
                    if let expectedDuration = viewModel.selectedScene?.expectedDuration {
                        Text("\(viewModel.currentItems.count) cues • duração \(formatTime(expectedDuration))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dqMuted)
                    } else {
                        Text("\(viewModel.currentItems.count) cues")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dqMuted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Editar cena", systemImage: "pencil") {
                            sceneBeingEdited = viewModel.selectedScene
                            isCreatingScene = false
                            isSceneEditorPresented = true
                        }
                        .buttonStyle(DQPerformanceButtonStyle())
                        Picker("Visualização", selection: Binding(
                            get: { viewModel.displayMode },
                            set: { viewModel.setDisplayMode($0) }
                        )) {
                            ForEach(PerformanceDisplayMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbolName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    Button("Parar tudo", systemImage: "stop.fill") { viewModel.stopAll() }
                        .buttonStyle(DQPerformanceButtonStyle(tint: .red, prominent: true))
                }
            }

            if viewModel.selectedScene?.expectedDuration != nil {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.sceneClockState == .running ? "timer" : "clock")
                        .foregroundStyle(.orange)
                    Text(formatTime(viewModel.sceneElapsedTime))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                    Text("/ \(formatTime(viewModel.currentSceneDuration))")
                        .foregroundStyle(Color.dqMuted)
                    Spacer()
                    Button(viewModel.sceneClockState == .running ? "Pausar" : "Iniciar", systemImage: viewModel.sceneClockState == .running ? "pause.fill" : "play.fill") {
                        if viewModel.sceneClockState == .running { viewModel.pauseSceneClock() }
                        else { viewModel.startSceneClock() }
                    }
                    .buttonStyle(DQPerformanceButtonStyle())
                    Button("Zerar", systemImage: "arrow.counterclockwise") { viewModel.resetSceneClock() }
                        .buttonStyle(DQPerformanceButtonStyle())
                }
                ProgressView(value: viewModel.sceneElapsedTime, total: max(viewModel.currentSceneDuration, 1))
                    .tint(.orange)
            }
            HStack(spacing: 14) {
                Toggle("Permitir sobreposição de mídias", isOn: Binding(
                    get: { viewModel.selectedProject?.mixMode == .overlay },
                    set: { viewModel.setMixMode($0 ? .overlay : .singleActive) }
                ))
                .toggleStyle(.switch)
                .font(.system(size: 12))
                Text(viewModel.selectedProject?.mixMode == .overlay ? "Várias ativas" : "Uma por vez")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dqMuted)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                    Text("P toca/pausa • ⇧P para")
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.dqMuted)
            }
        }
        .padding(16)
        .dqPanel()
    }

    private var playlistPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.dqPanelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Playlist em segundo plano")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(mainViewModel.currentTrack?.title ?? "Nenhuma faixa selecionada")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dqMuted)
                        .lineLimit(1)
                }
                Spacer()
                if let currentQueue = mainViewModel.currentQueue {
                    DQBadge(text: currentQueue.title, color: .blue)
                }
            }
            HStack(spacing: 8) {
                Button(
                    mainViewModel.playbackState == .playing ? "Pausar playlist" : "Iniciar playlist",
                    systemImage: mainViewModel.playbackState == .playing ? "pause.fill" : "play.fill"
                ) {
                    mainViewModel.togglePlayPause()
                }
                .buttonStyle(DQPerformanceButtonStyle(tint: .blue, prominent: true))
                .frame(maxWidth: .infinity)
                Button("Parar playlist", systemImage: "stop.fill") {
                    mainViewModel.stop()
                }
                .buttonStyle(DQPerformanceButtonStyle(tint: .red))
                .frame(maxWidth: .infinity)
            }
            Slider(
                value: Binding(
                    get: { audio.currentTime },
                    set: { mainViewModel.seek(to: $0) }
                ),
                in: 0...max(audio.duration, 1)
            )
            .tint(.blue)
            HStack {
                Text(formatTime(audio.currentTime))
                Spacer()
                Text(formatTime(audio.duration))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.dqMuted)
        }
        .padding(14)
        .dqPanel()
    }

    private var sceneItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.displayMode == .list ? "Sequência da cena" : "Cues agrupadas")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Importar mídias", systemImage: "plus") { viewModel.presentAddItemPanel() }
                    .buttonStyle(DQPerformanceButtonStyle(tint: .blue, prominent: true))
            }

            HStack(spacing: 10) {
                Text("#").frame(width: 22)
                Text("Cue")
                Spacer()
                Text("Classificação").frame(width: 95, alignment: .leading)
                Text("Duração").frame(width: 56, alignment: .trailing)
                Text("").frame(width: 86)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.dqMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.dqRow.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            ScrollView {
                LazyVStack(spacing: 6) {
                    if viewModel.displayMode == .list {
                        ForEach(Array(viewModel.currentItems.enumerated()), id: \.element.id) { index, item in
                            itemRow(item, index: index + 1)
                        }
                    } else {
                        ForEach(viewModel.groupedItems, id: \.classification) { group in
                            HStack {
                                Image(systemName: group.classification.symbolName)
                                Text(group.classification.title)
                                    .font(.system(size: 12, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(Color.dqAccent(group.classification.color))
                            .padding(.top, 7)
                            ForEach(group.items) { item in
                                itemRow(item, index: viewModel.currentItems.firstIndex(where: { $0.id == item.id }).map { $0 + 1 } ?? 0)
                            }
                        }
                    }
                    if viewModel.currentItems.isEmpty {
                        Text("Esta cena ainda não tem itens. Adicione uma faixa, efeito, voz ou ambiente.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dqMuted)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
            }
        }
        .padding(14)
        .dqPanel()
        .frame(maxHeight: .infinity)
    }

    private func itemRow(_ item: PerformanceItem, index: Int) -> some View {
        let active = viewModel.activeItems[item.id]
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dqMuted)
                .help("Arraste para reordenar")
            Text("\(index)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.dqMuted)
                .frame(width: 22)
            Image(systemName: item.classification.symbolName)
                .foregroundStyle(Color.dqAccent(item.classification.color))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(item.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
                    if item.playback == .loop { DQBadge(text: "Loop", color: .orange) }
                    if item.isMissing { DQBadge(text: "Ausente", color: .red) }
                }
                HStack(spacing: 8) {
                    Text(item.classification.title)
                    Text(item.formattedDuration)
                    if let active { Text("• \(formatTime(active.currentTime))") }
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.dqMuted)
            }
            Spacer()
            VStack(spacing: 2) {
                Button {
                    viewModel.moveItem(item.id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(DQPerformanceButtonStyle())
                .disabled(index <= 1)
                .opacity(index <= 1 ? 0.35 : 1)
                Button {
                    viewModel.moveItem(item.id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(DQPerformanceButtonStyle())
                .disabled(index >= viewModel.currentItems.count)
                .opacity(index >= viewModel.currentItems.count ? 0.35 : 1)
            }
            if let active {
                Button { active.state == .playing ? viewModel.pause(item.id) : viewModel.resume(item.id) } label: {
                    Image(systemName: active.state == .playing ? "pause.fill" : "play.fill")
                }
                .buttonStyle(DQPerformanceButtonStyle())
                Button { viewModel.stop(item.id) } label: { Image(systemName: "stop.fill") }
                    .buttonStyle(DQPerformanceButtonStyle(tint: .red))
            } else {
                Button { viewModel.trigger(item.id) } label: { Image(systemName: "play.fill") }
                    .buttonStyle(DQPerformanceButtonStyle(tint: .blue, prominent: true))
            }
            }
            if let active {
                Slider(
                    value: Binding(
                        get: { active.currentTime },
                        set: { viewModel.seek(item.id, to: $0) }
                    ),
                    in: 0...max(active.duration, 1)
                )
                .tint(.blue)
                .padding(.horizontal, 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(item.id == viewModel.selectedItemID ? Color.blue.opacity(0.24) : Color.dqRow)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectItem(item.id) }
        .onDrag {
            draggedItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [UTType.text.identifier],
            delegate: PerformanceItemDropDelegate(
                itemID: item.id,
                draggedItemID: $draggedItemID,
                viewModel: viewModel
            )
        )
    }

    private var activeItemsPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Ativos agora").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(viewModel.activeItems.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }
            if viewModel.activeItemsList.isEmpty {
                Text("Nenhum áudio em execução")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
            } else {
                ForEach(viewModel.activeItemsList) { active in
                    let name = viewModel.currentItems.first(where: { $0.id == active.id })?.name ?? "Item"
                    HStack {
                        Circle().fill(active.state == .playing ? .green : .orange).frame(width: 8, height: 8)
                        Text(name).lineLimit(1)
                        Spacer()
                        Text("\(formatTime(active.currentTime)) / \(formatTime(active.duration))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.dqMuted)
                    }
                }
            }
            HStack {
                Button("Pausar tudo", systemImage: "pause.fill") { viewModel.pauseAll() }
                    .buttonStyle(DQPerformanceButtonStyle())
                Button("Retomar", systemImage: "play.fill") { viewModel.resumeAll() }
                    .buttonStyle(DQPerformanceButtonStyle())
            }
        }
        .padding(14)
        .dqPanel()
        .frame(minHeight: 108, maxHeight: 150)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Detalhes do item")
                .font(.system(size: 17, weight: .semibold))
            if let item = selectedItem {
                TextField("Nome", text: Binding(
                    get: { item.name },
                    set: { updateItem(item, name: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                Picker("Classificação", selection: Binding(
                    get: { item.classification },
                    set: { updateItem(item, classification: $0) }
                )) {
                    ForEach(PerformanceClassification.allCases) { classification in
                        Text(classification.title).tag(classification)
                    }
                }
                Toggle("Repetir em loop", isOn: Binding(
                    get: { item.playback == .loop },
                    set: { updateItem(item, playback: $0 ? .loop : .once) }
                ))
                Toggle("Continuar na troca de cena", isOn: Binding(
                    get: { item.transition == .keepOnSceneChange },
                    set: { updateItem(item, transition: $0 ? .keepOnSceneChange : .stopOnSceneChange) }
                ))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(item.volume * 100))%")
                            .foregroundStyle(Color.dqMuted)
                    }
                    Slider(value: Binding(
                        get: { item.volume },
                        set: { updateItem(item, volume: $0) }
                    ), in: 0...1)
                }
                Text(item.fileURL?.lastPathComponent ?? "Nenhum arquivo selecionado")
                    .font(.system(size: 12))
                    .foregroundStyle(item.isMissing ? .red : Color.dqMuted)
                    .lineLimit(2)
                Divider().opacity(0.2)
                Button("Remover item", systemImage: "trash") { viewModel.removeItem(item.id) }
                    .buttonStyle(DQPerformanceButtonStyle(tint: .red))
            } else {
                Text("Selecione um item para editar classificação, volume, loop e comportamento na troca de cena.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .dqPanel()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var selectedItem: PerformanceItem? {
        viewModel.currentItems.first(where: { $0.id == viewModel.selectedItemID })
    }

    private var emptyPerformanceState: some View {
        VStack(spacing: 14) {
            Image(systemName: "theatermasks").font(.system(size: 44)).foregroundStyle(.blue)
            Text("Prepare seu primeiro espetáculo").font(.system(size: 20, weight: .bold))
            Text("Crie cenas e dispare trilhas, efeitos, vozes e ambientes em paralelo.")
                .foregroundStyle(Color.dqMuted)
            Button("Novo espetáculo", systemImage: "plus") { viewModel.createProject(named: "Novo espetáculo") }
                .buttonStyle(DQPerformanceButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dqPanel()
    }

    private func updateItem(_ item: PerformanceItem, name: String? = nil, classification: PerformanceClassification? = nil, playback: PerformancePlayback? = nil, transition: PerformanceTransition? = nil, volume: Double? = nil) {
        var updated = item
        if let name { updated.name = name }
        if let classification { updated.classification = classification }
        if let playback { updated.playback = playback }
        if let transition { updated.transition = transition }
        if let volume { updated.volume = volume }
        viewModel.updateItem(updated)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct PerformanceSceneEditorView: View {
    let scene: PerformanceScene?
    let onCancel: () -> Void
    let onSave: (String, TimeInterval?) -> Void

    @State private var usesAutomaticDuration: Bool
    @State private var name: String
    @State private var minutes: String
    @State private var seconds: String

    init(scene: PerformanceScene?, onCancel: @escaping () -> Void, onSave: @escaping (String, TimeInterval?) -> Void) {
        self.scene = scene
        self.onCancel = onCancel
        self.onSave = onSave
        let duration = scene?.expectedDuration ?? 0
        _name = State(initialValue: scene?.name ?? "Nova cena")
        _usesAutomaticDuration = State(initialValue: scene?.expectedDuration == nil)
        _minutes = State(initialValue: String(Int(duration) / 60))
        _seconds = State(initialValue: String(Int(duration) % 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(scene == nil ? "Nova cena" : "Editar cena")
                .font(.system(size: 18, weight: .bold))
            TextField("Nome da cena", text: $name)
                .textFieldStyle(.roundedBorder)

            Toggle("Definir duração da cena", isOn: Binding(
                get: { !usesAutomaticDuration },
                set: { usesAutomaticDuration = !$0 }
            ))

            if !usesAutomaticDuration {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Minutos")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dqMuted)
                        TextField("0", text: $minutes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Segundos")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dqMuted)
                        TextField("0", text: $seconds)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                    }
                }
            } else {
                Text("Sem duração definida, o relógio da cena não será exibido.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
            }

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .buttonStyle(DQPerformanceButtonStyle())
                Button("Salvar") {
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let duration = usesAutomaticDuration || manualDuration <= 0 ? nil : manualDuration
                    onSave(cleanName.isEmpty ? "Nova cena" : cleanName, duration)
                }
                .buttonStyle(DQPerformanceButtonStyle(prominent: true))
            }
        }
        .padding(22)
        .frame(width: 360)
    }

    private var manualDuration: TimeInterval {
        let minuteValue = max(0, Int(minutes.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        let secondValue = min(max(0, Int(seconds.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0), 59)
        return TimeInterval((minuteValue * 60) + secondValue)
    }
}

private struct PerformanceItemDropDelegate: DropDelegate {
    let itemID: UUID
    @Binding var draggedItemID: UUID?
    let viewModel: PerformanceViewModel

    func dropEntered(info: DropInfo) {
        guard let draggedItemID, draggedItemID != itemID else { return }
        viewModel.moveItem(draggedItemID, before: itemID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
