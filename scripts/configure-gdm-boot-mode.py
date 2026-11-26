#!/usr/bin/python3
"""Select GDM kiosk auto-login or the normal greeter for this boot."""
from __future__ import annotations
import json, os, re, tempfile
from pathlib import Path
CONFIG = Path("/etc/yapdp-kiosk/boot-mode.json")
GDM_CONFIG = Path("/etc/gdm3/custom.conf")
SERVICE_FLAG = "yapdp.service_mode=1"
def update_daemon_section(path: Path, settings: dict[str, str]) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    start, end = None, len(lines)
    for index, line in enumerate(lines):
        if re.match(r"^\s*\[daemon\]\s*(?:#.*)?$", line, re.I):
            start = index
            for pos in range(index + 1, len(lines)):
                if re.match(r"^\s*\[[^]]+\]", lines[pos]):
                    end = pos
                    break
            break
    if start is None:
        if lines and lines[-1].strip(): lines.append("")
        lines.append("[daemon]")
        start, end = len(lines) - 1, len(lines)
    wanted, seen, output = set(settings), set(), []
    for index, line in enumerate(lines):
        if start < index < end:
            match = re.match(r"^\s*#?\s*(AutomaticLoginEnable|AutomaticLogin|TimedLoginEnable)\s*=", line)
            if match and match.group(1) in wanted:
                key = match.group(1)
                if key not in seen:
                    output.append(f"{key}={settings[key]}")
                    seen.add(key)
                continue
        output.append(line)
    insert_at = next((i for i, line in enumerate(output)
                      if i > start and re.match(r"^\s*\[[^]]+\]", line)), len(output))
    output[insert_at:insert_at] = [f"{k}={v}" for k,v in settings.items() if k not in seen]
    content = "\n".join(output) + "\n"
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream: stream.write(content)
        os.chmod(temporary, path.stat().st_mode & 0o777)
        metadata = path.stat()
        os.chown(temporary, metadata.st_uid, metadata.st_gid)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)
def configure_gdm(config_path: Path, gdm_path: Path, cmdline: str) -> bool:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    service_mode = SERVICE_FLAG in cmdline.split()
    settings = ({"AutomaticLoginEnable":"False","AutomaticLogin":"","TimedLoginEnable":"False"}
                if service_mode else
                {"AutomaticLoginEnable":"True","AutomaticLogin":config["kiosk_user"],"TimedLoginEnable":"False"})
    update_daemon_section(gdm_path, settings)
    return service_mode
def main() -> int:
    service = configure_gdm(CONFIG, GDM_CONFIG, Path("/proc/cmdline").read_text("ascii"))
    print("yaPDP boot mode: service desktop" if service else "yaPDP boot mode: kiosk")
    return 0
if __name__ == "__main__": raise SystemExit(main())
