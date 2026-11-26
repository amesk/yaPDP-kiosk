#!/usr/bin/env python3
"""Capture the pre-install state of files owned or modified by yaPDP-kiosk."""
import json, os, shutil, subprocess, sys
from pathlib import Path

STATE = Path("/var/lib/yapdp-kiosk/original-state")
USER = sys.argv[1]
HOME = Path(sys.argv[2])
KIOSK_DIR = Path(sys.argv[3])
if STATE.exists():
    manifest = STATE / "manifest.json"
    if not manifest.is_file():
        raise SystemExit(f"Refusing to overwrite incomplete state backup: {STATE}")
    data = json.loads(manifest.read_text())
    if data.get("kiosk_user") != USER or data.get("kiosk_home") != str(HOME):
        raise SystemExit("Existing original-state backup belongs to a different kiosk account.")
    print(f"Original system state already captured: {STATE}")
    raise SystemExit(0)

paths = [
 "/etc/default/grub", "/etc/grub.d/01_yapdp_disable_stock", "/etc/grub.d/08_yapdp_kiosk_auth",
 "/etc/grub.d/09_yapdp_kiosk", "/etc/grub.d/10_linux", "/etc/grub.d/10_linux_zfs",
 "/etc/grub.d/20_linux_xen", "/etc/grub.d/20_memtest86+", "/etc/grub.d/30-os-prober",
 "/etc/grub.d/30_os-prober", "/etc/grub.d/30-uefi-firmware", "/etc/grub.d/30_uefi-firmware",
 "/etc/grub.d/40_custom", "/etc/grub.d/41_custom", "/etc/gdm3/custom.conf",
 "/etc/update-manager/release-upgrades", "/etc/update-manager/release-upgrades.yapdp-kiosk.bak", "/etc/nginx/sites-available/yapdp-kiosk",
 "/etc/nginx/sites-enabled/yapdp-kiosk", "/etc/xdg/autostart/yapdp-kiosk.desktop",
 "/etc/yapdp-kiosk/boot-mode.json", "/root/yapdp-kiosk-grub-password.txt", "/etc/systemd/system/yapdp-kiosk-guard.service",
 "/etc/systemd/system/gdm3.service.d/10-yapdp-boot-mode.conf",
 "/etc/systemd/system/getty@tty3.service.d/10-yapdp-service-mode.conf",
 "/etc/systemd/logind.conf.d/90-yapdp-kiosk.conf",
 "/etc/systemd/system/ctrl-alt-del.target", "/etc/sysctl.d/90-yapdp-kiosk.conf",
 "/etc/modules-load.d/yapdp-kiosk.conf", "/etc/sudoers.d/yapdp-kiosk-vt-lock",
 "/usr/local/lib/yapdp-kiosk/kiosk-guard.py",
 "/usr/local/lib/yapdp-kiosk/configure-gdm-boot-mode.py",
 "/usr/local/sbin/yapdp-vt-switch-lock", "/usr/local/sbin/activate-yapdp-kiosk", "/usr/local/sbin/deactivate-yapdp-kiosk", str(KIOSK_DIR / "config.js"),
 str(HOME / ".local/bin/gnome-kiosk-script"),
 str(HOME / ".config/gnome-initial-setup-done"),
 str(HOME / ".config/dconf/user"),
 str(HOME / ".config/autostart/yapdp-kiosk.desktop"),
 f"/var/lib/AccountsService/users/{USER}",
]
directories = ["/etc/yapdp-kiosk", "/etc/systemd/system/gdm3.service.d", "/etc/systemd/system/getty@tty3.service.d", "/etc/systemd/system/logind.conf.d", "/etc/sysctl.d", "/etc/modules-load.d", "/usr/local/lib/yapdp-kiosk", "/var/lib/AccountsService/users"]
directory_state = {p: Path(p).is_dir() for p in directories}
services = ["nginx.service", "gdm3.service", "yapdp-kiosk-guard.service", "getty@tty3.service"]
account_existed = subprocess.run(["id", USER], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
STATE.mkdir(parents=True, mode=0o700)
files = {}
for raw in paths:
    p = Path(raw)
    key = raw.lstrip("/")
    if p.is_symlink():
        target = os.readlink(p)
        files[raw] = {"kind":"symlink", "target":target}
        dest = STATE / "files" / key
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.symlink_to(target)
    elif p.is_file():
        st = p.stat()
        files[raw] = {"kind":"file", "mode":st.st_mode & 0o777, "uid":st.st_uid, "gid":st.st_gid}
        dest = STATE / "files" / key
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, dest)
    else:
        files[raw] = {"kind":"absent"}
service_state = {}
for service in services:
    enabled = subprocess.run(["systemctl","is-enabled",service],capture_output=True,text=True).stdout.strip()
    active = subprocess.run(["systemctl","is-active",service],capture_output=True,text=True).stdout.strip()
    service_state[service] = {"enabled":enabled or "unknown", "active":active or "unknown"}
manifest = {"version":1,"kiosk_user":USER,"kiosk_home":str(HOME),"account_existed":account_existed,"files":files,"directories":directory_state,"services":service_state}
tmp = STATE / "manifest.json.tmp"
tmp.write_text(json.dumps(manifest,indent=2)+"\n")
os.chmod(tmp,0o600)
tmp.replace(STATE / "manifest.json")
os.chmod(STATE,0o700)
print(f"Captured original system state in {STATE}")
