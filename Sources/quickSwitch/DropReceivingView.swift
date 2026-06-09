import AppKit

/// AppKit-level drag receiver sitting behind the SwiftUI content. SwiftUI's
/// `onDrop` only matches a fixed set of UTTypes; this catches the broader
/// (and messier) drag flavors some sources use — notably the macOS Dock,
/// `NSFilenamesPboardType`, promised file URLs, and plain path/URL strings.
final class DropReceivingView: NSView {
    /// Called with the dropped file/web URLs. Returns whether anything was added.
    var onDropURLs: (([URL]) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Ignore our own internal icon-reorder drags (handled by SwiftUI).
    private func isInternal(_ sender: NSDraggingInfo) -> Bool {
        if let view = sender.draggingSource as? NSView, view.window === window { return true }
        return false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isInternal(sender) ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isInternal(sender) ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isInternal(sender) else { return false }
        let urls = Self.extractURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        return onDropURLs?(urls) ?? false
    }

    static func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: false]
        ) as? [URL] {
            urls.append(contentsOf: objects)
        }

        if urls.isEmpty,
           let names = pasteboard.propertyList(
                forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
           ) as? [String] {
            urls.append(contentsOf: names.map { URL(fileURLWithPath: $0) })
        }

        if urls.isEmpty, let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                urls.append(url)
            } else if trimmed.hasPrefix("/") {
                urls.append(URL(fileURLWithPath: trimmed))
            }
        }

        return urls
    }
}
