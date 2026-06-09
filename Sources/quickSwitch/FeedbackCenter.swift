import Foundation
import Combine
import QuickSwitchCore

/// Transient UI feedback signals for add attempts:
/// - `rejected`: dropped something that couldn't be turned into an entry → shake.
/// - `duplicate(id)`: tried to add an entry already present → flash the existing icon.
final class FeedbackCenter: ObservableObject {
    enum Event: Equatable {
        case rejected
        case duplicate(String)
    }

    @Published private(set) var event: Event?
    /// Bumped on every event so views react even when the same event repeats.
    @Published private(set) var tick = 0

    func rejected() {
        event = .rejected
        tick += 1
    }

    func duplicate(_ id: String) {
        event = .duplicate(id)
        tick += 1
    }
}

/// Resolve a dropped URL and add it, emitting feedback on rejection/duplicate.
/// Shared by the SwiftUI drop paths and the AppKit drop receiver.
@discardableResult
func addItem(from url: URL, resolver: AppResolver, store: AppListStore, feedback: FeedbackCenter) -> Bool {
    guard let item = resolver.resolve(url: url) else {
        feedback.rejected()
        return false
    }
    switch store.add(item) {
    case .added:
        return true
    case .duplicate:
        feedback.duplicate(item.id)
        return false
    }
}
