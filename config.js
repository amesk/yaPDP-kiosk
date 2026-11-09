/*
 * Kiosk configuration.
 * Put images and videos in the media/ directory and list them below.
 * Supported media: .jpg, .jpeg, .png, .webp, .gif, .mp4, .webm, .ogv
 */
window.KIOSK_CONFIG = {
  title: "yaPDP",
  eyebrow: "INTERACTIVE EXHIBIT",
  subtitle: "Explore the world of PDP-11",
  footerText: "Please enjoy the exhibition",
  buttonText: "Press me to launch!",
  buttonHint: "Touch the button to begin",
  launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/",
  slideInterval: 10000,
  videoDefaultDuration: 20000,
  transitionDuration: 900,
  media: [
    // { src: "media/intro.jpg", type: "image", duration: 10000, caption: "A computer history story" },
    // { src: "media/exhibit.mp4", type: "video", duration: 20000, caption: "See the machine in action" }
    { src: "media/basic.png", type: "image", duration: 10000, caption: "A computer history story #1" },
    { src: "media/bsd.png", type: "image", duration: 10000, caption: "A computer history story #2" },
    { src: "media/lunar-lander.png", type: "image", duration: 10000, caption: "A computer history story#3" },
  ]
};
