pragma Singleton

import Quickshell
import QtQuick
import qs.config

Singleton {
    readonly property date now: clock.date

    // Built from config.json. Seconds costs a per-second wakeup, so the
    // clock's own precision follows the setting rather than always
    // running at the finer rate.
    readonly property string timeFormat: {
        const h = Config.settings.clock24h ? "HH" : "h";
        const s = Config.settings.showSeconds ? ":ss" : "";
        return h + ":mm" + s + (Config.settings.clock24h ? "" : " AP");
    }

    readonly property string time: Qt.formatDateTime(clock.date, timeFormat)
    readonly property string dateStr: Qt.formatDateTime(clock.date, Config.settings.dateFormat || "ddd d MMM")

    SystemClock {
        id: clock
        precision: Config.settings.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
