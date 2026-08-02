pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Read-only MPRIS view for the lockscreen's now-playing line.
//
// Nothing here can control playback -- the lockscreen shows what is
// playing and offers no transport, deliberately: media keys already work
// while locked (they are bound with `locked = true` in binds.lua), and a
// clickable transport on a lock surface is an attack surface for no gain.
Singleton {
    id: root

    readonly property var players: Mpris.players?.values ?? []

    property MprisPlayer active: null

    readonly property bool isPlaying: root.active?.isPlaying ?? false
    readonly property string title: root.active?.trackTitle ?? ""
    readonly property string artist: root.active?.trackArtist ?? ""
    readonly property string artUrl: root.active?.trackArtUrl ?? ""

    // Prefer whatever is actually playing; fall back to the first player
    // so a paused track still shows rather than blinking out.
    function pick(): void {
        const list = root.players;
        root.active = list.find(p => p.isPlaying) ?? list[0] ?? null;
    }

    Connections {
        target: Mpris.players

        function onValuesChanged(): void {
            root.pick();
        }
    }

    // Playback state changes on an existing player do not touch the
    // players list, so a slow re-pick covers pause/resume. Cheap, and this
    // process only lives for the length of one unlock.
    Timer {
        running: true
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pick()
    }
}
