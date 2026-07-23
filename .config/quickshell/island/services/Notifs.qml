pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The shell IS the notification daemon. New notifications are tracked
// (they appear in the Control Center list) and forwarded to GlobalState
// so the island can flash them.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications

    function clearAll(): void {
        // Copy first — dismissing mutates the list we're iterating.
        [...server.trackedNotifications.values].forEach(n => n.dismiss());
    }

    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: true

        onNotification: notif => {
            notif.tracked = true;
            GlobalState.pushNotif(notif);
        }
    }
}
