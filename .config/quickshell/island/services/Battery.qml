pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)
    readonly property bool charging: !UPower.onBattery

    readonly property string icon: {
        if (charging)
            return "bolt";
        if (percent >= 85)
            return "battery_full";
        if (percent >= 60)
            return "battery_5_bar";
        if (percent >= 40)
            return "battery_3_bar";
        if (percent >= 20)
            return "battery_2_bar";
        return "battery_alert";
    }
}
