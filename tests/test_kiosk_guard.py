import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "kiosk-guard.py"
# The production script imports evdev, which is an Ubuntu runtime dependency.
# Tests inject a tiny stub so the state machine remains testable on dev hosts.
import sys
from types import SimpleNamespace

sys.modules.setdefault("evdev", SimpleNamespace(
    InputDevice=object, ecodes=SimpleNamespace(
        KEY_RIGHTCTRL=97, KEY_RIGHTALT=100, KEY_RIGHTSHIFT=54,
        KEY_F1=59, KEY_F4=62, KEY_F5=63, KEY_F9=67, KEY_F10=68,
        KEY_F11=87, KEY_F12=88, EV_KEY=1, EV_SYN=0, SYN_REPORT=0,
    ), list_devices=lambda: [],
))
SPEC = importlib.util.spec_from_file_location("kiosk_guard", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class EventFilteringTests(unittest.TestCase):
    def test_all_f1_to_f12_are_filtered(self):
        class VirtualDevice:
            def __init__(self):
                self.events = []
            def write(self, event_type, code, value):
                self.events.append((event_type, code, value))
            def syn(self):
                self.events.append(("syn",))

        virtual = VirtualDevice()
        for key in (*range(59, 69), 87, 88):
            MODULE.forward_event(virtual, SimpleNamespace(type=1, code=key, value=1))
            MODULE.forward_event(virtual, SimpleNamespace(type=1, code=key, value=0))
        MODULE.forward_event(virtual, SimpleNamespace(type=1, code=30, value=1))
        self.assertEqual(virtual.events, [(1, 30, 1)])


class SequenceRecognizerTests(unittest.TestCase):
    def chord(self, recognizer, now=0.0):
        for key in (97, 100, 54):
            recognizer.feed(key, 1, now)
        recognizer.tick(now + 3.1)
        for key in (97, 100, 54):
            recognizer.feed(key, 0, now + 3.2)

    def test_accepts_service_sequence_after_hold(self):
        recognizer = MODULE.SequenceRecognizer((67, 68, 67))
        self.chord(recognizer)
        self.assertFalse(recognizer.feed(67, 1, 3.3))
        recognizer.feed(67, 0, 3.4)
        self.assertFalse(recognizer.feed(68, 1, 3.5))
        recognizer.feed(68, 0, 3.6)
        self.assertTrue(recognizer.feed(67, 1, 3.7))

    def test_short_hold_is_rejected(self):
        recognizer = MODULE.SequenceRecognizer((67, 68, 67))
        for key in (97, 100, 54):
            recognizer.feed(key, 1, 0.0)
        recognizer.feed(97, 0, 1.0)
        self.assertFalse(recognizer.feed(67, 1, 1.1))

    def test_wrong_key_resets_confirmation(self):
        recognizer = MODULE.SequenceRecognizer((67, 68, 67))
        self.chord(recognizer)
        self.assertFalse(recognizer.feed(68, 1, 3.3))
        self.assertEqual(recognizer.stage, "idle")

    def test_key_repeat_does_not_advance_sequence(self):
        recognizer = MODULE.SequenceRecognizer((67, 68, 67))
        self.chord(recognizer)
        self.assertFalse(recognizer.feed(67, 2, 3.3))
        self.assertEqual(recognizer.sequence_index, 0)

    def test_sequence_timeout_resets(self):
        recognizer = MODULE.SequenceRecognizer((67, 68, 67))
        self.chord(recognizer)
        recognizer.tick(9.0)
        self.assertEqual(recognizer.stage, "idle")


if __name__ == "__main__":
    unittest.main()
