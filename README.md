# yaPDP-kiosk

A standalone presentation shell for museum and exhibition computers. It displays a configurable slideshow and a prominent launch button, then navigates the same browser window to the exhibit.

The deployment target is **Ubuntu 24.04 with nginx and Google Chrome**. The kiosk shell remains independent of yaPDP; nginx serves both projects from the local filesystem.

## Deployment layout

Place the two repositories side by side:

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

## Install

1. Install Google Chrome on Ubuntu 24.04.
2. Place the yaPDP and yaPDP-kiosk directories in the layout above.
3. Run the installer:

   ```bash
   cd /opt/yapdp-exhibit/yaPDP-kiosk
   sudo bash ./install/ubuntu-24.04.sh
   ```

The installer installs nginx if necessary, configures a site listening **only on 127.0.0.1:8080**, enables nginx, and creates a desktop-session autostart entry for Chrome kiosk mode.

It does not configure desktop auto-login, lock down the desktop session, install Chrome, or modify power-management settings. Configure those OS-level policies for the dedicated kiosk account as part of preparing the exhibit computer.

After installation, the local pages are:

- Kiosk presentation: http://127.0.0.1:8080/
- yaPDP: http://127.0.0.1:8080/yapdp/pdp11.html

The installer can be run again after changing the paths or nginx configuration. It validates the nginx configuration before reloading the service.

## Configuration

Edit `config.js` to change the presentation text, launch URL, slideshow timing, and media playlist.

The default launch URL starts yaPDP with a three-minute idle timeout and returns to the kiosk page:

```js
launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/"
```

Change the timeout as needed. The corresponding idle-timeout/redirect support must be present in the yaPDP version being deployed.

Put slideshow images and videos in `media/` and list them in the `media` array. See [media/README.md](media/README.md).

## Start and test manually

From a graphical desktop session:

```bash
bash ./start-kiosk.sh
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
- Chrome kiosk mode is not a security boundary. Use a dedicated restricted desktop account and configure automatic login and recovery at the OS level.
- The Windows launcher is intentionally not maintained; Ubuntu 24.04 is the supported deployment target.

## GitHub Pages

The repository can also be hosted as a static presentation page using GitHub Pages (main branch, repository root). The local nginx installer is only for the Ubuntu exhibit deployment.

## License

Add the license appropriate for your deployment before redistributing the project.
