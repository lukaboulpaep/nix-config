import QtQuick
import QtTest
import "../BatteryModel.js" as Model

TestCase {
    name: "BatteryModel"
    function test_estimates() {
        compare(Model.duration(0), "");
        compare(Model.duration(-10), "");
        compare(Model.duration(NaN), "");
        compare(Model.duration(12), "1 min");
        compare(Model.duration(3900), "1h 5m");
    }
    function test_health_uses_percent_not_fraction() {
        compare(Model.health([
            {
                healthSupported: true,
                healthPercentage: 97.5
            }
        ]), 97.5);
        compare(Model.health([
            {
                healthSupported: true,
                healthPercentage: 105
            }
        ]), 100);
        compare(Model.health([
            {
                healthSupported: false,
                healthPercentage: 0
            }
        ]), -1);
        compare(Model.health([]), -1);
    }
    function test_health_multiple_packs_weighted_by_capacity() {
        compare(Model.health([
            {
                healthSupported: true,
                healthPercentage: 80,
                energyCapacity: 40
            },
            {
                healthSupported: true,
                healthPercentage: 100,
                energyCapacity: 100
            }
        ]), 140 / 150 * 100);
        compare(Model.health([
            {
                healthSupported: true,
                healthPercentage: 80,
                energyCapacity: 40
            },
            {
                healthSupported: false,
                healthPercentage: 0,
                energyCapacity: 100
            }
        ]), -1);
    }
    function test_profiles() {
        const parsed = Model.parseProfiles("  performance:\n    CpuDriver: amd_pstate\n    Degraded:   yes (high-operating-temperature)\n* balanced:\n    PlatformDriver: platform_profile\n    Degraded: no\n  power-saver:\n");
        compare(parsed.active, "balanced");
        compare(parsed.profiles.length, 3);
        compare(parsed.profiles[0].degraded, "yes (high-operating-temperature)");
        compare(parsed.profiles[1].degraded, "");
    }
    function test_unavailable_and_unsupported_profiles() {
        compare(Model.parseProfiles("service missing").profiles.length, 0);
        const parsed = Model.parseProfiles("* power-saver:\n  balanced:\n");
        compare(parsed.active, "power-saver");
        compare(parsed.profiles.length, 2);
        compare(Model.parseProfiles("balanced:\n").active, "");
    }
}
