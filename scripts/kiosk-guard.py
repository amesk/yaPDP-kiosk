#!/usr/bin/python3
"""Filter F1-F12 from physical keyboards in the public yaPDP kiosk session."""
from __future__ import annotations

import logging
import select
import sys
import time

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError as exc:
    raise SystemExit("python3-evdev is required: apt install python3-evdev") from exc

FUNCTION_KEYS = frozenset((*range(59, 69), 87, 88))
KEYBOARD_MARKERS = frozenset((
    ecodes.KEY_A, ecodes.KEY_ENTER, ecodes.KEY_SPACE, ecodes.KEY_ESC,
    ecodes.KEY_LEFTCTRL, ecodes.KEY_LEFTALT, ecodes.KEY_LEFTSHIFT,
    ecodes.KEY_RIGHTCTRL, ecodes.KEY_RIGHTALT, ecodes.KEY_RIGHTSHIFT,
))
SCAN_SECONDS = 1.0
VIRTUAL_PREFIX = "yaPDP filtered keyboard ("


def forward_event(virtual_device, event):
    if event.type == ecodes.EV_KEY and event.code in FUNCTION_KEYS:
        return
    if event.type == ecodes.EV_SYN:
        if event.code == ecodes.SYN_REPORT:
            virtual_device.syn()
        return
    virtual_device.write(event.type, event.code, event.value)


def create_keyboard_proxy(device):
    from evdev import UInput

    virtual = UInput.from_device(device, name=f"{VIRTUAL_PREFIX}{device.name})")
    try:
        device.grab()
    except Exception:
        virtual.close()
        raise
    return virtual


def is_keyboard(device):
    try:
        key_codes = set(device.capabilities().get(ecodes.EV_KEY, []))
    except OSError:
        logging.exception("Cannot read capabilities of input device %s (%s)", device.path, device.name)
        return False

    markers = key_codes & KEYBOARD_MARKERS
    function_keys = sorted(key_codes & FUNCTION_KEYS)
    logging.info(
        "Input device inspected: %s (%s); key_codes=%d; keyboard_markers=%d; F1-F12=%s",
        device.path, device.name, len(key_codes), len(markers), function_keys,
    )
    return bool(markers)


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s yapdp-kiosk-keyboard-filter %(levelname)s: %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    logging.info("F1-F12 keyboard filter started")

    devices, virtuals, next_scan = {}, {}, 0.0
    open_errors = set()

    while True:
        now = time.monotonic()
        if now >= next_scan:
            next_scan = now + SCAN_SECONDS
            try:
                current = set(list_devices())
            except OSError:
                logging.exception("Cannot enumerate input devices")
                current = set()

            for path in list(devices):
                if path not in current:
                    devices[path].close()
                    del devices[path]
                    virtual = virtuals.pop(path, None)
                    if virtual is not None:
                        virtual.close()
                    logging.info("Keyboard detached: %s", path)

            for path in current - set(devices):
                try:
                    device = InputDevice(path)
                except OSError as exc:
                    if path not in open_errors:
                        logging.warning("Cannot open input device %s: %s", path, exc)
                        open_errors.add(path)
                    continue

                open_errors.discard(path)

                if device.name.startswith(VIRTUAL_PREFIX):
                    device.close()
                    continue

                if is_keyboard(device):
                    try:
                        virtual = create_keyboard_proxy(device)
                    except Exception:
                        device.close()
                        logging.exception("Cannot install F-key filtering for %s (%s)", path, device.name)
                        raise

                    devices[path], virtuals[path] = device, virtual
                    logging.info("Keyboard attached and proxied: %s (%s)", path, device.name)
                else:
                    device.close()

        if not devices:
            time.sleep(0.25)
            continue

        try:
            ready, _, _ = select.select([device.fd for device in devices.values()], [], [], 0.25)
        except (OSError, ValueError):
            logging.exception("Cannot poll keyboard devices")
            continue

        fd_to_path = {device.fd: path for path, device in devices.items()}
        for fd in ready:
            path = fd_to_path.get(fd)
            device = devices.get(path) if path is not None else None
            if device is None:
                continue
            try:
                for event in device.read():
                    forward_event(virtuals[path], event)
            except OSError as exc:
                logging.warning("Keyboard read failed for %s: %s", path, exc)
                device.close()
                devices.pop(path, None)
                virtual = virtuals.pop(path, None)
                if virtual is not None:
                    virtual.close()


if __name__ == "__main__":
    raise SystemExit(main())
