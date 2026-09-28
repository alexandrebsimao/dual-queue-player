import AppKit
import Foundation

@MainActor
final class ProjectStore {
    static let shared = ProjectStore()
    private let fileManager = FileManager.default
    private let projectExtension = "dualqueue"

    private var applicationSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("DualQueuePlayer", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var autosaveURL: URL { applicationSupportURL.appendingPathComponent("LastProject.\(projectExtension)") }

    func loadLastProject() -> AppProject? {
        load(from: autosaveURL)
    }

    func saveAutosave(_ project: AppProject) {
        save(project, to: autosaveURL)
    }

    func saveAs(_ project: AppProject) -> URL? {
        let panel = NSSavePanel()
        panel.allowedFileTypes = [projectExtension]
        panel.nameFieldStringValue = "Meu Projeto.\(projectExtension)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let finalURL = url.pathExtension == projectExtension ? url : url.appendingPathExtension(projectExtension)
        return save(project, to: finalURL) ? finalURL : nil
    }

    func open() -> (project: AppProject, url: URL)? {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = [projectExtension]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let project = load(from: url) else { return nil }
        return (project, url)
    }

    @discardableResult
    func save(_ project: AppProject, to url: URL) -> Bool {
        do {
            let data = try JSONEncoder.pretty.encode(project)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            NSLog("DualQueue: erro ao salvar projeto: %@", error.localizedDescription)
            return false
        }
    }

    private func load(from url: URL) -> AppProject? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do { return try JSONDecoder().decode(AppProject.self, from: data) }
        catch {
            NSLog("DualQueue: erro ao abrir projeto: %@", error.localizedDescription)
            return nil
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
