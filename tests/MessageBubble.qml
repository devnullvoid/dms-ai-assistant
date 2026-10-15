import QtQuick
Item {
    property string messageId: ""
    property string role: ""
    property string text: ""
    property string status: ""
    property bool useMonospace: false
    signal copySuccess()
    signal regenerateRequested(string messageId)
    // Exercise real ListView layout with variable heights and the size change
    // when a streaming message switches to rendered markdown.
    implicitHeight: Math.max(80, Math.ceil(text.length / Math.max(1, width / 8)) * 20)
                    + (status === "streaming" ? 0 : 40)
}
