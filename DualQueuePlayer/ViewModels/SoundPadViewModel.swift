import Foundation
import Combine

@MainActor
final class SoundPadViewModel: ObservableObject {
    @Published var pages: [SoundPadPage]
    @Published var selectedPageIndex = 0
    var onChange: (() -> Void)?

    init(pages: [SoundPadPage] = [SoundPadPage(name: "Vinhetas")]) {
        self.pages = pages.isEmpty ? [SoundPadPage(name: "Vinhetas")] : pages
    }

    var selectedPage: SoundPadPage {
        pages[min(selectedPageIndex, pages.count - 1)]
    }

    func addPage() {
        pages.append(SoundPadPage(name: "Nova página"))
        selectedPageIndex = pages.count - 1
        onChange?()
    }

    func renamePage(_ name: String) {
        pages[selectedPageIndex].name = name
        onChange?()
    }

    func deletePage(at index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        pages.remove(at: index)
        selectedPageIndex = min(selectedPageIndex, pages.count - 1)
        onChange?()
    }

    func addPad() {
        guard pages[selectedPageIndex].pads.count < 12 else { return }
        let number = pages[selectedPageIndex].pads.count + 1
        pages[selectedPageIndex].pads.append(SoundPad(name: "Pad \(number)"))
        onChange?()
    }

    func removePad(at index: Int) {
        guard pages[selectedPageIndex].pads.indices.contains(index) else { return }
        pages[selectedPageIndex].pads.remove(at: index)
        onChange?()
    }

    func update(_ pad: SoundPad) {
        guard let index = pages[selectedPageIndex].pads.firstIndex(where: { $0.id == pad.id }) else { return }
        pages[selectedPageIndex].pads[index] = pad
        onChange?()
    }
}
