import Testing
import Foundation
@testable import QuickSwitchCore

// A reference-type suite so we can tear down in deinit (per the project's Swift testing rule).
// Each test gets a fresh instance with its own unique UserDefaults suite — parallel-safe.
final class AppListStoreTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func item(_ id: String) -> AppItem {
        AppItem(bundleID: id, displayName: id.uppercased())
    }

    @Test func addAppendsItem() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        #expect(store.items.map(\.id) == ["a"])
    }

    @Test func addIgnoresDuplicateID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("a"))
        #expect(store.items.count == 1)
    }

    @Test func addAllowsAppAndPathTogether() {
        let store = AppListStore(defaults: defaults)
        store.add(item("com.apple.Safari"))
        store.add(AppItem(path: "/Users/me/Docs", displayName: "Docs"))
        #expect(store.items.map(\.id) == ["com.apple.Safari", "/Users/me/Docs"])
    }

    @Test func removeDeletesByID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.remove(id: "a")
        #expect(store.items.map(\.id) == ["b"])
    }

    @Test func moveReordersItems() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.add(item("c"))
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(store.items.map(\.id) == ["b", "c", "a"])
    }

    @Test func persistenceRoundTripsAcrossInstances() {
        let store1 = AppListStore(defaults: defaults)
        store1.add(item("a"))
        store1.add(AppItem(path: "/tmp/x", displayName: "x"))

        let store2 = AppListStore(defaults: defaults)
        #expect(store2.items.map(\.id) == ["a", "/tmp/x"])
    }

    @Test func loadSkipsCorruptData() {
        defaults.set(Data("not json".utf8), forKey: "dockItems")
        let store = AppListStore(defaults: defaults)
        #expect(store.items.isEmpty)
    }
}
