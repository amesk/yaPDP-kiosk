#!/usr/bin/python3
"""Local keyboard service-mode guard for the yaPDP museum kiosk.

The process grabs physical keyboards and republishes their events through
uinput, suppressing F1-F12 before they reach the graphical session. It also
recognizes the local service sequence from the physical events.
"""

from __future__ import annotations

import fcntl
import logging
import os
import select
import subprocess
import sys
import time
from pathlib import Path

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError as exc:  # pragma: no cover - exercised by service startup
    raise SystemExit("python3-evdev is required: apt install python3-evdev") from exc

VT_UNLOCKSWITCH = 0x560C
VT_DEVICE = "/dev/tty0"
SERVICE_MODE_MARKER = Path("/run/yapdp-kiosk-service-mode")
MODIFIERS = frozenset((ecodes.KEY_RIGHTCTRL, ecodes.KEY_RIGHTALT, ecodes.KEY_RIGHTSHIFT))
HOLD_SECONDS = 3.0
SEQUENCE_SECONDS = 5.0
SCAN_SECONDS = 1.0
FUNCTION_KEYS = frozenset((*range(59, 69), 87, 88))


class SequenceRecognizer:
    """Recognize the two-stage service chord on one physical keyboard."""

    def __init__(self, sequence):
        self.sequence = tuple(sequence)
        self.pressed = set()
        self.stage = "idle"
        self.hold_started = None
        self.sequence_index = 0
        self.sequence_deadline = None

    def reset(self):
        self.pressed.clear()
        self.stage = "idle"
        self.hold_started = None
        self.sequence_index = 0
        self.sequence_deadline = None

    def tick(self, now):
        if self.stage == "holding" and self.hold_started is not None:
            if now - self.hold_started >= HOLD_SECONDS:
                self.stage = "release"
        if self.stage == "sequence" and self.sequence_deadline is not None:
            if now > self.sequence_deadline:
                self.reset()

    def feed(self, code, value, now):
        # value 2 is kernel key-repeat; it must never advance the sequence.
        if value == 2:
            return False
        if value not in (0, 1):
            return False

        if value == 1:
            if code in self.pressed:
                return False
            self.pressed.add(code)
            self.tick(now)

            if self.stage == "idle":
                if code in MODIFIERS:
                    if MODIFIERS.issubset(self.pressed):
                        self.stage = "holding"
                        self.hold_started = now
                return False

            if self.stage == "holding":
                if code not in MODIFIERS:
                    self.reset()
                return False

            if self.stage == "release":
                # Only the three modifiers may be released between stages.
                if code not in MODIFIERS:
                    self.reset()
                return False

            if self.stage == "sequence":
                if code != self.sequence[self.sequence_index]:
                    self.reset()
                    return False
                self.sequence_index += 1
                if self.sequence_index == len(self.sequence):
                    self.reset()
                    return True
                return False

        else:
            self.pressed.discard(code)
            self.tick(now)
            if self.stage == "holding" and code in MODIFIERS:
                # Releasing any modifier before the hold interval cancels it.
                self.reset()
            elif self.stage == "release" and not (MODIFIERS & self.pressed):
                self.stage = "sequence"
                self.sequence_deadline = now + SEQUENCE_SECONDS
        return False


def forward_event(virtual_device, event):
    """Forward one physical event, except F1-F12 and their key releases."""
    if event.type == ecodes.EV_KEY and event.code in FUNCTION_KEYS:
        return
    if event.type == ecodes.EV_SYN:
        if event.code == ecodes.SYN_REPORT:
            virtual_device.syn()
        return
    virtual_device.write(event.type, event.code, event.value)


def create_keyboard_proxy(device):
    """Grab a physical keyboard and expose a filtered virtual replacement."""
    from evdev import UInput

    virtual_device = UInput.from_device(
        device,
        name=f"yaPDP filtered keyboard ({device.name})",
    )
    try:
        device.grab()
    except Exception:
        virtual_device.close()
        raise
    return virtual_device


def unlock_vt_switching():
    fd = os.open(VT_DEVICE, os.O_RDWR | os.O_NOCTTY)
    try:
        fcntl.ioctl(fd, VT_UNLOCKSWITCH, 0)
    finally:
        os.close(fd)


def enter_service_mode():
    """Fail closed: leave VT locked unless the console hand-off can proceed."""
    SERVICE_MODE_MARKER.write_text("service mode requested\n", encoding="ascii")
    logging.warning("Service sequence accepted; preparing local maintenance console")

    # Start the getty before stopping GDM so a login prompt is ready when the
    # graphical session goes away. tty3 is deliberately explicit; NAutoVTs=0
    # prevents logind from creating arbitrary spare consoles.
    subprocess.run(["systemctl", "start", "getty@tty3.service"], check=True, timeout=30)
    subprocess.run(["systemctl", "stop", "display-manager.service"], check=True, timeout=60)
    unlock_vt_switching()
    subprocess.run(["chvt", "3"], check=True, timeout=10)
    logging.warning("Local maintenance console is available on tty3")


def is_keyboard(device, sequence):
    try:
        keys = set(device.capabilities().get(ecodes.EV_KEY, []))
        return bool(keys & (set(MODIFIERS) | set(sequence)))
    except OSError:
        return False


def load_service_sequence():
    config = Path("/etc/yapdp-kiosk/guard.conf")
    values = {}
    for line in config.read_text(encoding="ascii").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if separator:
            values[key.strip()] = value.strip()
    names = values.get("service_sequence", "").split(",")
    if len(names) != 3 or any(not name.startswith("KEY_F") for name in names):
        raise RuntimeError(f"Invalid service_sequence in {config}")
    try:
        return tuple(getattr(ecodes, name) for name in names)
    except AttributeError as exc:
        raise RuntimeError(f"Unsupported key name in {config}: {exc}") from exc


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s yapdp-kiosk-guard %(levelname)s: %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    sequence = load_service_sequence()
    logging.info("Keyboard guard started; F1-F12 are filtered before reaching the kiosk session")
    logging.info("Local service trigger loaded from root-owned configuration")

    devices = {}
    virtual_devices = {}
    recognizers = {}
    triggered = False
    next_scan = 0.0

    while not triggered:
        now = time.monotonic()
        if now >= next_scan:
            next_scan = now + SCAN_SECONDS
            try:
                current = set(list_devices())
            except OSError as exc:
                logging.error("Cannot enumerate input devices: %s", exc)
                current = set()

            for path in list(devices):
                if path not in current:
                    devices[path].close()
                    del devices[path]
                    virtual = virtual_devices.pop(path, None)
                    if virtual is not None:
                        virtual.close()
                    recognizers.pop(path, None)
                    logging.info("Keyboard disconnected: %s", path)

            for path in current - set(devices):
                try:
                    device = InputDevice(path)
                except OSError as exc:
                    # A hot-unplug can race list_devices(); retry on the next scan.
                    logging.debug("Cannot open input device %s: %s", path, exc)
                    continue

                # Our own uinput keyboards are visible in list_devices(); never
                # proxy them again or the virtual-device chain would grow forever.
                if device.name.startswith("yaPDP filtered keyboard ("):
                    device.close()
                    continue

                if is_keyboard(device, sequence):
                    try:
                        virtual = create_keyboard_proxy(device)
                    except Exception as exc:
                        device.close()
                        # Do not silently run with an unfiltered physical keyboard.
                        logging.exception("Cannot install the F-key filter for %s", path)
                        raise RuntimeError(f"Keyboard filtering unavailable for {path}") from exc
                    devices[path] = device
                    virtual_devices[path] = virtual
                    recognizers[path] = SequenceRecognizer(sequence)
                    logging.info("Keyboard attached and proxied: %s (%s)", path, device.name)
                else:
                    device.close()

        if not devices:
            time.sleep(0.25)
            continue

        try:
            ready, _, _ = select.select([device.fd for device in devices.values()], [], [], 0.25)
        except (OSError, ValueError):
            continue

        fd_to_path = {device.fd: path for path, device in devices.items()}
        now = time.monotonic()
        for fd in ready:
            path = fd_to_path.get(fd)
            if path is None:
                continue
            device = devices.get(path)
            if device is None:
                continue
            try:
                for event in device.read():
                    if event.type == ecodes.EV_KEY:
                        recognizer = recognizers[path]
                        if recognizer.feed(event.code, event.value, now):
                            triggered = True
                    forward_event(virtual_devices[path], event)
                    if triggered:
                        break
            except OSError as exc:
                logging.warning("Keyboard read failed for %s: %s", path, exc)
                device.close()
                devices.pop(path, None)
                virtual = virtual_devices.pop(path, None)
                if virtual is not None:
                    virtual.close()
                recognizers.pop(path, None)
            if triggered:
                break

        if not triggered:
            now = time.monotonic()
            for recognizer in recognizers.values():
                recognizer.tick(now)

    # A service-mode transition is one-shot. If any step fails, systemd restarts
    # the guard, but the marker prevents the kiosk launcher from relaunching Chrome.
    enter_service_mode()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
