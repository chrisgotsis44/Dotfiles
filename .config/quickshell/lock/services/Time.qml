pragma Singleton

import Quickshell
import QtQuick

Singleton {
    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string dateStr: Qt.formatDateTime(clock.date, "ddd d MMM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
