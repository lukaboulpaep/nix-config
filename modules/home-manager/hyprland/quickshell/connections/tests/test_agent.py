import importlib.util
import pathlib
import unittest
from gi.repository import GLib

spec = importlib.util.spec_from_file_location("agent", pathlib.Path(__file__).parents[1] / "bluetooth-agent.py")
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)

class Invocation:
    def __init__(self):
        self.value = None
        self.error = None
        self.replied = False
    def return_value(self, value):
        self.value = value.unpack() if value else None
        self.replied = True
    def return_dbus_error(self, name, message):
        self.error = name

class PairingTests(unittest.TestCase):
    def setUp(self):
        self.operation = agent.Operation.__new__(agent.Operation)
        self.operation.path = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
        self.operation.pending = None
        self.events = []
        self.operation.emit = lambda **data: self.events.append(data)
    def request(self, method, signature, args):
        invocation = Invocation()
        self.operation.agent_method(None, None, None, None, method, GLib.Variant(signature, args), invocation)
        return invocation
    def test_unexpected_device_is_rejected(self):
        inv = self.request("RequestConfirmation", "(ou)", ("/org/bluez/hci0/dev_00_00_00_00_00_00", 123))
        self.assertEqual(inv.error, "org.bluez.Error.Rejected")
        self.assertFalse(self.events)
    def test_confirmation_waits_for_user(self):
        inv = self.request("RequestConfirmation", "(ou)", (self.operation.path, 123))
        self.assertEqual(self.events[-1]["code"], "000123")
        self.assertFalse(inv.replied)
        self.operation.answer({"value": ""})
        self.assertTrue(inv.replied)
    def test_passkey_validation(self):
        inv = self.request("RequestPasskey", "(o)", (self.operation.path,))
        self.operation.answer({"value": "abc"})
        self.assertFalse(inv.replied)
        self.operation.answer({"value": "001234"})
        self.assertEqual(inv.value, (1234,))
    def test_display_does_not_wait_for_response(self):
        inv = self.request("DisplayPasskey", "(ouq)", (self.operation.path, 1234, 0))
        self.assertTrue(inv.replied)
        self.assertIsNone(self.operation.pending)
        self.assertEqual(self.events[-1]["code"], "001234")
    def test_cancel_clears_pending_confirmation(self):
        pending = self.request("RequestAuthorization", "(o)", (self.operation.path,))
        self.request("Cancel", "()", ())
        self.assertEqual(pending.error, "org.bluez.Error.Canceled")
        self.assertIsNone(self.operation.pending)
    def test_errors_do_not_expose_dbus_details(self):
        self.assertIn("nearby", agent.friendly_error("org.bluez.Error.AuthenticationTimeout"))
        self.assertIn("Paired", agent.friendly_error("org.bluez.Error.Failed", paired=True))

if __name__ == "__main__":
    unittest.main()
