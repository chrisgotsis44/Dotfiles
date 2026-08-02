pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.services
import qs.components

// Universal media player popup -- middle-click the island (or
// `qs -c island ipc call shell toggleMediaPlayer`). Rendered INSIDE the
// island like every other menu, so opening it IS the morph animation.
//
// Background: a flat dark surface, with the album only ever present as
// a faint tint on top of it. Three layers, bottom to top:
//
//   1. an opaque dark base (the theme's darkest surface), so contrast
//      for text and controls is a constant, not a function of whatever
//      the cover happens to look like
//   2. the cover as a colour tint at 20% -- decoded at 10x10 and
//      stretched, so it contributes colour and nothing else
//   3. a top-to-bottom dark gradient, deepest at the bottom where the
//      transport controls sit
//
// All three span the island's whole interior (they reach past this
// item's own bounds by the island's padding, see `bgInset`), and the
// island's ClippingRectangle trims them to the pill. That is what gives
// a clean edge: an earlier version faded the background out to
// transparent through a feathered Canvas mask, which read as a dark
// vignette bleeding around the border rather than as a card.
//
// The content (art thumbnail, text, controls) sits on top, fully sharp,
// with a text outline (`style: Text.Outline`) as a second line of
// defence on every label.
// Same cached-last-session behavior as MediaCard: when no MPRIS player
// is live, the track/art stay visible but every control dims and stops
// accepting input.
//
// Motion, all of it keyed off state the card already tracks:
//   - opening: the three blocks (header / seek / controls) slide up
//     into place on a short stagger, on top of the island's own morph.
//   - track change: the title/artist block fades and lifts in, and the
//     art thumbnail pops, so a skip is legible without looking at the
//     progress bar.
//   - playing: a slow halo breathes behind the play button, and the
//     seek fill carries a shimmer.
Item {
    id: root

    implicitWidth: 440
    implicitHeight: layout.implicitHeight + 32

    readonly property bool hasArt: Media.artUrl !== "" && bgArt.status === Image.Ready

    // ---- smooth playback clock ---- //
    // MPRIS position doesn't tick on its own, so the Media service polls
    // it once a second. Bound straight to that, the seek fill only had
    // new information once a second -- and animating between those
    // samples just converts the jump into a short lurch followed by
    // ~850ms of dead still, which is what read as the bar lagging. It
    // can't be fixed by tuning that animation's duration: too short and
    // it stutters, exactly one second long and the bar is permanently a
    // full second behind the music.
    //
    // So the bar doesn't animate between samples at all -- it advances
    // itself. This clock ticks forward by the real elapsed frame time
    // every frame, and each poll from the service snaps it back to the
    // truth. Playback is a straight line through time, so predicting it
    // is exact rather than a guess: the corrections land well under a
    // pixel and the fill just moves, continuously, at the same rate as
    // the music.
    //
    // Cost is zero when it isn't earning anything: no extra D-Bus
    // traffic (the 1s poll is untouched), and the per-frame tick only
    // runs while this popup is actually on screen AND playing.
    property real smoothPos: Media.position

    FrameAnimation {
        running: root.visible && Media.isPlaying && Media.length > 0
        onTriggered: root.smoothPos = Math.min(Media.length, root.smoothPos + frameTime)
    }

    Connections {
        target: Media

        // Every poll, plus seeks and track changes (both write
        // Media.position directly), land here.
        function onPositionChanged(): void {
            root.smoothPos = Media.position;
        }
    }

    // While dragging the seek bar, preview the drag position instead of
    // the live one -- same unidirectional pattern as CcSlider: the bar
    // never owns the position, it just fires seek() on release.
    readonly property real shownProgress: seekArea.pressed
        ? seekArea.dragFrac
        : Media.length > 0 ? Math.min(1, root.smoothPos / Media.length) : 0

    // One shared clock for every "this is playing" flourish (currently
    // the play-button halo). Read through plain bindings rather than a
    // Behavior so everything snaps back to its resting value the moment
    // playback stops, instead of freezing mid-cycle. Gated on `visible`
    // too: the loader that owns this popup latches it alive after the
    // first open, so an ungated loop would keep waking the render thread
    // for the entire time music is playing, popup on screen or not.
    property real playT: 0
    NumberAnimation on playT {
        running: root.visible && Media.isPlaying
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 2600
    }

    // Every transport button, styled once. The card's background is now
    // whatever colour the album happens to be, so the buttons can't rely
    // on the themed surface alone reading as "raised": the ring holds
    // their edge against a light wash, and the drop shadow (applied to
    // the row below) lifts them off a dark one. Ring is inside the
    // component, shadow is on the row -- one shadow pass for all five
    // rather than five.
    component TransportButton: IconButton {
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.32)
    }

    function fmt(secs: real): string {
        secs = Math.max(0, Math.floor(secs));
        const m = Math.floor(secs / 60);
        const s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ---- entrance stagger ---- //
    // Bar.qml's Section loader latches on first show and only toggles
    // opacity/scale afterwards, so the popup is built once and reused.
    // `visible` is effective visibility (it follows the parent), which
    // makes it the one signal that fires on EVERY open, not just the
    // first -- so that's what drives this. Translate transforms only:
    // layouts ignore transforms, and animating a transform can't
    // clobber the opacity bindings these blocks already own for the
    // no-player dimming.
    // Reopening also resyncs the playback clock: it stops ticking while
    // the popup is hidden, so without this the bar would open at
    // wherever it was parked and only catch up on the next poll -- a
    // visible jump on exactly the frame the user is looking at it.
    function onShown(): void {
        smoothPos = Media.position;
        intro.restart();
    }

    onVisibleChanged: if (visible) onShown()
    Component.onCompleted: if (visible) onShown()

    ParallelAnimation {
        id: intro

        NumberAnimation {
            target: headerShift
            property: "y"
            from: 18
            to: 0
            duration: Appearance.anim.durations.expand
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 60
            }
            NumberAnimation {
                target: seekShift
                property: "y"
                from: 18
                to: 0
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }
            NumberAnimation {
                target: controlsShift
                property: "y"
                from: 18
                to: 0
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    // ---- track change ---- //
    // Title and artist are separate properties that update a frame
    // apart; keying off both concatenated means a skip animates once,
    // not twice. The text is already the NEW track when this runs, so
    // it plays as "the new track slides in", not "the old one leaves".
    readonly property string trackKey: Media.title + " " + Media.artist
    onTrackKeyChanged: trackAnim.restart()

    SequentialAnimation {
        id: trackAnim

        PropertyAction {
            target: textShift
            property: "y"
            value: 12
        }
        PropertyAction {
            target: textCol
            property: "opacity"
            value: 0
        }
        PropertyAction {
            target: artFrame
            property: "scale"
            value: 0.9
        }
        ParallelAnimation {
            NumberAnimation {
                target: textShift
                property: "y"
                to: 0
                duration: 360
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
            NumberAnimation {
                target: textCol
                property: "opacity"
                to: 1
                duration: 280
            }
            NumberAnimation {
                target: artFrame
                property: "scale"
                to: 1
                duration: 420
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.expressive
            }
        }
    }

    // ---- background ---- //
    // This reaches past the card's own bounds by exactly the padding the
    // island adds around whatever section it shows (Bar.qml sizes the
    // pill as content + hPadding/vPadding), so the surface covers the
    // pill's entire interior rather than leaving a ring of island colour
    // around a smaller card. `overshoot` covers the morph: mid-animation
    // the island is briefly a different size than its final content, and
    // it is cheaper to paint past the edge than to leave a seam there --
    // the island's ClippingRectangle trims the excess either way, and
    // that clip is exactly where the clean rounded edge comes from.
    Item {
        id: bg

        readonly property int overshoot: 64

        anchors.fill: parent
        anchors.leftMargin: -Appearance.bar.hPadding - overshoot
        anchors.rightMargin: -Appearance.bar.hPadding - overshoot
        anchors.topMargin: -Appearance.bar.vPadding - overshoot
        anchors.bottomMargin: -Appearance.bar.vPadding - overshoot

        // 1. Opaque dark base. Contrast for the text and controls is now
        // a constant rather than a function of the cover: the album can
        // only ever tint this, never set the overall lightness. Uses the
        // theme's darkest surface rather than a hardcoded #121212 so it
        // still follows the theme switcher like everything else.
        Rectangle {
            anchors.fill: parent
            color: Colors.bg
        }

        // 2. The album, as colour only. Decoded at 10x10 and stretched,
        // so bilinear filtering leaves broad soft fields with no detail
        // to smear -- and then held at 20%, where it reads as a tint on
        // a dark card instead of as artwork in its own right. This is
        // what replaced a full-resolution blur, which turned busy covers
        // into mud at exactly the moment you wanted the effect most.
        Image {
            id: bgArt
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 10
            sourceSize.height: 10
            // Bilinear, not nearest -- without this the ten pixels stay
            // ten visible squares.
            smooth: true
            opacity: root.hasArt ? 0.2 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                }
            }
        }

        // 3. Top-to-bottom darkening, deepest at the bottom where the
        // transport controls sit. Keeps the bottom half consistently
        // readable no matter which way a given cover's tint pulls.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(0, 0, 0, 0.12)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(0, 0, 0, 0.5)
                }
            }
        }
    }

    ColumnLayout {
        id: layout
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 14

        // ------------------------------------------------------ //
        //  Art | title / artist / source badge                    //
        // ------------------------------------------------------ //
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            transform: Translate {
                id: headerShift
            }

            Item {
                id: artFrame
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                // Explicit rather than relying on the layout's default:
                // the art and the text block are different heights, so
                // which one centres against the other should be stated,
                // not inherited.
                Layout.alignment: Qt.AlignVCenter
                // Pops on track change (see trackAnim); scaling this
                // wrapper rather than the ClippingRectangle keeps the
                // rounded-corner mask itself pixel-exact.
                transformOrigin: Item.Center

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Colors.surfaceHigh
                    // A hairline of light along the edge: without it the
                    // thumbnail's dark corners dissolve into the blurred
                    // version of the SAME art sitting right behind them.
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "music_note"
                        font.pixelSize: 28
                        color: Colors.subtext
                        visible: !root.hasArt
                    }

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 144
                        sourceSize.height: 144
                        // Crossfade instead of a hard swap: loading is
                        // async, so a new cover would otherwise appear
                        // in one frame whenever it finished decoding,
                        // at an unpredictable moment after the skip.
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.durations.normal
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: textCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                transform: Translate {
                    id: textShift
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: Media.title
                        elide: Text.ElideRight
                        font.pixelSize: 19
                        font.weight: 800
                        // Slight positive tracking: at this weight over
                        // a busy blurred background, tightly-set glyphs
                        // were the first thing to smear together.
                        font.letterSpacing: 0.2
                        // Built-in Qt Quick text outline -- legibility
                        // over whatever's behind it (bright art, a light
                        // wallpaper through the glass tint) now that
                        // there's no dark scrim to guarantee contrast.
                        // Outline, not Sunken: a drop shadow only covers
                        // one side of each glyph, so a light background
                        // still ate the unshadowed edges; an outline
                        // wraps the whole letterform and holds up
                        // whichever way the art behind it happens to
                        // fall.
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }

                    // Dynamic source badge -- whichever MPRIS player is
                    // active right now, not a hardcoded service.
                    // Deliberately quiet: it's a provenance label, not a
                    // control. Tighter padding, shorter, and held at
                    // partial opacity so it sits behind the title in the
                    // hierarchy instead of competing with it.
                    StyledRect {
                        visible: Media.playerName !== ""
                        implicitWidth: badgeText.implicitWidth + 13
                        implicitHeight: 19
                        radius: 9.5
                        color: Colors.accentDim
                        border.width: 1
                        border.color: Qt.alpha(Colors.accent, 0.22)
                        opacity: 0.75
                        Layout.alignment: Qt.AlignVCenter

                        StyledText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: Media.playerName
                            font.pixelSize: 10
                            font.weight: 700
                            font.letterSpacing: 0.3
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Media.artist
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    font.weight: 500
                    // Colors.subtext is a mid grey tuned for flat themed
                    // surfaces; over the art wash it was the weakest
                    // thing on the card. A dimmed version of the primary
                    // text color keeps the hierarchy (clearly secondary
                    // to the title) with far more to read against.
                    color: Qt.alpha(Colors.text, 0.7)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !Media.hasPlayer && Media.title !== "Nothing playing"
                    text: "Last session"
                    font.pixelSize: 11
                    color: Qt.alpha(Colors.text, 0.5)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                }
            }
        }

        // ------------------------------------------------------ //
        //  Seek bar + times                                       //
        // ------------------------------------------------------ //
        // A clean CcSlider-style straight line rather than the old
        // audiogram -- same track/fill language as the Control Center's
        // Volume/Brightness sliders, with a shimmer riding the fill
        // while playing, a hover glow that follows the cursor, and a
        // scrubber dot that glides (Behavior on x) rather than snapping,
        // including across track skips (the reset to 0 is just a very
        // short glide, not an instant jump). No buffered-region indicator
        // -- MPRIS has no such property (confirmed against Quickshell's
        // MprisPlayer docs: position/length/metadata only, nothing about
        // buffering), so faking one would show information that isn't
        // real.
        //
        // Dimmed and inert while showing a cached session, exactly
        // like the CC card's progress bar.
        ColumnLayout {
            Layout.fillWidth: true
            // On top of the parent's 14px spacing: the seek bar is the
            // one element people aim a cursor at, and it was sitting
            // shoulder to shoulder with the title block above and the
            // controls below.
            Layout.topMargin: 7
            Layout.bottomMargin: 7
            spacing: 4
            enabled: Media.hasPlayer
            opacity: Media.hasPlayer ? 1 : 0.35
            transform: Translate {
                id: seekShift
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                }
            }

            Item {
                id: seekBar
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                readonly property bool hovering: seekArea.containsMouse || seekArea.pressed
                readonly property real lineHeight: hovering ? 8 : 5

                StyledRect {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: seekBar.lineHeight
                    radius: height / 2
                    // The themed track color is a flat surface tone; on
                    // top of blurred art it vanished, taking the "how
                    // long is this track" cue with it. Blending toward
                    // black and holding it translucent keeps it visible
                    // against both a dark card and a bright cover.
                    color: Qt.alpha(Qt.darker(Colors.sliderTrack, 1.4), 0.75)

                    Behavior on height {
                        NumberAnimation {
                            duration: Appearance.anim.durations.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                    }

                    ClippingRectangle {
                        id: fillClip
                        anchors.fill: parent
                        radius: track.radius
                        color: "transparent"

                        Rectangle {
                            id: fillRect
                            width: root.shownProgress * parent.width
                            height: parent.height
                            // Gradient rather than flat accent: gives the
                            // played region a sense of direction, and the
                            // brighter leading end marks the playhead
                            // even with the scrubber dot hidden.
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Qt.darker(Colors.accent, 1.25)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Colors.accent
                                }
                            }

                            // No Behavior on width, deliberately. The
                            // width now changes every frame by a fraction
                            // of a pixel (see root.smoothPos), so it is
                            // already the smoothest motion the display
                            // can show -- putting an animation on top of
                            // that would only add lag, chasing a target
                            // that has already moved again by the time it
                            // arrives. Seeks and track changes should
                            // land instantly for the same reason.

                            // Hot leading edge: the last stretch of the
                            // fill brightens toward the playhead, so the
                            // eye has something to track at the exact
                            // point the bar is growing from. Costs no
                            // animation of its own -- it's anchored to
                            // the fill's right edge, so it rides along
                            // with the width it's already computing.
                            Rectangle {
                                anchors.right: parent.right
                                width: Math.min(22, fillRect.width)
                                height: parent.height
                                visible: fillRect.width > 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0.0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: Qt.alpha(Qt.lighter(Colors.accent, 1.5), 0.9)
                                    }
                                }
                            }

                            // Shimmer: a soft bright band sweeping across
                            // the fill on a loop, only while playing.
                            // Eased rather than linear so it drifts and
                            // settles instead of marching at a constant
                            // rate, and paused for a beat between passes
                            // (the loop is longer than the sweep) so it
                            // reads as an occasional glint.
                            Rectangle {
                                id: shimmer
                                property real t: 0

                                visible: Media.isPlaying
                                width: 56
                                height: parent.height
                                x: -width + (fillRect.width + width) * shimmer.t
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0.0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 0.5
                                        color: Qt.alpha("#ffffff", 0.35)
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: "transparent"
                                    }
                                }

                                // Gated on the popup being on screen for
                                // the same reason as the play halo: this
                                // loop would otherwise run for as long as
                                // music plays, with nothing to show for
                                // it.
                                SequentialAnimation on t {
                                    running: root.visible && Media.isPlaying
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        from: 0
                                        to: 1
                                        duration: 1900
                                        easing.type: Easing.InOutSine
                                    }
                                    PauseAnimation {
                                        duration: 900
                                    }
                                }
                            }
                        }
                    }
                }

                // Interactive glow that follows the cursor while
                // hovering. Deliberately NOT a MultiEffect blur -- that
                // rendered as a hard square block here instead of a soft
                // halo (blur-shader edge case at this small a size), so
                // this fakes the same soft falloff cheaply and reliably
                // with plain concentric circles at shrinking opacity
                // instead: four rings, no shader involved.
                Item {
                    id: glow
                    opacity: seekBar.hovering ? 1 : 0
                    width: 1
                    height: 1
                    x: Math.max(0, Math.min(track.width, seekArea.mouseX))
                    anchors.verticalCenter: track.verticalCenter

                    // Fades rather than blinking on/off with `visible`;
                    // the position still follows the cursor exactly, so
                    // it never fades in somewhere stale.
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.durations.fast
                        }
                    }

                    Repeater {
                        model: [
                            {
                                d: 38,
                                o: 0.07
                            },
                            {
                                d: 28,
                                o: 0.11
                            },
                            {
                                d: 19,
                                o: 0.17
                            },
                            {
                                d: 11,
                                o: 0.26
                            }
                        ]

                        Rectangle {
                            required property var modelData
                            anchors.centerIn: parent
                            width: modelData.d
                            height: modelData.d
                            radius: width / 2
                            color: Colors.accent
                            opacity: modelData.o
                        }
                    }
                }

                // Scrubber dot at the true (or drag-preview) position --
                // only surfaced on hover/drag so the idle bar stays
                // minimal, matching the "line only" look until you
                // actually reach for it. Grows past full size while
                // actually dragging, so the grab registers.
                Rectangle {
                    id: scrubber
                    width: 12
                    height: 12
                    radius: 6
                    color: Colors.text
                    anchors.verticalCenter: track.verticalCenter
                    x: root.shownProgress * track.width - width / 2
                    visible: opacity > 0.01
                    scale: seekArea.pressed ? 1.25 : seekBar.hovering ? 1 : 0.4
                    opacity: seekBar.hovering ? 1 : 0

                    // Like the fill's width: no Behavior on x. The dot
                    // tracks the same per-frame position, so smoothing it
                    // would only make it trail the fill's leading edge it
                    // is supposed to sit exactly on.
                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.durations.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.anim.curves.expressive
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.durations.fast
                        }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: (Media.active?.canSeek ?? false) && Media.length > 0

                    property real dragFrac: 0

                    function update(x: real) {
                        dragFrac = Math.max(0, Math.min(1, x / width));
                    }

                    onPressed: e => update(e.x)
                    onPositionChanged: e => {
                        if (pressed)
                            update(e.x);
                    }
                    // Seek once on release, not continuously mid-drag --
                    // some players (browsers especially) handle a stream
                    // of position writes badly.
                    onReleased: Media.seek(dragFrac)
                }
            }

            RowLayout {
                Layout.fillWidth: true

                // Both readouts sit on a dimmed primary text color for
                // the same reason as the artist line: Colors.subtext is
                // too quiet over blurred art. Elapsed takes the accent
                // while scrubbing so the number you're steering by is
                // unmistakably the one that's moving.
                // Each readout takes half the row and aligns to its own
                // outer edge, rather than being pushed apart by a spacer
                // Item. Both then land exactly on the track's ends --
                // the track spans this same width -- so the column reads
                // as one block with flush margins.
                MonoText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: root.fmt(root.shownProgress * Media.length)
                    font.pixelSize: 11
                    font.weight: 600
                    color: seekArea.pressed ? Colors.accent : Qt.alpha(Colors.text, 0.75)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.8)

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.durations.fast
                        }
                    }
                }
                MonoText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: Media.length > 0 ? root.fmt(Media.length) : "--:--"
                    font.pixelSize: 11
                    font.weight: 600
                    color: Qt.alpha(Colors.text, 0.75)
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.8)
                }
            }
        }

        // ------------------------------------------------------ //
        //  Controls                                               //
        // ------------------------------------------------------ //
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14
            enabled: Media.hasPlayer
            opacity: Media.hasPlayer ? 1 : 0.35
            transform: Translate {
                id: controlsShift
            }

            // One shadow pass for the whole row. autoPadding lets the
            // blur extend past the buttons' own bounds instead of being
            // clipped flush at their edges.
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowBlur: 0.45
                shadowVerticalOffset: 2
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                }
            }

            TransportButton {
                icon: "shuffle"
                size: 36
                iconSize: 17
                active: Media.shuffleOn
                opacity: Media.shuffleSupported ? 1 : 0.35
                onClicked: Media.toggleShuffle()
            }

            TransportButton {
                icon: "skip_previous"
                size: 42
                iconSize: 22
                opacity: (Media.active?.canGoPrevious ?? false) ? 1 : 0.35
                onClicked: Media.previous()
            }

            // Play/pause, with a halo that breathes behind it while
            // playing -- the one piece of ambient motion on the card, and
            // the fastest way to read playback state from across the
            // room. It lives in a wrapper Item because IconButton binds
            // its own `scale` to its press feedback; the halo is a
            // sibling BEHIND the button, so it can grow past the
            // button's edge without touching it.
            Item {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                Rectangle {
                    anchors.centerIn: parent
                    width: 52 + 22 * root.playT
                    height: width
                    radius: width / 2
                    color: Colors.accent
                    // Fades out as it expands, so the loop's restart is
                    // invisible: the ring is already gone by then.
                    opacity: Media.isPlaying ? 0.22 * (1 - root.playT) : 0
                }

                TransportButton {
                    anchors.fill: parent
                    icon: Media.isPlaying ? "pause" : "play_arrow"
                    size: 52
                    iconSize: 26
                    active: true
                    // Solid glyph rather than the font's default
                    // outline: unfilled, "pause" draws as two hollow
                    // bars that read as much lighter than the solid
                    // skip arrows either side of it. FILL=1 gives filled
                    // rounded bars from the same family, so the weight
                    // matches instead of being approximated with
                    // hand-drawn rectangles.
                    iconFill: 1
                    onClicked: Media.togglePlaying()
                }
            }

            TransportButton {
                icon: "skip_next"
                size: 42
                iconSize: 22
                opacity: (Media.active?.canGoNext ?? false) ? 1 : 0.35
                onClicked: Media.next()
            }

            TransportButton {
                icon: Media.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                size: 36
                iconSize: 17
                active: Media.loopState !== MprisLoopState.None
                opacity: Media.loopSupported ? 1 : 0.35
                onClicked: Media.cycleLoop()
            }
        }
    }
}
