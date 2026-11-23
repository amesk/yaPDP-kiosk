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
  // Language the kiosk starts in. "auto" follows the browser language.
  locale: "ru",
  fallbackLocale: "en",

  locales: {
    ru: {
      documentTitle: "yaPDP — интерактивный экспонат",
      title: "yaPDP",
      eyebrow: "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ",
      subtitle: "Мир PDP-11",
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
      onboardingIntro: "В yaPDP можно познакомиться с компьютером PDP-11.",
      onboardingSteps: "Нажмите на значок волшебной палочки 🪄 и выберите один из готовых сценариев или просто загрузите операционную систему.",
      onboardingTimerLabel: "До возврата к заставке",
      onboardingBack: "Назад к заставке",
      onboardingContinue: "Перейти к yaPDP",
    },
    en: {
      documentTitle: "yaPDP — interactive exhibit",
      title: "yaPDP",
      eyebrow: "INTERACTIVE EXHIBIT",
      subtitle: "Explore the world of PDP-11",
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
      onboardingIntro: "Explore the PDP-11 computer with yaPDP.",
      onboardingSteps: "Select the magic wand 🪄 in the toolbar, then choose a ready-made scenario or simply boot one of the operating systems.",
      onboardingTimerLabel: "Returning to the welcome screen in",
      onboardingBack: "Back to welcome screen",
      onboardingContinue: "Continue to yaPDP",
    },
  },

  // Keep this a single top-level line: install/ubuntu-24.04.sh rewrites it from
  // the IDLE_TIMEOUT and IDLE_REDIRECT installer settings.
  launchUrl: "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=/",
  slideInterval: 10000,
  videoDefaultDuration: 20000,
  transitionDuration: 900,
  media: [
    // { src: "media/intro.jpg", type: "image", duration: 10000, captions: { ru: "…", en: "…" } },
    // { src: "media/exhibit.mp4", type: "video", duration: 20000, captions: { ru: "…", en: "…" } }
    { src: "media/basic.png", type: "image", duration: 10000, captions: { ru: "История компьютеров #1", en: "A computer history story #1" } },
    { src: "media/bsd.png", type: "image", duration: 10000, captions: { ru: "История компьютеров #2", en: "A computer history story #2" } },
    { src: "media/lunar-lander.png", type: "image", duration: 10000, captions: { ru: "История компьютеров #3", en: "A computer history story #3" } },
  ]
};
