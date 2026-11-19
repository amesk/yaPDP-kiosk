# Kiosk media

Put slideshow images and video files in this directory and list them in the
repository-root `config.js`.

The default museum playlist is composed for a **1920×1080 (Full HD), 16:9**
display. The three opening slides use original vector artwork authored for the
kiosk, so they remain sharp at Full HD and do not depend on an external server:

- `pdp11-system.svg` — PDP-11/70 cabinet and terminal
- `front-panel.svg` — console lights and switches
- `teletype.svg` — Teletype Model 33 ASR and paper tape

The sequence continues with the existing yaPDP screenshots:

- `basic.png` — BASIC
- `bsd.png` — 2.11 BSD
- `lunar-lander.png` — Lunar Lander

Each playlist item has Russian and English captions in `config.js`. The language
switch changes the caption without restarting the current slide.

Supported image formats: JPG, PNG, WebP, GIF, SVG.
Supported video formats: MP4 (H.264 recommended), WebM, OGV.

For reliable kiosk playback, encode video as H.264/AAC MP4, keep it muted (the
player is muted by default), and test it on the actual exhibit computer.

The SVG artwork is illustrative, not a documentary photograph or a
pixel-accurate reconstruction of DEC hardware. It is intentionally self-hosted
to keep the attract presentation available without an Internet connection.
