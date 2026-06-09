import Foundation
import Combine

/// Result of trying to add an entry.
public enum AddOutcome: Equatable {
    case added
    case duplicate
}

/// Single source of truth for the dock's entries. Persists to UserDefaults on every mutation.
public final class AppListStore: ObservableObject {
    @Published public private(set) var items: [AppItem]

    private let defaults: UserDefaults
    private static let key = "dockItems"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
    }

    @discardableResult
    public func add(_ item: AppItem) -> AddOutcome {
        guard !items.contains(where: { $0.id == item.id }) else { return .duplicate }
        items.append(item)
        persist()
        return .added
    }

    public func remove(id: String) {
        items.removeAll { $0.id == id }
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
