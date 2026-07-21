import AppKit

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

@MainActor
enum PasteboardGuard {
    /// Marker type from the NSPasteboard.org convention — clipboard managers
    /// (Maccy, Paste, …) skip items carrying it.
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func snapshot() -> PasteboardSnapshot {
        let items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var byType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    byType[type] = data
                }
            }
            return byType
        }
        return PasteboardSnapshot(items: items)
    }

    /// Restores only if nobody else wrote to the pasteboard since our write.
    static func restore(_ snapshot: PasteboardSnapshot, ifChangeCountStill expected: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == expected else { return }
        pasteboard.clearContents()
        let items = snapshot.items.map { byType in
            let item = NSPasteboardItem()
            for (type, data) in byType {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
