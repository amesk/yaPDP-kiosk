#!/usr/bin/env python3
"""Restore the exact pre-install files captured by capture-system-state.py."""
import json, os, shutil, sys
from pathlib import Path

STATE = Path("/var/lib/yapdp-kiosk/original-state")
manifest_path = STATE / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit(f"No valid original-state backup found at {STATE}; refusing destructive restore.")
data = json.loads(manifest_path.read_text())
if data.get("version") != 1 or not isinstance(data.get("files"), dict):
    raise SystemExit("Unsupported or corrupt original-state manifest; refusing restore.")

# Validate every required backup before touching the live system.
for raw, meta in data["files"].items():
    if meta.get("kind") == "file" and not (STATE / "files" / raw.lstrip("/")).is_file():
        raise SystemExit(f"Backup file missing for {raw}; refusing partial restore.")
    if meta.get("kind") not in ("file", "symlink", "absent"):
        raise SystemExit(f"Unknown backup kind for {raw}; refusing restore.")

for raw, meta in data["files"].items():
    target = Path(raw)
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        raise SystemExit(f"Refusing to replace unexpected non-file path: {target}")
    if meta["kind"] == "absent":
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    if meta["kind"] == "symlink":
        target.symlink_to(meta["target"])
    else:
        saved = STATE / "files" / raw.lstrip("/")
        shutil.copy2(saved, target)
        os.chown(target, meta["uid"], meta["gid"])
        os.chmod(target, meta["mode"])

# Remove only directories created by the installer, and only when empty.
for raw, existed in data.get("directories", {}).items():
    if not existed:
        try:
            Path(raw).rmdir()
        except OSError:
            pass

# The dedicated unprivileged account and its home are intentionally retained.
# Removing a currently logged-in account during rollback is unsafe; GDM's
# restored configuration prevents the kiosk session from auto-starting.
print("Restored pre-install configuration files and directory state.")
