#!/usr/bin/python3
"""Select kiosk automatic login or the normal GDM greeter for this boot."""

from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path

CONFIG = Path("/etc/yapdp-kiosk/boot-mode.json")
GDM_CONFIG = Path("/etc/gdm3/custom.conf")
SERVICE_FLAG = "yapdp.service_mode=1"
GDM_KEYS = ("AutomaticLoginEnable", "AutomaticLogin", "TimedLoginEnable")


def update_daemon_section(path: Path, settings: dict[str, str]) -> None:
    """Atomically update only the GDM [daemon] settings owned by this installer."""
    original_stat = path.stat()
    lines = path.read_text(encoding="utf-8").splitlines()

    section_start = None
    section_end = len(lines)
    for index, line in enumerate(lines):
        if re.match(r"^\s*\[daemon\]\s*(?:#.*)?$", line, re.IGNORECASE):
            section_start = index
            for end in range(index + 1, len(lines)):
                if re.match(r"^\s*\[[^]]+\]", lines[end]):
                    section_end = end
                    break
            break

    if section_start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("[daemon]")
        section_start = len(lines) - 1
        section_end = len(lines)

    seen = set()
    updated = []
    for index, line in enumerate(lines):
        if section_start < index < section_end:
            match = re.match(
                r"^\s*#?\s*(AutomaticLoginEnable|AutomaticLogin|TimedLoginEnable)\s*=",
                line,
            )
            if match:
                key = match.group(1)
                if key in settings:
                    if key not in seen:
                        updated.append(f"{key}={settings[key]}")
                        seen.add(key)
                    continue
        updated.append(line)

    insert_at = next(
        (
            index
            for index, line in enumerate(updated)
            if index > section_start and re.match(r"^\s*\[[^]]+\]", line)
        ),
        len(updated),
    )
    updated[insert_at:insert_at] = [
        f"{key}={value}" for key, value in settings.items() if key not in seen
    ]
    content = "\n".join(updated) + "\n"

    fd, temporary = tempfile.mkstemp(prefix=f"{path.name}.", dir=path.parent)
    try:
        if os.geteuid() == 0:
            os.fchown(fd, original_stat.st_uid, original_stat.st_gid)
        os.fchmod(fd, original_stat.st_mode & 0o777)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def configure_gdm(config_path: Path, gdm_path: Path, cmdline: str) -> bool:
    """Apply the one-boot policy and return True when this is a service boot."""
    config = json.loads(config_path.read_text(encoding="utf-8"))
    service_mode = SERVICE_FLAG in cmdline.split()

    if service_mode:
        settings = {
            "AutomaticLoginEnable": "False",
            "AutomaticLogin": "",
            "TimedLoginEnable": "False",
        }
    else:
        settings = {
            "AutomaticLoginEnable": "True",
            "AutomaticLogin": config["kiosk_user"],
            "TimedLoginEnable": "False",
        }

    update_daemon_section(gdm_path, settings)
    return service_mode


def main() -> int:
    cmdline = Path("/proc/cmdline").read_text(encoding="ascii")
    service_mode = configure_gdm(CONFIG, GDM_CONFIG, cmdline)
    mode = "service desktop" if service_mode else "kiosk"
    print(f"yaPDP boot mode: {mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
