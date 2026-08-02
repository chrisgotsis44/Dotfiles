pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Clipboard history manager — same design language as the launcher:
// search/filter bar on top, vertical list below, rendered inside the
// island (transparent root; the island supplies the panel).
//
// Text entries show their preview line; image entries show a real
// thumbnail (decoded by the Clipboard service via `cliphist decode`)
// with a type/size/dimensions caption. Enter or click copies the entry
// back to the Wayland clipboard, arrows navigate, Escape closes.
Item {
    id: root

    implicitWidth: 600
    implicitHeight: 520

    readonly property var filtered: {
        const q = search.text.toLowerCase().trim();
        let list = Clipboard.entries;
        if (q)
            list = list.filter(e => e.preview.toLowerCase().includes(q));
        return list.slice(0, 60);
    }

    function copyEntry(entry: var): void {
        if (!entry)
            return;
        Clipboard.copy(entry.id);
        GlobalState.clipboardOpen = false;
    }

    // Refresh history + reset the view every time the manager opens.
    function handleOpen(): void {
        Clipboard.refresh();
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    Connections {
        target: GlobalState
        function onClipboardOpenChanged() {
            if (GlobalState.clipboardOpen)
                root.handleOpen();
        }
    }

    // First open constructs this component, which means the signal above
    // has already fired before these Connections existed -- without this
    // the first open would show a stale (or empty) history and an
    // unfocused search field. See LauncherContent for the same pattern.
    Component.onCompleted: Qt.callLater(root.handleOpen)

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        StyledRect {
            width: parent.width
            height: 52
            radius: 16
            color: Colors.surface
            border.width: 1
            border.color: search.activeFocus ? Colors.accentDim : Colors.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "content_paste"
                    font.pixelSize: 20
                    color: Colors.subtext
                }

                TextInput {
                    id: search
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36
                    color: Colors.text
                    font.family: Appearance.font.family
                    font.pixelSize: 16
                    clip: true

                    onTextChanged: list.currentIndex = 0
                    onAccepted: root.copyEntry(root.filtered[list.currentIndex])

                    Keys.onEscapePressed: GlobalState.clipboardOpen = false
                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)

                    StyledText {
                        visible: search.text === ""
                        text: "Search clipboard…"
                        font.pixelSize: 16
                        color: Colors.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 62
            clip: true
            spacing: 4
            model: root.filtered
            currentIndex: 0
            highlightMoveDuration: Appearance.anim.durations.fast

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: search.text !== "" ? "No matches" : "Clipboard history is empty"
                font.pixelSize: 14
                color: Colors.faint
            }

            delegate: StyledRect {
                id: entryItem

                required property var modelData
                required property int index

                width: list.width
                implicitHeight: modelData.isImage ? 78 : 56
                radius: 14
                color: list.currentIndex === index ? Colors.surfaceHigh
                     : entryHover.hovered ? Colors.surfaceHover
                     : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    // Image entries: real decoded thumbnail
                    ClippingRectangle {
                        visible: entryItem.modelData.isImage
                        anchors.verticalCenter: parent.verticalCenter
                        width: 94
                        height: 62
                        radius: 10
                        color: Colors.surfaceHigh

                        Image {
                            anchors.fill: parent
                            // Re-evaluated when the service finishes
                            // decoding thumbnails (revision bump).
                            source: {
                                Clipboard.revision;
                                return entryItem.modelData.isImage
                                    ? "file://" + Clipboard.imageDir + "/" + entryItem.modelData.id
                                    : "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 188
                        }
                    }

                    // Text entries: note glyph
                    MaterialIcon {
                        visible: !entryItem.modelData.isImage
                        anchors.verticalCenter: parent.verticalCenter
                        text: "notes"
                        font.pixelSize: 20
                        color: Colors.subtext
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (entryItem.modelData.isImage ? 108 : 34) - 14
                        spacing: 2

                        StyledText {
                            width: parent.width
                            text: entryItem.modelData.isImage ? "Image" : entryItem.modelData.preview
                            elide: Text.ElideRight
                            font.pixelSize: 15
                            font.weight: entryItem.modelData.isImage ? 600 : 400
                        }
                        MonoText {
                            width: parent.width
                            visible: entryItem.modelData.isImage
                            text: entryItem.modelData.ext + " · " + entryItem.modelData.dims + " · " + entryItem.modelData.size
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                    }
                }

                HoverHandler {
                    id: entryHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.copyEntry(entryItem.modelData)
                }
            }
        }
    }
}
