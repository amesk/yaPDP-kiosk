# yaPDP-kiosk

A standalone presentation shell for museum and exhibition computers. It displays a configurable slideshow and a prominent launch button, then navigates the same browser window to the exhibit.

The deployment target is **Ubuntu 24.04 Desktop with GNOME/GDM, nginx, and Google Chrome or Chromium**. The kiosk shell remains independent of yaPDP; nginx serves both projects from the local filesystem.

## Quick install on a prepared Ubuntu 24.04 Desktop

Download and inspect the bootstrap script. It installs the official Google Chrome Stable package when Chrome is absent:

```bash
curl -fsSLo instant-setup.sh \
  https://raw.githubusercontent.com/amesk/yaPDP-kiosk/main/instant-setup.sh
less instant-setup.sh
sudo bash ./instant-setup.sh
```

The script is designed for a **fresh Ubuntu 24.04 Desktop installation**. It refuses to overwrite an existing `/opt/yapdp-exhibit` directory and pins exact commits of both repositories. It does not install the operating system, partition disks, or configure firmware/BIOS settings. The bootstrap installs Chrome Stable from Google's official download endpoint when needed; this requires internet access and an amd64 machine.

The bootstrap:
1. Checks Ubuntu 24.04 Desktop and GDM.
2. Installs the official Google Chrome Stable `.deb` from Google if Chrome is not already installed, then verifies the executable and version. On amd64 only.
3. Installs Git if needed.
4. Checks out the pinned yaPDP and yaPDP-kiosk revisions under `/opt/yapdp-exhibit/`.
5. Runs the kiosk installer.

Do not pipe a remote script directly into a root shell. Download it, inspect it, and then run it with sudo.

## What the installer configures

- Creates a dedicated unprivileged `yapdp-kiosk` account (override with `KIOSK_USER=name`).
- Refuses to use a kiosk account that belongs to the `sudo` group.
- Enables GDM automatic login for that account.
- Adds a per-user desktop-session autostart entry for the kiosk browser.
- Installs/configures nginx on **127.0.0.1:8080** only.
- Keeps application files root-owned and readable by the kiosk account.

The kiosk account is not an administrator. Keep a separate administrator account for maintenance. Automatic login is a physical-access convenience, not a security boundary: anyone with access to the machine can use the active kiosk session. Do not store secrets in the kiosk account.

The installer edits the `[daemon]` section of `/etc/gdm3/custom.conf` to set GDM automatic login. Review this setting if the machine already has a customized display-manager policy. The change takes effect after reboot.

## Deployment layout

```text
/opt/yapdp-exhibit/
├── yaPDP-kiosk/
│   ├── index.html
│   ├── config.js
│   ├── start-kiosk.sh
│   └── ...
└── yaPDP/
    ├── pdp11.html
    ├── src/
    ├── css/
    ├── assets/
    ├── media/
    └── states/
```

Use a normal yaPDP checkout/release. No FS Bundle, generated resource archive, Node.js runtime, or changes to yaPDP are required for this deployment.

## Manual install / reconfiguration

If both repositories are already placed side by side in the layout above, run:

```bash
cd /opt/yapdp-exhibit/yaPDP-kiosk
sudo bash ./install/ubuntu-24.04.sh
```

The installer can be run again to reconfigure nginx and GDM. It does not overwrite the repository tree. The first-run bootstrap, by contrast, deliberately refuses to overwrite an existing installation.

## Configuration

Edit `config.js` to change the presentation text, launch URL, slideshow timing, and media playlist.

The default launch URL starts yaPDP with a three-minute idle timeout and returns to the kiosk page:

```js
launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/"
```

Change the timeout as needed. The corresponding idle-timeout/redirect support must be present in the yaPDP version being deployed.

Put slideshow images and videos in `media/` and list them in the `media` array. See [media/README.md](media/README.md).

## Start and test manually

From the kiosk desktop session:

```bash
bash /opt/yapdp-exhibit/yaPDP-kiosk/start-kiosk.sh
```

Or test the server without starting Chrome:

```bash
curl -I http://127.0.0.1:8080/
curl -I http://127.0.0.1:8080/yapdp/pdp11.html
```

## Operational notes

- nginx binds to loopback only; the exhibit is not exposed to the museum LAN by this site.
- Both pages use the same origin, so normal browser navigation works without `file://` restrictions.
- yaPDP resources are served directly from the regular repository tree. Adding states, disk images, or other supported resources does not require rebuilding a bundle.
- Returning to the kiosk page after inactivity is navigation, not a factory reset. Define and test a separate visitor-session reset policy if each visitor must receive a pristine emulator state.
- Chrome kiosk mode is not a security boundary. The dedicated account is unprivileged, but automatic login means physical access to the computer grants access to its active session.
- The Windows launcher is intentionally not maintained; Ubuntu 24.04 is the supported deployment target.

## GitHub Pages

The repository can also be hosted as a static presentation page using GitHub Pages (main branch, repository root). The local nginx installer is only for the Ubuntu exhibit deployment.

## License

Add the license appropriate for your deployment before redistributing the project.
