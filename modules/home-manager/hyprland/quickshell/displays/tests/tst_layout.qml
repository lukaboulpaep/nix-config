import QtQuick
import QtTest
import "../DisplayModel.js" as Model

TestCase {
    name: "DisplayArrangement"
    readonly property var displays: [
        {
            id: "a",
            width: 1440,
            height: 900
        },
        {
            id: "b",
            width: 1920,
            height: 1080
        }
    ]
    readonly property var layout: ({
            mode: "extend",
            primary: "a",
            positions: {
                a: {
                    x: 0,
                    y: 0
                },
                b: {
                    x: 1440,
                    y: 0
                }
            }
        })
    function test_presets_keep_primary_and_do_not_mutate_original() {
        const stacked = Model.arrange(displays, layout, "vertical", false);
        compare(stacked.positions.b.y, 900);
        compare(stacked.positions.b.x, 0);
        compare(stacked.primary, "a");
        compare(layout.positions.b.x, 1440);
        const reversed = Model.arrange(displays, layout, "horizontal", true);
        compare(reversed.positions.a.x, 1920);
        compare(reversed.positions.b.x, 0);
    }
    function test_drag_snaps_left_and_above_without_overlap() {
        const left = Model.snap(displays, layout, "b", -1850, 0);
        compare(left.positions.b.x, -1920);
        compare(left.positions.b.y, 0);
        const above = Model.snap(displays, layout, "b", 0, -1000);
        compare(above.positions.b.x, 0);
        compare(above.positions.b.y, -1080);
    }
    function test_negative_coordinates_fit_preview() {
        const left = Model.snap(displays, layout, "b", -1920, 0);
        const bounds = Model.dimensions(displays, left);
        compare(bounds.x, -1920);
        compare(bounds.width, 3360);
        compare(bounds.height, 1080);
    }
}
