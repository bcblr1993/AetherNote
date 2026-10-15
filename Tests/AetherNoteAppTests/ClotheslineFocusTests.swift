import Testing
@testable import AetherNote

@Test func restoresOnlyAfterLastFocusedWindowCloses() {
    var focus = ClotheslineFocus()
    focus.begin(.editor, lineVisible: true)
    focus.begin(.settings, lineVisible: false)
    #expect(focus.isActive)
    let restored1 = focus.end(.editor, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(!restored1)
    #expect(focus.isActive)
    let restored2 = focus.end(.settings, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(restored2)
    #expect(!focus.isActive && !focus.restoreVisible)
}

@Test func switchingDaysKeepsOriginalVisibility() {
    var focus = ClotheslineFocus()
    focus.begin(.editor, lineVisible: true)
    focus.begin(.editor, lineVisible: false)
    let restored3 = focus.end(.editor, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(restored3)
    let restored4 = focus.end(.editor, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(!restored4)
}

@Test func quickAddDoesNotRevealHiddenClothesline() {
    var focus = ClotheslineFocus()
    focus.begin(.editor, lineVisible: false)
    let restored5 = focus.end(.editor, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(!restored5)
}

@Test func disabledOrInactiveClotheslineStaysHidden() {
    for flags in [(false, true, true), (true, false, true), (true, true, false)] {
        var focus = ClotheslineFocus()
        focus.begin(.editor, lineVisible: true)
        let restored6 = focus.end(.editor, lineEnabled: flags.0, appActive: flags.1, sessionActive: flags.2)
        #expect(!restored6)
        #expect(!focus.restoreVisible)
    }
    var focus = ClotheslineFocus()
    focus.begin(.editor, lineVisible: true)
    focus.disableLine()
    let restored7 = focus.end(.editor, lineEnabled: true, appActive: true, sessionActive: true)
    #expect(!restored7)
}
