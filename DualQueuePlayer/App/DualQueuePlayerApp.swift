import SwiftUI

@main
struct DualQueuePlayerApp: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup("DualQueue Player") {
            MainView(viewModel: viewModel)
                .frame(minWidth: 1_180, minHeight: 760)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Novo Projeto") { viewModel.newProject() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Abrir Projeto…") { viewModel.openProject() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Salvar Projeto") { viewModel.saveProject() }
                    .keyboardShortcut("s", modifiers: [.command])
                Button("Salvar Projeto Como…") { viewModel.saveProjectAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
