import Foundation
import Combine

/// Single source of truth for the dock's app list. Persists to UserDefaults on every mutation.
public final class AppListStore: ObservableObject {
    @Published public private(set) var items: [AppItem]

    private let defaults: UserDefaults
    private static let key = "appItems"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
    }

    public func add(_ item: AppItem) {
        guard !items.contains(where: { $0.bundleID == item.bundleID }) else { return }
        items.append(item)
        persist()
    }

    public func remove(bundleID: String) {
        items.removeAll { $0.bundleID == bundleID }
        persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Mirrors SwiftUI's MutableCollection.move(fromOffsets:toOffset:) without
        // depending on SwiftUI (which this pure-logic target does not link).
        let moved = source.map { items[$0] }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        var result = items
        for index in source.sorted(by: >) {
            result.remove(at: index)
        }
        result.insert(contentsOf: moved, at: insertionIndex)
        items = result
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.key)
    }

    private static func load(from defaults: UserDefaults) -> [AppItem] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppItem].self, from: data)
        else { return [] }
        return decoded
    }
}
