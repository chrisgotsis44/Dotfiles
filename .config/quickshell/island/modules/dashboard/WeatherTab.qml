pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Particles
import qs.config
import qs.services
import qs.components

// The Dashboard's Weather tab -- a Breezy-Weather-style full forecast
// panel fed by services/WeatherData.qml (Open-Meteo). Top to bottom:
//
//   Hero        location + time, big temperature, condition icon, and an
//               ambient animation layer that reacts to the live
//               condition (sun-glow pulse, drifting clouds, rain/snow
//               particles, storm flashes, twinkling stars at night)
//   Stats grid  feels-like / humidity / wind / UV / AQI / pressure /
//               visibility / today's precip chance
//   Hourly      horizontally scrollable next-24-hours strip with a
//               Canvas temperature curve under the hour cells
//   Daily       7-day list, each row a min/max range bar positioned
//               within the whole week's span (today also gets a marker
//               for the current temperature)
//   Sun & Moon  sunrise->sunset arc with the sun's current position,
//               plus the computed moon phase
//
// All ambient animations and particle systems bind their `running` to
// effective visibility, so they fully stop while the dashboard is
// closed or another tab is active -- zero idle cost.
Item {
    id: root

    implicitHeight: col.implicitHeight

    readonly property var cur: WeatherData.current
    readonly property bool isDay: cur ? cur.isDay : true

    // Sun position along the day's arc, 0 at sunrise -> 1 at sunset.
    // Time.time makes it re-evaluate every minute.
    readonly property real sunFrac: {
        Time.time;
        if (!WeatherData.sunriseMs || WeatherData.sunsetMs <= WeatherData.sunriseMs)
            return 0;
        return Math.max(0, Math.min(1, (Date.now() - WeatherData.sunriseMs) / (WeatherData.sunsetMs - WeatherData.sunriseMs)));
    }

    onSunFracChanged: sunArc.requestPaint()

    Connections {
        target: WeatherData
        function onHourlyChanged() { hourChart.requestPaint(); }
        function onDailyChanged() { sunArc.requestPaint(); }
    }

    // Canvases paint with theme colors, so a live theme switch has to
    // trigger a repaint -- they don't rebind like declarative items.
    Connections {
        target: Colors
        function onPaletteChanged() {
            hourChart.requestPaint();
            sunArc.requestPaint();
        }
    }

    // Small stat tile for the quick-stats grid.
    component StatCell: StyledRect {
        id: cell

        property string icon
        property string label
        property string value
        property string sub: ""

        Layout.fillWidth: true
        implicitHeight: 60
        radius: 16
        color: Colors.surface
        border.width: 1
        border.color: Colors.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MaterialIcon {
                text: cell.icon
                font.pixelSize: 19
                color: Colors.accent
            }

            Column {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    width: parent.width
                    text: cell.label
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Colors.subtext
                }
                Row {
                    spacing: 5

                    MonoText {
                        id: cellValue
                        text: cell.value
                        font.pixelSize: 14
                        font.weight: 600
                    }
                    StyledText {
                        anchors.baseline: cellValue.baseline
                        visible: cell.sub !== ""
                        text: cell.sub
                        font.pixelSize: 11
                        color: Colors.faint
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        // ======================================================== //
        //  HERO -- current conditions + ambient animation           //
        // ======================================================== //
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 156
            radius: 24
            clip: true
            color: Colors.surface
            border.width: 1
            border.color: Colors.border

            // ---- ambient layer (behind the text) ---- //
            Item {
                id: fx
                anchors.fill: parent

                readonly property string kind: WeatherData.heroKind

                // Sun-glow pulse (clear day): warm core over a wide
                // accent-tinted halo, breathing slowly.
                Item {
                    visible: fx.kind === "clear" && root.isDay
                    anchors.fill: parent

                    Rectangle {
                        id: sunHalo
                        x: parent.width - width + 60
                        y: -height / 2
                        width: 290
                        height: 290
                        radius: width / 2
                        color: Qt.alpha(Colors.accent, 0.16)

                        SequentialAnimation on scale {
                            running: sunHalo.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.14; duration: 2600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        x: parent.width - width + 20
                        y: -height / 2 + 26
                        width: 150
                        height: 150
                        radius: width / 2
                        // The one deliberately unthemed color in the shell:
                        // the sun is gold on every planet.
                        color: Qt.alpha("#F6C453", 0.34)

                        SequentialAnimation on opacity {
                            running: visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 2600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // Twinkling stars (clear night).
                Repeater {
                    model: fx.kind === "clear" && !root.isDay ? 14 : 0

                    Rectangle {
                        id: star
                        required property int index
                        x: (star.index * 131 + 47) % Math.max(1, fx.width - 8)
                        y: (star.index * 71 + 13) % Math.max(1, fx.height - 30)
                        width: star.index % 3 === 0 ? 3 : 2
                        height: width
                        radius: width / 2
                        color: Colors.text
                        opacity: 0.2

                        SequentialAnimation on opacity {
                            running: star.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: (star.index * 211) % 1400 }
                            NumberAnimation { to: 0.85; duration: 800 + (star.index * 97) % 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.15; duration: 800 + (star.index * 61) % 900; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // Drifting soft cloud blobs (cloudy / fog, and behind
                // rain & snow too -- precipitation implies cloud).
                Repeater {
                    model: ["cloudy", "fog", "rain", "snow", "storm"].includes(fx.kind) ? 3 : 0

                    Rectangle {
                        id: cloud
                        required property int index
                        y: 8 + cloud.index * 34
                        width: 200 + cloud.index * 55
                        height: 54 + cloud.index * 12
                        radius: height / 2
                        color: Qt.alpha(Colors.text, 0.055)

                        NumberAnimation on x {
                            running: cloud.visible
                            loops: Animation.Infinite
                            from: -cloud.width
                            to: fx.width
                            duration: 34000 + cloud.index * 17000
                        }
                    }
                }

                // Low haze band (fog only).
                Rectangle {
                    visible: fx.kind === "fog"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * 0.55
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.alpha(Colors.text, 0.10) }
                    }
                }

                // Rain / snow particles. `system.running` is bound to
                // effective visibility so nothing simulates while the
                // dashboard is closed or another tab is shown.
                ParticleSystem {
                    id: precipSystem
                    anchors.fill: parent
                    running: visible && (fx.kind === "rain" || fx.kind === "storm" || fx.kind === "snow")

                    Emitter {
                        anchors.top: parent.top
                        anchors.topMargin: -14
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        emitRate: fx.kind === "snow" ? 22 : fx.kind === "storm" ? 70 : 45
                        lifeSpan: fx.kind === "snow" ? 5200 : 1600
                        velocity: AngleDirection {
                            angle: 95
                            angleVariation: fx.kind === "snow" ? 24 : 4
                            magnitude: fx.kind === "snow" ? 42 : 170
                            magnitudeVariation: fx.kind === "snow" ? 16 : 45
                        }
                    }

                    ItemParticle {
                        delegate: Rectangle {
                            width: fx.kind === "snow" ? 4 : 2
                            height: fx.kind === "snow" ? 4 : 13
                            radius: width / 2
                            rotation: fx.kind === "snow" ? 0 : 12
                            color: Qt.alpha(Colors.text, fx.kind === "snow" ? 0.65 : 0.30)
                        }
                    }
                }

                // Occasional lightning flash (storm only).
                Rectangle {
                    id: flash
                    visible: fx.kind === "storm"
                    anchors.fill: parent
                    color: Colors.text
                    opacity: 0

                    SequentialAnimation on opacity {
                        running: flash.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: 3700 }
                        NumberAnimation { to: 0.18; duration: 50 }
                        NumberAnimation { to: 0.02; duration: 90 }
                        NumberAnimation { to: 0.26; duration: 60 }
                        NumberAnimation { to: 0; duration: 300 }
                        PauseAnimation { duration: 5600 }
                    }
                }
            }

            // ---- readout ---- //
            Item {
                anchors.fill: parent
                anchors.margins: 20

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 3

                    Row {
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "location_on"
                            font.pixelSize: 15
                            color: Colors.accent
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: WeatherData.city || "Locating…"
                            font.pixelSize: 16
                            font.weight: 700
                        }
                        MonoText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.time
                            font.pixelSize: 12
                            color: Colors.subtext
                        }
                    }

                    StyledText {
                        text: root.cur ? WeatherData.descFor(root.cur.code) : "Waiting for data…"
                        font.pixelSize: 14
                        color: Colors.subtext
                    }
                }

                // Big temperature -- Adwaita Sans on purpose, same call
                // as the clock: the mono font's digits read blocky at
                // display sizes.
                StyledText {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: root.cur ? Math.round(root.cur.temp) + "°" : "--°"
                    font.family: Appearance.font.family
                    font.pixelSize: 58
                    font.weight: 800
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.cur ? WeatherData.iconFor(root.cur.code, root.cur.isDay) : "cloud"
                    font.pixelSize: 76
                    color: Qt.alpha(Colors.text, 0.9)
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: WeatherData.updatedLabel
                    font.pixelSize: 11
                    color: Colors.faint
                }
            }
        }

        // ======================================================== //
        //  QUICK STATS                                              //
        // ======================================================== //
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            StatCell {
                icon: "thermostat"
                label: "Feels like"
                value: root.cur ? Math.round(root.cur.feels) + "°" : "--"
            }
            StatCell {
                icon: "humidity_percentage"
                label: "Humidity"
                value: root.cur ? root.cur.humidity + "%" : "--"
            }
            StatCell {
                icon: "air"
                label: "Wind"
                value: root.cur ? Math.round(root.cur.windSpeed) + " km/h" : "--"
                sub: root.cur ? WeatherData.compass(root.cur.windDir) : ""
            }
            StatCell {
                icon: "wb_sunny"
                label: "UV index"
                value: WeatherData.uv >= 0 ? Math.round(WeatherData.uv).toString() : "--"
                sub: WeatherData.uvLabel(WeatherData.uv)
            }
            StatCell {
                icon: "aq_indoor"
                label: "Air quality"
                value: WeatherData.aqi >= 0 ? WeatherData.aqi.toString() : "--"
                sub: WeatherData.aqiLabel(WeatherData.aqi)
            }
            StatCell {
                icon: "compress"
                label: "Pressure"
                value: root.cur ? Math.round(root.cur.pressure) + " hPa" : "--"
            }
            StatCell {
                icon: "visibility"
                label: "Visibility"
                value: WeatherData.visibilityKm >= 0
                    ? (WeatherData.visibilityKm >= 10
                        ? Math.round(WeatherData.visibilityKm) + " km"
                        : WeatherData.visibilityKm.toFixed(1) + " km")
                    : "--"
            }
            StatCell {
                icon: "rainy"
                label: "Rain chance"
                value: WeatherData.daily.length > 0 ? WeatherData.daily[0].precip + "%" : "--"
                sub: "today"
            }
        }

        // ======================================================== //
        //  HOURLY -- next 24 h strip + temperature curve            //
        // ======================================================== //
        StatCard {
            Layout.fillWidth: true
            icon: "schedule"
            title: "NEXT 24 HOURS"

            Flickable {
                width: parent.width
                height: 130
                contentWidth: hourStrip.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: hourStrip
                    width: WeatherData.hourly.length * 58

                    Row {
                        Repeater {
                            model: WeatherData.hourly

                            Column {
                                id: hourCell
                                required property var modelData
                                required property int index
                                width: 58
                                spacing: 3

                                MonoText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: hourCell.modelData.label
                                    font.pixelSize: 11
                                    font.weight: hourCell.index === 0 ? 700 : 400
                                    color: hourCell.index === 0 ? Colors.text : Colors.subtext
                                }
                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: WeatherData.iconFor(hourCell.modelData.code, hourCell.modelData.isDay)
                                    font.pixelSize: 19
                                    color: hourCell.index === 0 ? Colors.accent : Colors.text
                                }
                                MonoText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: hourCell.modelData.precip + "%"
                                    font.pixelSize: 10
                                    color: hourCell.modelData.precip >= 30 ? Colors.accent : Colors.faint
                                }
                            }
                        }
                    }

                    // The temperature curve: dots centered under each
                    // hour cell, connected with midpoint-smoothed
                    // quadratic segments, soft gradient fill below.
                    Canvas {
                        id: hourChart
                        width: hourStrip.width
                        height: 46

                        onVisibleChanged: if (visible) requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const data = WeatherData.hourly;
                            if (data.length < 2)
                                return;

                            const cellW = 58;
                            const padY = 9;
                            let min = Infinity, max = -Infinity;
                            for (const h of data) {
                                min = Math.min(min, h.temp);
                                max = Math.max(max, h.temp);
                            }
                            const span = Math.max(1, max - min);
                            const px = i => i * cellW + cellW / 2;
                            const py = t => padY + (1 - (t - min) / span) * (height - padY * 2);

                            ctx.beginPath();
                            ctx.moveTo(px(0), py(data[0].temp));
                            for (let i = 1; i < data.length; i++) {
                                const mx = (px(i - 1) + px(i)) / 2;
                                const my = (py(data[i - 1].temp) + py(data[i].temp)) / 2;
                                ctx.quadraticCurveTo(px(i - 1), py(data[i - 1].temp), mx, my);
                            }
                            ctx.lineTo(px(data.length - 1), py(data[data.length - 1].temp));

                            // Fill first (under the line), then stroke.
                            ctx.save();
                            ctx.lineTo(px(data.length - 1), height);
                            ctx.lineTo(px(0), height);
                            ctx.closePath();
                            // String(color): Context2D's addColorStop wants
                            // a color *string*; QML colors stringify to
                            // "#AARRGGBB", which it parses fine.
                            const grad = ctx.createLinearGradient(0, 0, 0, height);
                            grad.addColorStop(0, String(Qt.alpha(Colors.accent, 0.20)));
                            grad.addColorStop(1, String(Qt.alpha(Colors.accent, 0.0)));
                            ctx.fillStyle = grad;
                            ctx.fill();
                            ctx.restore();

                            ctx.beginPath();
                            ctx.moveTo(px(0), py(data[0].temp));
                            for (let i = 1; i < data.length; i++) {
                                const mx = (px(i - 1) + px(i)) / 2;
                                const my = (py(data[i - 1].temp) + py(data[i].temp)) / 2;
                                ctx.quadraticCurveTo(px(i - 1), py(data[i - 1].temp), mx, my);
                            }
                            ctx.lineTo(px(data.length - 1), py(data[data.length - 1].temp));
                            ctx.strokeStyle = Colors.accent;
                            ctx.lineWidth = 2;
                            ctx.stroke();

                            for (let i = 0; i < data.length; i++) {
                                ctx.beginPath();
                                ctx.arc(px(i), py(data[i].temp), i === 0 ? 3.5 : 2.5, 0, Math.PI * 2);
                                ctx.fillStyle = Colors.accent;
                                ctx.fill();
                            }
                        }
                    }

                    Row {
                        Repeater {
                            model: WeatherData.hourly

                            MonoText {
                                required property var modelData
                                width: 58
                                horizontalAlignment: Text.AlignHCenter
                                text: Math.round(modelData.temp) + "°"
                                font.pixelSize: 12
                                font.weight: 600
                            }
                        }
                    }
                }
            }
        }

        // ======================================================== //
        //  DAILY -- 7-day forecast with range bars                  //
        // ======================================================== //
        StatCard {
            Layout.fillWidth: true
            icon: "calendar_month"
            title: "7-DAY FORECAST"

            Column {
                width: parent.width
                spacing: 2

                // The whole week's extremes, so each day's bar shows
                // where it sits within the week -- not just its own span.
                readonly property real weekMin: {
                    let m = Infinity;
                    for (const d of WeatherData.daily)
                        m = Math.min(m, d.min);
                    return m;
                }
                readonly property real weekMax: {
                    let m = -Infinity;
                    for (const d of WeatherData.daily)
                        m = Math.max(m, d.max);
                    return m;
                }

                Repeater {
                    model: WeatherData.daily

                    RowLayout {
                        id: dayRow

                        required property var modelData
                        required property int index

                        readonly property real weekMin: parent.weekMin
                        readonly property real weekMax: parent.weekMax
                        readonly property real span: Math.max(1, weekMax - weekMin)

                        width: parent.width
                        height: 30
                        spacing: 10

                        StyledText {
                            Layout.preferredWidth: 58
                            text: dayRow.modelData.day
                            font.pixelSize: 13
                            font.weight: dayRow.index === 0 ? 700 : 500
                        }

                        MaterialIcon {
                            text: WeatherData.iconFor(dayRow.modelData.code, true)
                            font.pixelSize: 18
                            color: Colors.text
                        }

                        MonoText {
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                            text: dayRow.modelData.precip + "%"
                            font.pixelSize: 11
                            color: dayRow.modelData.precip >= 30 ? Colors.accent : Colors.faint
                        }

                        MonoText {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(dayRow.modelData.min) + "°"
                            font.pixelSize: 12
                            color: Colors.subtext
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: Colors.surfaceHigh
                            }

                            Rectangle {
                                readonly property real x0: (dayRow.modelData.min - dayRow.weekMin) / dayRow.span
                                readonly property real x1: (dayRow.modelData.max - dayRow.weekMin) / dayRow.span
                                x: x0 * parent.width
                                width: Math.max(6, (x1 - x0) * parent.width)
                                height: parent.height
                                radius: 3
                                color: Colors.accent
                            }

                            // Today's row: where the temperature is right
                            // now within today's range.
                            Rectangle {
                                visible: dayRow.index === 0 && root.cur !== null
                                x: root.cur
                                    ? Math.max(0, Math.min(1, (root.cur.temp - dayRow.weekMin) / dayRow.span)) * parent.width - width / 2
                                    : 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: Colors.text
                                border.width: 2
                                border.color: Colors.bg
                            }
                        }

                        MonoText {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(dayRow.modelData.max) + "°"
                            font.pixelSize: 12
                            font.weight: 600
                        }
                    }
                }

                StyledText {
                    visible: WeatherData.daily.length === 0
                    text: "Waiting for forecast…"
                    font.pixelSize: 13
                    color: Colors.faint
                }
            }
        }

        // ======================================================== //
        //  SUN & MOON                                               //
        // ======================================================== //
        StatCard {
            Layout.fillWidth: true
            icon: "wb_twilight"
            title: "SUN & MOON"

            RowLayout {
                width: parent.width
                spacing: 18

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84

                    Canvas {
                        id: sunArc
                        anchors.fill: parent
                        anchors.bottomMargin: 22

                        onVisibleChanged: if (visible) requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const pad = 22;
                            const cy = height - 4;
                            const rx = (width - pad * 2) / 2;
                            const ry = height - 14;
                            const cx = width / 2;
                            const frac = root.sunFrac;

                            // Full arc, faint & dashed. Traced manually:
                            // ctx.ellipse() closes the WHOLE ellipse, so
                            // the bottom half would show under the
                            // horizon line.
                            ctx.beginPath();
                            ctx.setLineDash([4, 5]);
                            for (let t = 0; t <= 1.001; t += 0.02) {
                                const a = Math.PI * (1 - t);
                                const x = cx + rx * Math.cos(a);
                                const y = cy - ry * Math.sin(a);
                                if (t === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = Qt.alpha(Colors.text, 0.18);
                            ctx.lineWidth = 2;
                            ctx.stroke();
                            ctx.setLineDash([]);

                            // Elapsed portion, accent. Canvas ellipse()
                            // can't do partial sweeps portably, so trace
                            // it manually.
                            if (frac > 0) {
                                ctx.beginPath();
                                for (let t = 0; t <= frac; t += 0.01) {
                                    const a = Math.PI * (1 - t);
                                    const x = cx + rx * Math.cos(a);
                                    const y = cy - ry * Math.sin(a);
                                    if (t === 0)
                                        ctx.moveTo(x, y);
                                    else
                                        ctx.lineTo(x, y);
                                }
                                ctx.strokeStyle = Colors.accent;
                                ctx.lineWidth = 2.5;
                                ctx.stroke();
                            }

                            // The sun itself.
                            const a = Math.PI * (1 - frac);
                            const sx = cx + rx * Math.cos(a);
                            const sy = cy - ry * Math.sin(a);
                            const up = frac > 0 && frac < 1;
                            ctx.beginPath();
                            ctx.arc(sx, sy, 9, 0, Math.PI * 2);
                            ctx.fillStyle = Qt.alpha("#F6C453", up ? 0.35 : 0.15);
                            ctx.fill();
                            ctx.beginPath();
                            ctx.arc(sx, sy, 5, 0, Math.PI * 2);
                            ctx.fillStyle = up ? "#F6C453" : Qt.alpha(Colors.text, 0.4);
                            ctx.fill();
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        spacing: 0

                        MonoText {
                            text: WeatherData.sunrise
                            font.pixelSize: 12
                            font.weight: 600
                        }
                        StyledText {
                            text: "Sunrise"
                            font.pixelSize: 10
                            color: Colors.faint
                        }
                    }

                    Column {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: 0

                        MonoText {
                            anchors.right: parent.right
                            text: WeatherData.sunset
                            font.pixelSize: 12
                            font.weight: 600
                        }
                        StyledText {
                            anchors.right: parent.right
                            text: "Sunset"
                            font.pixelSize: 10
                            color: Colors.faint
                        }
                    }
                }

                Column {
                    Layout.preferredWidth: 130
                    spacing: 3

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: WeatherData.moonEmoji
                        font.pixelSize: 38
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: WeatherData.moonName || "—"
                        font.pixelSize: 12
                        font.weight: 600
                        color: Colors.subtext
                    }
                }
            }
        }
    }
}
