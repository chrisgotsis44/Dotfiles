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

    // Default microphone -- mirrors sink/volume/muted above exactly.
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? false

    // Every output device, for the Control Center's audio detail view.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    // Every input device (mics) -- same node list, just the non-sink,
    // non-stream half of it.
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    // Per-app playback streams (one row per player/browser tab/etc.),
    // for individual volume control in the detail view.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)

    // Suppress the OSD for the initial burst of property updates when
    // PipeWire first connects.
    property bool ready: false

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Bind all sinks/sources/streams so their descriptions and live
    // volumes are readable in the detail view.
    PwObjectTracker {
        objects: root.sinks
    }
    PwObjectTracker {
        objects: root.sources
    }
    PwObjectTracker {
        objects: root.streams
    }

    function setSink(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setVolume(v: real): void {
        if (!sink?.ready || !sink.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setInputVolume(v: real): void {
        if (!source?.ready || !source.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(): void {
        if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleInputMute(): void {
        if (source?.ready && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    onVolumeChanged: if (ready) GlobalState.showOsd()
    onMutedChanged: if (ready) GlobalState.showOsd()

    Timer {
        interval: 1500
        running: true
        onTriggered: root.ready = true
    }
}
