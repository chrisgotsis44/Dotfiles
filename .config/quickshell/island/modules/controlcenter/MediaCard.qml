import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// Now-playing card. The album art is rendered twice: once heavily
// blurred as the card's full background, once sharp as a thumbnail.
//
// When no MPRIS player is running, Media serves the cached last
// session: the track and art stay visible, but the transport controls
// and progress bar dim and stop accepting input.
ClippingRectangle {
    id: root

    implicitHeight: 140
    radius: 22
    color: Colors.surface
    border.width: 1
    border.color: Colors.border

    readonly property bool hasArt: Media.artUrl !== "" && bgArt.status === Image.Ready

    Image {
        id: bgArt
        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 460
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bgArt
        visible: root.hasArt
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.1
    }

    // Legibility scrim over the blur
    Rectangle {
        anchors.fill: parent
        color: root.hasArt ? Colors.scrim : "transparent"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Item {
            width: parent.width
            height: 68

            ClippingRectangle {
                id: thumb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 68
                height: 68
                radius: 14
                color: Colors.surfaceHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    font.pixelSize: 26
                    color: Colors.subtext
                    visible: !root.hasArt
                }

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 136
                    sourceSize.height: 136
                }
            }

            Column {
                anchors.left: thumb.right
                anchors.leftMargin: 14
                anchors.right: controls.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                StyledText {
                    width: parent.width
                    text: Media.title
                    elide: Text.ElideRight
                    font.pixelSize: 16
                    font.weight: 700
                }
                StyledText {
                    width: parent.width
                    text: Media.artist
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: Colors.subtext
                }
                StyledText {
                    width: parent.width
                    visible: !Media.hasPlayer && Media.title !== "Nothing playing"
                    text: "Last session"
                    font.pixelSize: 11
                    color: Colors.faint
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Dimmed and inert while showing a cached session.
                enabled: Media.hasPlayer
                opacity: Media.hasPlayer ? 1 : 0.35

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_previous"
                    size: 36
                    iconSize: 18
                    onClicked: Media.previous()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Media.isPlaying ? "pause" : "play_arrow"
                    size: 46
                    iconSize: 24
                    active: true
                    onClicked: Media.togglePlaying()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_next"
                    size: 36
                    iconSize: 18
                    onClicked: Media.next()
                }
            }
        }

        // Seekable progress bar
        Item {
            width: parent.width
            height: 16
            enabled: Media.hasPlayer
            opacity: Media.hasPlayer ? 1 : 0.35

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                color: Colors.sliderTrack

                Rectangle {
                    width: Media.progress * parent.width
                    height: parent.height
                    radius: 2.5
                    color: Colors.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: e => Media.seek(e.x / width)
            }
        }
    }
}
