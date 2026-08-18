pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Full weather backend for the Dashboard's Weather tab, separate from
// the lightweight Weather.qml (which keeps feeding the hover pill and
// Control Center card from wttr.in and stays untouched).
//
// Chain: ipapi.co (IP -> lat/lon/city, fetched once per session) ->
// Open-Meteo forecast + air-quality (two parallel curls). Everything is
// parsed into plain JS structures the tab can bind to directly:
//
//   current   { temp, feels, humidity, windSpeed, windDir, code, isDay,
//               pressure }
//   hourly    [24 x { label, temp, code, precip, isDay }]  from this hour
//   daily     [ 7 x { day, code, precip, min, max }]       daily[0] = today
//
// plus sunrise/sunset (label + epoch ms for the sun-arc), UV, AQI,
// visibility, and a locally-computed moon phase. The last successful
// fetch is cached to ~/.cache so a restart repopulates the tab
// instantly instead of showing a blank panel until the first fetch.
Singleton {
    id: root

    // ---- location (IP-geolocated once, then remembered) ----
    property string city: ""
    property string latitude: ""
    property string longitude: ""

    // ---- parsed model ----
    property var current: null
    property var hourly: []
    property var daily: []
    property string sunrise: "--:--"
    property string sunset: "--:--"
    property double sunriseMs: 0
    property double sunsetMs: 0
    property int aqi: -1
    property real uv: -1
    property real visibilityKm: -1
    property string moonName: ""
    property string moonEmoji: ""
    property double fetchedAt: 0

    readonly property bool ready: current !== null
    readonly property bool busy: geoProc.running || geoFallbackProc.running || forecastProc.running

    // Drives the hero card's ambient animation.
    // One of: "clear" | "cloudy" | "fog" | "rain" | "snow" | "storm"
    readonly property string heroKind: current ? kindFor(current.code) : "clear"

    // Referencing Time.time makes this re-evaluate every minute without
    // its own timer.
    readonly property string updatedLabel: {
        Time.time;
        if (!fetchedAt)
            return "";
        const mins = Math.round((Date.now() - fetchedAt) / 60000);
        if (mins < 1)
            return "Updated just now";
        if (mins < 60)
            return "Updated " + mins + " min ago";
        const h = Math.round(mins / 60);
        return "Updated " + h + (h === 1 ? " hour ago" : " hours ago");
    }

    // ---- WMO weather-code mappings ----

    function iconFor(code: int, isDay: bool): string {
        if (code === 0 || code === 1)
            return isDay ? "clear_day" : "clear_night";
        if (code === 2)
            return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "foggy";
        if (code >= 51 && code <= 67)
            return "rainy";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "weather_snowy";
        if (code >= 80 && code <= 82)
            return "rainy";
        if (code === 96 || code === 99)
            return "weather_hail";
        if (code >= 95)
            return "thunderstorm";
        return "cloud";
    }

    function descFor(code: int): string {
        if (code === 0) return "Clear sky";
        if (code === 1) return "Mostly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Foggy";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 65) return "Rain";
        if (code === 66 || code === 67) return "Freezing rain";
        if (code >= 71 && code <= 75) return "Snow";
        if (code === 77) return "Snow grains";
        if (code >= 80 && code <= 82) return "Rain showers";
        if (code === 85 || code === 86) return "Snow showers";
        if (code === 96 || code === 99) return "Thunderstorm with hail";
        if (code >= 95) return "Thunderstorm";
        return "";
    }

    function kindFor(code: int): string {
        if (code <= 1) return "clear";
        if (code <= 3) return "cloudy";
        if (code === 45 || code === 48) return "fog";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        if (code >= 95) return "storm";
        return "rain";
    }

    function compass(deg: real): string {
        const pts = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return pts[Math.round(deg / 45) % 8];
    }

    function aqiLabel(v: int): string {
        if (v < 0) return "";
        if (v <= 20) return "Good";
        if (v <= 40) return "Fair";
        if (v <= 60) return "Moderate";
        if (v <= 80) return "Poor";
        if (v <= 100) return "Very poor";
        return "Extreme";
    }

    function uvLabel(v: real): string {
        if (v < 0) return "";
        if (v < 3) return "Low";
        if (v < 6) return "Moderate";
        if (v < 8) return "High";
        if (v < 11) return "Very high";
        return "Extreme";
    }

    // Phase fraction from a known new moon (2000-01-06 18:14 UTC),
    // bucketed into the eight classic phases. An approximation, but
    // accurate to well under a day -- plenty for a phase readout.
    function computeMoon(): void {
        const synodic = 29.53058867;
        const epoch = Date.UTC(2000, 0, 6, 18, 14) / 86400000;
        const days = Date.now() / 86400000 - epoch;
        const p = (days % synodic + synodic) % synodic / synodic;
        const idx = Math.round(p * 8) % 8;
        root.moonName = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
                         "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"][idx];
        root.moonEmoji = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"][idx];
    }

    // ---- fetching ----

    function refresh(): void {
        if (busy)
            return;
        if (latitude === "")
            geoProc.running = true;
        else {
            forecastProc.running = true;
            aqiProc.running = true;
        }
    }

    Process {
        id: geoProc
        command: ["curl", "-sf", "--max-time", "8", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    if (!j.latitude || !j.longitude)
                        throw "no coordinates";
                    root.latitude = String(j.latitude);
                    root.longitude = String(j.longitude);
                    root.city = j.city || "";
                    forecastProc.running = true;
                    aqiProc.running = true;
                } catch (e) {
                    // ipapi.co rate-limits bursts (429, observed live) --
                    // fall back to ipinfo.io before giving up on this
                    // round entirely.
                    geoFallbackProc.running = true;
                }
            }
        }
    }

    Process {
        id: geoFallbackProc
        command: ["curl", "-sf", "--max-time", "8", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const parts = (j.loc || "").split(",");
                    if (parts.length !== 2)
                        throw "no coordinates";
                    root.latitude = parts[0];
                    root.longitude = parts[1];
                    root.city = j.city || "";
                    forecastProc.running = true;
                    aqiProc.running = true;
                } catch (e) {
                    retryTimer.restart();
                }
            }
        }
    }

    Process {
        id: forecastProc
        command: ["curl", "-sf", "--max-time", "12",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.latitude + "&longitude=" + root.longitude
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,surface_pressure,wind_speed_10m,wind_direction_10m"
            + "&hourly=temperature_2m,precipitation_probability,weather_code,uv_index,visibility,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"
            + "&timezone=auto&forecast_days=8"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apply(JSON.parse(text), true);
                } catch (e) {
                    retryTimer.restart();
                }
            }
        }
    }

    Process {
        id: aqiProc
        command: ["curl", "-sf", "--max-time", "12",
            "https://air-quality-api.open-meteo.com/v1/air-quality"
            + "?latitude=" + root.latitude + "&longitude=" + root.longitude
            + "&current=european_aqi"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text).current.european_aqi;
                    if (v !== undefined && v !== null) {
                        root.aqi = Math.round(v);
                        root.saveCache();
                    }
                } catch (e) {}
            }
        }
    }

    function apply(fc: var, save: bool): void {
        const cur = fc.current;
        const hr = fc.hourly;
        const dy = fc.daily;

        root.current = {
            temp: cur.temperature_2m,
            feels: cur.apparent_temperature,
            humidity: cur.relative_humidity_2m,
            windSpeed: cur.wind_speed_10m,
            windDir: cur.wind_direction_10m,
            code: cur.weather_code,
            isDay: cur.is_day === 1,
            pressure: cur.surface_pressure
        };

        // Hourly window: from the current hour, 24 entries.
        let idx = hr.time.indexOf(cur.time.slice(0, 13) + ":00");
        if (idx < 0)
            idx = 0;
        const hours = [];
        for (let i = idx; i < Math.min(idx + 24, hr.time.length); i++) {
            hours.push({
                label: i === idx ? "Now" : hr.time[i].slice(11, 16),
                temp: hr.temperature_2m[i],
                code: hr.weather_code[i],
                precip: hr.precipitation_probability[i] ?? 0,
                isDay: hr.is_day[i] === 1
            });
        }
        root.hourly = hours;
        root.uv = hr.uv_index ? (hr.uv_index[idx] ?? -1) : -1;
        root.visibilityKm = hr.visibility ? hr.visibility[idx] / 1000 : -1;

        const days = [];
        for (let i = 0; i < Math.min(7, dy.time.length); i++) {
            const d = new Date(dy.time[i] + "T12:00");
            days.push({
                day: i === 0 ? "Today" : Qt.formatDateTime(d, "ddd"),
                code: dy.weather_code[i],
                precip: dy.precipitation_probability_max[i] ?? 0,
                min: dy.temperature_2m_min[i],
                max: dy.temperature_2m_max[i]
            });
        }
        root.daily = days;

        root.sunrise = dy.sunrise[0].slice(11, 16);
        root.sunset = dy.sunset[0].slice(11, 16);
        // timezone=auto means these ISO strings are in the location's
        // local time, which (IP geolocation) matches the system TZ.
        root.sunriseMs = new Date(dy.sunrise[0]).getTime();
        root.sunsetMs = new Date(dy.sunset[0]).getTime();

        root.computeMoon();
        root.fetchedAt = Date.now();
        root.rawForecast = fc;
        if (save)
            root.saveCache();
    }

    // ---- cache (instant repopulation on shell restart) ----

    property var rawForecast: null

    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-island-weather.json"

    function saveCache(): void {
        if (!rawForecast)
            return;
        cacheFile.setText(JSON.stringify({
            city: root.city,
            latitude: root.latitude,
            longitude: root.longitude,
            aqi: root.aqi,
            fetchedAt: root.fetchedAt,
            fc: root.rawForecast
        }));
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        onLoaded: {
            // A live fetch may have already beaten the disk read -- never
            // clobber fresh data with the cache.
            if (root.ready)
                return;
            try {
                const j = JSON.parse(text());
                root.city = j.city || "";
                root.latitude = j.latitude || "";
                root.longitude = j.longitude || "";
                root.apply(j.fc, false);
                root.fetchedAt = j.fetchedAt || 0;
                if (j.aqi !== undefined)
                    root.aqi = j.aqi;
            } catch (e) {}
        }
        onLoadFailed: error => {}
    }

    Timer {
        id: retryTimer
        interval: 120000
        onTriggered: root.refresh()
    }

    Timer {
        // Poll interval from config.json, clamped so a hand edit can't
        // hammer the API (or stop refreshing for a day).
        interval: Math.max(5, Math.min(180, Config.settings.weatherRefreshMin)) * 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
