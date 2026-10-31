"""Per-display hardware brightness. All writes are clamped to 10–100%."""
import concurrent.futures
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

MINIMUM = 10


def run(*args, timeout=12, allow_error=False):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, "LC_ALL": "C"})
    if result.returncode and not allow_error:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Brightness command failed")
    return result.stdout


def clamp(value):
    value = float(value)
    if not math.isfinite(value):
        raise ValueError("Invalid brightness")
    return max(MINIMUM, min(100, round(value)))


def parse_ddc(text):
    displays = []
    for block in re.split(r"(?m)^(?=Display \d+|Invalid display)", text):
        if not re.match(r"Display \d+", block):
            continue
        bus = re.search(r"I2C bus:\s*/dev/i2c-(\d+)", block)
        connector = re.search(r"DRM connector:\s*card\d+-(\S+)", block)
        monitor = re.search(r"Monitor:\s*([^\n]+)", block)
        if bus:
            displays.append({"bus": bus[1], "connector": connector[1] if connector else "",
                             "monitor": monitor[1].strip() if monitor else ""})
    return displays


def parse_vcp(text):
    # ddcutil's brief continuous-value format: VCP 10 C <current> <maximum>
    match = re.search(r"\bVCP\s+10\s+C\s+(\d+)\s+(\d+)", text, re.I)
    if not match or int(match[2]) <= 0:
        raise RuntimeError("This display does not report adjustable brightness")
    return int(match[1]), int(match[2])


def connectors():
    return {re.sub(r"^card\d+-", "", p.name): p for p in Path("/sys/class/drm").glob("card*-*")}


def identity(monitor, path):
    try:
        edid = (path / "edid").read_bytes()
    except (OSError, TypeError):
        edid = b""
    data = edid or (monitor.get("description", "") + monitor.get("serial", "")).encode()
    return monitor["name"] + ":" + hashlib.sha256(data).hexdigest()[:16]


def map_ddc(monitor, detected, monitors):
    exact = [d for d in detected if d["connector"] == monitor["name"]]
    if len(exact) == 1:
        return exact[0]
    # Older DDC versions may omit the connector. Never guess by display order.
    model = monitor.get("model", "").strip()
    serial = monitor.get("serial", "").strip()
    if not model:
        return None
    same = [m for m in monitors if m.get("model", "").strip() == model]
    candidates = [d for d in detected if not d["connector"] and model in d["monitor"]
                  and (len(same) == 1 or (serial and serial in d["monitor"]))]
    return candidates[0] if len(candidates) == 1 else None


def topology(monitors, paths):
    # Bus and connector objects are recreated on dock reconnect. Include their
    # identity as well as EDID so a recycled bus number never reuses an old map.
    objects = list(paths.values()) + list(Path("/sys/bus/i2c/devices").glob("i2c-*"))
    stamps = []
    for path in sorted(objects):
        try:
            stat = path.stat()
            stamps.append((str(path.resolve()), stat.st_ino, stat.st_ctime_ns))
        except OSError:
            stamps.append((str(path), None))
    displays = sorted(identity(m, paths.get(m["name"])) for m in monitors)
    return hashlib.sha256(json.dumps([displays, stamps]).encode()).hexdigest()


def cache_path():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    return Path(runtime) / "quickshell-brightness-v2.json" if runtime else None


def read_cache(signature):
    path = cache_path()
    try:
        cached = json.loads(path.read_text()) if path else {}
        if cached.get("topology") != signature:
            return None
        rows = cached["displays"]
        # Retry unavailable controls periodically, but keep working connections.
        if any(not row["supported"] for row in rows) and time.time() - cached["time"] > 30:
            return None
        return rows
    except (OSError, ValueError, KeyError, TypeError):
        return None


def save_cache(signature, rows):
    path = cache_path()
    if path:
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
                json.dump({"topology": signature, "time": time.time(), "displays": rows}, file)
            os.replace(file.name, path)
        except OSError:
            pass  # Controls remain usable if caching is unavailable.


def read_value(item, known=False):
    if item["kind"] == "backlight":
        panel = Path("/sys/class/backlight") / item["device"]
        return int((panel / "brightness").read_text()), int((panel / "max_brightness").read_text())
    options = ["--skip-ddc-checks"] if known else []
    return parse_vcp(run("ddcutil", "--bus", item["device"], *options, "getvcp", "10", "--brief"))


def discover(read_values=True):
    monitors = json.loads(run("hyprctl", "monitors", "-j", timeout=3))
    paths = connectors()
    signature = topology(monitors, paths)
    cached = read_cache(signature)
    if cached is not None and not read_values:
        return cached
    backlights = list(Path("/sys/class/backlight").glob("*"))
    internal = [m for m in monitors if re.match(r"^(eDP|LVDS|DSI)-", m["name"])]
    detected = []
    if cached is None and len(internal) < len(monitors):
        try:
            detected = parse_ddc(run("ddcutil", "detect", "--brief", allow_error=True))
        except (RuntimeError, OSError, subprocess.TimeoutExpired):
            pass

    def display(monitor):
        connector = monitor["name"]
        built_in = monitor in internal
        item = {"id": identity(monitor, paths.get(connector)), "connector": connector,
                "name": "Laptop display" if built_in else (monitor.get("model") or "External display"),
                "value": None, "supported": False, "message": "", "kind": "", "connection": signature}
        previous = next((d for d in cached or [] if d["id"] == item["id"]), None)
        matches = [b for b in backlights if connector in b.resolve().parts or
                   any(p.endswith("-" + connector) for p in b.resolve().parts)]
        if built_in and not matches and len(internal) == 1 and len(backlights) == 1:
            matches = backlights
        if previous:
            item.update(kind=previous["kind"])
            if "device" in previous:
                item["device"] = previous["device"]
        elif built_in and len(matches) == 1:
            item.update(kind="backlight", device=matches[0].name)
        else:
            ddc = map_ddc(monitor, detected, monitors)
            if ddc:
                item.update(kind="ddc", device=ddc["bus"])
        if not item["kind"]:
            item["message"] = ("Brightness control isn’t available for this display."
                if built_in else "Brightness control isn’t available through this connection. Check the monitor’s DDC/CI setting.")
            return item
        try:
            current, maximum = read_value(item, bool(previous and previous["supported"]))
            if maximum <= 0:
                raise ValueError("Invalid maximum")
            item.update(value=round(100 * current / maximum), maximum=maximum, supported=True)
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            item["message"] = "This display isn’t responding to brightness controls."
        return item

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(display, monitors))
    # Do not preserve a map collected across a hotplug event.
    if topology(monitors, connectors()) == signature:
        # Reading an unavailable display must not extend its retry deadline.
        if cached is None or all(row["supported"] for row in rows):
            save_cache(signature, rows)
        return rows
    raise RuntimeError("Displays changed. Try again in a moment.")


def set_brightness(display_id, requested, ddc=None, verify=True):
    percent = clamp(requested)
    # Validate topology cheaply; only rescan DDC after connection changes.
    item = next((d for d in discover(False) if d["id"] == display_id), None)
    if not item or not item["supported"]:
        raise RuntimeError("This display is no longer available. Reopen brightness controls and try again.")
    if item["kind"] == "backlight":
        panel = Path("/sys/class/backlight") / item["device"]
        maximum = int((panel / "max_brightness").read_text())
        # Round upward so integer hardware steps never dip below the floor.
        target = math.ceil(maximum * percent / 100)
        run("brightnessctl", "--device", item["device"], "set", str(target))
        actual = int((panel / "brightness").read_text())
    else:
        maximum = item["maximum"]
        target = math.ceil(maximum * percent / 100)
        if ddc is not None:
            actual, maximum = ddc.write(item, target, verify)
        else:
            run("ddcutil", "--bus", item["device"], "--skip-ddc-checks", "setvcp", "10", str(target),
                "--verify" if verify else "--noverify")
            actual = target
    if maximum <= 0:
        raise RuntimeError("The monitor reported an invalid brightness range")
    if abs(actual - target) > max(1, maximum * .02):
        raise RuntimeError("The display didn’t apply the brightness change. Check its picture mode or monitor settings.")
    return {"id": display_id, "value": round(100 * actual / maximum), "verified": verify}


def serve():
    # Native-library diagnostics must not mix with the JSON response stream.
    output = os.fdopen(os.dup(sys.stdout.fileno()), "w", buffering=1)
    os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
    ddc = None
    try:
        from ddc_session import DdcSession
        ddc = DdcSession()
        ddc.prepare(discover(False))
    except (OSError, ValueError, RuntimeError, AttributeError, subprocess.TimeoutExpired) as error:
        print("Brightness helper:", error, file=sys.stderr)
    print(json.dumps({"ready": True}), file=output)
    for line in sys.stdin:
        try:
            request = json.loads(line)
            result = set_brightness(request["id"], request["value"], ddc, request.get("verify", True))
        except (OSError, ValueError, RuntimeError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
            result = {"error": str(error)}
        print(json.dumps(result), file=output)
    return 0


def step_brightness(delta):
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        raise RuntimeError("No desktop session available")
    # Auto-repeat launches separate helpers. Serialize the read/modify/write so
    # simultaneous key presses cannot overwrite each other's brightness steps.
    with (Path(runtime) / "quickshell-brightness-step.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return step_backlights(delta)


def step_backlights(delta):
    panels = [item for item in discover(False) if item["supported"] and item["kind"] == "backlight"]
    if not panels:
        raise RuntimeError("No adjustable laptop display found")
    results = []
    for panel in panels:
        current, maximum = read_value(panel)
        if maximum <= 0:
            raise RuntimeError("Invalid brightness range")
        results.append(set_brightness(panel["id"], 100 * current / maximum + float(delta)))
    return {"displays": results}


def main():
    try:
        if sys.argv[1:] == ["serve"]:
            return serve()
        if sys.argv[1:] == ["list"]:
            result = {"displays": discover()}
        elif len(sys.argv) == 4 and sys.argv[1] == "set":
            result = set_brightness(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 3 and sys.argv[1] == "step":
            result = step_brightness(sys.argv[2])
        else:
            raise ValueError("Use list, set DISPLAY_ID PERCENT, or step DELTA")
        print(json.dumps(result))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
