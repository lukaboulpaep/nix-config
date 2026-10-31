"""Keep libddcutil initialized between slider updates; release bus locks per call."""
import ctypes as c
from pathlib import Path
import shutil


class VcpValue(c.Structure):
    _fields_ = [(name, c.c_ubyte) for name in ("mh", "ml", "sh", "sl")]


class DdcSession:
    def __init__(self):
        executable = shutil.which("ddcutil")
        if not executable:
            raise RuntimeError("Monitor controls are unavailable")
        self.lib = c.CDLL(str(Path(executable).resolve().parent.parent / "lib/libddcutil.so"))
        self.connection = None
        self.references = {}
        pointer = c.POINTER(c.c_void_p)
        self.init = self.bind("ddca_init2", [c.c_char_p, c.c_int, c.c_int, c.c_void_p])
        self.identify = self.bind("ddca_create_busno_display_identifier", [c.c_int, pointer])
        self.reference = self.bind("ddca_get_display_ref", [c.c_void_p, pointer])
        self.free_identifier = self.bind("ddca_free_display_identifier", [c.c_void_p])
        self.open = self.bind("ddca_open_display2", [c.c_void_p, c.c_bool, pointer])
        self.close = self.bind("ddca_close_display", [c.c_void_p])
        self.redetect = self.bind("ddca_redetect_displays", [])
        self.set_value = self.bind("ddca_set_non_table_vcp_value2", [c.c_void_p, c.c_ubyte, c.c_ubyte, c.c_ubyte])
        self.get_value = self.bind("ddca_get_non_table_vcp_value", [c.c_void_p, c.c_ubyte, c.POINTER(VcpValue)])
        self.check(self.init(b"--disable-watch-displays", 0, 0, None))

    def bind(self, name, args):
        function = getattr(self.lib, name)
        function.argtypes = args
        function.restype = c.c_int
        return function

    @staticmethod
    def check(status):
        if status:
            raise RuntimeError("The monitor did not respond to brightness controls (code %s)" % status)

    def get_reference(self, item):
        if self.connection != item["connection"]:
            if self.connection is not None:
                self.check(self.redetect())
            self.references.clear()
            self.connection = item["connection"]
        if item["id"] not in self.references:
            identifier, reference = c.c_void_p(), c.c_void_p()
            self.check(self.identify(int(item["device"]), c.byref(identifier)))
            try:
                self.check(self.reference(identifier, c.byref(reference)))
            finally:
                self.free_identifier(identifier)
            self.references[item["id"]] = reference
        return self.references[item["id"]]

    def prepare(self, rows):
        for item in rows:
            if item["kind"] == "ddc" and item["supported"]:
                self.get_reference(item)

    def write(self, item, target, verify):
        handle = c.c_void_p()
        self.check(self.open(self.get_reference(item), False, c.byref(handle)))
        try:
            self.check(self.set_value(handle, 0x10, target >> 8, target & 255))
            if not verify:
                return target, item["maximum"]
            value = VcpValue()
            self.check(self.get_value(handle, 0x10, c.byref(value)))
            return value.sh * 256 + value.sl, value.mh * 256 + value.ml
        finally:
            self.close(handle)
