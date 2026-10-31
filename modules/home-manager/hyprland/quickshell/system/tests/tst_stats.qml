import QtQuick
import QtTest
import "../Stats.js" as Stats

TestCase {
    name: "SystemStats"
    function test_cpuCountsGuestOnlyOnce() {
        const start = Stats.cpuSnapshot("cpu 100 0 20 200 20 0 0 0 50 0\ncpu0 100 0 20 200 20 0 0 0 50 0");
        const end = Stats.cpuSnapshot("cpu 120 0 30 250 40 0 0 0 70 0\ncpu0 120 0 30 250 40 0 0 0 70 0");
        compare(start.cpu.total, 340);
        fuzzyCompare(Stats.cpuUsage(start.cpu, end.cpu), 30, 0.0001);
        compare(Stats.cpuUsage(undefined, end.cpu), -1);
        compare(Stats.cpuUsage(end.cpu, start.cpu), -1);
    }
    function test_memoryUsesAvailableIncludingReclaimableCache() {
        const value = Stats.memorySnapshot("MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 750 kB\nSwapTotal: 200 kB\nSwapFree: 150 kB");
        compare(value.percent, 25);
        compare(value.used, 250 * 1024);
        compare(value.swapUsed, 50 * 1024);
        compare(Stats.memorySnapshot("MemTotal: 0 kB"), null);
    }
    function test_networkRatesHandleResetsAndResume() {
        const snapshot = Stats.networkSnapshot(" lo: 10 0 0 0 0 0 0 0 20 0 0 0 0 0 0 0\n eth0: 100 0 0 0 0 0 0 0 50 0 0 0 0 0 0 0");
        compare(Object.keys(snapshot).length, 1);
        compare(Stats.networkRate(snapshot.eth0, {
            rx: 300,
            tx: 150
        }, 2).rx, 100);
        compare(Stats.networkRate(snapshot.eth0, {
            rx: 300,
            tx: 150
        }, 2).tx, 50);
        compare(Stats.networkRate(snapshot.eth0, {
            rx: 1,
            tx: 1
        }, 2).rx, -1);
        compare(Stats.networkRate(snapshot.eth0, {
            rx: 300,
            tx: 150
        }, 60).rx, -1);
    }
    function test_selectsLowestMetricDefaultRoute() {
        const source = "Iface Destination Gateway Flags RefCnt Use Metric Mask\neth0 00000000 01010101 0003 0 0 100 00000000\nwlan0 00000000 01010101 0003 0 0 600 00000000\nveth0 00000000 01010101 0000 0 0 0 00000000";
        compare(Stats.defaultInterface(source, false), "eth0");
        compare(Stats.defaultInterface("", false), "");
        const zero = "00000000000000000000000000000000";
        compare(Stats.defaultInterface(zero + " 00 " + zero + " 00 " + zero + " 00000064 00000001 00000000 00000001 wlan0", true), "wlan0");
    }
    function test_historyKeepsRealTimeWindowAndGaps() {
        let samples = [];
        for (let i = 0; i <= 200; i++)
            samples = Stats.appendSample(samples, i % 100, i * 2000);
        compare(samples.length, 61);
        compare(samples[0].time, 280000);
        samples = Stats.appendSample(samples, 30, 410000);
        compare(samples[samples.length - 2].value, -1);
        compare(samples[samples.length - 1].value, 30);
    }
    function test_units() {
        compare(Stats.bytes(1024), "1.0 KiB");
        compare(Stats.bytes(-1), "—");
        compare(Stats.uptime(90061), "1d 1h");
    }
}
