import importlib.util
import pathlib
import sys
import unittest
from types import SimpleNamespace
SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "kiosk-guard.py"
sys.modules.setdefault("evdev", SimpleNamespace(
    InputDevice=object,
    ecodes=SimpleNamespace(KEY_RIGHTCTRL=97, KEY_RIGHTALT=100, KEY_RIGHTSHIFT=54,
                           EV_KEY=1, EV_SYN=0, SYN_REPORT=0),
    list_devices=lambda: [],
))
SPEC = importlib.util.spec_from_file_location("kiosk_guard", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
class EventFilteringTests(unittest.TestCase):
    class VirtualDevice:
        def __init__(self): self.events = []
        def write(self, event_type, code, value): self.events.append((event_type, code, value))
        def syn(self): self.events.append(("syn",))
    def test_all_function_keys_are_filtered_on_press_and_release(self):
        virtual = self.VirtualDevice()
        for key in (*range(59, 69), 87, 88):
            MODULE.forward_event(virtual, SimpleNamespace(type=1, code=key, value=1))
            MODULE.forward_event(virtual, SimpleNamespace(type=1, code=key, value=0))
        self.assertEqual(virtual.events, [])
    def test_regular_keys_and_modifiers_are_forwarded(self):
        virtual = self.VirtualDevice()
        MODULE.forward_event(virtual, SimpleNamespace(type=1, code=30, value=1))
        MODULE.forward_event(virtual, SimpleNamespace(type=1, code=97, value=1))
        self.assertEqual(virtual.events, [(1, 30, 1), (1, 97, 1)])
    def test_keyboard_detected_without_right_side_modifiers(self):\n        class Device:\n            def capabilities(self): return {1: [30, 28, 1, 42, 29]}\n        self.assertTrue(MODULE.is_keyboard(Device()))\n    def test_mouse_is_not_detected_as_keyboard(self):\n        class Device:\n            def capabilities(self): return {1: [272, 273, 274]}\n        self.assertFalse(MODULE.is_keyboard(Device()))\n    def test_syn_report_is_forwarded(self):
        virtual = self.VirtualDevice()
        MODULE.forward_event(virtual, SimpleNamespace(type=0, code=0, value=0))
        self.assertEqual(virtual.events, [("syn",)])
if __name__ == "__main__": unittest.main()
