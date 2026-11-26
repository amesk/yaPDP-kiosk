#!/usr/bin/env python3
"""Restore the exact pre-install files captured by capture-system-state.py."""
import json, os, shutil, subprocess, sys
from pathlib import Path

STATE = Path("/var/lib/yapdp-kiosk/original-state")
manifest_path = STATE / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit(f"No valid original-state backup found at {STATE}; refusing destructive restore.")
data = json.loads(manifest_path.read_text())
if data.get("version") != 1 or not isinstance(data.get("files"),dict):
    raise SystemExit("Unsupported or corrupt original-state manifest; refusing restore.")
backup_root = STATE / "files"
for raw, meta in data["files"].items():
    target = Path(raw)
    saved = backup_root / raw.lstrip("/")
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        raise SystemExit(f"Refusing to replace unexpected non-file path: {target}")
    if meta["kind"] == "absent":
        continue
    target.parent.mkdir(parents=True,exist_ok=True)
    if meta["kind"] == "symlink":
        target.symlink_to(meta["target"])
    elif meta["kind"] == "file":
        if not saved.is_file():
            raise SystemExit(f"Backup file missing: {saved}")
        shutil.copy2(saved,target)
        os.chown(target,meta["uid"],meta["gid"])
        os.chmod(target,meta["mode"])
    else:
        raise SystemExit(f"Unknown backup kind for {target}")
print("Restored pre-install configuration files.")
