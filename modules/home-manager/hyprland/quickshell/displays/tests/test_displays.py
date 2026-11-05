import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("displays", Path(__file__).resolve().parents[1] / "displays.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def display(name, internal=False, x=0, width=1920, height=1080):
    return dict(id=name, name=name, label=name, internal=internal, x=x, y=0, width=width, height=height,
                pixelWidth=width, pixelHeight=height, scale=1, rate=60, transform=0, disabled=False,
                mirror="none", focused=internal, workspace=1 if internal else 2)


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.dict(mod.os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": ""}))
        self.displays = [display("eDP-2", True, width=1440, height=900), display("DP-7", x=1440)]

    def test_connection_policy_is_generic_and_falls_back(self):
        self.assertEqual(mod.primary_for(self.displays, True), "DP-7")
        self.assertEqual(mod.primary_for(self.displays, False), "eDP-2")
        self.assertEqual(mod.primary_for(self.displays[:1], True), "eDP-2")
        self.assertEqual(mod.primary_for(self.displays[1:], False), "DP-7")

    def test_rejects_stale_topology_overlap_and_nonfinite_positions(self):
        layout = mod.arranged(self.displays, "eDP-2")
        mod.validate(layout, self.displays)
        with self.assertRaises(ValueError):
            mod.validate(layout, self.displays[:1])
        layout["positions"]["DP-7"]["x"] = 0
        with self.assertRaisesRegex(ValueError, "overlap"):
            mod.validate(layout, self.displays)
        layout["positions"]["DP-7"]["x"] = float("nan")
        with self.assertRaises(ValueError):
            mod.validate(layout, self.displays)

    def test_mirror_sets_source_first_and_extend_clears_mirroring(self):
        layout = mod.arranged(self.displays, "eDP-2")
        layout["mode"] = "mirror"
        code = mod.layout_code(layout, list(reversed(self.displays)))
        self.assertLess(code.index('["output"]="eDP-2"'), code.index('["output"]="DP-7"'))
        self.assertIn('["mirror"]="eDP-2"', code)
        layout["mode"] = "extend"
        self.assertEqual(mod.layout_code(layout, self.displays).count('["mirror"]=""'), 2)

    def test_lua_escapes_monitor_names_without_shell_interpolation(self):
        value = 'name"\\\n; os.execute("no")'
        encoded = mod.lua(value)
        self.assertNotIn('\n', encoded)
        self.assertNotIn('os.execute("no")', encoded)
        self.assertIn('\\034', encoded)
        self.assertEqual(mod.lua("é"), '"\\195\\169"')

    def test_port_changed_same_edid_keeps_identity(self):
        raw = [{"name": "DP-2", "make": "Example", "model": "Screen", "serial": "123", "width": 3840, "height": 2160, "scale": 2}]
        with patch.object(mod, "hypr", return_value=json.dumps(raw)):
            first = mod.monitors()[0]
        raw[0]["name"] = "DP-9"
        with patch.object(mod, "hypr", return_value=json.dumps(raw)):
            second = mod.monitors()[0]
        self.assertEqual(first["id"], second["id"])
        self.assertEqual(second["width"], 1920)

    def test_numeric_mirror_source_resolves_to_connector_for_rollback(self):
        raw = [{"id": 0, "name": "eDP-2", "mirrorOf": "none"},
               {"id": 4, "name": "DP-7", "mirrorOf": "0"}]
        with patch.object(mod, "hypr", return_value=json.dumps(raw)):
            displays = mod.monitors()
        self.assertEqual(displays[1]["mirror"], "eDP-2")
        with patch.object(mod, "monitors", return_value=displays), patch.object(mod, "hypr") as hypr, patch.object(mod.time, "sleep"):
            mod.restore({"displays": displays})
        self.assertIn('["mirror"]="eDP-2"', hypr.call_args_list[0].args[1])

    def test_second_pass_repairs_layer_coordinates_after_monitor_move(self):
        state = {"monitor_y": 900, "layer_y": 900}
        def compositor(*args):
            state["layer_y"] = state["monitor_y"]
            state["monitor_y"] = 0
        with patch.object(mod, "hypr", side_effect=compositor):
            mod.apply_rules('hl.monitor({output="eDP-2", position="0x0"})')
        self.assertEqual(state["layer_y"], state["monitor_y"])

    def test_same_model_replacement_remaps_primary_and_positions(self):
        original = [display("internal:eDP-1", True), display("Example|Desk Monitor|123", x=1920)]
        connected = [display("internal:eDP-2", True), display("Example|Desk Monitor|456", x=1920)]
        layout = mod.arranged(original, original[1]["id"])
        matched = mod.match_layout(layout, connected)
        self.assertEqual(matched["primary"], connected[1]["id"])
        self.assertEqual(matched["positions"][connected[1]["id"]], layout["positions"][original[1]["id"]])
        self.assertIn(original[1]["id"], layout["positions"])

    def test_matching_rejects_unrelated_models_ambiguous_twins_and_overlap(self):
        original = [display("Example|Desk|1"), display("Example|Desk|2", x=1920)]
        layout = mod.arranged(original, original[0]["id"])
        twins = [display("Example|Desk|3"), display("Example|Desk|4", x=1920)]
        self.assertIsNone(mod.match_layout(layout, twins))
        other = [original[0], display("Different|Desk|2", x=1920)]
        self.assertIsNone(mod.match_layout(layout, other))
        larger = copy.deepcopy(original)
        larger[0]["width"] = 3840
        self.assertIsNone(mod.match_layout(layout, larger))

    def test_auto_match_prefers_exact_and_does_not_guess_conflicting_layouts(self):
        a = [display("Example|Desk|1")]
        b = [display("Example|Desk|2")]
        c = [display("Example|Desk|3")]
        first = mod.arranged(a, a[0]["id"])
        second = mod.arranged(b, b[0]["id"])
        second["mode"] = "mirror"
        config = {"layouts": {json.dumps(mod.signature(a)): first, json.dumps(mod.signature(b)): second}}
        self.assertEqual(mod.remembered_layout(config, a), first)
        self.assertIsNone(mod.remembered_layout(config, c))
        del config["layouts"][json.dumps(mod.signature(b))]
        self.assertEqual(mod.remembered_layout(config, c)["primary"], c[0]["id"])

    def test_pointer_stays_on_its_display_when_primary_and_origin_change(self):
        with patch.object(mod, "hypr", return_value='{"x": 200, "y": 300}'):
            pointer = mod.pointer_context(self.displays)
        after = copy.deepcopy(self.displays)
        after[0]["y"] = 1060
        after[0]["focused"] = False
        after[1]["focused"] = True
        with patch.object(mod, "hypr") as hypr:
            self.assertEqual(mod.restore_pointer(pointer, after), after[0]["name"])
        hypr.assert_called_with("dispatch", "movecursor", "200", "1360")

    def test_pointer_on_mirror_destination_moves_to_source(self):
        after = copy.deepcopy(self.displays)
        after[1]["mirror"] = after[0]["name"]
        with patch.object(mod, "hypr") as hypr:
            self.assertEqual(mod.restore_pointer({"name": after[1]["name"], "x": 1800, "y": 1000}, after), after[0]["name"])
        hypr.assert_called_with("dispatch", "movecursor", "1439", "899")

    def test_assigning_main_does_not_focus_the_other_monitor(self):
        with patch.object(mod, "hypr") as hypr:
            mod.place_workspaces({"1": "DP-7", "2": "DP-7"}, [{"id": 1, "monitor": "eDP-2"}])
        self.assertNotIn("hl.dsp.focus", hypr.call_args.args[1])

    def test_main_change_moves_group_and_preserves_separate_workspaces(self):
        displays = self.displays + [display("HDMI-1", x=3360)]
        workspaces = [{"id": 1, "monitor": "eDP-2"}, {"id": 4, "monitor": "eDP-2"},
                      {"id": 7, "monitor": "HDMI-1"}, {"id": 8, "monitor": "DP-7"}]
        layout = mod.arranged(displays, "DP-7")
        layout["workspaces"] = mod.workspace_overrides(displays, "eDP-2", workspaces)
        targets = mod.workspace_targets(layout, displays, workspaces)
        self.assertEqual(targets["1"], "DP-7")
        self.assertEqual(targets["4"], "DP-7")
        self.assertEqual(targets["7"], "HDMI-1")
        self.assertEqual(targets["8"], "DP-7")
        self.assertEqual(targets["10"], "DP-7")  # unopened workspace follows main

    def test_mirror_temporarily_combines_workspaces_without_losing_placements(self):
        layout = mod.arranged(self.displays, "eDP-2")
        layout["workspaces"] = {"7": "DP-7", "name:chat": "DP-7"}
        layout["mode"] = "mirror"
        self.assertEqual(set(mod.workspace_targets(layout, self.displays, []).values()), {"eDP-2"})
        layout["mode"] = "extend"
        self.assertEqual(mod.workspace_targets(layout, self.displays, [])["name:chat"], "DP-7")

    def test_model_matching_also_remaps_workspace_placements(self):
        old = [display("internal:eDP-1", True), display("Example|Desk|1", x=1920)]
        new = [display("internal:eDP-2", True), display("Example|Desk|2", x=1920)]
        layout = mod.arranged(old, old[0]["id"])
        layout["workspaces"] = {"5": old[1]["id"]}
        self.assertEqual(mod.match_layout(layout, new)["workspaces"], {"5": new[1]["id"]})

    def test_invalid_workspace_placement_is_rejected(self):
        layout = mod.arranged(self.displays, "eDP-2")
        for overrides in ({"0": "DP-7"}, {"special:scratch": "DP-7"}, {"2": "missing"}, []):
            layout["workspaces"] = overrides
            with self.assertRaisesRegex(ValueError, "workspace"):
                mod.validate(layout, self.displays)

    def test_empty_secondary_gets_unused_numbered_workspace_before_unmirroring(self):
        layout = mod.arranged(self.displays, "DP-7")
        workspaces = [{"id": 1, "monitor": "eDP-2", "windows": 2},
                      {"id": 2, "monitor": "eDP-2", "windows": 1}]
        targets, defaults, reserved = mod.workspace_plan(layout, self.displays, workspaces)
        self.assertEqual(reserved, {"10": "eDP-2"})
        self.assertEqual(defaults["eDP-2"], "10")
        self.assertEqual(targets["1"], "DP-7")
        self.assertEqual(targets["2"], "DP-7")
        self.assertNotIn("11", targets)
        self.assertIn('["workspace"]="10",["monitor"]="eDP-2",["default"]=true',
                      "\n".join(mod.workspace_rules(targets, defaults)))

    def test_empty_secondaries_use_distinct_slots_and_preserve_explicit_assignments(self):
        displays = self.displays + [display("HDMI-2", x=3360)]
        layout = mod.arranged(displays, "eDP-2")
        layout["workspaces"] = {"7": "DP-7"}
        targets, defaults, reserved = mod.workspace_plan(layout, displays, [])
        self.assertEqual(defaults["DP-7"], "7")
        self.assertEqual(defaults["HDMI-2"], "10")
        self.assertEqual(reserved, {"10": "HDMI-2"})
        self.assertEqual(targets["7"], "DP-7")

    def test_full_workspaces_are_never_taken_for_an_empty_display(self):
        workspaces = [{"id": i, "monitor": "eDP-2", "windows": 1} for i in range(1, 11)]
        with self.assertRaisesRegex(ValueError, "All ten"):
            mod.workspace_plan(mod.arranged(self.displays, "eDP-2"), self.displays, workspaces)

    def test_retire_only_empty_nonpersistent_extra_workspaces(self):
        workspaces = [{"id": 11, "monitor": "DP-7", "windows": 0},
                      {"id": 12, "monitor": "DP-7", "windows": 1},
                      {"id": 13, "monitor": "DP-7", "windows": 0, "ispersistent": True}]
        self.assertEqual(mod.empty_extra_workspaces(workspaces), ["11"])
        targets, _, _ = mod.workspace_plan(mod.arranged(self.displays, "eDP-2"), self.displays, workspaces)
        self.assertNotIn("11", targets)
        self.assertIn("12", targets)
        self.assertIn("13", targets)


class ReloadTests(unittest.TestCase):
    def test_monitor_snapshot_keeps_closed_lid_and_layout_and_is_replaced(self):
        with tempfile.TemporaryDirectory() as runtime:
            directory = Path(runtime) / "hypr" / "test-session"
            directory.mkdir(parents=True)
            displays = [display("eDP-1", True), display("DP-5", x=1440)]
            displays[0]["disabled"] = True
            with patch.dict(mod.os.environ, {"XDG_RUNTIME_DIR": runtime,
                                             "HYPRLAND_INSTANCE_SIGNATURE": "test-session"}), \
                 patch.object(mod, "monitors", return_value=displays):
                mod.save_monitor_rules()
                rules = (directory / "desktop-monitors.lua").read_text().splitlines()
                self.assertIn('["output"]="eDP-1"', rules[0])
                self.assertIn('["disabled"]=true', rules[0])
                self.assertIn('["position"]="1440x0"', rules[1])
                displays[0]["disabled"] = False
                displays[1]["mirror"] = "eDP-1"
                mod.save_monitor_rules()
                rules = (directory / "desktop-monitors.lua").read_text()
                self.assertNotIn('["disabled"]=true', rules)
                self.assertIn('["mirror"]="eDP-1"', rules)
                self.assertFalse((directory / "desktop-monitors.tmp").exists())


class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(patch.dict(mod.os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": ""}))
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.displays = [display("eDP-1", True), display("DP-9", x=1920)]
        self.patches = [patch.object(mod, "runtime_dir", return_value=self.directory),
                        patch.object(mod, "monitors", side_effect=lambda: copy.deepcopy(self.displays)),
                        patch.object(mod, "hypr", side_effect=lambda *a: "[]" if a[0] == "-j" else "ok"),
                        patch.object(mod.subprocess, "Popen"), patch.object(mod.time, "sleep")]
        for p in self.patches:
            p.start()
        self.controller = mod.Controller(self.directory / "settings.json")

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def close_lid(self):
        workspaces = [{"id": 1, "monitor": "eDP-1", "windows": 2},
                      {"id": 2, "monitor": "DP-9", "windows": 1},
                      {"id": -12, "name": "chat", "monitor": "eDP-1", "windows": 1}]
        def compositor(*args):
            if args == ("-j", "workspaces"):
                return json.dumps(workspaces)
            return "[]" if args[0] == "-j" else "ok"
        with patch.object(mod, "lid_closed", return_value=True), \
             patch.object(mod, "hypr", side_effect=compositor), \
             patch.object(mod, "apply_rules") as rules, \
             patch.object(mod, "place_workspaces") as place, \
             patch.object(self.controller, "emit"):
            self.assertTrue(self.controller.sync_lid())
        self.displays[0]["disabled"] = True
        return rules.call_args.args[0], place.call_args.args[0]

    def test_lid_parks_numbered_and_named_workspaces_without_saving_layout(self):
        config = copy.deepcopy(self.controller.config)
        rules, targets = self.close_lid()
        self.assertIn('["output"]="eDP-1"', rules)
        self.assertIn('["disabled"]=true', rules)
        self.assertTrue(all(name == "DP-9" for name in targets.values()))
        self.assertIn("name:chat", targets)
        self.assertEqual(self.controller.config, config)
        snapshot = json.loads((self.directory / "lid.json").read_text())
        self.assertEqual(snapshot["workspaces"][0]["monitor"], "eDP-1")
        self.assertEqual(snapshot["displays"][1]["workspace"], 2)
        with patch.object(self.controller, "refresh") as refresh:
            self.controller.remember_workspaces()
            refresh.assert_not_called()

    def test_lid_open_restores_snapshot_and_clears_temporary_state(self):
        self.close_lid()
        snapshot = copy.deepcopy(self.controller.lid_snapshot)
        with patch.object(mod, "lid_closed", return_value=False), \
             patch.object(mod, "restore") as restore, patch.object(self.controller, "emit"):
            self.assertTrue(self.controller.sync_lid())
            restore.assert_called_once_with(snapshot)
        self.assertIsNone(self.controller.lid_snapshot)
        self.assertFalse((self.directory / "lid.json").exists())

    def test_closed_lid_is_idempotent_and_survives_helper_restart(self):
        self.close_lid()
        restarted = mod.Controller(self.controller.path)
        self.assertEqual(restarted.lid_snapshot, self.controller.lid_snapshot)
        with patch.object(mod, "lid_closed", return_value=True), patch.object(mod, "apply_rules") as apply:
            self.assertFalse(restarted.sync_lid())
            apply.assert_not_called()
        with patch.object(mod, "lid_closed", return_value=False), patch.object(mod, "restore") as restore, \
             patch.object(restarted, "emit"):
            restarted.sync_lid()
            restore.assert_called_once()

    def test_lid_without_external_monitor_keeps_laptop_enabled(self):
        self.displays = self.displays[:1]
        with patch.object(mod, "lid_closed", return_value=True), patch.object(mod, "apply_rules") as apply:
            self.assertFalse(self.controller.sync_lid())
            apply.assert_not_called()
        self.assertIsNone(self.controller.lid_snapshot)

    def test_unplugging_external_while_closed_recovers_laptop(self):
        self.close_lid()
        self.displays = self.displays[:1]
        with patch.object(mod, "lid_closed", return_value=True), patch.object(mod, "restore") as restore, \
             patch.object(self.controller, "emit"):
            self.assertTrue(self.controller.sync_lid())
            restore.assert_called_once()

    def test_resume_without_outputs_keeps_snapshot_until_panel_returns(self):
        self.close_lid()
        panel = copy.deepcopy(self.displays[0])
        self.displays = []
        with patch.object(mod, "lid_closed", return_value=False), \
             patch.object(self.controller, "emit"):
            with self.assertRaisesRegex(RuntimeError, "Waiting for a display"):
                self.controller.sync_lid()
            self.assertIsNotNone(self.controller.lid_snapshot)
            self.assertTrue((self.directory / "lid.json").exists())

            # The connector has returned, but enabling it has not completed.
            self.displays = [panel]
            with self.assertRaisesRegex(RuntimeError, "finish restoring"):
                self.controller.sync_lid()
            self.assertIsNotNone(self.controller.lid_snapshot)
            self.assertTrue((self.directory / "lid.json").exists())

            def enable_panel(_):
                self.displays[0]["disabled"] = False
            with patch.object(mod, "apply_rules", side_effect=enable_panel):
                self.assertTrue(self.controller.sync_lid())
            self.assertIsNone(self.controller.lid_snapshot)
            self.assertFalse((self.directory / "lid.json").exists())

    def test_reload_while_closed_preserves_original_snapshot(self):
        self.close_lid()
        snapshot = copy.deepcopy(self.controller.lid_snapshot)
        self.displays[0]["disabled"] = False
        with patch.object(mod, "lid_closed", return_value=True), patch.object(self.controller, "emit"):
            self.assertTrue(self.controller.sync_lid())
        self.assertEqual(self.controller.lid_snapshot["workspaces"], snapshot["workspaces"])
        self.assertEqual(self.controller.lid_snapshot["displays"], snapshot["displays"])

    def test_trial_is_not_saved_until_confirmed(self):
        layout = mod.arranged(self.displays, "DP-9")
        self.controller.apply(layout)
        self.assertIsNotNone(self.controller.pending)
        self.assertFalse(self.controller.path.exists())
        self.assertTrue((self.directory / "pending.json").exists())
        self.controller.keep()
        self.assertIsNone(self.controller.pending)
        self.assertEqual(json.loads(self.controller.path.read_text())["primary"], "DP-9")
        self.assertFalse((self.directory / "pending.json").exists())

    def test_revert_restores_snapshot_and_clears_pending(self):
        self.controller.apply(mod.arranged(self.displays, "DP-9"))
        with patch.object(mod, "restore") as restore:
            self.controller.revert()
            self.assertEqual(restore.call_args.args[0]["displays"], self.displays)
        self.assertIsNone(self.controller.pending)
        self.assertFalse(self.controller.path.exists())

    def test_expired_watchdog_cannot_be_confirmed(self):
        self.controller.apply(mod.arranged(self.displays, "DP-9"))
        (self.directory / "pending.json").unlink()
        with self.assertRaisesRegex(ValueError, "expired"):
            self.controller.keep()
        self.assertFalse(self.controller.path.exists())

    def test_failed_apply_rolls_back_without_saving(self):
        with patch.object(mod, "place_workspaces", side_effect=RuntimeError("failed")), patch.object(mod, "restore") as restore:
            with self.assertRaisesRegex(RuntimeError, "failed"):
                self.controller.apply(mod.arranged(self.displays, "DP-9"))
            restore.assert_called_once()
        self.assertIsNone(self.controller.pending)
        self.assertFalse(self.controller.path.exists())

    def test_watchdog_only_restores_matching_transaction(self):
        self.controller.apply(mod.arranged(self.displays, "DP-9"))
        token = json.loads((self.directory / "pending.json").read_text())["token"]
        with patch.object(mod, "restore") as restore:
            mod.watchdog("unrelated")
            restore.assert_not_called()
            mod.watchdog(token)
            restore.assert_called_once()

    def test_hotplug_policy_and_unplug_fallback(self):
        self.controller.handle({"action": "preference", "externalMain": True})
        self.controller.displays = self.displays[:1]
        with patch.object(self.controller, "apply") as apply, patch.object(self.controller, "emit"):
            self.controller.reconnect()
            self.assertEqual(apply.call_args.args[0]["primary"], "DP-9")
        self.displays = self.displays[:1]
        with patch.object(self.controller, "apply") as apply, patch.object(self.controller, "emit"):
            self.controller.reconnect()
            self.assertEqual(apply.call_args.args[0]["primary"], "eDP-1")

    def test_startup_restores_workspace_owners_when_saved_layout_already_matches(self):
        layout = mod.arranged(self.displays, "DP-9")
        layout["workspaces"] = {"10": "eDP-1", "7": "eDP-1"}
        self.controller.config.update(configured=True, externalMain=True, primary="DP-9",
                                      layouts={self.controller.key(): layout})
        self.controller.persist()
        controller = mod.Controller(self.controller.path)
        self.assertEqual(controller.layout, layout)
        # Geometry and cached placements match, but compositor assignments and
        # workspace rules still need restoring after login.
        workspaces = [{"id": 1, "monitor": "DP-9", "windows": 1},
                      {"id": 2, "monitor": "eDP-1", "windows": 1}]
        def compositor(*args):
            if args == ("-j", "workspaces"):
                return json.dumps(workspaces)
            return "[]" if args[0] == "-j" else "ok"
        with patch.object(mod, "hypr", side_effect=compositor) as hypr:
            controller.restore_startup_layout()
        code = "\n".join(call.args[1] for call in hypr.call_args_list if call.args[0] == "eval")
        self.assertIn('hl.workspace_rule({["workspace"]="2",["monitor"]="DP-9"', code)
        self.assertIn('hl.dsp.workspace.move({["workspace"]="2",["monitor"]="DP-9"})', code)
        self.assertEqual(controller.layout["workspaces"], layout["workspaces"])
        self.assertIsNone(controller.pending)

    def test_startup_legacy_layout_does_not_save_initial_workspace_as_override(self):
        layout = mod.arranged(self.displays, "DP-9")
        self.controller.config.update(configured=True, primary="DP-9",
                                      layouts={self.controller.key(): layout})
        self.controller.layout = mod.current_layout(self.displays, "DP-9")
        workspaces = [{"id": 1, "monitor": "DP-9", "windows": 1},
                      {"id": 2, "monitor": "eDP-1", "windows": 0}]
        def compositor(*args):
            if args == ("-j", "workspaces"):
                return json.dumps(workspaces)
            return "[]" if args[0] == "-j" else "ok"
        with patch.object(mod, "hypr", side_effect=compositor), patch.object(mod, "place_workspaces") as place:
            self.controller.restore_startup_layout()
        self.assertEqual(place.call_args.args[0]["2"], "DP-9")
        self.assertEqual(self.controller.layout["workspaces"], {"10": "eDP-1"})

    def test_startup_without_saved_layout_uses_connection_preference(self):
        self.controller.config.update(configured=True, externalMain=True)
        with patch.object(self.controller, "apply") as apply:
            self.controller.restore_startup_layout()
        self.assertEqual(apply.call_args.args[0]["primary"], "DP-9")
        self.assertEqual(apply.call_args.kwargs, {"trial": False, "restore_workspaces": True})

    def test_startup_leaves_unconfigured_or_closed_lid_layout_alone(self):
        with patch.object(self.controller, "apply") as apply:
            self.controller.restore_startup_layout()
            apply.assert_not_called()
            self.controller.config.update(configured=True, externalMain=True)
            self.controller.lid_snapshot = {"displays": self.displays}
            self.controller.restore_startup_layout()
            apply.assert_not_called()

    def test_named_layout_requires_matching_displays(self):
        self.controller.handle({"action": "save", "name": "Desk"})
        profile = self.controller.config["profiles"][0]
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.controller.handle({"action": "save", "name": "desk"})
        self.displays = self.displays[:1]
        with self.assertRaisesRegex(ValueError, "connected displays changed"):
            self.controller.handle({"action": "load", "id": profile["id"]})

    def test_hotplug_reuses_a_confirmed_layout_for_same_model(self):
        original = [display("internal:eDP-1", True), display("Example|Desk|1", x=1920)]
        layout = mod.arranged(original, original[0]["id"])
        layout["positions"][original[1]["id"]] = {"x": 0, "y": 1080}
        self.controller.config.update(configured=True, layouts={json.dumps(mod.signature(original)): layout})
        self.displays = [display("internal:eDP-1", True), display("Example|Desk|2", x=1920)]
        with patch.object(self.controller, "apply") as apply, patch.object(self.controller, "emit"):
            self.controller.reconnect()
        self.assertEqual(apply.call_args.args[0]["positions"]["Example|Desk|2"], {"x": 0, "y": 1080})
        self.assertFalse(apply.call_args.kwargs["trial"])

    def test_preset_update_captures_current_placements_and_load_restores_them(self):
        self.controller.handle({"action": "save", "name": "Desk"})
        profile = self.controller.config["profiles"][0]
        self.assertEqual(profile["layout"]["workspaces"], {})
        def compositor(*args):
            if args == ("-j", "workspaces"):
                return json.dumps([{"id": 1, "monitor": "eDP-1"}, {"id": 5, "monitor": "DP-9"}])
            return "[]" if args[0] == "-j" else "ok"
        with patch.object(mod, "hypr", side_effect=compositor), patch.object(self.controller, "emit"):
            self.controller.refresh()
            self.assertEqual(profile["layout"]["workspaces"], {})  # no automatic preset edits
            self.controller.handle({"action": "update", "id": profile["id"]})
            self.assertEqual(profile["layout"]["workspaces"], {"5": "DP-9"})
            with patch.object(self.controller, "apply") as apply:
                self.controller.handle({"action": "load", "id": profile["id"]})
                self.assertTrue(apply.call_args.kwargs["restore_workspaces"])
                self.assertEqual(apply.call_args.args[0]["workspaces"], {"5": "DP-9"})

    def test_trial_rollback_restores_workspace_rules_and_moves(self):
        snapshot = {"displays": self.displays, "managedWorkspaces": ["1", "2"],
                    "workspaceRules": [{"workspace": "1", "monitor": "eDP-1", "default": True}],
                    "workspaces": [{"id": 1, "monitor": "eDP-1"}, {"id": 5, "monitor": "DP-9"}]}
        with patch.object(mod, "hypr") as hypr:
            mod.restore(snapshot)
        calls = "\n".join(call.args[1] for call in hypr.call_args_list)
        self.assertIn('["workspace"]="2",["monitor"]="",["default"]=false', calls)
        self.assertIn('["workspace"]="5",["monitor"]="DP-9"', calls)


if __name__ == "__main__":
    unittest.main()
