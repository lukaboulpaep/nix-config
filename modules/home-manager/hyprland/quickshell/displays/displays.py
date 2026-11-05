#!/usr/bin/env python3
"""Display layouts for the desktop panel; JSON-lines IPC and timed rollback."""
import copy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import time
import uuid


def hypr(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=8)
    if result.returncode or (args[0] == "eval" and result.stdout.strip() != "ok"):
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "The display change failed.")
    return result.stdout


def lua(value):
    # Lua quoted strings, independent of shell syntax and JSON's Unicode escapes.
    if isinstance(value, str):
        return '"' + ''.join('\\%03d' % b if b < 32 or b >= 127 or b in (34, 92) else chr(b)
                             for b in value.encode("utf-8")) + '"'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)) and math.isfinite(value):
        return str(value)
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    raise ValueError("Unsupported display setting")


def monitors():
    raw = json.loads(hypr("-j", "monitors", "all"))
    names_by_id = {str(m.get("id")): m["name"] for m in raw}
    result = []
    identities = ["|".join(str(m.get(k, "")).strip() for k in ("make", "model", "serial")) for m in raw]
    for m, identity in zip(raw, identities):
        name = m["name"]
        internal = name.startswith(("eDP-", "LVDS-", "DSI-"))
        key = "internal:" + name if internal else identity
        if not identity.strip("|") or identities.count(identity) > 1:
            key += "|" + name
        scale = m.get("scale", 1) or 1
        width, height = m.get("width", 1920), m.get("height", 1080)
        if m.get("transform", 0) % 2:
            width, height = height, width
        result.append({"id": key, "name": name, "label": "Laptop display" if internal else
                       " ".join(str(m.get(k, "")).strip() for k in ("make", "model")).strip() or name,
                       "internal": internal, "width": round(width / scale), "height": round(height / scale),
                       "pixelWidth": m.get("width", 1920), "pixelHeight": m.get("height", 1080),
                       "scale": scale, "rate": m.get("refreshRate", 60), "transform": m.get("transform", 0),
                       "x": m.get("x", 0), "y": m.get("y", 0), "disabled": m.get("disabled", False),
                       "mirror": names_by_id.get(str(m.get("mirrorOf")), m.get("mirrorOf", "none")),
                       "focused": m.get("focused", False),
                       "workspace": m.get("activeWorkspace", {}).get("id", 0)})
    return result


def signature(displays):
    return sorted(d["id"] for d in displays)


def lid_closed():
    for path in Path("/proc/acpi/button/lid").glob("*/state"):
        try:
            state = path.read_text().strip().split()[-1]
            if state in ("open", "closed"):
                return state == "closed"
        except (OSError, IndexError):
            pass
    return None


def match_layout(layout, displays):
    """Reuse connector-independent identities, then unique monitor-model matches.

    Old saved layouts already encode make/model/serial in their keys. Never
    guess between identical monitors or match unrelated models by resolution.
    """
    if not isinstance(layout, dict) or len(layout.get("positions", {})) != len(displays):
        return None
    old_ids = list(layout["positions"])
    remaining = set(signature(displays))
    mapping = {key: key for key in old_ids if key in remaining}
    remaining.difference_update(mapping.values())

    def model(key):
        if key.startswith("internal:"):
            return ("internal",)
        parts = key.split("|")
        if len(parts) >= 3 and parts[0].strip() and parts[1].strip():
            return tuple(p.strip().casefold() for p in parts[:2])
        return None

    unmatched = [key for key in old_ids if key not in mapping]
    for key in unmatched:
        identity = model(key)
        candidates = [other for other in remaining if identity and model(other) == identity]
        if len(candidates) != 1 or sum(model(other) == identity for other in unmatched) != 1:
            return None
        mapping[key] = candidates[0]
        remaining.remove(candidates[0])
    if layout.get("primary") not in mapping:
        return None
    mapped = copy.deepcopy(layout)
    mapped["primary"] = mapping[layout["primary"]]
    mapped["positions"] = {mapping[key]: copy.deepcopy(pos) for key, pos in layout["positions"].items()}
    if "workspaces" in layout:
        if not isinstance(layout["workspaces"], dict) or any(target not in mapping for target in layout["workspaces"].values()):
            return None
        mapped["workspaces"] = {workspace: mapping[target] for workspace, target in layout["workspaces"].items()}
    try:
        return validate(mapped, displays)
    except ValueError:
        return None


def remembered_layout(config, displays):
    exact = config.get("layouts", {}).get(json.dumps(signature(displays)))
    if exact is not None:
        return match_layout(exact, displays)
    # Prefer the last confirmed setup over named presets. Multiple different
    # matches require a manual choice rather than an arbitrary automatic switch.
    for layouts in (config.get("layouts", {}).values(),
                    [p["layout"] for p in config.get("profiles", [])]):
        candidates = [matched for layout in layouts if (matched := match_layout(layout, displays))]
        if candidates:
            return candidates[0] if all(c == candidates[0] for c in candidates) else None
    return None


def pointer_context(displays):
    point = json.loads(hypr("-j", "cursorpos"))
    if not isinstance(point, dict):
        return {}
    enabled = [d for d in displays if not d["disabled"] and d["mirror"] in ("none", "", None)]
    target = next((d for d in enabled if d["x"] <= point["x"] < d["x"] + d["width"]
                   and d["y"] <= point["y"] < d["y"] + d["height"]), None)
    if target is None:
        target = next((d for d in enabled if d["focused"]), None)
    if not target:
        return {}
    return {"name": target["name"], "x": point["x"] - target["x"], "y": point["y"] - target["y"]}


def restore_pointer(context, displays):
    target = next((d for d in displays if d["name"] == context.get("name") and not d["disabled"]), None)
    if target and target["mirror"] not in ("none", "", None):
        target = next((d for d in displays if d["name"] == target["mirror"]), None)
    if not target:
        return pointer_context(displays).get("name", "")
    x = target["x"] + round(max(0, min(context["x"], target["width"] - 1)))
    y = target["y"] + round(max(0, min(context["y"], target["height"] - 1)))
    # Moving the active workspace can change focus independently of the pointer.
    # Restore both, otherwise the compositor can warp back to the other output.
    hypr("eval", "hl.dispatch(hl.dsp.focus(" + lua({"monitor": target["name"]}) + "))")
    hypr("dispatch", "movecursor", str(x), str(y))
    return target["name"]


def primary_for(displays, external_main=False):
    candidates = [d for d in displays if d["internal"] != external_main and not d["disabled"]]
    return (candidates or [d for d in displays if not d["disabled"]] or displays)[0]["id"] if displays else ""


def current_layout(displays, primary=""):
    enabled = [d for d in displays if not d["disabled"]]
    source = next((d for d in enabled if d["mirror"] in ("none", "", None)), None)
    mirrored = any(d["mirror"] not in ("none", "", None) for d in enabled)
    if primary not in [d["id"] for d in enabled]:
        primary = next((d["id"] for d in enabled if d["focused"]), primary_for(displays))
    return {"mode": "mirror" if mirrored else "extend", "primary": source["id"] if mirrored and source else primary,
            "positions": {d["id"]: {"x": d["x"], "y": d["y"]} for d in displays}}


def arranged(displays, primary):
    x = 0
    positions = {}
    for d in sorted(displays, key=lambda d: (not d["internal"], d["name"])):
        positions[d["id"]] = {"x": x, "y": 0}
        x += d["width"]
    return {"mode": "extend", "primary": primary, "positions": positions}


def validate(layout, displays):
    if not isinstance(layout, dict) or layout.get("mode") not in ("extend", "mirror"):
        raise ValueError("Choose Extend or Mirror.")
    ids = signature(displays)
    if not ids or sorted(layout.get("positions", {})) != ids or layout.get("primary") not in ids:
        raise ValueError("The connected displays changed. Review the layout and try again.")
    for p in layout["positions"].values():
        if not isinstance(p, dict) or any(type(p.get(k)) is not int or abs(p[k]) > 100000 for k in ("x", "y")):
            raise ValueError("Invalid display position.")
    overrides = layout.get("workspaces", {})
    if not isinstance(overrides, dict) or any(not valid_workspace(key) or target not in ids for key, target in overrides.items()):
        raise ValueError("Invalid saved workspace placement.")
    if layout["mode"] == "extend":
        for i, a in enumerate(displays):
            pa = layout["positions"][a["id"]]
            for b in displays[i + 1:]:
                pb = layout["positions"][b["id"]]
                if (pa["x"] < pb["x"] + b["width"] and pb["x"] < pa["x"] + a["width"]
                        and pa["y"] < pb["y"] + b["height"] and pb["y"] < pa["y"] + a["height"]):
                    raise ValueError("Displays overlap. Drag them apart or choose a preset arrangement.")
    return copy.deepcopy(layout)


def monitor_spec(d, position, mirror="", disabled=False):
    return {"output": d["name"], "mode": f'{d["pixelWidth"]}x{d["pixelHeight"]}@{d["rate"]:.5f}',
            "position": f'{position["x"]}x{position["y"]}', "scale": d["scale"],
            "transform": d["transform"], "mirror": mirror, "disabled": disabled}


def layout_code(layout, displays):
    layout = validate(layout, displays)
    main = next(d for d in displays if d["id"] == layout["primary"])
    ordered = [main] + [d for d in displays if d is not main]
    lines = []
    for d in ordered:
        mirror = main["name"] if layout["mode"] == "mirror" and d is not main else ""
        pos = {"x": 0, "y": 0} if layout["mode"] == "mirror" else layout["positions"][d["id"]]
        lines.append("hl.monitor(" + lua(monitor_spec(d, pos, mirror)) + ")")
    return "\n".join(lines)


def valid_workspace(key):
    return isinstance(key, str) and ((key.isascii() and key.isdigit() and 0 < int(key) < 2147483647)
                                    or (key.startswith("name:") and len(key) > 5 and not any(ord(c) < 32 for c in key)))


def workspace_key(workspace):
    if workspace["id"] > 0:
        return str(workspace["id"])
    name = workspace.get("name", "")
    return "name:" + name if name and not name.startswith("special:") else None


def workspace_overrides(displays, primary, workspaces, previous=None):
    ids = {d["name"]: d["id"] for d in displays}
    result = {key: target for key, target in (previous or {}).items() if target in ids.values() and target != primary}
    for workspace in workspaces:
        key, target = workspace_key(workspace), ids.get(workspace["monitor"])
        if not key or not target:
            continue
        if target == primary:
            result.pop(key, None)
        else:
            result[key] = target
    return result


def workspace_targets(layout, displays, workspaces):
    names = {d["id"]: d["name"] for d in displays}
    # These are the desktop's numbered workspace shortcuts, including unopened
    # workspaces. Also handle existing named/additional workspaces and presets.
    keys = {str(i) for i in range(1, 11)} | {key for w in workspaces if (key := workspace_key(w))}
    keys.update(layout.get("workspaces", {}))
    return {key: names[layout["primary"] if layout["mode"] == "mirror" else
                       layout.get("workspaces", {}).get(key, layout["primary"])] for key in sorted(keys)}


def workspace_plan(layout, displays, workspaces):
    targets = workspace_targets(layout, displays, workspaces)
    existing = {workspace_key(w): w for w in workspaces if workspace_key(w)}
    for key in empty_extra_workspaces(workspaces):
        targets.pop(key, None)
    enabled = [d for d in displays if layout["mode"] != "mirror" or d["id"] == layout["primary"]]
    defaults, reserved = {}, {}
    # Each independent output needs a default workspace before it is enabled or
    # its last workspace moves away. Otherwise Hyprland invents workspace 11.
    for d in sorted(enabled, key=lambda d: d["id"] != layout["primary"]):
        candidates = [key for key, owner in targets.items() if owner == d["name"]]
        visible = str(d["workspace"])
        real = [key for key in candidates if key in existing and
                (not key.isdigit() or int(key) <= 10 or existing[key].get("windows", 0) > 0)]
        numbered = [str(i) for i in range(1, 11) if str(i) in candidates]
        choice = visible if visible in real else next(iter(real or numbered), None)
        if choice is None:
            # Prefer a not-yet-created slot; never steal an occupied workspace,
            # a separate saved placement, or another output's chosen default.
            free = [str(i) for i in range(10, 0, -1)
                    if existing.get(str(i), {}).get("windows", 0) == 0
                    and str(i) not in layout.get("workspaces", {})
                    and str(i) not in defaults.values()]
            free.sort(key=lambda key: key in existing)
            if not free:
                raise ValueError("All ten workspaces are in use. Move a workspace to the empty display before applying this layout.")
            choice = free[0]
            targets[choice] = d["name"]
            reserved[choice] = d["id"]
        defaults[d["name"]] = choice
    return targets, defaults, reserved


def empty_extra_workspaces(workspaces):
    return [str(w["id"]) for w in workspaces if w["id"] > 10
            and w.get("windows", 0) == 0 and not w.get("ispersistent", False)]


def workspace_rules(targets, defaults=None):
    chosen = set((defaults or {}).values()) if defaults is not None else {"1"}
    return ["hl.workspace_rule(" + lua({"workspace": key, "monitor": name, "default": key in chosen}) + ")"
            for key, name in targets.items()]


def place_workspaces(targets, workspaces, active=None, defaults=None):
    lines = workspace_rules(targets, defaults)
    for workspace in workspaces:
        key = workspace_key(workspace)
        if key in targets and workspace["monitor"] != targets[key]:
            lines.append("if hl.get_workspace(" + lua(key) + ") then hl.dispatch(hl.dsp.workspace.move(" +
                         lua({"workspace": key, "monitor": targets[key]}) + ")) end")
    # Materialize defaults for outputs with no existing assigned workspace.
    for name, key in (defaults or {}).items():
        if not any(workspace_key(w) == key for w in workspaces):
            lines.append("hl.dispatch(hl.dsp.focus(" + lua({"workspace": key, "on_current_monitor": False}) + "))")
    # Moving several workspaces must not leave the last (possibly empty) one
    # visible. Keep the previously visible workspaces where their groups went.
    for key in active or []:
        lines.append("if hl.get_workspace(" + lua(key) + ") then hl.dispatch(hl.dsp.focus(" +
                     lua({"workspace": key, "on_current_monitor": False}) + ")) end")
    if lines:
        hypr("eval", "\n".join(lines))


def save_monitor_rules():
    # Session-local: a later login must discover its own outputs. Loading these
    # rules with the main config prevents a reload from waking a closed laptop.
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not instance or not runtime:
        return
    path = Path(runtime) / "hypr" / instance / "desktop-monitors.lua"
    code = []
    for d in monitors():
        mirror = d["mirror"] if d["mirror"] not in ("none", "", None) else ""
        code.append("hl.monitor(" + lua(monitor_spec(d, d, mirror, d["disabled"])) + ")")
    temporary = path.with_suffix(".tmp")
    temporary.write_text("\n".join(code) + "\n")
    temporary.replace(path)


def apply_rules(code):
    # Hyprland 0.55 can arrange layer surfaces using the previous output origin
    # when moving/mirroring a monitor. A second IPC pass, after the first request
    # has finished arranging outputs, commits layers at the new coordinates.
    # Keep the existing surfaces: unmapping them would expose the fallback image.
    hypr("eval", code)
    hypr("eval", code)
    save_monitor_rules()


def restore(snapshot):
    available = {d["name"] for d in monitors()}
    if not available:
        # Outputs can disappear briefly while resuming without the dock.
        # Keep the lid snapshot so sync_lid retries when the panel returns.
        raise RuntimeError("Waiting for a display to return before restoring the layout.")
    previous = [d for d in snapshot["displays"] if d["name"] in available]
    # Bring source outputs back before restoring mirrors.
    previous.sort(key=lambda d: d["mirror"] not in ("none", "", None))
    code = []
    for d in previous:
        mirror = d["mirror"] if d["mirror"] in available else ""
        code.append("hl.monitor(" + lua(monitor_spec(d, d, mirror, d["disabled"])) + ")")
    if not any(not d["disabled"] and d["mirror"] in ("none", "", None) for d in previous):
        # The old source may have been unplugged during the trial.
        remaining = monitors()
        if remaining:
            d = remaining[0]
            code.append("hl.monitor(" + lua(monitor_spec(d, {"x": 0, "y": 0})) + ")")
    rules = snapshot.get("workspaceRules", [snapshot.get("workspaceRule") or {"workspace": "1", "monitor": "", "default": False}])
    for key in snapshot.get("managedWorkspaces", []):
        if not any(rule["workspace"] == key for rule in rules):
            code.append("hl.workspace_rule(" + lua({"workspace": key, "monitor": "", "default": False}) + ")")
    code.extend("hl.workspace_rule(" + lua(rule) + ")" for rule in rules)
    apply_rules("\n".join(code))
    time.sleep(0.25)
    restored = monitors()
    enabled = {d["name"] for d in restored if not d["disabled"]}
    expected = {d["name"] for d in previous if not d["disabled"]}
    if not enabled or not expected.issubset(enabled):
        raise RuntimeError("Waiting for the display layout to finish restoring.")
    moves = []
    for w in snapshot.get("workspaces", []):
        key = workspace_key(w)
        if key and w["monitor"] in available:
            spec = lua({"workspace": key, "monitor": w["monitor"]})
            moves.append("if hl.get_workspace(" + lua(key) + ") then hl.dispatch(hl.dsp.workspace.move(" + spec + ")) end")
    focused = next((d["name"] for d in previous if d["focused"] and not d["disabled"]), "")
    for d in previous:
        if not d["disabled"] and d["mirror"] in ("none", "", None) and d["workspace"] > 0:
            key = str(d["workspace"])
            moves.append("if hl.get_workspace(" + lua(key) + ") then hl.dispatch(hl.dsp.focus(" +
                         lua({"workspace": key, "on_current_monitor": False}) + ")) end")
    if focused:
        moves.append("hl.dispatch(hl.dsp.focus(" + lua({"monitor": focused}) + "))")
    if moves:
        hypr("eval", "\n".join(moves))
    if snapshot.get("pointer"):
        restore_pointer(snapshot["pointer"], monitors())


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def read_json(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def runtime_dir():
    session = hashlib.sha256(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "").encode()).hexdigest()[:16]
    return Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / ("desktop-displays-" + str(os.getuid()) + "-" + session)


def watchdog(token):
    time.sleep(22)
    directory = runtime_dir()
    with (directory / "transaction.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        pending = read_json(directory / "pending.json", {})
        if pending.get("token") == token:
            try:
                restore(pending["before"])
            finally:
                (directory / "pending.json").unlink(missing_ok=True)


class Controller:
    def __init__(self, state_path=None):
        self.path = state_path or Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "desktop-displays/settings.json"
        self.config = read_json(self.path, {"externalMain": False, "configured": False, "profiles": [], "layouts": {}})
        self.displays = monitors()
        self.layout = current_layout(self.displays, self.config.get("primary", ""))
        self.layout["workspaces"] = copy.deepcopy((remembered_layout(self.config, self.displays) or {}).get("workspaces", {}))
        self.pending = None
        self.error = ""
        self.message = ""
        self.generation = 0
        self.pointer_screen = pointer_context(self.displays).get("name", "")
        self.directory = runtime_dir()
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.lid_snapshot = read_json(self.directory / "lid.json", None)

    def sync_lid(self):
        closed = lid_closed()
        if closed is None:
            return False
        current = monitors()
        external = [d for d in current if not d["internal"] and not d["disabled"]]
        internal = [d for d in current if d["internal"] and not d["disabled"]]
        if self.lid_snapshot and (not closed or not external):
            # Restore the exact pre-close layout, ownership and visible pages.
            # Also recover the laptop panel if the last external is unplugged.
            snapshot = self.lid_snapshot
            restore(snapshot)
            self.layout = copy.deepcopy(snapshot["layout"])
            self.lid_snapshot = None
            (self.directory / "lid.json").unlink(missing_ok=True)
            self.refresh()
            self.generation += 1
            self.emit()
            return True
        if not closed or not external or not internal:
            return False
        if self.pending:
            self.revert()
            current = monitors()
            external = [d for d in current if not d["internal"] and not d["disabled"]]
            internal = [d for d in current if d["internal"] and not d["disabled"]]
            if not external or not internal:
                return False
        if not self.lid_snapshot:
            self.refresh()
            self.lid_snapshot = self.checkpoint()
            self.lid_snapshot["layout"] = copy.deepcopy(self.layout)
            # Persist before changing outputs, so a bar restart cannot lose it.
            atomic_json(self.directory / "lid.json", self.lid_snapshot)
        target = next((d for d in external if d["id"] == self.layout["primary"]), external[0])
        live = json.loads(hypr("-j", "workspaces"))
        names = {d["name"] for d in external}
        targets = workspace_targets(self.lid_snapshot["layout"], self.lid_snapshot["displays"], live)
        targets = {key: name if name in names else target["name"] for key, name in targets.items()}
        self.lid_snapshot["managedWorkspaces"] = list(targets)
        atomic_json(self.directory / "lid.json", self.lid_snapshot)
        # Rebind unopened workspaces too, so shortcuts cannot wake the lid panel.
        defaults = {target["name"]: str(target["workspace"])} if target["workspace"] > 0 else {}
        hypr("eval", "\n".join(workspace_rules(targets, defaults)))
        code = ["hl.monitor(" + lua(monitor_spec(d, d)) + ")" for d in external]
        code += ["hl.monitor(" + lua(monitor_spec(d, d, disabled=True)) + ")" for d in internal]
        apply_rules("\n".join(code))
        place_workspaces(targets, json.loads(hypr("-j", "workspaces")), defaults=defaults)
        self.refresh()
        self.generation += 1
        self.emit()
        return True

    def key(self):
        return json.dumps(signature(self.displays))

    def persist(self):
        atomic_json(self.path, self.config)

    def emit(self):
        profiles = []
        for p in self.config.get("profiles", []):
            matched = match_layout(p["layout"], self.displays)
            profiles.append({"id": p["id"], "name": p["name"], "mode": p["layout"]["mode"],
                             "primary": matched["primary"] if matched else p["layout"]["primary"],
                             "available": matched is not None})
        print(json.dumps({"event": "state", "displays": self.displays, "layout": self.layout,
                          "externalMain": self.config.get("externalMain", False), "profiles": profiles,
                          "generation": self.generation, "pointerScreen": self.pointer_screen,
                          "pending": self.pending is not None, "remaining": max(0, math.ceil(self.pending["deadline"] - time.monotonic())) if self.pending else 0,
                          "error": self.error, "message": self.message}), flush=True)

    def checkpoint(self):
        rules = json.loads(hypr("-j", "workspacerules"))
        return {"displays": copy.deepcopy(self.displays), "pointer": pointer_context(self.displays),
                "workspaces": json.loads(hypr("-j", "workspaces")),
                "workspaceRules": [{"workspace": str(r.get("workspaceString", r.get("workspace", ""))),
                                    "monitor": r.get("monitor", ""), "default": r.get("default", False)} for r in rules]}

    def apply(self, layout, trial=True, restore_workspaces=False):
        self.displays = monitors()
        layout = validate(layout, self.displays)
        before = self.checkpoint()
        if not restore_workspaces and self.layout["mode"] != "mirror":
            layout["workspaces"] = workspace_overrides(self.displays, self.layout["primary"], before["workspaces"],
                                                       self.layout.get("workspaces"))
        layout["workspaces"] = {key: target for key, target in layout.get("workspaces", {}).items()
                                if target != layout["primary"]}
        targets, defaults, reserved = workspace_plan(layout, self.displays, before["workspaces"])
        retired = empty_extra_workspaces(before["workspaces"])
        for key in retired:
            layout["workspaces"].pop(key, None)
        layout["workspaces"].update(reserved)
        before["managedWorkspaces"] = list(targets) + retired
        before["layout"] = copy.deepcopy(self.layout)
        token = uuid.uuid4().hex
        with (self.directory / "transaction.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            atomic_json(self.directory / "pending.json", {"token": token, "before": before})
        # Separate process survives a stalled or killed panel/helper.
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--watch", token],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        self.pending = {"before": before, "layout": layout, "deadline": time.monotonic() + 20}
        try:
            # Bind the secondary output's empty numbered workspace before
            # unmirroring/re-enabling it, not after it already picked 11.
            hypr("eval", "\n".join(workspace_rules({key: "" for key in retired}, {}) + workspace_rules(targets, defaults)))
            apply_rules(layout_code(layout, self.displays))
            old_primary = before["layout"]["primary"]
            previous_outputs = sorted(before["displays"], key=lambda d: d["id"] == old_primary)
            active = [str(d["workspace"]) for d in previous_outputs
                      if not d["disabled"] and d["mirror"] in ("none", "", None)
                      and d["workspace"] > 0 and str(d["workspace"]) not in retired]
            place_workspaces(targets, json.loads(hypr("-j", "workspaces")), active, defaults)
            self.layout = layout
            self.displays = monitors()
            self.pointer_screen = restore_pointer(before["pointer"], self.displays)
            self.generation += 1
            if not trial:
                self.keep()
        except Exception:
            self.revert()
            raise

    def keep(self):
        if not self.pending:
            return
        with (self.directory / "transaction.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if not (self.directory / "pending.json").exists():
                self.layout = self.pending["before"].get("layout", self.layout)
                self.pending = None
                self.refresh()
                raise ValueError("The trial expired and the previous layout was restored.")
            self.config.setdefault("layouts", {})[self.key()] = self.pending["layout"]
            self.config["primary"] = self.pending["layout"]["primary"]
            self.config["configured"] = True
            self.persist()
            (self.directory / "pending.json").unlink(missing_ok=True)
            self.pending = None
        self.message = "Layout saved."

    def revert(self):
        if not self.pending:
            return
        with (self.directory / "transaction.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if (self.directory / "pending.json").exists():
                restore(self.pending["before"])
                (self.directory / "pending.json").unlink(missing_ok=True)
            self.layout = copy.deepcopy(self.pending["before"].get("layout", self.layout))
            self.pending = None
        self.refresh()
        self.generation += 1
        self.message = "Previous layout restored."

    def refresh(self):
        previous = self.layout.get("workspaces", {})
        self.displays = monitors()
        self.layout = current_layout(self.displays, self.config.get("primary", ""))
        self.layout["workspaces"] = copy.deepcopy(previous) if self.layout["mode"] == "mirror" else workspace_overrides(
            self.displays, self.layout["primary"], json.loads(hypr("-j", "workspaces")), previous)
        self.pointer_screen = pointer_context(self.displays).get("name", "")

    def remember_workspaces(self):
        if self.lid_snapshot or self.pending or (self.directory / "pending.json").exists() or self.layout["mode"] == "mirror":
            return
        self.refresh()
        saved = self.config.get("layouts", {}).get(self.key())
        workspaces = json.loads(hypr("-j", "workspaces"))
        targets, defaults, reserved = workspace_plan(self.layout, self.displays, workspaces)
        retired = empty_extra_workspaces(workspaces)
        for key in retired:
            self.layout["workspaces"].pop(key, None)
        self.layout["workspaces"].update(reserved)
        if saved is not None and (saved.get("workspaces") != self.layout["workspaces"] or retired):
            saved["workspaces"] = copy.deepcopy(self.layout["workspaces"])
            pointer = pointer_context(self.displays)
            if retired:
                hypr("eval", "\n".join(workspace_rules({key: "" for key in retired}, {})))
            place_workspaces(targets, workspaces, defaults=defaults)
            restore_pointer(pointer, monitors())
            self.displays = monitors()
            self.persist()
        self.emit()

    def reconnect(self, force=False):
        if self.lid_snapshot:
            self.sync_lid()
            return
        old = signature(self.displays)
        now = monitors()
        if signature(now) == old and not force:
            return
        if self.pending:
            self.revert()
        self.displays = now
        if not now or not self.config.get("configured"):
            self.layout = current_layout(now, self.config.get("primary", ""))
            self.emit()
            return
        desired = remembered_layout(self.config, now)
        if force and desired is None:
            self.emit()
            return
        if desired is None:
            desired = arranged(now, primary_for(now, self.config.get("externalMain", False)))
        elif desired["mode"] == "extend" and not force:
            desired["primary"] = primary_for(now, self.config.get("externalMain", False))
        self.apply(desired, trial=False, restore_workspaces="workspaces" in desired)
        self.emit()

    def handle(self, request):
        action = request.get("action")
        self.error = ""
        self.message = ""
        if self.lid_snapshot and action in ("apply", "load", "save", "update"):
            raise ValueError("Open the laptop lid before changing or saving the display layout.")
        if self.pending and action not in ("keep", "revert", "status"):
            raise ValueError("Keep or revert the current layout first.")
        if action == "status":
            if not self.pending:
                self.refresh()
        elif action == "apply":
            self.apply(request["layout"])
        elif action == "keep":
            self.keep()
        elif action == "revert":
            self.revert()
        elif action == "preference":
            if type(request.get("externalMain")) is not bool:
                raise ValueError("Invalid connection preference.")
            self.config["externalMain"] = request["externalMain"]
            self.config["configured"] = True
            self.persist()
            self.message = "Preference saved for the next display connection."
        elif action == "save":
            name = request.get("name", "").strip()
            if not name or len(name) > 60 or any(ord(c) < 32 for c in name):
                raise ValueError("Give the layout a short name.")
            profiles = self.config.setdefault("profiles", [])
            if any(p["name"].casefold() == name.casefold() for p in profiles):
                raise ValueError("A layout with that name already exists.")
            if len(profiles) >= 30:
                raise ValueError("Remove a saved layout before adding another.")
            self.refresh()
            profiles.append({"id": uuid.uuid4().hex, "name": name, "layout": validate(self.layout, self.displays)})
            self.persist()
            self.message = "Layout saved as “" + name + "”."
        elif action == "load":
            profile = next((p for p in self.config.get("profiles", []) if p["id"] == request.get("id")), None)
            if not profile:
                raise ValueError("This saved layout no longer exists.")
            self.displays = monitors()
            matched = match_layout(profile["layout"], self.displays)
            if matched is None:
                raise ValueError("The connected displays changed. This layout needs matching, unambiguous monitor models.")
            self.apply(matched, restore_workspaces="workspaces" in matched)
        elif action == "update":
            profile = next((p for p in self.config.get("profiles", []) if p["id"] == request.get("id")), None)
            if not profile:
                raise ValueError("This saved layout no longer exists.")
            self.refresh()
            profile["layout"] = validate(self.layout, self.displays)
            self.persist()
            self.message = "Updated “" + profile["name"] + "” with this layout and workspace placements."
        elif action == "delete":
            self.config["profiles"] = [p for p in self.config.get("profiles", []) if p["id"] != request.get("id")]
            self.persist()
        else:
            raise ValueError("Unknown display action.")


def serve():
    directory = runtime_dir()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    guard = (directory / "service.lock").open("a")
    try:
        fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(json.dumps({"event": "error", "error": "Display controls are already running."}), flush=True)
        return
    controller = Controller()
    save_monitor_rules()
    # Recover an interrupted trial before restoring any confirmed layout.
    pending = read_json(directory / "pending.json", {})
    if pending:
        with (directory / "transaction.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            restore(pending["before"])
            (directory / "pending.json").unlink(missing_ok=True)
        controller.refresh()
    saved = remembered_layout(controller.config, controller.displays)
    if not controller.lid_snapshot and saved and saved != controller.layout:
        try:
            controller.apply(saved, trial=False, restore_workspaces="workspaces" in saved)
        except Exception as e:
            controller.error = str(e)
    controller.emit()
    events = None
    event_buffer = b""
    event_due = 0
    workspace_due = 0
    config_reloaded = False
    try:
        events = socket.socket(socket.AF_UNIX)
        events.connect(str(Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr" / os.environ["HYPRLAND_INSTANCE_SIGNATURE"] / ".socket2.sock"))
    except (OSError, KeyError):
        if events:
            events.close()
        events = None
    stop = False
    def stopping(*_):
        nonlocal stop
        stop = True
    signal.signal(signal.SIGTERM, stopping)
    signal.signal(signal.SIGINT, stopping)
    last_remaining = -1
    fallback_due = time.monotonic() + 10
    input_buffer = b""
    try:
        while not stop:
            ready, _, _ = select.select([sys.stdin] + ([events] if events else []), [], [], 0.5)
            try:
                controller.sync_lid()
            except Exception as e:
                if controller.error != str(e):
                    controller.error = str(e)
                    controller.emit()
            if sys.stdin in ready:
                data = os.read(sys.stdin.fileno(), 65536)
                if not data:
                    break
                input_buffer += data
                if len(input_buffer) > 1048576:
                    raise ValueError("Display request too large.")
                while b"\n" in input_buffer:
                    line, input_buffer = input_buffer.split(b"\n", 1)
                    try:
                        controller.handle(json.loads(line))
                    except Exception as e:
                        controller.error = str(e)
                    controller.emit()
            if events and events in ready:
                data = events.recv(65536)
                if not data:
                    events.close()
                    events = None
                else:
                    event_buffer += data
                    while b"\n" in event_buffer:
                        line, event_buffer = event_buffer.split(b"\n", 1)
                        if line.startswith((b"monitoradded", b"monitorremoved", b"configreloaded")):
                            event_due = time.monotonic() + 1
                        if line.startswith(b"configreloaded"):
                            config_reloaded = True
                        if line.startswith(b"moveworkspace"):
                            workspace_due = time.monotonic() + 0.05
            now = time.monotonic()
            if (event_due and now >= event_due) or (not events and now >= fallback_due):
                event_due = 0
                fallback_due = now + 10
                try:
                    controller.reconnect(force=config_reloaded)
                except Exception as e:
                    controller.error = str(e)
                    controller.emit()
                config_reloaded = False
            if workspace_due and now >= workspace_due:
                workspace_due = 0
                try:
                    controller.remember_workspaces()
                except Exception as e:
                    controller.error = str(e)
                    controller.emit()
            if controller.pending:
                remaining = math.ceil(controller.pending["deadline"] - now)
                if remaining <= 0:
                    controller.revert()
                if remaining != last_remaining:
                    last_remaining = remaining
                    controller.emit()
    finally:
        controller.revert()
        if events:
            events.close()


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--watch":
        watchdog(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == "status":
        print(json.dumps({"displays": monitors()}))
    else:
        try:
            serve()
        except Exception as error:
            print(json.dumps({"event": "error", "error": str(error)}), flush=True)
            sys.exit(1)
