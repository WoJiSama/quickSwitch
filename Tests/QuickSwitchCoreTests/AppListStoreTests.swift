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
        #expect(store.items.map(\.bundleID) == ["a"])
    }

    @Test func addIgnoresDuplicateBundleID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("a"))
        #expect(store.items.count == 1)
    }

    @Test func removeDeletesByBundleID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.remove(bundleID: "a")
        #expect(store.items.map(\.bundleID) == ["b"])
    }

    @Test func moveReordersItems() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.add(item("c"))
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(store.items.map(\.bundleID) == ["b", "c", "a"])
    }

    @Test func persistenceRoundTripsAcrossInstances() {
        let store1 = AppListStore(defaults: defaults)
        store1.add(item("a"))
        store1.add(item("b"))

        let store2 = AppListStore(defaults: defaults)
        #expect(store2.items.map(\.bundleID) == ["a", "b"])
    }

    @Test func loadSkipsCorruptData() {
        defaults.set(Data("not json".utf8), forKey: "appItems")
        let store = AppListStore(defaults: defaults)
        #expect(store.items.isEmpty)
    }
}
