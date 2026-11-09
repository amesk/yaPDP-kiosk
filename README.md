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

The first-run wizard uses `dialog` to collect the two Git repository URLs, the visitor inactivity timeout, and the URL to return to when the timeout expires. It also asks whether to install the optional yaPDP Plymouth boot splash; the default is **No**. The defaults point to the official yaPDP repositories, use a three-minute timeout, and return to the kiosk welcome page. The wizard installs the small `dialog` package if it is not already present.

The same settings can be supplied through environment variables. This also enables unattended installation:

```bash
sudo env NONINTERACTIVE=1 \
  YAPDP_REPO_URL=https://github.com/amesk/yaPDP.git \
  KIOSK_REPO_URL=https://github.com/amesk/yaPDP-kiosk.git \
  IDLE_TIMEOUT=180 \
  IDLE_REDIRECT=/ \
  bash ./instant-setup.sh
```

Supported variables are `YAPDP_REPO_URL`, `KIOSK_REPO_URL`, `IDLE_TIMEOUT` (seconds; `0` disables automatic return), `IDLE_REDIRECT` (HTTP(S) URL or relative URL), `INSTALL_PLYMOUTH` (`0` by default; set to `1` to install the optional boot splash), `KIOSK_USER`, `YAPDP_REF`, and `KIOSK_REF`. The two refs remain pinned to known-good commits by default; override them when deploying a fork or another repository that does not contain those commits. When running interactively, environment values are shown as the dialog defaults and can be edited. Set `NONINTERACTIVE=1` to skip all prompts.

The script is designed for a **fresh Ubuntu 24.04 Desktop installation**. It refuses to overwrite an existing `/opt/yapdp-exhibit` directory and pins exact commits of both repositories. It does not install the operating system, partition disks, or configure firmware/BIOS settings. The bootstrap installs Chrome Stable from Google's official download endpoint when needed; this requires internet access and an amd64 machine.

The bootstrap:
1. Checks Ubuntu 24.04 Desktop and GDM.
2. Installs the official Google Chrome Stable `.deb` from Google if Chrome is not already installed, then verifies the executable and version. On amd64 only.
3. Installs Git if needed.
4. Checks out the pinned yaPDP and yaPDP-kiosk revisions under `/opt/yapdp-exhibit/`.
5. Runs the kiosk installer.\n6. If `INSTALL_PLYMOUTH=1` (or selected in the interactive wizard), installs the optional yaPDP Plymouth theme and rebuilds initramfs. If that optional step fails, the kiosk installation remains in place and the bootstrap prints instructions for retrying it later.

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

The installer generates `config.js`'s `launchUrl` from `IDLE_TIMEOUT` and `IDLE_REDIRECT`. The default is a three-minute timeout and a return to the kiosk welcome page. The redirect may be a relative URL (for example `/` or `/attract.html`) or an absolute HTTP(S) URL on another site. Set `IDLE_TIMEOUT=0` to disable the automatic hand-off; in that case yaPDP opens without idle parameters.

The installer updates only the `launchUrl` setting and preserves the rest of the presentation configuration. The deployed yaPDP revision must include the idle-timeout/redirect support. The kiosk launcher also disables GNOME's idle screen blanking and automatic screen lock for the dedicated kiosk account, so the exhibit does not fall back to a password prompt during operation. These settings are applied in the kiosk user's graphical session; the administrator's desktop settings are not changed.

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


## Plymouth boot splash

The repository includes an optional PDP-11/70-inspired Plymouth theme for the Ubuntu 24.04 exhibit computer. The first-run bootstrap asks whether to install it (default: No); unattended deployments can opt in with `INSTALL_PLYMOUTH=1`. The theme is installed after the kiosk setup because selecting it changes the system boot theme and rebuilds initramfs. If omitted, the normal Ubuntu boot theme remains selected. The theme can also be installed later without reinstalling the kiosk.

See [plymouth/README.md](plymouth/README.md). Install with `sudo bash plymouth/install.sh` after testing on the target machine; rollback with `sudo bash plymouth/uninstall.sh`.
