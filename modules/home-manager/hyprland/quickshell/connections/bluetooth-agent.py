"""One Bluetooth operation, with pairing questions over private JSON stdio."""
import json
import re
import signal
import sys
import threading

from gi.repository import Gio, GLib

AGENT = """<node><interface name="org.bluez.Agent1">
<method name="Release"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="Cancel"/>
</interface></node>"""


def friendly_error(message, paired=False):
    if "AuthenticationRejected" in message:
        return "Pairing was declined. Try again when both devices are ready."
    if "AuthenticationFailed" in message or "AuthenticationCanceled" in message:
        return "Pairing didn’t finish. Check the code and try again."
    if "AuthenticationTimeout" in message or "Timeout" in message:
        return "The device didn’t respond. Make sure it’s nearby and in pairing mode."
    if "NotReady" in message:
        return "Turn Bluetooth on and try again."
    if "InProgress" in message:
        return "This device is already busy. Wait a moment and try again."
    if "NotAuthorized" in message or "AccessDenied" in message:
        return "The system didn’t allow this change."
    if paired:
        return "Paired, but couldn’t connect yet. Wake the device and choose Connect."
    return "Couldn’t complete the change. Check that the device is awake and nearby."


class Operation:
    def __init__(self, action, path, value=""):
        self.action, self.path = action, path
        self.value = value
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.loop = GLib.MainLoop()
        self.pending = None
        self.paired = False
        self.finished = False
        self.agent_path = "/desktop/connections/agent"

    def emit(self, **data):
        print(json.dumps(data), flush=True)

    def finish(self, ok, error=""):
        if self.finished:
            return
        self.finished = True
        if self.pending:
            self.pending[1].return_dbus_error("org.bluez.Error.Canceled", "Canceled")
            self.pending = None
        self.emit(event="done", ok=ok, error=error)
        self.loop.quit()

    def call(self, path, interface, method, parameters, callback):
        def done(bus, result):
            try:
                bus.call_finish(result)
            except GLib.Error as error:
                self.finish(False, "Couldn’t save the device name. Try again." if self.action == "rename" else friendly_error(str(error), self.paired))
                return
            if not self.finished:
                callback()
        self.bus.call("org.bluez", path, interface, method, parameters, None,
                      Gio.DBusCallFlags.NONE, 110000, None, done)

    def device_call(self, method, callback):
        self.call(self.path, "org.bluez.Device1", method, None, callback)

    def set_property(self, name, value, callback):
        interface = "org.bluez.Adapter1" if name == "Powered" else "org.bluez.Device1"
        self.call(self.path, "org.freedesktop.DBus.Properties", "Set",
                  GLib.Variant("(ssv)", (interface, name, GLib.Variant("s" if name == "Alias" else "b", value))), callback)

    def after_pair(self):
        self.paired = True
        self.emit(event="progress", message="Paired · connecting…")
        self.set_property("Trusted", True, lambda: self.device_call("Connect", lambda: self.finish(True)))

    def agent_method(self, connection, sender, path, interface, method, params, invocation):
        args = params.unpack()
        if method in ("Cancel", "Release"):
            if self.pending:
                self.pending[1].return_dbus_error("org.bluez.Error.Canceled", "Canceled")
                self.pending = None
            self.emit(event="prompt", kind="")
            invocation.return_value(None)
            return
        if not args or args[0] != self.path:
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Unexpected device")
            return
        kind = {"RequestPinCode": "pin", "RequestPasskey": "passkey",
                "RequestConfirmation": "confirm", "RequestAuthorization": "authorize",
                "AuthorizeService": "authorize", "DisplayPinCode": "display",
                "DisplayPasskey": "display"}.get(method)
        code = str(args[1]) if method == "DisplayPinCode" else f"{args[1]:06d}" if method in ("RequestConfirmation", "DisplayPasskey") else ""
        if kind == "display":
            invocation.return_value(None)
        else:
            if self.pending:
                self.pending[1].return_dbus_error("org.bluez.Error.Rejected", "Superseded")
            self.pending = (kind, invocation)
        self.emit(event="prompt", kind=kind, code=code)

    def answer(self, data):
        if data.get("cancel"):
            if self.pending:
                self.pending[1].return_dbus_error("org.bluez.Error.Rejected", "Declined")
                self.pending = None
            if self.action == "pair":
                self.bus.call("org.bluez", self.path, "org.bluez.Device1", "CancelPairing",
                              None, None, Gio.DBusCallFlags.NONE, 2000, None, None)
            self.finish(False, "Pairing canceled.")
        elif self.pending:
            kind, invocation = self.pending
            value = str(data.get("value", ""))
            if kind == "pin" and not 1 <= len(value) <= 16:
                return False
            if kind == "passkey" and not re.fullmatch(r"\d{1,6}", value):
                return False
            self.pending = None
            invocation.return_value(GLib.Variant("(s)", (value,)) if kind == "pin" else
                                    GLib.Variant("(u)", (int(value),)) if kind == "passkey" else None)
            self.emit(event="prompt", kind="")
        return False

    def read_input(self):
        for line in sys.stdin:
            try:
                data = json.loads(line)
                if isinstance(data, dict):
                    GLib.idle_add(self.answer, data)
            except ValueError:
                pass
        if self.action == "pair":
            GLib.idle_add(self.answer, {"cancel": True})

    def start(self):
        threading.Thread(target=self.read_input, daemon=True).start()
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.answer, {"cancel": True})
        GLib.timeout_add_seconds(115, lambda: self.finish(False, "The device didn’t respond. Try again."))
        success = lambda: self.finish(True)
        if self.action == "pair":
            info = Gio.DBusNodeInfo.new_for_xml(AGENT).interfaces[0]
            self.bus.register_object(self.agent_path, info, self.agent_method, None, None)
            self.call("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
                      GLib.Variant("(os)", (self.agent_path, "KeyboardDisplay")),
                      lambda: self.device_call("Pair", self.after_pair))
        elif self.action in ("connect", "disconnect"):
            self.device_call(self.action.capitalize(), success)
        elif self.action == "forget":
            self.call(self.path.rsplit("/", 1)[0], "org.bluez.Adapter1", "RemoveDevice", GLib.Variant("(o)", (self.path,)), success)
        elif self.action in ("on", "off"):
            self.set_property("Powered", self.action == "on", success)
        elif self.action in ("trust", "untrust"):
            self.set_property("Trusted", self.action == "trust", success)
        elif self.action == "rename":
            self.set_property("Alias", self.value, success)
        self.loop.run()


def main():
    if len(sys.argv) not in (3, 4):
        return 2
    action, path = sys.argv[1:3]
    value = sys.argv[3] if len(sys.argv) == 4 else ""
    if action == "rename":
        if len(sys.argv) != 4 or len(value) > 128 or any(ord(c) < 32 or ord(c) == 127 for c in value):
            return 2
    elif len(sys.argv) != 3:
        return 2
    is_adapter = action in ("on", "off")
    pattern = r"/org/bluez/hci\d+" + ("" if is_adapter else r"/dev_[0-9A-Fa-f_]+")
    if action not in ("pair", "connect", "disconnect", "forget", "on", "off", "trust", "untrust", "rename") or not re.fullmatch(pattern, path):
        return 2
    try:
        Operation(action, path, value).start()
    except GLib.Error as error:
        print(json.dumps({"event": "done", "ok": False, "error": friendly_error(str(error))}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
