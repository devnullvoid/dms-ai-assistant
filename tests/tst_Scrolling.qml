import QtQuick
import QtQuick.Controls
import QtTest

TestCase {
    id: testCase
    name: "MessageListScrolling"
    when: windowShown
    visible: true
    width: 640
    height: 480

    ListModel { id: messageModel }
    QtObject {
        id: service
        property bool isStreaming: false
    }
    Component {
        id: listComponent
        MessageList {
            width: testCase.width
            height: testCase.height
            messages: messageModel
            aiService: service
        }
    }
    property var panel
    property var view

    function init() {
        messageModel.clear();
        service.isStreaming = true;
        for (let i = 0; i < 40; i++)
            messageModel.append({ id: "message-" + i, role: i % 2 ? "assistant" : "user",
                              content: "message ".repeat(20 + i % 5 * 20), status: "streaming" });
        panel = createTemporaryObject(listComponent, testCase);
        verify(panel !== null);
        view = findChild(panel, "messageListView");
        verify(view !== null);
        tryVerify(() => view.atYEnd, 2000);
        wait(100);
    }

    function scrollUp() {
        mouseWheel(view, view.width / 2, view.height / 2, 0, 720);
        tryVerify(() => !panel.stickToBottom && !view.atYEnd, 2000);
        tryVerify(() => !view.moving, 2000);
        wait(150);
    }

    function test_stream_end_and_layout_preserve_reader_position() {
        scrollUp();
        const topIndex = view.indexAt(view.contentX + 20, view.contentY + 20);
        service.isStreaming = false;
        messageModel.setProperty(39, "status", "ok");
        messageModel.setProperty(39, "content", "final markdown content ".repeat(500));
        messageModel.append({ id: "new", role: "assistant", content: "new message", status: "ok" });
        panel.height -= 60;
        wait(200);
        verify(!panel.stickToBottom);
        verify(!view.atYEnd);
        compare(view.indexAt(view.contentX + 20, view.contentY + 20), topIndex);
    }

    function test_queued_scroll_is_cancelled_by_user_input() {
        service.isStreaming = false; // starts the markdown-settle timer
        mouseWheel(view, view.width / 2, view.height / 2, 0, 720);
        wait(200);
        verify(!panel.stickToBottom);
        verify(!view.atYEnd);
    }

    function test_layout_position_changes_do_not_reenable_following() {
        scrollUp();
        // Simulate the geometry correction a variable-height ListView can make.
        view.positionViewAtEnd();
        verify(!panel.stickToBottom);
    }

    function test_following_survives_growth_and_resumes_at_bottom() {
        messageModel.setProperty(39, "content", "streaming chunk ".repeat(500));
        tryVerify(() => view.atYEnd, 2000);
        verify(panel.stickToBottom);
        scrollUp();
        // Scroll back to the bottom using actual wheel input.
        for (let i = 0; i < 12 && !view.atYEnd; i++) {
            mouseWheel(view, view.width / 2, view.height / 2, 0, -720);
            wait(50);
        }
        tryVerify(() => view.atYEnd && panel.stickToBottom, 2000);
        service.isStreaming = false;
        messageModel.setProperty(39, "status", "ok");
        tryVerify(() => view.atYEnd, 2000);
    }

    function test_scrollbar_drag_preserves_reader_position() {
        const bar = findChild(panel, "messageScrollBar");
        verify(bar !== null);
        const handleY = (bar.position + bar.size / 2) * bar.height;
        mousePress(bar, bar.width / 2, handleY);
        mouseMove(bar, bar.width / 2, bar.height / 3, 100);
        mouseRelease(bar, bar.width / 2, bar.height / 3);
        tryVerify(() => !view.atYEnd && !panel.stickToBottom, 2000);
        service.isStreaming = false;
        wait(100);
        verify(!view.atYEnd);
    }
}
