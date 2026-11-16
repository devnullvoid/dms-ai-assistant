import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "ConversationTabStrip"
    when: windowShown
    visible: true
    width: 480
    height: 100
    property var tabs

    Component {
        id: component
        ConversationTabs {
            width: 460
            height: 36
            conversations: [{id: "first", title: "First chat"}, {id: "second", title: "Second chat"}]
            activeId: "first"
            onSelected: conversationId => activeId = conversationId
        }
    }
    SignalSpy { id: selectedSpy; signalName: "selected" }
    SignalSpy { id: renamedSpy; signalName: "renamed" }
    SignalSpy { id: closedSpy; signalName: "closeRequested" }
    SignalSpy { id: newSpy; signalName: "newRequested" }

    function init() {
        tabs = createTemporaryObject(component, testCase);
        verify(tabs !== null);
        selectedSpy.target = tabs;
        renamedSpy.target = tabs;
        closedSpy.target = tabs;
        newSpy.target = tabs;
        selectedSpy.clear(); renamedSpy.clear(); closedSpy.clear(); newSpy.clear();
    }

    function test_click_select_and_plus() {
        mouseClick(findChild(tabs, "conversationTab-second"), 20, 16);
        compare(tabs.activeId, "second");
        compare(selectedSpy.count, 1);
        mouseClick(findChild(tabs, "newConversationButton"), 16, 16);
        compare(newSpy.count, 1);
    }

    function test_double_click_rename_and_escape() {
        const tab = findChild(tabs, "conversationTab-first");
        mouseDoubleClickSequence(tab, 20, 16);
        const field = findChild(tabs, "conversationRename-first");
        tryVerify(() => field.visible && field.activeFocus);
        field.selectAll();
        keyClick(Qt.Key_R);
        keyClick(Qt.Key_Return);
        compare(renamedSpy.count, 1);
        compare(renamedSpy.signalArguments[0][0], "first");
        compare(renamedSpy.signalArguments[0][1], "r");
        mouseDoubleClickSequence(tab, 20, 16);
        tryVerify(() => field.visible && field.activeFocus);
        keyClick(Qt.Key_Escape);
        compare(renamedSpy.count, 1);
        verify(!field.visible);
    }

    function test_close_does_not_select_and_single_tab_has_no_close() {
        mouseClick(findChild(tabs, "conversationClose-second"), 10, 10);
        compare(closedSpy.count, 1);
        compare(closedSpy.signalArguments[0][0], "second");
        compare(selectedSpy.count, 0);
        tabs.conversations = [{id: "first", title: "Only chat"}];
        verify(!findChild(tabs, "conversationClose-first").parent.visible);
    }

    function test_active_tab_is_revealed_when_overflowing() {
        const many = [];
        for (let i = 0; i < 10; i++) many.push({id: "tab-" + i, title: "Chat " + i});
        tabs.conversations = many;
        tabs.activeId = "tab-9";
        const scroll = findChild(tabs, "conversationTabScroll");
        tryVerify(() => scroll.contentX > 0);
        const tab = findChild(tabs, "conversationTab-tab-9");
        verify(tab.x + tab.width <= scroll.contentX + scroll.width + 1);
    }

    function test_overflow_buttons_scroll_without_selecting_a_tab() {
        const many = [];
        for (let i = 0; i < 10; i++) many.push({id: "tab-" + i, title: "Chat " + i});
        tabs.conversations = many;
        tabs.activeId = "tab-9";
        const scroll = findChild(tabs, "conversationTabScroll");
        const left = findChild(tabs, "scrollConversationTabsLeft");
        const right = findChild(tabs, "scrollConversationTabsRight");
        tryVerify(() => scroll.contentX > 0 && left.visible && left.enabled);
        const originalX = scroll.contentX;
        mouseClick(left, 16, 16);
        verify(scroll.contentX < originalX);
        compare(tabs.activeId, "tab-9");
        compare(selectedSpy.count, 0);
        const afterLeft = scroll.contentX;
        mouseClick(right, 16, 16);
        verify(scroll.contentX > afterLeft);
        for (let i = 0; i < 20 && left.enabled; i++) mouseClick(left, 16, 16);
        compare(scroll.contentX, 0);
        verify(!left.enabled);
        for (let i = 0; i < 20 && right.enabled; i++) mouseClick(right, 16, 16);
        compare(scroll.contentX, scroll.contentWidth - scroll.width);
        verify(!right.enabled);
    }

    function test_disabled_strip_does_not_dispatch_actions() {
        tabs.enabled = false;
        mouseClick(findChild(tabs, "conversationTab-second"), 20, 16);
        mouseClick(findChild(tabs, "newConversationButton"), 16, 16);
        compare(selectedSpy.count, 0);
        compare(newSpy.count, 0);
    }
}
