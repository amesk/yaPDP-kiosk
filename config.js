/*
 * Kiosk configuration.
 * Put images and videos in the media/ directory and list them below.
 * Supported media: .jpg, .jpeg, .png, .webp, .gif, .mp4, .webm, .ogv
 *
 * All visible text lives in `locales`. index.html carries the default Russian
 * wording, so a key missing from a dictionary falls back to that text instead
 * of an empty string.
 */

window.KIOSK_CONFIG = {
  locale: "ru",
  fallbackLocale: "en",

  locales: {
    ru: {
      documentTitle: "yaPDP — интерактивный экспонат",
      title: "yaPDP",
      eyebrow: "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ",
      subtitle: "Мир PDP-11/70",
      footerText: "Приятного знакомства с экспонатом",
      buttonText: "Запустить",
      buttonHint: "Коснитесь кнопки, чтобы начать",
      ariaStage: "Презентация экспоната",
      ariaStart: "Запустить экспонат",
      ariaLang: "Язык / Language",
      loadError: "Не удалось загрузить",
      launchMissing: "Укажите launchUrl в config.js",
      onboardingEyebrow: "ИНСТРУКЦИЯ ДЛЯ ПОСЕТИТЕЛЯ",
      onboardingTitle: "Как начать работу",
      onboardingIntro: "В yaPDP можно познакомиться с компьютером PDP-11/70.",
      onboardingSteps: "Нажмите на значок волшебной палочки 🪄 в правом верхнем углу экрана и выберите один из готовых сценариев или просто загрузите операционную систему.",
      onboardingTimerLabel: "До возврата к заставке",
      onboardingBack: "Назад к заставке",
      onboardingContinue: "Перейти к yaPDP",
    },
    en: {
      documentTitle: "yaPDP — interactive exhibit",
      title: "yaPDP",
      eyebrow: "INTERACTIVE EXHIBIT",
      subtitle: "Explore the world of PDP-11/70",
      footerText: "Please enjoy the exhibition",
      buttonText: "Press me to launch!",
      buttonHint: "Touch the button to begin",
      ariaStage: "Museum presentation",
      ariaStart: "Start the exhibit",
      ariaLang: "Language / Язык",
      loadError: "Unable to load",
      launchMissing: "Set launchUrl in config.js",
      onboardingEyebrow: "VISITOR GUIDE",
      onboardingTitle: "How to get started",
      onboardingIntro: "Explore the PDP-11/70 computer with yaPDP.",
      onboardingSteps: "Select the magic wand 🪄 in the upper right corner of the screen, then choose a ready-made scenario or simply boot one of the operating systems.",
      onboardingTimerLabel: "Returning to the welcome screen in",
      onboardingBack: "Back to welcome screen",
      onboardingContinue: "Continue to yaPDP",
    },
  },

  // Keep this a single top-level line: installer rewrites it.
  launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/",

  slideInterval: 10000,
  videoDefaultDuration: 20000,
  transitionDuration: 900,

  media: [
    {
      // 1. The PDP-11/70 as a complete machine.
      src: "media/01-pdp11-overview.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "PDP-11/70. Один из самых известных мини-компьютеров своей эпохи.",
        en: "PDP-11/70. One of the most iconic minicomputers of its era."
      }
    },
    {
      // 2. Front panel, switches and indicator lights.
      src: "media/02-pdp11-front-panel.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Передняя панель. Компьютер можно было видеть и контролировать на уровне аппаратуры.",
        en: "The front panel. The machine could be observed and controlled at the hardware level."
      }
    },
    {
      // 3. PDP-11 installed in a real computer room.
      src: "media/03-pdp11-computer-room.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Мини-компьютеры работали в лабораториях, университетах и на предприятиях.",
        en: "Minicomputers were used in laboratories, universities and industry."
      }
    },
    {
      // 4. An operator or engineer working with a PDP-11.
      src: "media/04-pdp11-operator.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "За каждым компьютером стояли люди, которые с ним работали.",
        en: "Behind every computer were the people who worked with it."
      }
    },
    {
      // 5. DEC VT100 terminal.
      src: "media/05-vt100-overview.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "VT100. Терминал, ставший одним из символов эпохи UNIX.",
        en: "VT100. A terminal that became an icon of the UNIX era."
      }
    },
    {
      // 6. VT100 in actual use, preferably with a person at the keyboard.
      src: "media/06-vt100-in-use.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Клавиатура, экран и командная строка. Так человек общался с компьютером.",
        en: "Keyboard, screen and command line. This was how people interacted with computers."
      }
    },
    {
      // 7. Complete Teletype Model 33 ASR.
      src: "media/07-teletype-asr33.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Teletype Model 33 ASR. Компьютерный диалог на бумаге.",
        en: "Teletype Model 33 ASR. A computer conversation on paper."
      }
    },
    {
      // 8. Paper tape reader/punch and printed output.
      src: "media/08-teletype-paper-tape.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Перфолента сохраняла программы и данные. Бумага была частью интерфейса.",
        en: "Paper tape stored programs and data. Paper was part of the interface."
      }
    },
    {
      // 9. A strong closing image: PDP-11 or a person at a terminal.
      src: "media/09-come-and-try.jpg",
      type: "image",
      duration: 15000,
      captions: {
        ru: "Теперь ваша очередь. Попробуйте поработать с PDP-11!",
        en: "Now it's your turn. Try working with a PDP-11!"
      }
    }
  ]
};
