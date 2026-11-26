# yaPDP-kiosk

A standalone presentation shell for museum and exhibition computers. It displays
a configurable slideshow and a prominent launch button, then navigates the same
browser window to the exhibit.

The deployment target is **Ubuntu 24.04 Desktop with GNOME/GDM, nginx, and
Google Chrome or Chromium**. The kiosk shell remains independent of yaPDP; nginx
serves both projects from the local filesystem.

## Quick install on a prepared Ubuntu 24.04 Desktop

Download and run the bootstrap script. It installs the official Google Chrome
Stable package when Chrome is absent:

```bash
wget -O - https://raw.githubusercontent.com/amesk/yaPDP-kiosk/master/instant-setup.sh | bash
```

Root privileges are acquired automatically, with or without `sudo` in front of
the command.

If you prefer not to launch potentially dangerous scripts from remote locations,
please, download `instant-setup.sh` locally and check it first.

The first-run wizard uses `dialog` to collect the two Git repository URLs, a Git
ref (branch, tag, or commit SHA) for each repository, the visitor inactivity
timeout, and the URL to return to when the timeout expires. It also asks whether
to install the optional yaPDP Plymouth boot splash; the default is **No**. The
defaults point to the official yaPDP repositories, use a three-minute timeout,
and return to the kiosk welcome page. The wizard installs the small `dialog`
package if it is not already present.

The same settings can be supplied through environment variables. This also
enables unattended installation:

```bash
sudo env NONINTERACTIVE=1 \
  YAPDP_REPO_URL=https://github.com/amesk/yaPDP.git \
  KIOSK_REPO_URL=https://github.com/amesk/yaPDP-kiosk.git \
  IDLE_TIMEOUT=180 \
  IDLE_REDIRECT=/ \
  INSTALL_PLYMOUTH=0 \
  bash ./instant-setup.sh
```

Supported variables are `YAPDP_REPO_URL`, `KIOSK_REPO_URL`, `IDLE_TIMEOUT`
(seconds; `0` disables automatic return), `IDLE_REDIRECT` (HTTP(S) URL or
relative URL), `INSTALL_PLYMOUTH` (`0` by default; set to `1` to install the
optional boot splash), `KIOSK_USER`, `YAPDP_REF`, and `KIOSK_REF`. The two refs
default to known-good commit SHAs for reproducible museum deployments; choose a
branch, tag, or commit SHA when deploying a fork or another revision.
Interactive values are prefilled from the environment/defaults. When running
interactively, environment values are shown as the dialog defaults and can be
edited. Set `NONINTERACTIVE=1` to skip all prompts.

The script is designed for a **fresh Ubuntu 24.04 Desktop installation**. It
refuses to overwrite an existing `/opt/yapdp-exhibit` directory and pins exact
commits of both repositories. It does not install the operating system,
partition disks, or configure firmware/BIOS settings. The bootstrap installs
Chrome Stable from Google's official download endpoint when needed; this
requires internet access and an amd64 machine.

The bootstrap:

1. Checks Ubuntu 24.04 Desktop and GDM.
2. Installs the official Google Chrome Stable `.deb` from Google if Chrome is
   not already installed, then verifies the executable and version. On amd64
   only.
3. Installs Git if needed.
4. Checks out the selected yaPDP and yaPDP-kiosk refs under
   `/opt/yapdp-exhibit/`.
5. Runs the kiosk installer.
6. If `INSTALL_PLYMOUTH=1` (or selected in the interactive wizard), installs the
   optional yaPDP Plymouth theme and rebuilds initramfs. If that optional step
   fails, the kiosk installation remains in place and the bootstrap prints
   instructions for retrying it later.

## What the installer configures

- Creates a dedicated unprivileged `yapdp-kiosk` account (override with
  `KIOSK_USER=name`).
- Refuses to use a kiosk account that belongs to the `sudo` group.
- Installs GNOME Kiosk and its script-session component.
- Creates the GNOME Kiosk user launcher at `~/.local/bin/gnome-kiosk-script`,
  which runs the existing supervised Chrome launcher.
- Selects the GNOME Kiosk Wayland session for the kiosk account and enables GDM
  automatic login.
- Removes the legacy desktop autostart entry; Chrome runs as the kiosk session's
  foreground application, not on top of a normal GNOME desktop.
- Installs/configures nginx on **127.0.0.1:8080** only.
- Keeps application files root-owned and readable by the kiosk account.

The kiosk account is not an administrator. Keep a separate administrator account
for maintenance. Automatic login is a physical-access convenience, not a
security boundary: anyone with access to the machine can use the active kiosk
session. Do not store secrets in the kiosk account.

The installer edits the `[daemon]` section of `/etc/gdm3/custom.conf` to set GDM
automatic login and configures the kiosk user's AccountsService session
preference to `gnome-kiosk-script-wayland`. Review these settings if the machine
already has a customized display-manager policy. The change takes effect after
reboot.

The kiosk account uses GNOME Kiosk Script Session rather than a normal GNOME
desktop. The session launches the user's `~/.local/bin/gnome-kiosk-script`; that
script starts the existing Chrome supervisor, which relaunches the browser if it
exits. Keep a separate administrator account for maintenance.

### Installer progress and logs

The interactive bootstrap keeps the terminal focused on the current installation
phase and an overall phase-based progress indicator. Package-manager, download,
and configuration output is suppressed from the live display rather than
discarded.

Each run writes its complete stdout/stderr diagnostics to a timestamped log
under `/var/log/yapdp-kiosk/`. The bootstrap and nested Ubuntu installer share
the same log. If setup fails, the error screen reports the log path; in
noninteractive mode the same diagnostics are retained without opening a dialog.
The percentage represents completed installation phases, not a fabricated
byte-level estimate of apt/dpkg work.

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

Use a normal yaPDP checkout/release. No FS Bundle, generated resource archive,
Node.js runtime, or changes to yaPDP are required for this deployment.

## Manual install / reconfiguration

If both repositories are already placed side by side in the layout above, run:

```bash
cd /opt/yapdp-exhibit/yaPDP-kiosk
sudo bash ./install/ubuntu-24.04.sh
```

The installer can be run again to reconfigure nginx and GDM. It does not
overwrite the repository tree. The first-run bootstrap, by contrast,
deliberately refuses to overwrite an existing installation.

## Configuration

Edit `config.js` to change the presentation text, the default language, the
launch URL, slideshow timing, and the media playlist.

The installer generates `config.js`'s `launchUrl` from `IDLE_TIMEOUT` and
`IDLE_REDIRECT`. When a visitor presses the attract screen's Start button, the
kiosk first shows its own bilingual museum onboarding dialog. It explains the
yaPDP magic-wand menu and the choice between a prepared scenario and booting an
operating system directly. The dialog countdown uses the same timeout and return
URL; continuing opens yaPDP with `onboarding=skip`, so the emulator's own
first-run hint does not duplicate the museum instructions. The default is a
three-minute timeout and a return to the kiosk welcome page. The redirect may be
a relative URL (for example `/` or `/attract.html`) or an absolute HTTP(S) URL
on another site. Set `IDLE_TIMEOUT=0` to disable the automatic hand-off; in that
case yaPDP opens without idle parameters.

The installer updates only the `launchUrl` setting and preserves the rest of the
presentation configuration. The deployed yaPDP revision must include the
idle-timeout/redirect support. The kiosk launcher also disables GNOME's idle
screen blanking and automatic screen lock for the dedicated kiosk account, so
the exhibit does not fall back to a password prompt during operation. These
settings are applied in the kiosk user's graphical session; the administrator's
desktop settings are not changed.

Put slideshow images and videos in `media/` and list them in the `media` array.
See [media/README.md](media/README.md).

### Language and visible text

The kiosk is bilingual out of the box: Russian is the default language and an
**RU | EN** switch sits in the top-right corner. All visible wording is stored
in `config.js`:

| Key | Meaning |
| --- | --- |
| `locale` | Language the kiosk starts in: `"ru"` (default), `"en"`, or `"auto"` to follow the browser language |
| `fallbackLocale` | Language used when a key is missing from the active dictionary |
| `locales.ru`, `locales.en` | Text dictionaries: `documentTitle`, `title`, `eyebrow`, `subtitle`, `buttonText`, `buttonHint`, `footerText`, `ariaStage`, `ariaStart`, `ariaLang`, `loadError`, `launchMissing` |
| `media[].captions` | Per-language slide caption, for example `{ ru: "…", en: "…" }`; the legacy `caption` key still works |

A string resolves in this order: `locales[locale]` → `locales[fallbackLocale]` →
the wording in `index.html` → internal default. `index.html` therefore doubles
as the Russian reference text: a missing translation degrades to Russian instead
of an empty screen.

Behaviour worth knowing:

- The switch is hidden when `locales` defines fewer than two languages, so a
  single-language deployment shows no extra control.
- Switching the language rewrites text only. The current slide, its progress
  bar, and any running video continue undisturbed.
- The visitor's choice is kept in `sessionStorage` (`yapdp.kiosk.lang`), so it
  survives the hand-off to yaPDP and the return to the welcome page, but a
  browser restart resets it to `locale` and the next visitor sees the default
  language.
- `?lang=en` appended to `KIOSK_URL` in `start-kiosk.sh` pins one machine to
  English regardless of the stored choice; `locale: "auto"` follows the browser
  language instead.
- The browser's own translation UI is disabled, because the page is Russian
  while the Chrome profile is English and Chrome would otherwise offer to
  translate the exhibit. `start-kiosk.sh` passes
  `--disable-features=Translate,TranslateUI`, and `index.html` declares
  `translate="no"` together with `<meta name="google" content="notranslate">`. A
  machine managed by other means should instead set the Chrome policy
  `TranslateEnabled` to `false`.

The earlier flat keys (`title`, `eyebrow`, `subtitle`, `buttonText`,
`buttonHint`, `footerText`) moved into `locales`. A configuration that still
uses them keeps working: the runtime falls back to the wording in `index.html`,
so an exhibit updated in place shows Russian defaults instead of breaking.

### Updating an already installed kiosk

`instant-setup.sh` defaults to `KIOSK_REF=master`, so a fresh installation picks
up the current revision automatically. For an exhibit that is already running:

```bash
sudo git -C /opt/yapdp-exhibit/yaPDP-kiosk pull --ff-only
```

Then restart Chrome (or reboot the machine) to load the new files. Notes:

- No installer re-run is required for presentation changes: nginx already serves
  the repository directory, and `install/ubuntu-24.04.sh` was not modified by
  this change.
- `css/kiosk.css`, `js/i18n.js`, and `js/app.js` are requested with a `?v=`
  suffix. Bump that suffix in `index.html` whenever one of those files changes,
  otherwise the kiosk browser may keep using the cached copy.
- `config.js` is tracked by Git. Edits made directly on the exhibit machine will
  conflict with `git pull --ff-only`; re-apply them after the update or keep
  local values out of the tracked file until the planned `config.local.js`
  overlay lands.
- The localization resolver has unit tests: `node --test tests` (Node.js is
  needed on the developer machine only, never on the kiosk).

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

- nginx binds to loopback only; the exhibit is not exposed to the museum LAN by
  this site.
- Both pages use the same origin, so normal browser navigation works without
  `file://` restrictions.
- yaPDP resources are served directly from the regular repository tree. Adding
  states, disk images, or other supported resources does not require rebuilding
  a bundle.
- Returning to the kiosk page after inactivity is navigation, not a factory
  reset. Define and test a separate visitor-session reset policy if each visitor
  must receive a pristine emulator state.
- GNOME Kiosk limits the visitor session to the configured application instead
  of exposing a normal desktop. It is an application-containment measure, not a
  complete security boundary: physical access may still allow attempts to bypass
  it. The dedicated account is unprivileged; keep a separate administrator
  account for maintenance.
- The Windows launcher is intentionally not maintained; Ubuntu 24.04 is the
  supported deployment target.

### GRUB-protected local service mode

The GRUB menu contains exactly two managed entries:

- **Load yaPDP-kiosk** — unrestricted and selected by default.
- **Enter service mode** — requires the separate GRUB password.

The menu is displayed for five seconds. If no selection is made, the kiosk
starts automatically. The service entry boots the same Ubuntu installation
with `yapdp.service_mode=1`; it does not change the persistent GRUB default
and does not set a service mode for the next boot.

Before GDM starts, a small boot-mode hook reads the kernel command line:

- On a normal boot it enables GDM automatic login to the dedicated GNOME Kiosk
  account.
- On a service-mode boot it disables automatic login, leaving the standard
  Ubuntu GDM greeter. Staff sign in with their separate Ubuntu administrator
  account and receive the normal Ubuntu desktop.
- On the next reboot the service-mode kernel parameter is absent, so GDM
  restores kiosk automatic login. No manual mode reset is required.

The service boot does not start the F1-F12 keyboard filter or the kiosk-session
VT lock. The public kiosk session starts the filter and locks VT switching
after GNOME Kiosk has acquired its graphical VT. F1-F12 are suppressed before
they reach Chrome; ordinary keys are forwarded through a uinput keyboard.

The installer generates a separate random GRUB password for the GRUB user
`kiosk-admin`. GRUB may ask for the username and password when staff select
the protected entry. The credentials are shown at the end of interactive
installation and the password is stored root-only at
`/root/yapdp-kiosk-grub-password.txt`. Only its PBKDF2 hash is written into
the GRUB configuration. Retrieve the password locally with:

```bash
sudo cat /root/yapdp-kiosk-grub-password.txt
```

GRUB authentication protects the service entry, editing menu entries, and the
GRUB command line. The normal kiosk entry remains available without a
password. The installer suppresses stock Ubuntu kernel/recovery and firmware
menu generators so the visible menu contains only the two managed entries.
A small early GRUB generator hook reapplies that suppression whenever
`update-grub` runs, including after kernel package updates.
The current kernel is loaded through Ubuntu's `/vmlinuz` and `/initrd.img`
symlinks, which are updated when kernel packages change.

The keyboard filter requires `python3-evdev` and the Linux `uinput` module.
Its logs are available with:

```bash
journalctl -u yapdp-kiosk-guard.service
systemctl status yapdp-kiosk-guard.service
```

The installer also applies defence-in-depth settings:

- `kernel.sysrq = 0` disables Magic SysRq.
- `ctrl-alt-del.target` is masked.
- logind ignores power, reboot, suspend, and hibernate keys. A long hardware
  power-button hold remains a firmware-level power-off path.
- `NAutoVTs=0` and `ReserveVT=0` prevent automatic spare gettys.

This does not protect firmware setup, booting from external media, or physical
disk access. Set a BIOS/UEFI administrator password, disable external boot
where appropriate, and secure the chassis.

## GitHub Pages

The repository can also be hosted as a static presentation page using GitHub
Pages (main branch, repository root). The local nginx installer is only for the
Ubuntu exhibit deployment.

## License

Add the license appropriate for your deployment before redistributing the project.

## Plymouth boot splash

The repository includes an optional PDP-11/70-inspired Plymouth theme for the
Ubuntu 24.04 exhibit computer. The first-run bootstrap asks whether to install
it (default: No); unattended deployments can opt in with `INSTALL_PLYMOUTH=1`.
The theme is installed after the kiosk setup because selecting it changes the
system boot theme and rebuilds initramfs. If omitted, the normal Ubuntu boot
theme remains selected. The theme can also be installed later without
reinstalling the kiosk.

See [plymouth/README.md](plymouth/README.md). Install with `sudo bash
plymouth/install.sh` after testing on the target machine; rollback with `sudo
bash plymouth/uninstall.sh`.
