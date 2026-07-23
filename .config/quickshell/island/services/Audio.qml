pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default-sink volume, shared by the island OSD, the Control Center
// slider and the media widgets. Changing it from anywhere (slider,
// hardware keys, wpctl in a terminal) updates every consumer, because
// they all bind to the same PipeWire node.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    // Every output device, for the Control Center's audio detail view.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    // Suppress the OSD for the initial burst of property updates when
    // PipeWire first connects.
    property bool ready: false

    PwObjectTracker {
        objects: [root.sink]
    }

    // Bind all sinks so their descriptions are readable in the list.
    PwObjectTracker {
        objects: root.sinks
    }

    function setSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolume(v: real): void {
        if (!sink?.ready || !sink.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(): void {
        if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    onVolumeChanged: if (ready) GlobalState.showOsd()
    onMutedChanged: if (ready) GlobalState.showOsd()

    Timer {
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }
}
