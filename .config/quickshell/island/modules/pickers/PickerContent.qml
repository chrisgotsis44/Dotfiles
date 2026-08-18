pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The shared body of both character pickers: search on top, results
// below, Enter or a click copies the glyph and closes.
//
// Emoji and glyphs differ only in their data and their labelling, so
// they are two instances of this rather than two components -- see
// EmojiPicker.qml and GlyphPicker.qml, which are thin wrappers that
// supply `entries` and wire `dismissed` to their own GlobalState flag.
//
// Entries are { e: glyph, n: name, k: keywords, nerd: bool }. `nerd`
// selects the font the glyph itself is drawn in: Private Use Area
// codepoints only exist in a Nerd Font, and the UI font would draw them
// as tofu.
//
// Rendered inside the island (transparent root -- the island supplies
// the panel), same as the launcher.
Item {
    id: root

    required property var entries
    required property string placeholder
    required property string icon
    // Mirrors the GlobalState flag that owns this picker. The search
    // field resets and takes focus on each rising edge, so reopening
    // never lands you in the middle of the last search.
    required property bool active

    signal dismissed

    implicitWidth: 600
    implicitHeight: 520

    readonly property string term: search.text.toLowerCase().trim()

    readonly property var results: {
        const t = root.term;
        if (t === "")
            return root.entries.slice(0, 60);

        // A whole-word keyword hit outranks a mid-word name hit. Without
        // that, "ok" buries 👍 (keyword "ok") under "cooked rice" and
        // "cookie", which merely contain the letters -- the keyword is
        // the deliberate signal and the substring is an accident.
        const rank = x => {
            if (x.n === t)
                return 0;
            if (x.n.startsWith(t))
                return 1;
            if ((x.k ?? "").split(" ").indexOf(t) !== -1)
                return 2;
            if (x.n.includes(t))
                return 3;
            return 4;
        };

        return root.entries.filter(x => x.n.includes(t) || (x.k !== undefined && x.k.includes(t))).sort((a, b) => rank(a) - rank(b) || a.n.length - b.n.length || a.n.localeCompare(b.n)).slice(0, 60);
    }

    function activate(item: var): void {
        if (!item)
            return;
        // wl-copy rather than writing to cliphist directly -- cliphist is
        // already watching the clipboard, so this lands in the history
        // too without a second code path.
        Quickshell.execDetached(["wl-copy", "--", item.e]);
        root.dismissed();
    }

    function handleOpen(): void {
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    onActiveChanged: if (active) root.handleOpen()

    // Bar.qml only builds this the first time the picker is opened, so on
    // that first open `active` was ALREADY true before this component
    // existed and onActiveChanged never fires -- without this the search
    // field would come up unfocused and you could not type until you
    // closed and reopened it. Being constructed at all means "it is
    // opening". Deferred via callLater so the item is fully in the scene
    // before asking for focus.
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
                    text: root.icon
                    font.pixelSize: Appearance.font.px(20)
                    color: Colors.accent
                }

                TextInput {
                    id: search
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36
                    color: Colors.text
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.px(16)
                    clip: true

                    onTextChanged: list.currentIndex = 0
                    onAccepted: root.activate(root.results[list.currentIndex])

                    Keys.onEscapePressed: root.dismissed()
                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)

                    StyledText {
                        visible: search.text === ""
                        text: root.placeholder
                        font.pixelSize: Appearance.font.px(16)
                        color: Colors.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // An empty list with no explanation reads as broken.
        StyledText {
            width: parent.width
            visible: root.results.length === 0
            text: "No matches"
            horizontalAlignment: Text.AlignHCenter
            topPadding: 20
            font.pixelSize: Appearance.font.px(14)
            color: Colors.subtext
        }

        ListView {
            id: list
            width: parent.width
            height: parent.height - 62
            clip: true
            spacing: 4
            model: root.results
            currentIndex: 0
            highlightMoveDuration: Appearance.anim.durations.fast

            delegate: StyledRect {
                id: resultItem

                required property var modelData
                required property int index

                width: list.width
                implicitHeight: 56
                radius: 14
                color: list.currentIndex === index ? Colors.surfaceHigh : resultHover.hovered ? Colors.surfaceHover : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        horizontalAlignment: Text.AlignHCenter
                        text: resultItem.modelData.e
                        // PUA glyphs exist only in the Nerd Font; the UI
                        // font would draw them as tofu.
                        font.family: resultItem.modelData.nerd ? Appearance.font.mono : Appearance.font.family
                        font.pixelSize: Appearance.font.px(26)
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 1

                        StyledText {
                            width: parent.width
                            text: resultItem.modelData.n
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.px(15)
                            font.weight: 600
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: resultItem.modelData.k ?? ""
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.px(12)
                            color: Colors.subtext
                        }
                    }
                }

                HoverHandler {
                    id: resultHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.activate(resultItem.modelData)
                }
            }
        }
    }
}
