import unittest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch

import brightness


class BrightnessTests(unittest.TestCase):
    def test_floor_and_ceiling(self):
        for value, expected in [(-100, 10), (0, 10), (9, 10), (10, 10), (25, 25), (60, 60), (200, 100)]:
            self.assertEqual(brightness.clamp(value), expected)
        for value in ["nan", "inf", "not a number"]:
            with self.assertRaises(ValueError):
                brightness.clamp(value)

    def test_detect_skips_invalid_displays_and_preserves_connector(self):
        detected = brightness.parse_ddc("""Invalid display
   I2C bus: /dev/i2c-1
Display 1
   I2C bus: /dev/i2c-9
   DRM connector: card2-DP-3
   Monitor: AOC:Desk display:123
Display 2
   I2C bus: /dev/i2c-12
   DRM connector: card2-HDMI-A-1
   Monitor: DEL:Other display:456
""")
        self.assertEqual([d["bus"] for d in detected], ["9", "12"])
        self.assertEqual(detected[0]["connector"], "DP-3")

    def test_ambiguous_monitors_are_never_matched_by_order(self):
        monitors = [{"name": "DP-1", "model": "Same", "serial": ""},
                    {"name": "DP-2", "model": "Same", "serial": ""}]
        detected = [{"bus": "1", "connector": "", "monitor": "Vendor:Same:"},
                    {"bus": "2", "connector": "", "monitor": "Vendor:Same:"}]
        self.assertIsNone(brightness.map_ddc(monitors[0], detected, monitors))
        detected[1]["connector"] = "DP-1"
        self.assertEqual(brightness.map_ddc(monitors[0], detected, monitors)["bus"], "2")

    @patch.object(brightness, "discover")
    @patch.object(brightness, "run")
    def test_ddc_write_scales_and_clamps_to_hardware_maximum(self, run, discover):
        discover.return_value = [{"id": "test", "supported": True, "kind": "ddc", "device": "9", "maximum": 240}]
        run.return_value = ""
        self.assertEqual(brightness.set_brightness("test", 0)["value"], 10)
        run.assert_called_once_with("ddcutil", "--bus", "9", "--skip-ddc-checks", "setvcp", "10", "24", "--verify")

    @patch.object(brightness, "discover")
    @patch.object(brightness, "run")
    def test_disconnected_or_replaced_monitor_is_not_written(self, run, discover):
        discover.return_value = [{"id": "replacement", "supported": True, "kind": "ddc", "device": "9"}]
        with self.assertRaises(RuntimeError):
            brightness.set_brightness("old-monitor", 50)
        run.assert_not_called()

    @patch.object(brightness, "discover")
    @patch.object(brightness, "run")
    def test_monitor_ignoring_write_reports_failure(self, run, discover):
        discover.return_value = [{"id": "test", "supported": True, "kind": "ddc", "device": "9", "maximum": 100}]
        run.side_effect = RuntimeError("verification failed")
        with self.assertRaisesRegex(RuntimeError, "verification failed"):
            brightness.set_brightness("test", 40)

    def test_cache_invalidated_when_connection_changes(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(brightness, "cache_path", return_value=Path(directory) / "cache.json"):
            rows = [{"id": "test", "supported": True, "maximum": 240}]
            brightness.save_cache("original-connection", rows)
            self.assertEqual(brightness.read_cache("original-connection"), rows)
            self.assertIsNone(brightness.read_cache("reconnected-bus"))

    def test_recreated_connector_invalidates_same_monitor(self):
        with tempfile.TemporaryDirectory() as directory:
            connector = Path(directory) / "connector"
            connector.mkdir()
            (connector / "edid").write_bytes(b"same monitor")
            monitors = [{"name": "DP-1"}]
            before = brightness.topology(monitors, {"DP-1": connector})
            connector.rename(Path(directory) / "old-connector")
            connector.mkdir()
            (connector / "edid").write_bytes(b"same monitor")
            self.assertNotEqual(brightness.topology(monitors, {"DP-1": connector}), before)

    @patch.object(brightness, "discover")
    def test_live_updates_use_native_session_and_release_is_verified(self, discover):
        item = {"id": "test", "supported": True, "kind": "ddc", "device": "9", "maximum": 100}
        discover.return_value = [item]
        session = Mock()
        session.write.return_value = (40, 100)
        self.assertFalse(brightness.set_brightness("test", 40, session, False)["verified"])
        session.write.assert_called_with(item, 40, False)
        self.assertTrue(brightness.set_brightness("test", 40, session, True)["verified"])
        session.write.assert_called_with(item, 40, True)
        session.write.return_value = (100, 100)
        with self.assertRaisesRegex(RuntimeError, "didn’t apply"):
            brightness.set_brightness("test", 40, session, True)

    @patch.object(brightness, "read_cache")
    @patch.object(brightness, "topology", return_value="same")
    @patch.object(brightness, "connectors", return_value={})
    @patch.object(brightness, "run", return_value='[{"name":"DP-1"}]')
    def test_slider_write_reuses_mapping_without_ddc_discovery(self, run, connectors, topology, cache):
        cache.return_value = [{"id": "test", "supported": True, "maximum": 240}]
        self.assertEqual(brightness.discover(False), cache.return_value)
        run.assert_called_once_with("hyprctl", "monitors", "-j", timeout=3)

    def test_unsupported_or_invalid_brightness_is_rejected(self):
        for response in ["VCP 10 ERR", "VCP 10 C 20 0", ""]:
            with self.assertRaises(RuntimeError):
                brightness.parse_vcp(response)


if __name__ == "__main__":
    unittest.main()
