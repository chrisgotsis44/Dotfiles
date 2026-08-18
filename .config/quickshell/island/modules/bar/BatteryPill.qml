import QtQuick
import qs.config
import qs.services
import qs.components

// Compact battery readout — charge icon + percentage, no pill/background
// container, matching WeatherPill which it sits beside in the hover
// island.
//
// Collapses to nothing when there's no physical battery: Battery.available
// checks UPower's isLaptopBattery, so a mouse/keyboard's own battery never
// makes this appear on a desktop. Kept as a zero-width Row rather than
// hidden in place so the layouts around it close up instead of leaving a
// gap where it would have been.
Row {
    id: root

    // The hover island and Big Island render this at slightly different
    // scales; everything else about them is identical.
    property int iconSize: 17
    property int textSize: 12

    spacing: 4
    visible: Battery.available

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: Battery.icon
        font.pixelSize: Appearance.font.px(root.iconSize)
        color: Battery.charging ? Colors.accent : Colors.text
    }
    MonoText {
        anchors.verticalCenter: parent.verticalCenter
        text: Battery.percent + "%"
        font.pixelSize: Appearance.font.px(root.textSize)
        font.weight: 600
        color: Colors.subtext
    }
}
