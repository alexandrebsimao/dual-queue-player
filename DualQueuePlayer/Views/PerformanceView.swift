import SwiftUI

struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    @State private var projectToDelete: PerformanceProject?
    @State private var sceneToDelete: PerformanceScene?
    @State private var isRenamingProject = false
    @State private var isRenamingScene = false
    @State private var projectNameDraft = ""
    @State private var sceneNameDraft = ""

    var body: some View {
        HStack(spacing: 12) {
            projectSidebar
                .frame(width: 235)
            if viewModel.selectedProject != nil {
                mainPanel
            } else {
                emptyPerformanceState
            }
            inspector
                .frame(width: 265)
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
        .alert("Renomear cena", isPresented: $isRenamingScene) {
            TextField("Nome da cena", text: $sceneNameDraft)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                if let scene = viewModel.selectedScene { viewModel.renameScene(scene.id, to: sceneNameDraft) }
            }
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
                        viewModel.addScene()
                    } label: {
                        Image(systemName: "plus.circle.fill")
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
                                        sceneNameDraft = scene.name
                                        isRenamingScene = true
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
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedProject?.name ?? "Performance")
                        .font(.system(size: 22, weight: .bold))
                    Text(viewModel.selectedScene?.name ?? "Selecione ou crie uma cena")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dqMuted)
                }
                Spacer()
                Picker("Visualização", selection: Binding(
                    get: { viewModel.displayMode },
                    set: { viewModel.setDisplayMode($0) }
                )) {
                    ForEach(PerformanceDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

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
                Button("Parar tudo", systemImage: "stop.fill") { viewModel.stopAll() }
                    .buttonStyle(DQPerformanceButtonStyle(tint: .red, prominent: true))
            }
            ProgressView(value: viewModel.currentSceneDuration > 0 ? viewModel.sceneElapsedTime : 0, total: max(viewModel.currentSceneDuration, 1))
                .tint(.orange)
            HStack(spacing: 10) {
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
            }
        }
        .padding(16)
        .dqPanel()
    }

    private var sceneItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.displayMode == .list ? "Sequência da cena" : "Cues agrupadas")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Importar mídias", systemImage: "plus") { viewModel.presentAddItemPanel() }
                    .buttonStyle(DQPerformanceButtonStyle())
            }

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
