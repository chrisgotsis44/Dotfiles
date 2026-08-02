pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Polkit
import qs.config
import qs.services
import qs.components

// Polkit authentication prompt — rendered inside the island like every
// other menu. There's no local "open" state here: qs/services/Polkit.qml
// wraps Quickshell's native PolkitAgent, and Bar.qml shows this section
// whenever GlobalState.polkitOpen (== Polkit.active) is true. Everything
// below just reacts to whichever AuthFlow that agent currently exposes.
Item {
    id: root

    readonly property AuthFlow flow: Polkit.flow

    implicitWidth: 400
    implicitHeight: content.implicitHeight + 44

    // A failed attempt starts a fresh session for the same identity with
    // a brand new prompt (see AuthFlow docs) -- reset + refocus so the old
    // password never lingers in the field across a retry.
    Connections {
        target: root.flow
        function onInputPromptChanged() {
            passwordField.text = "";
            if (root.flow && root.flow.isResponseRequired)
                passwordField.forceActiveFocus();
        }
    }

    function focusPassword(): void {
        if (root.flow && root.flow.isResponseRequired)
            passwordField.forceActiveFocus();
    }

    onFlowChanged: root.focusPassword()

    // Bar.qml builds this section on the first authentication request of
    // the session, by which point Polkit.flow is already set -- so the
    // binding above starts at its final value and onFlowChanged never
    // fires. Without this the very first prompt would come up with the
    // password field unfocused, and you'd have to click it before typing.
    Component.onCompleted: Qt.callLater(root.focusPassword)

    // Small pill button shared by Cancel / Authenticate below.
    component ActionButton: StyledRect {
        id: btn

        required property string label
        property bool primary: false
        property bool enabled: true

        signal clicked()

        implicitWidth: label_.implicitWidth + 32
        implicitHeight: 40
        radius: Appearance.rounding.small
        opacity: enabled ? 1 : 0.4

        color: primary ? (tap.pressed ? Colors.accentDim : Colors.accent) : (tap.pressed ? Colors.surfacePressed : hover.hovered ? Colors.surfaceHover : Colors.surfaceHigh)

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.fast
            }
        }

        StyledText {
            id: label_
            anchors.centerIn: parent
            text: btn.label
            font.pixelSize: 15
            font.weight: 600
            color: btn.primary ? Colors.accentFg : Colors.text
        }

        HoverHandler {
            id: hover
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tap
            enabled: btn.enabled
            onTapped: btn.clicked()
        }
    }

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 400 - 44
        spacing: 16

        Row {
            width: parent.width
            spacing: 14

            IconImage {
                anchors.top: parent.top
                implicitSize: 36
                source: root.flow ? Quickshell.iconPath(root.flow.iconName || "dialog-password", "dialog-password") : ""
            }

            Column {
                width: parent.width - 36 - 14
                spacing: 3

                StyledText {
                    width: parent.width
                    text: "Authentication Required"
                    wrapMode: Text.Wrap
                    font.pixelSize: 15
                    font.weight: 700
                }
                StyledText {
                    width: parent.width
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: Colors.subtext
                }
            }
        }

        // Only relevant when more than one identity can authorize the
        // action (e.g. several admin-group users) -- a single-user prompt
        // never shows this, the inputPrompt below already says who.
        Row {
            width: parent.width
            spacing: 8
            visible: (root.flow?.identities.length ?? 0) > 1

            Repeater {
                model: root.flow ? root.flow.identities : []

                StyledRect {
                    id: idChip
                    required property var modelData

                    implicitWidth: idLabel.implicitWidth + 24
                    implicitHeight: 30
                    radius: 15
                    color: root.flow && root.flow.selectedIdentity === modelData ? Colors.accent : Colors.surfaceHigh

                    StyledText {
                        id: idLabel
                        anchors.centerIn: parent
                        text: idChip.modelData.displayName || idChip.modelData.string
                        font.pixelSize: 12
                        font.weight: 600
                        color: root.flow && root.flow.selectedIdentity === idChip.modelData ? Colors.accentFg : Colors.text
                    }

                    TapHandler {
                        onTapped: root.flow.selectedIdentity = idChip.modelData
                    }
                }
            }
        }

        // Password (or other credential) field -- only shown while the
        // agent is actually waiting on a response.
        StyledRect {
            width: parent.width
            implicitHeight: 44
            visible: root.flow?.isResponseRequired ?? false
            radius: 14
            color: Colors.surface
            border.width: 1
            border.color: passwordField.activeFocus ? Colors.accentDim : Colors.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    font.pixelSize: 18
                    color: Colors.subtext
                }

                TextInput {
                    id: passwordField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28 - 10
                    color: Colors.text
                    font.family: Appearance.font.family
                    font.pixelSize: 15
                    clip: true
                    // Most conversations are a password (responseVisible
                    // false); anything the agent marks visible (e.g. a
                    // security question) is shown in the clear instead.
                    echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password

                    onAccepted: if (root.flow)
                        root.flow.submit(text)

                    Keys.onEscapePressed: if (root.flow)
                        root.flow.cancelAuthenticationRequest()

                    StyledText {
                        visible: passwordField.text === ""
                        text: root.flow?.inputPrompt || "Password"
                        font.pixelSize: 15
                        color: Colors.faint
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Inline error/info from the agent -- e.g. "Sorry, try again."
        StyledText {
            width: parent.width
            visible: (root.flow?.supplementaryMessage ?? "") !== ""
            text: root.flow?.supplementaryMessage ?? ""
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: (root.flow?.supplementaryIsError ?? false) ? Colors.danger : Colors.subtext
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            ActionButton {
                label: "Cancel"
                onClicked: if (root.flow)
                    root.flow.cancelAuthenticationRequest()
            }
            ActionButton {
                label: "Authenticate"
                primary: true
                enabled: root.flow?.isResponseRequired ?? false
                onClicked: if (root.flow)
                    root.flow.submit(passwordField.text)
            }
        }
    }
}
