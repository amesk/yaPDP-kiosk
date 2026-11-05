# Kiosk media

Put your slideshow images and video files in this directory.

Then add each file to the `media` array in the repository-root `config.js`.

Example:

```js
media: [
  { src: "media/museum-overview.jpg", type: "image", duration: 10000, caption: "The exhibition" },
  { src: "media/pdp11-demo.mp4", type: "video", duration: 25000, caption: "PDP-11 in action" }
]
```

Supported image formats: JPG, PNG, WebP, GIF.
Supported video formats: MP4 (H.264 recommended), WebM, OGV.

For reliable kiosk playback, encode video as H.264/AAC MP4, keep it muted (the player is muted by default), and test it on the actual exhibit computer.
