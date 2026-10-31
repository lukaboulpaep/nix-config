import QtQuick
import Quickshell
import Quickshell.Io
import "Stats.js" as Stats

Scope {
    id: metrics
    property bool active: false
    property int cpu: -1
    property int memory: -1
    property var cpuHistory: []
    property var memoryHistory: []
    property var cores: []
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property real uptimeSeconds: -1
    property real download: -1
    property real upload: -1
    property real temperature: -1
    property int fanSpeed: -1
    property int gpu: -1
    property string cpuModel: ""
    property real frequency: 0
    property string operatingSystem: "Linux"
    property string kernel: ""
    property var disks: []
    property bool storageFailed: false
    property var previousCpu: ({})
    property double previousCpuTime: 0
    property var previousNetwork: ({})
    property double previousNetworkTime: 0
    property string route4: ""
    property string route6: ""

    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            const now = Date.now(), current = Stats.cpuSnapshot(text());
            const validInterval = metrics.previousCpuTime > 0 && now - metrics.previousCpuTime <= 6000;
            const usage = validInterval ? Stats.cpuUsage(metrics.previousCpu.cpu, current.cpu) : -1;
            metrics.cpu = usage >= 0 ? Math.round(usage) : -1;
            metrics.cpuHistory = Stats.appendSample(metrics.cpuHistory, usage, now);
            metrics.cores = Object.keys(current).filter(key => key !== "cpu").map(key => ({
                        name: key,
                        value: validInterval ? Stats.cpuUsage(metrics.previousCpu[key], current[key]) : -1
                    }));
            metrics.previousCpu = current;
            metrics.previousCpuTime = now;
        }
        onLoadFailed: {
            metrics.cpu = -1;
            metrics.previousCpu = ({});
        }
    }
    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        onLoaded: {
            const value = Stats.memorySnapshot(text());
            if (!value) {
                metrics.memory = -1;
                return;
            }
            metrics.memory = Math.round(value.percent);
            metrics.memoryTotal = value.total;
            metrics.memoryUsed = value.used;
            metrics.swapTotal = value.swapTotal;
            metrics.swapUsed = value.swapUsed;
            metrics.memoryHistory = Stats.appendSample(metrics.memoryHistory, value.percent, Date.now());
        }
        onLoadFailed: metrics.memory = -1
    }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: metrics.uptimeSeconds = Number(text().trim().split(/\s+/)[0])
    }
    FileView {
        id: route4File
        path: "/proc/net/route"
        onLoaded: metrics.route4 = Stats.defaultInterface(text(), false)
        onLoadFailed: metrics.route4 = ""
    }
    FileView {
        id: route6File
        path: "/proc/net/ipv6_route"
        onLoaded: metrics.route6 = Stats.defaultInterface(text(), true)
        onLoadFailed: metrics.route6 = ""
    }
    FileView {
        id: networkFile
        path: "/proc/net/dev"
        onLoaded: {
            const now = Date.now(), current = Stats.networkSnapshot(text());
            const name = metrics.route4 || metrics.route6;
            const rate = Stats.networkRate(metrics.previousNetwork[name], current[name], (now - metrics.previousNetworkTime) / 1000);
            metrics.download = rate.rx;
            metrics.upload = rate.tx;
            metrics.previousNetwork = current;
            metrics.previousNetworkTime = now;
        }
        onLoadFailed: {
            metrics.download = -1;
            metrics.upload = -1;
        }
    }
    FileView {
        id: cpuInfoFile
        path: "/proc/cpuinfo"
        onLoaded: {
            const source = text();
            metrics.cpuModel = (source.match(/^(?:model name|Hardware|Processor)\s*:\s*(.+)$/m) || ["", "Processor"])[1];
            const frequencies = [], pattern = /^cpu MHz\s*:\s*([\d.]+)/gm;
            let match;
            while ((match = pattern.exec(source)) !== null)
                frequencies.push(Number(match[1]));
            metrics.frequency = frequencies.length ? frequencies.reduce((a, b) => a + b, 0) / frequencies.length / 1000 : 0;
        }
    }
    FileView {
        path: "/etc/os-release"
        onLoaded: metrics.operatingSystem = (text().match(/^PRETTY_NAME="?([^"\n]+)"?$/m) || ["", "Linux"])[1]
    }
    FileView {
        path: "/proc/sys/kernel/osrelease"
        onLoaded: metrics.kernel = text().trim()
    }

    function readHardware() {
        if (!hardware.running)
            hardware.running = true;
        cpuInfoFile.reload();
    }
    onActiveChanged: if (active) {
        readHardware();
        if (!storage.running)
            storage.running = true;
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memoryFile.reload();
            uptimeFile.reload();
            route4File.reload();
            route6File.reload();
            networkFile.reload();
        }
    }
    Timer {
        interval: 5000
        running: metrics.active
        repeat: true
        onTriggered: metrics.readHardware()
    }
    Timer {
        interval: 15000
        running: metrics.active
        repeat: true
        onTriggered: if (!storage.running)
            storage.running = true
    }
    Process {
        id: hardware
        command: ["bash", Quickshell.shellPath("system/hardware-stats.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const temperatures = [], fans = [], graphics = [];
                for (const line of text.trim().split("\n")) {
                    const fields = line.split("\t");
                    if (fields[0] === "temperature" && /^(coretemp|k10temp|zenpower|cpu_thermal|cpu-thermal|soc_thermal)$/.test(fields[1])) {
                        const value = Number(fields[3]) / 1000;
                        if (Number.isFinite(value) && value > 0 && value < 150)
                            temperatures.push({
                                label: fields[2],
                                value: value
                            });
                    }
                    if (fields[0] === "fan" && Number(fields[2]) >= 0)
                        fans.push(Number(fields[2]));
                    if (fields[0] === "gpu" && Number(fields[2]) >= 0 && Number(fields[2]) <= 100)
                        graphics.push(Number(fields[2]));
                }
                const packageTemps = temperatures.filter(t => /Package|Tdie/.test(t.label));
                const chosen = packageTemps.length ? packageTemps : temperatures;
                metrics.temperature = chosen.length ? Math.max(...chosen.map(t => t.value)) : -1;
                metrics.fanSpeed = fans.length ? Math.max(...fans) : -1;
                metrics.gpu = graphics.length ? Math.max(...graphics) : -1;
            }
        }
        onExited: code => {
            if (code !== 0) {
                metrics.temperature = -1;
                metrics.fanSpeed = -1;
                metrics.gpu = -1;
            }
        }
    }
    Process {
        id: storage
        command: ["timeout", "3", "df", "-B1", "--output=source,size,used,avail,target", "/", "/home"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            id: storageOutput
        }
        onExited: code => {
            metrics.storageFailed = code !== 0;
            if (code !== 0) {
                metrics.disks = [];
                return;
            }
            const seen = {}, result = [];
            for (const line of storageOutput.text.trim().split("\n").slice(1)) {
                const fields = line.trim().split(/\s+/);
                if (fields.length < 5 || seen[fields[0]] || !(Number(fields[1]) > 0))
                    continue;
                seen[fields[0]] = true;
                result.push({
                    name: fields[4] === "/" ? "System drive" : "Home drive",
                    total: Number(fields[1]),
                    used: Number(fields[2]),
                    available: Number(fields[3])
                });
            }
            metrics.disks = result;
        }
    }
}
