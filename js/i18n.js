/*
 * Localization helpers for the kiosk shell.
 *
 * These functions are deliberately free of DOM and browser API access so the
 * resolution rules can be unit-tested with `node --test tests/`.
 */
(function (root) {
  "use strict";

  // Strings the kiosk shell writes into index.html.
  const STRING_KEYS = [
    "documentTitle",
    "title",
    "eyebrow",
    "subtitle",
    "footerText",
    "buttonText",
    "buttonHint",
    "ariaStage",
    "ariaStart",
    "ariaLang",
    "loadError",
    "launchMissing",
    "onboardingEyebrow",
    "onboardingTitle",
    "onboardingIntro",
    "onboardingSteps",
    "onboardingTimerLabel",
    "onboardingBack",
    "onboardingContinue"
  ];

  // Last-resort strings. index.html carries the same Russian wording, so these
  // are only used when a DOM node is missing or a value resolves to nothing.
  const BUILTIN_DEFAULTS = {
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
    onboardingContinue: "Перейти к yaPDP"
  };

  function isText(value) {
    return typeof value === "string" && value.trim() !== "";
  }

  function lookup(dict, key) {
    if (!dict || typeof dict !== "object") return "";
    return isText(dict[key]) ? dict[key] : "";
  }

  function availableLocales(config) {
    const locales = config && config.locales;
    if (!locales || typeof locales !== "object") return [];
    return Object.keys(locales).filter(isText);
  }

  function fallbackLocale(config, available) {
    const list = Array.isArray(available) ? available : availableLocales(config);
    const requested = config && config.fallbackLocale;
    if (isText(requested) && list.indexOf(requested) !== -1) return requested;
    if (list.indexOf("en") !== -1) return "en";
    return list.length ? list[0] : "";
  }

  function resolveString(locale, config, defaults, key) {
    const locales = (config && config.locales) || {};
    const order = [locale, fallbackLocale(config)];
    for (let i = 0; i < order.length; i += 1) {
      const value = lookup(locales[order[i]], key);
      if (value) return value;
    }
    if (defaults && isText(defaults[key])) return defaults[key];
    return BUILTIN_DEFAULTS[key] || "";
  }

  function buildStrings(locale, config, defaults) {
    const strings = {};
    for (let i = 0; i < STRING_KEYS.length; i += 1) {
      strings[STRING_KEYS[i]] = resolveString(locale, config, defaults, STRING_KEYS[i]);
    }
    return strings;
  }

  function resolveCaption(item, locale, config) {
    if (!item || typeof item !== "object") return "";
    const captions = item.captions;
    if (captions && typeof captions === "object") {
      const order = [locale, fallbackLocale(config)];
      for (let i = 0; i < order.length; i += 1) {
        const value = lookup(captions, order[i]);
        if (value) return value;
      }
    }
    return isText(item.caption) ? item.caption : "";
  }

  function nextLocale(locale, available) {
    const list = Array.isArray(available) ? available : [];
    if (!list.length) return locale;
    const index = list.indexOf(locale);
    return list[(index + 1) % list.length];
  }

  function normalizeTag(tag) {
    return String(tag || "").toLowerCase().replace("_", "-").split("-")[0];
  }

  function findAvailable(code, available) {
    if (!isText(code)) return "";
    const list = Array.isArray(available) ? available : [];
    for (let i = 0; i < list.length; i += 1) {
      if (normalizeTag(list[i]) === normalizeTag(code)) return list[i];
    }
    return "";
  }

  function matchLanguages(languages, available) {
    const wanted = Array.isArray(languages) ? languages : [];
    for (let i = 0; i < wanted.length; i += 1) {
      const match = findAvailable(wanted[i], available);
      if (match) return match;
    }
    return "";
  }

  function readLanguageParameter(search) {
    const query = typeof search === "string" ? search : "";
    const match = /(?:^|[?&])lang=([^&#]*)/.exec(query);
    if (!match) return "";
    try {
      return decodeURIComponent(match[1]);
    } catch (error) {
      return match[1];
    }
  }

  function detectInitialLocale(config, context) {
    const available = availableLocales(config);
    const ctx = context || {};
    const preferred = isText(config && config.locale) ? config.locale : "";

    // An explicit ?lang= in the kiosk URL pins one machine to one language.
    const fromUrl = findAvailable(readLanguageParameter(ctx.search), available);
    if (fromUrl) return fromUrl;

    // The visitor's last choice survives navigation to the exhibit and back,
    // but not a browser restart, so the next visitor starts in config.locale.
    const fromStorage = findAvailable(ctx.stored, available);
    if (fromStorage) return fromStorage;

    if (preferred && preferred !== "auto") {
      // index.html is authored in this language, so honour it even when the
      // configuration ships no translation dictionaries at all.
      if (!available.length || findAvailable(preferred, available)) return preferred;
    }

    const fromBrowser = matchLanguages(ctx.languages, available);
    if (fromBrowser) return fromBrowser;

    const fallback = fallbackLocale(config, available);
    if (fallback) return fallback;

    return preferred && preferred !== "auto" ? preferred : "ru";
  }

  const api = {
    STRING_KEYS: STRING_KEYS,
    BUILTIN_DEFAULTS: BUILTIN_DEFAULTS,
    availableLocales: availableLocales,
    fallbackLocale: fallbackLocale,
    resolveString: resolveString,
    buildStrings: buildStrings,
    resolveCaption: resolveCaption,
    nextLocale: nextLocale,
    matchLanguages: matchLanguages,
    readLanguageParameter: readLanguageParameter,
    detectInitialLocale: detectInitialLocale
  };

  root.KioskI18n = api;
  if (typeof module === "object" && module.exports) module.exports = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
