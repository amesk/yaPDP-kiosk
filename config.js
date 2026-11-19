/*
 * Kiosk configuration.
 * Put images and videos in the media/ directory and list them below.
 * Supported media: .jpg, .jpeg, .png, .webp, .gif, .svg, .mp4, .webm, .ogv
 *
 * All visible text lives in `locales`. index.html carries the default Russian
 * wording, so a key missing from a dictionary falls back to that text instead
 * of an empty string.
 */
window.KIOSK_CONFIG = {
  // Language the kiosk starts in. "auto" follows the browser language.
  locale: "ru",
  fallbackLocale: "en",

  locales: {
    ru: {
      documentTitle: "yaPDP — интерактивный экспонат",
      title: "yaPDP",
      eyebrow: "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ",
      subtitle: "Откройте для себя мир PDP-11",
      footerText: "История вычислительной техники — в ваших руках",
      buttonText: "Запустить PDP-11",
      buttonHint: "Коснитесь кнопки, чтобы начать",
      ariaStage: "Презентация экспоната",
      ariaStart: "Запустить экспонат",
      ariaLang: "Язык / Language",
      loadError: "Не удалось загрузить",
      launchMissing: "Укажите launchUrl в config.js",
    },
    en: {
      documentTitle: "yaPDP — interactive exhibit",
      title: "yaPDP",
      eyebrow: "INTERACTIVE EXHIBIT",
      subtitle: "Discover the world of the PDP-11",
      footerText: "Computing history — at your fingertips",
      buttonText: "Launch the PDP-11",
      buttonHint: "Touch the button to begin",
      ariaStage: "Exhibit presentation",
      ariaStart: "Launch the exhibit",
      ariaLang: "Language / Язык",
      loadError: "Unable to load",
      launchMissing: "Set launchUrl in config.js",
    },
  },

  // Keep this a single top-level line: install/ubuntu-24.04.sh rewrites it from
  // the IDLE_TIMEOUT and IDLE_REDIRECT installer settings.
  launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/",
  slideInterval: 9000,
  videoDefaultDuration: 20000,
  transitionDuration: 900,

  // 1920x1080 widescreen sequence. The SVG artwork is authored for this
  // composition and scales cleanly to the museum's Full HD display.
  media: [
    {
      src: "media/pdp11-system.svg",
      type: "image",
      duration: 9000,
      captions: {
        ru: "PDP-11/70 — легендарный 16-разрядный компьютер DEC",
        en: "PDP-11/70 — DEC's legendary 16-bit computer"
      }
    },
    {
      src: "media/front-panel.svg",
      type: "image",
      duration: 9000,
      captions: {
        ru: "Лампочки и тумблеры. Управляйте машиной напрямую",
        en: "Lights and switches. Take direct control of the machine"
      }
    },
    {
      src: "media/teletype.svg",
      type: "image",
      duration: 9000,
      captions: {
        ru: "Teletype Model 33 ASR — клавиатура, принтер и бумажная лента",
        en: "Teletype Model 33 ASR — keyboard, printer and paper tape"
      }
    },
    {
      src: "media/basic.png",
      type: "image",
      duration: 9000,
      captions: {
        ru: "Напишите программу на BASIC и запустите её на PDP-11",
        en: "Write a BASIC program and run it on the PDP-11"
      }
    },
    {
      src: "media/bsd.png",
      type: "image",
      duration: 9000,
      captions: {
        ru: "2.11 BSD — UNIX-система на PDP-11",
        en: "2.11 BSD — a UNIX system running on the PDP-11"
      }
    },
    {
      src: "media/lunar-lander.png",
      type: "image",
      duration: 9000,
      captions: {
        ru: "Lunar Lander — сыграйте в классику ранних компьютерных игр",
        en: "Lunar Lander — play a classic of early computer gaming"
      }
    }
  ]
};
