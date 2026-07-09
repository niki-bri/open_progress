import Foundation
import WidgetKit

@MainActor
final class ProgressStore: ObservableObject {
    @Published var items: [ProgressItem] = [] {
        didSet {
            guard hasLoaded else { return }
            ProgressStorage.save(items)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var hasLoaded = false

    init() {
        items = ProgressStorage.load()
        hasLoaded = true
    }

    func add(_ item: ProgressItem) {
        items.insert(item, at: 0)
    }

    func update(_ item: ProgressItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.modifiedAt = Date()
        items[index] = updated
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}
