import SwiftUI

struct KeyboardShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContext: ShortcutGuideContext = .playlist

    private var contextShortcuts: [ReservedKeyboardShortcut] {
        switch selectedContext {
        case .playlist:
            return shortcuts(["space", "escape", "a", "b", "left", "right", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        case .performance:
            return shortcuts(["p", "shift+p", "space", "escape", "left", "right"])
        }
    }

    private var menuShortcuts: [ReservedKeyboardShortcut] {
        shortcuts(["command+n", "command+o", "command+s", "command+shift+s"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.blue)
                    .font(.system(size: 22))
                Text("Guia de atalhos")
                    .font(.title2.bold())
                Spacer()
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Picker("Contexto", selection: $selectedContext) {
                ForEach(ShortcutGuideContext.allCases) { context in
                    Text(context.title).tag(context)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedContext.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.dqMuted)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(contextShortcuts) { shortcut in
                        HStack(spacing: 12) {
                            Text(shortcut.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .frame(width: 92, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.dqPanelRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text(shortcut.action)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dqMuted)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 8) {
                Text("Atalhos comuns do aplicativo")
                    .font(.system(size: 12, weight: .semibold))
                ForEach(menuShortcuts) { shortcut in
                    HStack(spacing: 12) {
                        Text(shortcut.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 92, alignment: .leading)
                        Text(shortcut.action)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dqMuted)
                    }
                }
            }

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Para usar um atalho personalizado")
                    .font(.system(size: 12, weight: .semibold))
                Text("Escolha uma tecla livre, como C, D, F ou Shift+tecla. O app precisa estar em foco e o pad precisa ter um arquivo de áudio configurado.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dqMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Durante a edição de textos ou da captura de atalho, os atalhos ficam temporariamente desativados.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dqMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(width: 520, height: 560)
    }

    private func shortcuts(_ names: [String]) -> [ReservedKeyboardShortcut] {
        names.compactMap { name in
            KeyboardShortcutFormatter.reservedShortcuts.first { $0.shortcut == name }
        }
    }
}

private enum ShortcutGuideContext: String, CaseIterable, Identifiable {
    case playlist
    case performance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlist: "Playlist"
        case .performance: "Performance"
        }
    }

    var subtitle: String {
        switch self {
        case .playlist:
            "Atalhos para controlar a playlist e acionar os pads pela posição na página atual."
        case .performance:
            "Atalhos para controlar a playlist em segundo plano e os cues da operação Performance."
        }
    }
}
