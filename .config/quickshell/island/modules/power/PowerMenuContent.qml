import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Session actions, rendered inside the island pill.
Item {
    implicitWidth: row.implicitWidth
    implicitHeight: 68

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 16

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "lock"
            size: 60
            iconSize: 26
            onClicked: {
                GlobalState.powerMenuOpen = false;
                Quickshell.execDetached(["loginctl", "lock-session"]);
            }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "bedtime"
            size: 60
            iconSize: 26
            onClicked: {
                GlobalState.powerMenuOpen = false;
                Quickshell.execDetached(["systemctl", "suspend"]);
            }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "logout"
            size: 60
            iconSize: 26
            onClicked: {
                GlobalState.powerMenuOpen = false;
                Quickshell.execDetached(["loginctl", "terminate-session", "self"]);
            }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "restart_alt"
            size: 60
            iconSize: 26
            onClicked: Quickshell.execDetached(["systemctl", "reboot"])
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "power_settings_new"
            size: 60
            iconSize: 26
            activeColor: Colors.danger
            onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }
}
