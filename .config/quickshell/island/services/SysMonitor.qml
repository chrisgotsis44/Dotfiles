pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// System stats for the Dashboard's Performance tab. One aggregated
// shell poll (prefixed lines, parsed below) every 2s -- and ONLY while
// the dashboard is actually open; closed, this service costs nothing.
//
// CPU usage and network speeds are deltas between consecutive samples,
// so they read 0 until the second tick after opening (~2s).
Singleton {
    id: root

    readonly property bool active: GlobalState.dashboardOpen

    // ---- CPU ----
    property string cpuModel: ""
    property real cpuUsage: 0 // 0-1
    property int cpuTemp: 0   // °C
    property real cpuFreqMHz: 0 // current clock, averaged across cores

    // ---- GPU ----
    property bool gpuAvailable: false
    property string gpuModel: ""
    property real gpuUsage: 0 // 0-1
    property int gpuTemp: 0   // °C

    // ---- Memory ----
    property real memTotal: 0 // bytes
    property real memUsed: 0  // bytes

    // ---- Network ----
    property string netInterface: ""
    property real downSpeed: 0 // bytes/s
    property real upSpeed: 0   // bytes/s
    property real totalRx: 0   // bytes since boot
    property real totalTx: 0   // bytes since boot

    // ---- Storage ----
    // [{ source, size, used, target }] -- mounted real filesystems,
    // deduped by mount target. The dashboard's Storage tile picks one.
    property var disks: []

    function fmtBytes(b: real): string {
        if (b >= 1024 * 1024 * 1024)
            return (b / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
        if (b >= 1024 * 1024)
            return (b / (1024 * 1024)).toFixed(1) + " MiB";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + " KiB";
        return b.toFixed(0) + " B";
    }

    function fmtSpeed(b: real): string {
        return fmtBytes(b) + "/s";
    }

    // Previous sample for the delta-based readings.
    property var prev: null

    onActiveChanged: {
        if (active) {
            prev = null;
            poll.running = true;
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: poll.running = true
    }

    Process {
        id: modelProc
        running: true
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuModel = text.trim()
        }
    }

    Process {
        id: poll
        command: ["sh", "-c", `
            head -1 /proc/stat | sed 's/^/STAT /'
            awk '/^MemTotal/{t=$2}/^MemAvailable/{a=$2}END{print "MEM",t,a}' /proc/meminfo
            awk '/^cpu MHz/{s+=$4;n++}END{if(n>0) printf "CPUFREQ %.0f\n", s/n}' /proc/cpuinfo
            IF=$(ip -o route get 1 2>/dev/null | awk '{print $5;exit}')
            [ -n "$IF" ] && echo NET $IF $(cat /sys/class/net/$IF/statistics/rx_bytes) $(cat /sys/class/net/$IF/statistics/tx_bytes)
            for d in /sys/class/hwmon/hwmon*; do
                n=$(cat $d/name 2>/dev/null)
                if [ "$n" = k10temp ] || [ "$n" = coretemp ] || [ "$n" = zenpower ]; then
                    echo CPUTEMP $(cat $d/temp1_input); break
                fi
            done
            command -v nvidia-smi >/dev/null 2>&1 && echo "GPU $(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null)"
            df -B1 --output=source,size,used,target -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null | tail -n+2 | sed 's/^/DISK /'
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const now = {};
                const diskList = [];
                const seenTargets = new Set();

                for (const line of text.trim().split("\n")) {
                    const p = line.trim().split(/\s+/);

                    if (p[0] === "STAT") {
                        // STAT cpu user nice system idle iowait irq ...
                        const nums = p.slice(2).map(Number);
                        now.total = nums.reduce((a, b) => a + b, 0);
                        now.idle = nums[3] + (nums[4] || 0);
                    } else if (p[0] === "MEM") {
                        root.memTotal = Number(p[1]) * 1024;
                        root.memUsed = (Number(p[1]) - Number(p[2])) * 1024;
                    } else if (p[0] === "NET") {
                        root.netInterface = p[1];
                        now.rx = Number(p[2]);
                        now.tx = Number(p[3]);
                        root.totalRx = now.rx;
                        root.totalTx = now.tx;
                    } else if (p[0] === "CPUFREQ") {
                        root.cpuFreqMHz = Number(p[1]);
                    } else if (p[0] === "CPUTEMP") {
                        root.cpuTemp = Math.round(Number(p[1]) / 1000);
                    } else if (p[0] === "GPU") {
                        // GPU <name with spaces>, <temp>, <util>
                        const rest = line.trim().substring(4).split(",").map(s => s.trim());
                        if (rest.length >= 3) {
                            root.gpuAvailable = true;
                            root.gpuModel = rest[0];
                            root.gpuTemp = Number(rest[1]) || 0;
                            root.gpuUsage = (Number(rest[2]) || 0) / 100;
                        }
                    } else if (p[0] === "DISK") {
                        // DISK source size used target
                        const target = p.slice(4).join(" ");
                        if (!seenTargets.has(target)) {
                            seenTargets.add(target);
                            diskList.push({
                                source: p[1],
                                size: Number(p[2]),
                                used: Number(p[3]),
                                target: target
                            });
                        }
                    }
                }

                if (diskList.length > 0)
                    root.disks = diskList;

                now.time = Date.now();

                if (root.prev) {
                    const dt = (now.time - root.prev.time) / 1000;
                    if (now.total !== undefined && root.prev.total !== undefined) {
                        const dTotal = now.total - root.prev.total;
                        const dIdle = now.idle - root.prev.idle;
                        if (dTotal > 0)
                            root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                    }
                    if (now.rx !== undefined && root.prev.rx !== undefined && dt > 0) {
                        root.downSpeed = Math.max(0, (now.rx - root.prev.rx) / dt);
                        root.upSpeed = Math.max(0, (now.tx - root.prev.tx) / dt);
                    }
                }
                root.prev = now;
            }
        }
    }
}
