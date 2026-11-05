# yaPDP-kiosk

A standalone, configurable full-screen presentation shell for museum and exhibition computers.

It runs in Chrome Kiosk Mode, rotates through local images and videos, and displays a prominent **Press me to launch!** button. Touching the button navigates the same browser window to the configured exhibit URL.

The kiosk shell is deliberately independent of yaPDP and can be reused for other exhibits.

## Quick start (Windows)

1. Install Google Chrome.
2. Put images and videos in `media/`.
3. Edit `config.js`: set `launchUrl` and the `media` playlist.
4. Double-click `start-kiosk.bat`.

The batch file launches Chrome with `--kiosk` and a dedicated browser profile in `chrome-profile/`. Press `Alt+F4` to exit. Chrome Kiosk Mode hides browser controls; it is not a security boundary. For a public installation, also configure Windows Assigned Access or an equivalent locked-down account.

## Configuration

Edit `config.js`:

```js
window.KIOSK_CONFIG = {
  title: "yaPDP",
  eyebrow: "INTERACTIVE EXHIBIT",
  subtitle: "Explore the world of PDP-11",
  footerText: "Please enjoy the exhibition",
  buttonText: "Press me to launch!",
  buttonHint: "Touch the button to begin",
  launchUrl: "https://amesk.github.io/yaPDP/",
  slideInterval: 10000,
  videoDefaultDuration: 20000,
  transitionDuration: 900,
  media: [
    { src: "media/intro.jpg", type: "image", duration: 10000, caption: "The exhibition" },
    { src: "media/demo.mp4", type: "video", duration: 20000, caption: "PDP-11 in action" }
  ]
};
```

Durations are in milliseconds. The `type` field is optional: `.mp4`, `.webm` and `.ogv` files are detected as video automatically. Videos are muted and loop until their configured duration expires. With an empty playlist, the page shows its background and launch button.

## GitHub Pages

This is a static site. Enable GitHub Pages in repository settings using the `main` branch and `/ (root)` to host it online.

## Media tips

- Prefer 16:9 images at or above the display's native resolution.
- Use H.264 MP4 for broad browser compatibility.
- Keep files reasonably sized to reduce initial loading time.
- Test playback on the actual kiosk computer.

See [media/README.md](media/README.md) for playlist examples.

## Project layout

```text
index.html
config.js
css/kiosk.css
js/app.js
media/
start-kiosk.bat
README.md
```

## License

Add the license appropriate for your deployment before redistributing the project.
