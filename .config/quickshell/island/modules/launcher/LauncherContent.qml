pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import "Emoji.js" as Emoji

// Search bar on top, results below. Enter activates the highlighted
// entry, arrows navigate, Escape closes. Rendered inside the island
// (transparent root — the island supplies the panel).
//
// Three modes, chosen by a leading character rather than a mode switch,
// so there is nothing to remember beyond the prefix itself:
//
//   (none)   applications, ranked by match quality then launch count
//   =        calculator          =8*1024      Enter copies the result
//   :        emoji picker        :rocket      Enter copies the glyph
//
// Every mode produces the same result shape (kind/title/subtitle/payload)
// so the list below stays one delegate rather than three.
Item {
    id: root

    implicitWidth: 600
    implicitHeight: 520

    readonly property string query: search.text
    readonly property string mode: {
        if (root.query.startsWith("="))
            return "calc";
        if (root.query.startsWith(":"))
            return "emoji";
        return "apps";
    }
    // Everything after the prefix.
    readonly property string term: root.mode === "apps" ? root.query : root.query.slice(1)

    // ---------------------------------------------------------------- //
    //  Calculator                                                       //
    // ---------------------------------------------------------------- //
    // Deliberately not a bare eval of whatever was typed. The expression
    // is whitelisted twice -- once for the character set, once for the
    // identifiers -- so the only things that can reach the evaluator are
    // numbers, operators and a fixed list of Math functions.
    readonly property var mathNames: ["sqrt", "cbrt", "abs", "round", "floor", "ceil", "min", "max", "pow", "log2", "log10", "log", "exp", "sin", "cos", "tan", "atan", "asin", "acos", "sign", "trunc"]

    function calc(expr: string): var {
        const src = expr.trim();
        if (src === "")
            return null;
        if (!/^[0-9+\-*/%^().,\s a-zA-Z]*$/.test(src))
            return null;

        const idents = src.match(/[a-zA-Z]+/g) ?? [];
        for (const id of idents) {
            const lower = id.toLowerCase();
            if (lower !== "pi" && lower !== "e" && root.mathNames.indexOf(lower) === -1)
                return null;
        }

        let js = src.replace(/\^/g, "**");
        js = js.replace(/[a-zA-Z]+/g, m => {
            const lower = m.toLowerCase();
            if (lower === "pi")
                return "Math.PI";
            if (lower === "e")
                return "Math.E";
            return "Math." + lower;
        });

        try {
            const value = Function('"use strict"; return (' + js + ')')();
            if (typeof value !== "number" || !isFinite(value))
                return null;
            return value;
        } catch (err) {
            return null;
        }
    }

    function formatNumber(value: real): string {
        if (Number.isInteger(value))
            return value.toLocaleString(Qt.locale(), "f", 0);
        // Trailing-zero-free, but without exposing float noise like
        // 0.30000000000000004.
        return String(parseFloat(value.toPrecision(12)));
    }

    // ---------------------------------------------------------------- //
    //  Results                                                          //
    // ---------------------------------------------------------------- //
    readonly property var results: {
        if (root.mode === "calc") {
            const value = root.calc(root.term);
            if (value === null)
                return [];
            return [
                {
                    kind: "calc",
                    title: root.formatNumber(value),
                    subtitle: "Enter to copy",
                    payload: root.formatNumber(value)
                }
            ];
        }

        if (root.mode === "emoji") {
            const t = root.term.toLowerCase().trim();
            let hits = Emoji.list;
            if (t !== "") {
                // A whole-word keyword hit outranks a mid-word name hit.
                // Without that, ":ok" buries 👍 (keyword "ok") under
                // "cooked rice" and "cookie", which merely contain the
                // letters -- the keyword is the deliberate signal and the
                // substring is an accident.
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
                hits = hits.filter(x => x.n.includes(t) || (x.k !== undefined && x.k.includes(t))).sort((a, b) => rank(a) - rank(b) || a.n.length - b.n.length || a.n.localeCompare(b.n));
            }
            return hits.slice(0, 60).map(x => ({
                        kind: "emoji",
                        glyph: x.e,
                        title: x.n,
                        subtitle: x.k ?? "",
                        payload: x.e
                    }));
        }

        const q = root.term.toLowerCase().trim();
        let apps = [...DesktopEntries.applications.values].filter(a => !a.noDisplay);

        // Frequently-launched apps break ties in their favor -- most
        // used first with no query (rofi-style), or ranked above
        // equally-good text matches once you start typing.
        const byUsage = (a, b) => AppUsage.countFor(b.id) - AppUsage.countFor(a.id);

        if (q) {
            // Rank: name prefix > name substring > comment/keywords
            const score = a => {
                const name = a.name.toLowerCase();
                if (name.startsWith(q))
                    return 0;
                if (name.includes(q))
                    return 1;
                if ((a.comment ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q))
                    return 2;
                return 3;
            };
            apps = apps.filter(a => score(a) < 3).sort((a, b) => score(a) - score(b) || byUsage(a, b) || a.name.localeCompare(b.name));
        } else {
            apps.sort((a, b) => byUsage(a, b) || a.name.localeCompare(b.name));
        }

        return apps.slice(0, 50).map(a => ({
                    kind: "app",
                    entry: a,
                    title: a.name,
                    subtitle: a.comment ?? ""
                }));
    }

    function activate(item: var): void {
        if (!item)
            return;

        if (item.kind === "app") {
            AppUsage.recordLaunch(item.entry.id);
            item.entry.execute();
        } else {
            // wl-copy rather than writing to cliphist directly -- cliphist
            // is already watching the clipboard, so this lands in the
            // history too without a second code path.
            Quickshell.execDetached(["wl-copy", "--", item.payload]);
        }

        GlobalState.launcherOpen = false;
    }

    // Reset to a blank search with the field focused, every time the
    // launcher opens.
    function handleOpen(): void {
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    Connections {
        target: GlobalState
        function onLauncherOpenChanged() {
            if (GlobalState.launcherOpen)
                root.handleOpen();
        }
    }

    // Bar.qml only builds this component the first time the launcher is
    // opened, so on that first open the signal above has ALREADY fired by
    // the time these Connections exist -- without this the search field
    // would come up unfocused and you couldn't type until you closed and
    // reopened it. Being constructed at all means "it is opening".
    // Deferred via callLater so the item is fully in the scene before
    // asking for focus.
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
                    text: root.mode === "calc" ? "calculate" : root.mode === "emoji" ? "mood" : "search"
                    font.pixelSize: 20
                    color: root.mode === "apps" ? Colors.subtext : Colors.accent
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
                    onAccepted: root.activate(root.results[list.currentIndex])

                    Keys.onEscapePressed: GlobalState.launcherOpen = false
                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)

                    StyledText {
                        visible: search.text === ""
                        text: "Search apps…    = calculator    : emoji"
                        font.pixelSize: 16
                        color: Colors.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Only reachable in the two prefix modes, and only when nothing
        // matched -- an empty list with no explanation reads as broken,
        // especially for a half-typed expression like "=8*".
        StyledText {
            width: parent.width
            visible: root.mode !== "apps" && root.results.length === 0 && root.term.trim() !== ""
            text: root.mode === "calc" ? "Not a valid expression" : "No emoji matches"
            horizontalAlignment: Text.AlignHCenter
            topPadding: 20
            font.pixelSize: 14
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

                    // One slot, three fillings: an app icon, the emoji
                    // itself at display size, or a calculator glyph.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34

                        IconImage {
                            anchors.fill: parent
                            visible: resultItem.modelData.kind === "app"
                            source: resultItem.modelData.kind === "app" ? Quickshell.iconPath(resultItem.modelData.entry.icon, "application-x-executable") : ""
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: resultItem.modelData.kind === "emoji"
                            text: resultItem.modelData.kind === "emoji" ? resultItem.modelData.glyph : ""
                            font.pixelSize: 26
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: resultItem.modelData.kind === "calc"
                            text: "calculate"
                            font.pixelSize: 24
                            color: Colors.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 1

                        StyledText {
                            width: parent.width
                            text: resultItem.modelData.title
                            elide: Text.ElideRight
                            font.pixelSize: resultItem.modelData.kind === "calc" ? 20 : 15
                            font.weight: resultItem.modelData.kind === "calc" ? 700 : 600
                            color: resultItem.modelData.kind === "calc" ? Colors.accent : Colors.text
                        }
                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: resultItem.modelData.subtitle
                            elide: Text.ElideRight
                            font.pixelSize: 12
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
