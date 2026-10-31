"""Run with dbus-run-session; emulates BlueZ without touching real devices."""
import json
import os
import pathlib
import subprocess
import sys
import threading
from gi.repository import Gio, GLib

DEVICE = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
XML = '''<node>
<interface name="org.bluez.AgentManager1"><method name="RegisterAgent"><arg type="o" direction="in"/><arg type="s" direction="in"/></method></interface>
<interface name="org.bluez.Device1"><method name="Pair"/><method name="Connect"/><method name="CancelPairing"/></interface>
<interface name="org.freedesktop.DBus.Properties"><method name="Set"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="in"/></method></interface>
</node>'''
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName", GLib.Variant("(su)", ("org.bluez", 0)), None, Gio.DBusCallFlags.NONE, 2000, None)
state = {"agent": None, "trusted": False, "connected": False, "done": None, "prompt": False, "error": ""}
loop = GLib.MainLoop()

def method(connection, sender, path, interface, name, params, invocation):
    if name == "RegisterAgent":
        state["agent"] = (sender, params.unpack()[0])
        invocation.return_value(None)
    elif name == "Pair":
        def confirmed(connection, result):
            try:
                connection.call_finish(result)
                invocation.return_value(None)
            except GLib.Error as error:
                state["error"] = str(error)
                invocation.return_dbus_error("org.bluez.Error.AuthenticationRejected", "Rejected")
        bus.call(state["agent"][0], state["agent"][1], "org.bluez.Agent1", "RequestConfirmation", GLib.Variant("(ou)", (DEVICE, 123)), None, Gio.DBusCallFlags.NONE, 3000, None, confirmed)
    elif name == "Set":
        interface, prop, value = params.unpack()
        assert interface == "org.bluez.Device1"
        if prop == "Trusted":
            state["trusted"] = value
        elif prop == "Alias":
            state["alias"] = value
        invocation.return_value(None)
    elif name == "Connect":
        state["connected"] = True
        invocation.return_value(None)
    else:
        invocation.return_value(None)

info = Gio.DBusNodeInfo.new_for_xml(XML)
for interface in info.interfaces:
    bus.register_object("/org/bluez" if interface.name.endswith("AgentManager1") else DEVICE, interface, method, None, None)
helper = pathlib.Path(__file__).parents[1] / "bluetooth-agent.py"
env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"])
process = subprocess.Popen([sys.executable, "-B", str(helper), "pair", DEVICE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)

def consume():
    for line in process.stdout:
        event = json.loads(line)
        if event["event"] == "prompt" and event["kind"] == "confirm":
            state["prompt"] = event["code"] == "000123"
            process.stdin.write('{"value":""}\n')
            process.stdin.flush()
        if event["event"] == "done":
            state["done"] = event
            GLib.idle_add(loop.quit)
            return
    GLib.idle_add(loop.quit)

threading.Thread(target=consume, daemon=True).start()
GLib.timeout_add_seconds(6, loop.quit)
try:
    loop.run()
    process.wait(timeout=2)
    assert state["prompt"], state
    assert state["trusted"] and state["connected"], state
    assert state["done"] and state["done"]["ok"], state
    assert process.returncode == 0, process.stderr.read()
    print("PASS: real helper registered agent, requested confirmation, paired, trusted and connected over an isolated D-Bus")
finally:
    if process.poll() is None:
        process.kill()
        process.wait()

for alias in ("Living room · speaker", ""):
    state["done"] = None
    process = subprocess.Popen([sys.executable, "-B", str(helper), "rename", DEVICE, alias], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    threading.Thread(target=consume, daemon=True).start()
    try:
        loop.run()
        process.wait(timeout=2)
        assert state["done"] and state["done"]["ok"], state
        assert state["alias"] == alias, state
        assert process.returncode == 0, process.stderr.read()
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
print("PASS: renamed device with Unicode and spaces, then restored its original name")
