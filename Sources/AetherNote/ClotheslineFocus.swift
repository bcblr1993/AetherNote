/// Tracks the visibility to restore after the last focused window closes.
/// A hidden or disabled clothesline must never appear just because an editor closes.
struct ClotheslineFocus {
    enum Window: Hashable { case editor, review, settings }
    private(set) var windows: Set<Window> = []
    private(set) var restoreVisible = false
    var isActive: Bool { !windows.isEmpty }

    mutating func begin(_ window: Window, lineVisible: Bool) {
        if windows.isEmpty { restoreVisible = lineVisible }
        windows.insert(window)
    }
    mutating func disableLine() { restoreVisible = false }
    mutating func end(_ window: Window, lineEnabled: Bool, appActive: Bool, sessionActive: Bool) -> Bool {
        guard windows.remove(window) != nil, windows.isEmpty else { return false }
        defer { restoreVisible = false }
        return restoreVisible && lineEnabled && appActive && sessionActive
    }
}
