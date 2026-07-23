pragma Singleton

import Quickshell
import Quickshell.Services.Polkit
import QtQuick

// The shell IS the polkit authentication agent, the same way Notifs.qml
// makes it the notification daemon. Only one process on the system can
// hold this D-Bus role at a time -- if another agent (polkit-gnome,
// lxqt-policykit, ...) is running it'll grab the registration first and
// this one will just sit idle, so that package should be removed/disabled
// for the island's own prompt to actually appear.
Singleton {
    id: root

    readonly property alias flow: agent.flow
    readonly property bool active: agent.isActive
    readonly property bool registered: agent.isRegistered

    PolkitAgent {
        id: agent
    }
}
