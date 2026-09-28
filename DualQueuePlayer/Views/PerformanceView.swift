import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum PerformanceScreen: String, CaseIterable, Identifiable {
    case projects
    case execution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: "Espetáculos"
        case .execution: "Execução"
        }
    }

    var symbolName: String {
        switch self {
        case .projects: "square.grid.2x2"
        case .execution: "play.rectangle"
        }
    }
}

struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    @State private var screen: PerformanceScreen = .execution
    @State private var isProjectEditorPresented = false
    @State private var isSceneEditorPresented = false
    @State private var isEditingSceneName = false
    @State private var isEditingProjectName = false
    @State private var projectNameDraft = ""
    @State private var sceneNameDraft = ""
    @State private var expectedDurationDraft = ""
    @State private var editingItem: PerformanceItem?
    @State private var expandedItemID: UUID?
    @State private var draggedItemID: UUID?
    @State private var draggedSceneID: UUID?
    @State private var isDeleteProjectConfirmationPresented = false
    @State private var isDeleteSceneConfirmationPresented = false

    var body: some View {
        VStack(spacing: 12) {
            performanceNavigation
            if screen == .projects {
                projectBrowser
            } else {
                HStack(alignment: .top, spacing: 12) {
                    projectSidebar
                        .frame(width: 220)
                    if viewModel.selectedProject != nil {
                        workspace
                    } else {
                        emptyWorkspace
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isProjectEditorPresented) {
            NameEditorView(title: "Novo espetáculo", placeholder: "Nome do espetáculo", name: $projectNameDraft) {
                viewModel.createProject(named: projectNameDraft)
                isProjectEditorPresented = false
            } onCancel: {
                isProjectEditorPresented = false
            }
        }
        .sheet(isPresented: $isSceneEditorPresented) {
            NameEditorView(title: "Nova cena", placeholder: "Nome da cena", name: $sceneNameDraft) {
                viewModel.addScene(named: sceneNameDraft)
                isSceneEditorPresented = false
            } onCancel: {
                isSceneEditorPresented = false
            }
        }
        .sheet(isPresented: $isEditingProjectName) {
            NameEditorView(title: "Renomear espetáculo", placeholder: "Nome do espetáculo", name: $projectNameDraft) {
                if let projectID = viewModel.selectedProjectID { viewModel.renameProject(projectID, to: projectNameDraft) }
                isEditingProjectName = false
            } onCancel: {
                isEditingProjectName = false
            }
        }
        .sheet(isPresented: $isEditingSceneName) {
            NameEditorView(title: "Renomear cena", placeholder: "Nome da cena", name: $sceneNameDraft) {
                if let sceneID = viewModel.selectedSceneID { viewModel.renameScene(sceneID, to: sceneNameDraft) }
                isEditingSceneName = false
            } onCancel: {
                isEditingSceneName = false
            }
        }
        .sheet(item: $editingItem) { item in
            PerformanceItemEditorView(item: item) { updated in
                viewModel.updateItem(updated)
                editingItem = nil
            } onCancel: {
                editingItem = nil
            }
        }
        .alert("Excluir espetáculo?", isPresented: $isDeleteProjectConfirmationPresented) {
            Button("Excluir", role: .destructive) {
                if let projectID = viewModel.selectedProjectID { viewModel.removeProject(projectID) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as cenas e cues deste espetáculo serão removidas.")
        }
        .alert("Excluir cena?", isPresented: $isDeleteSceneConfirmationPresented) {
            Button("Excluir", role: .destructive) {
                if let sceneID = viewModel.selectedSceneID { viewModel.removeScene(sceneID) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As cues desta cena serão removidas.")
        }
    }

    private var performanceNavigation: some View {
        HStack(spacing: 10) {
            Label("Performance", systemImage: "theatermasks.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
            Picker("Área", selection: $screen) {
                ForEach(PerformanceScreen.allCases) { item in
                    Label(item.title, systemImage: item.symbolName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Spacer()
            if let project = viewModel.selectedProject, screen == .execution {
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dqMuted)
            }
            Button {
                projectNameDraft = ""
                isProjectEditorPresented = true
            } label: {
                Label("Novo espetáculo", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
    }

    private var projectBrowser: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Escolha um espetáculo")
                        .font(.system(size: 24, weight: .bold))
                    Text("Projetos com cenas, grupos e cues para operação ao vivo.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dqMuted)
                }
                Spacer()
                Button {
                    projectNameDraft = ""
                    isProjectEditorPresented = true
                } label: {
                    Label("Novo espetáculo", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.projects.isEmpty {
                emptyProjects
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(viewModel.projects) { project in
                            projectCard(project)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dqPanel()
    }

    private func projectCard(_ project: PerformanceProject) -> some View {
        Button {
            viewModel.selectProject(project.id)
            screen = .execution
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(systemName: project.kind == .dance ? "figure.dance" : "theatermasks.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(project.id == viewModel.selectedProjectID ? .blue : .purple)
                        .frame(width: 38, height: 38)
                        .background((project.id == viewModel.selectedProjectID ? Color.blue : Color.purple).opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dqMuted)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text("\(project.kind.title) · \(project.scenes.count) cenas · \(project.scenes.reduce(0) { $0 + $1.items.count }) cues")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dqMuted)
                }
                Divider().opacity(0.2)
                HStack {
                    Text(project.selectedSceneID.flatMap { id in project.scenes.first(where: { $0.id == id })?.name } ?? "Nenhuma cena selecionada")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dqMuted)
                        .lineLimit(1)
                    Spacer()
                    Text("Abrir")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(project.id == viewModel.selectedProjectID ? Color.blue.opacity(0.10) : Color.dqRow)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var emptyProjects: some View {
        VStack(spacing: 10) {
            Image(systemName: "theatermasks")
                .font(.system(size: 40))
                .foregroundStyle(Color.dqMuted)
            Text("Nenhum espetáculo criado")
                .font(.system(size: 16, weight: .semibold))
            Text("Crie um projeto para organizar cenas e cues de áudio.")
                .font(.system(size: 12))
                .foregroundStyle(Color.dqMuted)
            Button("Novo espetáculo") {
                projectNameDraft = ""
                isProjectEditorPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Espetáculos", systemImage: "theatermasks.fill")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    projectNameDraft = ""
                    isProjectEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .help("Novo espetáculo")
            }

            if viewModel.projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "theatermasks")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dqMuted)
                    Text("Nenhum espetáculo")
                        .foregroundStyle(Color.dqMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.projects) { project in
                            Button {
                                viewModel.selectProject(project.id)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "theatermasks.fill")
                                        .foregroundStyle(project.id == viewModel.selectedProjectID ? .blue : Color.dqMuted)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name).lineLimit(1)
                                        Text("\(project.scenes.count) cenas")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dqMuted)
                                    }
                                    Spacer()
                                }
                                .padding(9)
                                .background(project.id == viewModel.selectedProjectID ? Color.blue.opacity(0.22) : Color.dqRow)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().opacity(0.2)
            HStack(spacing: 8) {
                Button("Renomear") {
                    projectNameDraft = viewModel.selectedProject?.name ?? ""
                    isEditingProjectName = true
                }
                .disabled(viewModel.selectedProject == nil)
                Button {
                    isDeleteProjectConfirmationPresented = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedProject == nil)
            }
        }
        .padding(14)
        .dqPanel()
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            sceneHeader
            clockPanel
            HStack {
                Text(viewModel.selectedScene?.name ?? "Nenhuma cena")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("Visualização")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dqMuted)
                Picker("Visualização", selection: Binding(
                    get: { viewModel.displayMode },
                    set: { viewModel.updatePerformanceSettings(displayMode: $0) }
                )) {
                    ForEach(PerformanceDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                Button {
                    viewModel.addItem()
                } label: {
                    Label("Adicionar cue", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedScene == nil)
                Button {
                    importAudioFiles()
                } label: {
                    Label("Importar áudios", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedScene == nil)
            }

            if viewModel.displayMode == .list {
                itemList
            } else {
                groupedCueList
            }
            activeItemsPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sceneHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(viewModel.selectedProject?.name ?? "Performance", systemImage: "theatermasks.fill")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button {
                    viewModel.selectAdjacentScene(direction: -1)
                } label: {
                    Label("Anterior", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(!hasAdjacentScene(direction: -1))
                Button {
                    viewModel.selectAdjacentScene(direction: 1)
                } label: {
                    Label("Próxima", systemImage: "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(!hasAdjacentScene(direction: 1))
                Button {
                    sceneNameDraft = ""
                    isSceneEditorPresented = true
                } label: {
                    Label("Nova cena", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Button {
                    isDeleteSceneConfirmationPresented = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedScene == nil)
                Button("Renomear") {
                    sceneNameDraft = viewModel.selectedScene?.name ?? ""
                    isEditingSceneName = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedScene == nil)
            }
            if let project = viewModel.selectedProject, !project.scenes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(project.scenes) { scene in
                            Button {
                                viewModel.selectScene(scene.id)
                            } label: {
                                Text(scene.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(scene.id == viewModel.selectedSceneID ? Color.blue.opacity(0.8) : Color.dqPanelRaised)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .onDrag {
                                draggedSceneID = scene.id
                                return NSItemProvider(item: scene.id.uuidString as NSString, typeIdentifier: UTType.utf8PlainText.identifier)
                            }
                            .onDrop(of: [UTType.utf8PlainText.identifier], delegate: PerformanceSceneDropDelegate(targetID: scene.id, draggedID: $draggedSceneID) { sourceID, targetID in
                                viewModel.moveScene(sourceID, before: targetID)
                            })
                        }
                    }
                }
            }
        }
        .padding(14)
        .dqPanel()
    }

    private var clockPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Relógio da cena", systemImage: "timer")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(format(viewModel.sceneElapsedTime))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                if let expected = viewModel.sceneExpectedDuration {
                    Text("/ \(format(expected))")
                        .foregroundStyle(Color.dqMuted)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
            if viewModel.sceneExpectedDuration != nil {
                Slider(value: Binding(
                    get: { viewModel.sceneElapsedTime },
                    set: { viewModel.seekSceneClock(to: $0) }
                ), in: 0...max(viewModel.sceneExpectedDuration ?? 1, 1))
                .tint(.blue)
            }
            HStack(spacing: 8) {
                Button(viewModel.sceneClockState == .running ? "Pausar" : "Iniciar") {
                    if viewModel.sceneClockState == .running { viewModel.pauseSceneClock() }
                    else { viewModel.startSceneClock() }
                }
                .buttonStyle(.borderedProminent)
                Button("Zerar") { viewModel.resetSceneClock() }
                    .buttonStyle(.bordered)
                Spacer()
                Toggle("Manter ambientes na troca de cena", isOn: Binding(
                    get: { viewModel.selectedProject?.keepActiveItemsOnSceneChange ?? false },
                    set: { viewModel.updatePerformanceSettings(keepActiveItemsOnSceneChange: $0) }
                ))
                .toggleStyle(.checkbox)
                Button("Parar tudo", role: .destructive) { viewModel.stopAll() }
                    .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
                TextField("Duração esperada (segundos)", text: $expectedDurationDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Aplicar duração") { applyExpectedDuration() }
                    .buttonStyle(.bordered)
                if viewModel.sceneExpectedDuration != nil {
                    Button("Remover duração") {
                        expectedDurationDraft = ""
                        viewModel.setExpectedDuration(nil)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(14)
        .dqPanel()
        .onAppear { syncExpectedDurationDraft() }
        .onChange(of: viewModel.selectedSceneID) { _ in syncExpectedDurationDraft() }
    }

    private var itemList: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                if let scene = viewModel.selectedScene, !scene.items.isEmpty {
                    ForEach(Array(scene.items.enumerated()), id: \.element.id) { index, item in
                    PerformanceItemRow(index: index, item: item, active: viewModel.activeItems[item.id], hasExecuted: viewModel.executedItemIDs.contains(item.id), isExpanded: expandedItemID == item.id, toggleExpanded: {
                        expandedItemID = expandedItemID == item.id ? nil : item.id
                    }, trigger: {
                        viewModel.trigger(item.id)
                    }, pause: {
                        viewModel.pause(item.id)
                    }, resume: {
                        viewModel.resume(item.id)
                    }, stop: {
                        viewModel.stop(item.id)
                    }, edit: {
                        editingItem = item
                    }, remove: {
                        viewModel.removeItem(item.id)
                    }, seek: { value in
                        let duration = viewModel.activeItems[item.id]?.duration ?? item.duration
                        viewModel.seek(item.id, to: value * duration)
                    }, quickConfigure: { classification, playback, transition, mixBehavior, volume in
                        viewModel.updateItemSettings(item.id, classification: classification, playback: playback, transition: transition, mixBehavior: mixBehavior, volume: volume)
                    })
                                .onDrag {
                                    draggedItemID = item.id
                                    return NSItemProvider(item: item.id.uuidString as NSString, typeIdentifier: UTType.utf8PlainText.identifier)
                                }
                                .onDrop(of: [UTType.utf8PlainText.identifier], delegate: PerformanceItemDropDelegate(targetID: item.id, draggedID: $draggedItemID) { sourceID, targetID in
                                    viewModel.moveItem(sourceID, before: targetID)
                                })
                        if index < scene.items.count - 1 { Divider().opacity(0.15) }
                    }
                } else {
                    emptyItems
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(Color.dqPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var groupedCueList: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                ForEach(viewModel.groupedItems, id: \.classification) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(group.classification.title, systemImage: group.classification.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("\(group.items.count) cues")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dqMuted)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                PerformanceItemRow(index: index, item: item, active: viewModel.activeItems[item.id], hasExecuted: viewModel.executedItemIDs.contains(item.id), isExpanded: expandedItemID == item.id, toggleExpanded: {
                                    expandedItemID = expandedItemID == item.id ? nil : item.id
                                }, trigger: {
                                    viewModel.trigger(item.id)
                                }, pause: {
                                    viewModel.pause(item.id)
                                }, resume: {
                                    viewModel.resume(item.id)
                                }, stop: {
                                    viewModel.stop(item.id)
                                }, edit: {
                                    editingItem = item
                                }, remove: {
                                    viewModel.removeItem(item.id)
                                }, seek: { value in
                                    let duration = viewModel.activeItems[item.id]?.duration ?? item.duration
                                    viewModel.seek(item.id, to: value * duration)
                                }, quickConfigure: { classification, playback, transition, mixBehavior, volume in
                                    viewModel.updateItemSettings(item.id, classification: classification, playback: playback, transition: transition, mixBehavior: mixBehavior, volume: volume)
                                })
                                if index < group.items.count - 1 { Divider().opacity(0.12) }
                            }
                        }
                        .background(Color.dqPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(10)
                    .background(Color.dqRow.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if viewModel.groupedItems.isEmpty { emptyItems }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(Color.dqPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activeItemsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Ativos agora", systemImage: "waveform.and.mic")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(viewModel.activeItems.count)")
                    .foregroundStyle(Color.dqMuted)
                if !viewModel.activeItems.isEmpty {
                    Button("Pausar tudo") { viewModel.pauseAll() }
                        .buttonStyle(.bordered)
                    Button("Retomar") { viewModel.resumeAll() }
                        .buttonStyle(.bordered)
                    Button("Parar tudo", role: .destructive) { viewModel.stopAll() }
                        .buttonStyle(.bordered)
                }
            }
            if viewModel.activeItems.isEmpty {
                Text("Nenhuma cue em execução")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dqMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                    ForEach(Array(viewModel.activeItems.values)) { active in
                        if let item = viewModel.itemAnywhere(withID: active.itemID) {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(active.state == .playing ? Color.green : Color.orange)
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Text("\(active.state == .playing ? "Tocando" : "Pausado") · \(format(active.currentTime)) / \(format(active.duration))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color.dqMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.dqRow)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    }
                }
            }
        }
        .padding(12)
        .dqPanel()
    }

    private var emptyWorkspace: some View {
        VStack(spacing: 12) {
            Image(systemName: "theatermasks")
                .font(.system(size: 42))
                .foregroundStyle(Color.dqMuted)
            Text("Crie um espetáculo para começar")
                .font(.system(size: 18, weight: .semibold))
            Text("Depois adicione cenas e cues de áudio para operar a apresentação.")
                .foregroundStyle(Color.dqMuted)
            Button("Novo espetáculo") {
                projectNameDraft = ""
                isProjectEditorPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dqPanel()
    }

    private var emptyItems: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 25))
                .foregroundStyle(Color.dqMuted)
            Text("Nenhuma cue nesta cena")
                .foregroundStyle(Color.dqMuted)
            Button("Adicionar cue") { viewModel.addItem() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private func hasAdjacentScene(direction: Int) -> Bool {
        guard let project = viewModel.selectedProject,
              let selectedID = viewModel.selectedSceneID,
              let index = project.scenes.firstIndex(where: { $0.id == selectedID }) else { return false }
        return project.scenes.indices.contains(index + direction)
    }

    private func format(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(max(0, time)) / 60, Int(max(0, time)) % 60)
    }

    private func syncExpectedDurationDraft() {
        if let expected = viewModel.sceneExpectedDuration {
            expectedDurationDraft = String(format: "%.0f", expected)
        } else {
            expectedDurationDraft = ""
        }
    }

    private func applyExpectedDuration() {
        guard let duration = Double(expectedDurationDraft), duration >= 0 else { return }
        viewModel.setExpectedDuration(duration)
    }

    private func importAudioFiles() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aac", "aiff", "aif"]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        viewModel.importItems(from: panel.urls)
    }
}

private struct PerformanceItemDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let move: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard draggedID != nil else { return nil }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private struct PerformanceSceneDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let move: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard draggedID != nil else { return nil }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private struct PerformanceItemRow: View {
    let index: Int
    let item: PerformanceItem
    let active: ActivePerformanceItem?
    let hasExecuted: Bool
    let isExpanded: Bool
    let toggleExpanded: () -> Void
    let trigger: () -> Void
    let pause: () -> Void
    let resume: () -> Void
    let stop: () -> Void
    let edit: () -> Void
    let remove: () -> Void
    let seek: (Double) -> Void
    let quickConfigure: (PerformanceClassification?, PerformancePlayback?, PerformanceTransition?, PerformanceMixBehavior?, Double?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(hasExecuted ? .purple : Color.dqMuted)
                    .frame(width: 22)
                Button {
                    if active?.state == .playing { pause() }
                    else if active?.state == .paused { resume() }
                    else { trigger() }
                } label: {
                    Image(systemName: active?.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(active == nil ? (hasExecuted ? .purple : .blue) : (active?.state == .playing ? .green : .orange))
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        DQBadge(text: item.classification.title, color: .blue)
                        if item.playback == .loop { DQBadge(text: "Loop", color: .purple) }
                    }
                    HStack(spacing: 8) {
                        Text(item.formattedDuration)
                        if let active {
                            Text("Agora \(format(active.currentTime)) / \(format(active.duration))")
                                .foregroundStyle(active.state == .playing ? .green : .orange)
                        }
                        if item.isMissing { Text("Arquivo ausente").foregroundStyle(.orange) }
                        if let shortcut = item.keyboardShortcut, !shortcut.isEmpty { Text("Atalho: \(shortcut)") }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(item.isMissing ? .orange : Color.dqMuted)
                }
                menuButton
                Spacer()
                if let active {
                    Text(active.state == .playing ? "Tocando" : "Pausado")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(active.state == .playing ? .green : .orange)
                    Button(action: active.state == .playing ? pause : resume) {
                        Image(systemName: active.state == .playing ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    Button(action: stop) { Image(systemName: "stop.fill") }
                        .buttonStyle(.bordered)
                } else if hasExecuted {
                    Text("Executada")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.purple)
                }
                Button(action: toggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.dqMuted)
                        .frame(width: 24, height: 28)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Ocultar configuração" : "Mostrar configuração")
            }
            Slider(value: Binding(
                get: { progressValue },
                set: seek
            ), in: 0...1)
                .tint(active == nil ? (hasExecuted ? .purple : Color.white.opacity(0.22)) : (active?.state == .playing ? .green : .orange))
                .padding(.leading, 40)
                .disabled(active == nil || progressDuration <= 0)
            if isExpanded {
                expandedSettings
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(active != nil ? Color.blue.opacity(0.08) : (hasExecuted ? Color.purple.opacity(0.08) : Color.clear))
        .contentShape(Rectangle())
    }

    private var menuButton: some View {
        Menu {
            Button("Editar", action: edit)
            Menu("Classificação") {
                ForEach(PerformanceClassification.allCases) { classification in
                    Button {
                        quickConfigure(classification, nil, nil, nil, nil)
                    } label: {
                        Label(classification.title, systemImage: classification.symbolName)
                    }
                }
            }
            Menu("Reprodução") {
                ForEach(PerformancePlayback.allCases) { playback in
                    Button(playback.title) {
                        quickConfigure(nil, playback, nil, nil, nil)
                    }
                }
            }
            Menu("Troca de cena") {
                ForEach(PerformanceTransition.allCases) { transition in
                    Button(transition.title) {
                        quickConfigure(nil, nil, transition, nil, nil)
                    }
                }
            }
            Menu("Sobreposição") {
                ForEach(PerformanceMixBehavior.allCases) { mixBehavior in
                    Button(mixBehavior.title) {
                        quickConfigure(nil, nil, nil, mixBehavior, nil)
                    }
                }
            }
            Slider(value: Binding(
                get: { item.volume },
                set: { quickConfigure(nil, nil, nil, nil, $0) }
            ), in: 0...1)
            Button("Remover", role: .destructive, action: remove)
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 26, height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(width: 30)
    }

    private var expandedSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("Classificação", selection: Binding(
                    get: { item.classification },
                    set: { quickConfigure($0, nil, nil, nil, nil) }
                )) {
                    ForEach(PerformanceClassification.allCases) { classification in
                        Text(classification.title).tag(classification)
                    }
                }
                .frame(width: 150)

                Picker("Reprodução", selection: Binding(
                    get: { item.playback },
                    set: { quickConfigure(nil, $0, nil, nil, nil) }
                )) {
                    ForEach(PerformancePlayback.allCases) { playback in
                        Text(playback.title).tag(playback)
                    }
                }
                .frame(width: 125)

                Picker("Troca", selection: Binding(
                    get: { item.transition },
                    set: { quickConfigure(nil, nil, $0, nil, nil) }
                )) {
                    ForEach(PerformanceTransition.allCases) { transition in
                        Text(transition == .stopOnSceneChange ? "Parar na troca" : "Continuar")
                            .tag(transition)
                    }
                }
                .frame(width: 145)

                Toggle("Sobrepor", isOn: Binding(
                    get: { item.mixBehavior == .overlay },
                    set: { quickConfigure(nil, nil, nil, $0 ? .overlay : .interruptOthers, nil) }
                ))
                .toggleStyle(.checkbox)
                .frame(width: 105)
            }
            HStack(spacing: 8) {
                Text("Volume")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dqMuted)
                Slider(value: Binding(
                    get: { item.volume },
                    set: { quickConfigure(nil, nil, nil, nil, $0) }
                ), in: 0...1)
                Text("\(Int(item.volume * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.dqMuted)
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 28)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .controlSize(.small)
    }

    private var progressValue: Double {
        let duration = progressDuration
        guard duration > 0, duration.isFinite else { return 0 }
        return min(1, max(0, (active?.currentTime ?? 0) / duration))
    }

    private var progressDuration: TimeInterval {
        active?.duration ?? item.duration
    }

    private func format(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(max(0, time)) / 60, Int(max(0, time)) % 60)
    }
}

private struct NameEditorView: View {
    let title: String
    let placeholder: String
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            TextField(placeholder, text: $name)
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
        .frame(width: 380)
    }
}

private struct PerformanceItemEditorView: View {
    @State private var item: PerformanceItem
    let onSave: (PerformanceItem) -> Void
    let onCancel: () -> Void

    init(item: PerformanceItem, onSave: @escaping (PerformanceItem) -> Void, onCancel: @escaping () -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar cue").font(.title2.bold())
            TextField("Nome", text: $item.name)
            HStack {
                Image(systemName: item.isMissing ? "exclamationmark.triangle.fill" : "waveform")
                    .foregroundStyle(item.isMissing ? .orange : Color.dqMuted)
                Text(item.fileURL?.lastPathComponent ?? "Nenhum arquivo selecionado")
                    .foregroundStyle(Color.dqMuted)
                    .lineLimit(1)
                Spacer()
                Button("Escolher…") { chooseFile() }
            }
            Picker("Classificação", selection: $item.classification) {
                ForEach(PerformanceClassification.allCases) { classification in
                    Label(classification.title, systemImage: classification.symbolName).tag(classification)
                }
            }
            Picker("Reprodução", selection: $item.playback) {
                ForEach(PerformancePlayback.allCases) { playback in Text(playback.title).tag(playback) }
            }
            Picker("Troca de cena", selection: $item.transition) {
                ForEach(PerformanceTransition.allCases) { transition in Text(transition.title).tag(transition) }
            }
            Toggle("Permitir sobreposição com outras cues", isOn: Binding(
                get: { item.mixBehavior == .overlay },
                set: { item.mixBehavior = $0 ? .overlay : .interruptOthers }
            ))
            HStack {
                Text("Volume")
                Slider(value: $item.volume, in: 0...1)
                Text("\(Int(item.volume * 100))%")
                    .font(.system(size: 12, design: .monospaced))
            }
            TextField("Atalho opcional", text: Binding(
                get: { item.keyboardShortcut ?? "" },
                set: { item.keyboardShortcut = $0.isEmpty ? nil : $0.lowercased() }
            ))
            HStack {
                Button("Cancelar", action: onCancel)
                Spacer()
                Button("Salvar") { onSave(item) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp3", "wav", "m4a", "aac", "aiff", "aif"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        item.fileURL = url
        item.name = item.name == "Cue 1" ? url.deletingPathExtension().lastPathComponent : item.name
        item.isMissing = false
    }
}
