pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// MPRIS integration with explicit Spotify support and a persistent
// last-session cache.
//
// Player selection (first match wins): playing Spotify > anything
// playing > Spotify paused > any controllable player > anything.
//
// Whenever a track is playing, its metadata is written to a small JSON
// cache on disk. If the player pauses, quits, or the shell restarts,
// the widgets keep showing the cached title/artist/artwork until a new
// session takes over — the island never blanks out to "Nothing playing"
// just because Spotify was closed.
Singleton {
    id: root

    property MprisPlayer active: null

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: active?.isPlaying ?? false

    // Live metadata when a player has a track loaded, cache otherwise.
    readonly property bool liveMeta: (active?.trackTitle ?? "") !== ""
    readonly property string title: liveMeta ? active.trackTitle : (cache.title !== "" ? cache.title : "Nothing playing")
    readonly property string artist: liveMeta ? (active.trackArtist ?? "") : cache.artist
    readonly property string artUrl: liveMeta ? (active.trackArtUrl ?? "") : cache.artUrl

    // Polled copy of the playback position (MPRIS position doesn't tick
    // on its own — see the Timer below).
    property real position: 0
    readonly property real length: active?.length ?? 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    function isSpotify(p: MprisPlayer): bool {
        return ((p.identity ?? "") + " " + (p.desktopEntry ?? "")).toLowerCase().includes("spotify");
    }

    function updateActive(): void {
        const players = Mpris.players.values;
        active = players.find(p => p.isPlaying && root.isSpotify(p))
            ?? players.find(p => p.isPlaying)
            ?? players.find(p => root.isSpotify(p))
            ?? players.find(p => p.canControl)
            ?? players[0]
            ?? null;
        saveCache();
    }

    function saveCache(): void {
        if ((active?.trackTitle ?? "") === "")
            return;
        cache.title = active.trackTitle;
        cache.artist = active.trackArtist ?? "";
        cache.artUrl = active.trackArtUrl ?? "";
        cacheView.writeAdapter();
    }

    function togglePlaying(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext)
            active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    function seek(fraction: real): void {
        if (active?.canSeek && length > 0)
            active.position = fraction * length;
    }

    onActiveChanged: position = active?.position ?? 0

    // ---- persistent last-session cache ----
    FileView {
        id: cacheView
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-island-media.json"

        adapter: JsonAdapter {
            id: cache
            property string title: ""
            property string artist: ""
            property string artUrl: ""
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.updateActive();
        }
    }

    // Re-pick the active player whenever any player's state flips
    // (e.g. Spotify pauses, mpv starts) and cache new tracks as they
    // start.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onPlaybackStateChanged() {
                root.updateActive();
            }
            function onTrackTitleChanged() {
                root.position = root.active?.position ?? 0;
                root.saveCache();
            }
            function onTrackArtistChanged() {
                root.saveCache();
            }
            function onTrackArtUrlChanged() {
                root.saveCache();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.isPlaying
        onTriggered: root.position = root.active?.position ?? 0
    }
}
