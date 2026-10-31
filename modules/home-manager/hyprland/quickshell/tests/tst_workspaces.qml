import QtQuick
import QtTest
import "../WorkspaceModel.js" as Model

TestCase {
    name: "WorkspaceBars"
    function test_move_updates_both_bars_even_with_old_saved_assignment() {
        const before = [
            {
                id: 1,
                name: "1",
                monitor: "DP-1",
                windowCount: 2
            },
            {
                id: 4,
                name: "4",
                monitor: "eDP-1",
                windowCount: 1
            }
        ];
        const monitors = [
            {
                name: "DP-1",
                activeWorkspace: 1
            },
            {
                name: "eDP-1",
                activeWorkspace: 4
            }
        ];
        const entries = Model.entries(before, monitors, "DP-1", {
            "4": "eDP-1"
        });
        verify(entries.find(e => e.id === 1).current);
        verify(entries.find(e => e.id === 4).current);
        before[1].monitor = "DP-1";
        monitors[0].activeWorkspace = 4;
        monitors[1].activeWorkspace = 11;
        before.push({
            id: 11,
            name: "11",
            monitor: "eDP-1",
            windowCount: 0
        });
        const moved = Model.entries(before, monitors, "DP-1", {
            "4": "eDP-1"
        });
        verify(!moved.filter(e => e.monitor === "eDP-1").some(e => e.id === 4));
        verify(moved.filter(e => e.monitor === "DP-1").find(e => e.id === 4).current);
        verify(!moved.find(e => e.id === 1).current);
        verify(moved.find(e => e.id === 11).current);
        compare(moved.find(e => e.id === 4).windowCount, 1);
    }
    function test_empty_workspaces_follow_main_with_separate_placements() {
        const entries = Model.entries([], [], "DP-2", {
            "7": "HDMI-1"
        });
        compare(entries.length, 10);
        compare(entries.filter(e => e.monitor === "DP-2").length, 9);
        compare(entries.find(e => e.id === 7).monitor, "HDMI-1");
        const changed = Model.entries([], [], "eDP-1", {
            "7": "HDMI-1"
        });
        compare(changed.find(e => e.id === 2).monitor, "eDP-1");
        compare(changed.find(e => e.id === 7).monitor, "HDMI-1");
    }
    function test_extra_and_named_workspaces_are_visible_but_scratchpads_are_not() {
        const entries = Model.entries([
            {
                id: 12,
                name: "12",
                monitor: "HDMI-1",
                windowCount: 0
            },
            {
                id: -1337,
                name: "chat",
                monitor: "DP-1",
                windowCount: 1
            },
            {
                id: -99,
                name: "special:scratch",
                monitor: "DP-1",
                windowCount: 1
            }
        ], [
            {
                name: "HDMI-1",
                activeWorkspace: 12
            }
        ], "DP-1", {});
        verify(entries.find(e => e.id === 12).current);
        compare(entries.find(e => e.id === -1337).label, "chat");
        verify(!entries.some(e => e.id === -99));
    }
    function test_named_workspace_dispatch_preserves_quotes_and_unicode() {
        const request = Model.focusRequest({
            key: 'name:chat "é"\\\n'
        });
        verify(request.includes('name:chat \\034é\\034\\092\\010'));
        verify(request.includes('on_current_monitor = false'));
        verify(!request.includes('\n'));
    }
}
