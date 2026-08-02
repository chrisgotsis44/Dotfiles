import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.config

// Wallpaper, blur, dim, edge scrim and the motion behind the lockscreen.
//
// Deliberately knows nothing about lock state -- LockSurface drives the
// booleans, which is what lets the same component fade back OUT on a
// successful unlock (the wallpaper sharpens, then the surface goes away).
Item {
    id: root

    // Entrance: false -> true ramps blur and dim up from nothing.
    property bool active: false
    // Idle: deepens both.
    property bool dimmed: false
    // Pointer parallax offset, in pixels, set by the surface.
    property real parallaxX: 0
    property real parallaxY: 0

    property string wallPath: ""

    readonly property var videoExts: [".mp4", ".mkv", ".mov", ".webm"]

    // Video wallpapers can't go through Image at all. The picker has
    // already generated a still for every one of them (that's what the
    // thumbs_<theme> cache is), so reuse it rather than showing nothing.
    readonly property string resolved: {
        const p = root.wallPath;
        if (p === "")
            return "";
        const lower = p.toLowerCase();
        if (!root.videoExts.some(e => lower.endsWith(e)))
            return "file://" + p;
        const name = p.slice(p.lastIndexOf("/") + 1);
        return "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/thumbs_" + Colors.themeName + "/" + name;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/colorschemes/.current-wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallPath = text().trim()
        onLoadFailed: error => {}
    }

    // Opaque floor. The lock surface itself is transparent so the unlock
    // reveal can show the desktop through it, which means this rectangle
    // is the only thing guaranteeing the desktop is never visible while
    // locked -- it must stay opaque and unconditional.
    Rectangle {
        anchors.fill: parent
        color: Colors.bg
    }

    Item {
        id: drift
        anchors.fill: parent

        // Four separate transforms rather than one, because they animate
        // independently and would otherwise fight over the same property:
        // the ambient loop owns driftScale, the entrance owns settleScale.
        // The combined overshoot always has to exceed drift + parallax, or
        // the movement exposes an uncovered edge.
        transform: [
            Scale {
                id: driftScale
                origin.x: drift.width / 2
                origin.y: drift.height / 2
                xScale: 1.06
                yScale: 1.06
            },
            Scale {
                id: settleScale
                origin.x: drift.width / 2
                origin.y: drift.height / 2
                // Starts wider than it ends: on lock the wallpaper eases
                // back as the blur comes up, so the screen reads as a
                // camera settling rather than a still being covered over.
                xScale: root.active ? 1.0 : 1.06
                yScale: settleScale.xScale

                Behavior on xScale {
                    NumberAnimation {
                        duration: Appearance.anim.durations.expand * 2
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.emphasized
                    }
                }
            },
            Translate {
                id: driftShift
            },
            // Pointer parallax, kept to a handful of pixels: enough that
            // the background feels attached to the cursor, small enough
            // that it never announces itself.
            Translate {
                x: root.parallaxX
                y: root.parallaxY

                Behavior on x {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.OutQuad
                    }
                }
            }
        ]

        Image {
            id: wall
            anchors.fill: parent
            source: root.resolved
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            // Decoded small on purpose: the upscale to full screen is
            // itself most of the blur, which is what makes the shader
            // pass below cheap enough to run under a never-ending
            // animation.
            sourceSize.width: 512
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blurMax: 48
            blur: root.active ? (root.dimmed ? 1.0 : 0.7) : 0

            Behavior on blur {
                NumberAnimation {
                    duration: Appearance.anim.durations.expand
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg
        opacity: root.active ? (root.dimmed ? 0.74 : 0.42) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    // Edge scrim. The date and the status row sit in the corners with no
    // surface behind them, so they would otherwise be at the mercy of
    // whatever the wallpaper happens to put there. Weighted to the bottom,
    // which carries more content.
    Rectangle {
        anchors.fill: parent
        opacity: root.active ? 1 : 0

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(0, 0, 0, 0.34)
            }
            GradientStop {
                position: 0.26
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.46)
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.expand
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }
    }

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                targets: [driftScale]
                properties: "xScale,yScale"
                to: 1.1
                duration: 30000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: driftShift
                property: "x"
                to: root.width * 0.012
                duration: 30000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: driftShift
                property: "y"
                to: root.height * -0.012
                duration: 30000
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                targets: [driftScale]
                properties: "xScale,yScale"
                to: 1.06
                duration: 30000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: driftShift
                property: "x"
                to: 0
                duration: 30000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: driftShift
                property: "y"
                to: 0
                duration: 30000
                easing.type: Easing.InOutSine
            }
        }
    }
}
