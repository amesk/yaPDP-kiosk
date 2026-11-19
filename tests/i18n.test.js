"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const i18n = require("../js/i18n.js");

const CONFIG = {
  locale: "ru",
  fallbackLocale: "en",
  locales: {
    ru: { title: "yaPDP", buttonText: "Запустить", loadError: "Не удалось загрузить" },
    en: { title: "yaPDP", buttonText: "Press me to launch!", loadError: "Unable to load" }
  }
};

const DEFAULTS = {
  title: "Документ",
  eyebrow: "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ",
  buttonText: "Из разметки",
  buttonHint: "Коснитесь кнопки",
  documentTitle: "yaPDP — интерактивный экспонат",
  loadError: "",
  launchMissing: ""
};

test("resolveString prefers the active locale", () => {
  assert.equal(i18n.resolveString("en", CONFIG, DEFAULTS, "buttonText"), "Press me to launch!");
  assert.equal(i18n.resolveString("ru", CONFIG, DEFAULTS, "buttonText"), "Запустить");
});

test("resolveString falls back to fallbackLocale, then to index.html text", () => {
  // "eyebrow" exists only in index.html.
  assert.equal(i18n.resolveString("en", CONFIG, DEFAULTS, "eyebrow"), "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ");
  // Unknown key resolves to an empty string instead of throwing.
  assert.equal(i18n.resolveString("en", CONFIG, DEFAULTS, "missingKey"), "");
});

test("resolveString ignores blank dictionary values", () => {
  const config = { locales: { ru: { buttonText: "   " }, en: { buttonText: "Go" } }, fallbackLocale: "en" };
  assert.equal(i18n.resolveString("ru", config, {}, "buttonText"), "Go");
});

test("buildStrings returns every shell key", () => {
  const strings = i18n.buildStrings("en", CONFIG, DEFAULTS);
  for (const key of i18n.STRING_KEYS) {
    assert.equal(typeof strings[key], "string", key + " must resolve to a string");
  }
  assert.equal(strings.buttonText, "Press me to launch!");
  assert.match(strings.loadError, /Unable to load/);
});

test("resolveCaption supports per-locale captions and the legacy caption key", () => {
  const item = { captions: { ru: "История #1", en: "Story #1" } };
  assert.equal(i18n.resolveCaption(item, "ru", CONFIG), "История #1");
  assert.equal(i18n.resolveCaption(item, "en", CONFIG), "Story #1");
  assert.equal(i18n.resolveCaption({ caption: "Legacy" }, "en", CONFIG), "Legacy");
  assert.equal(i18n.resolveCaption({}, "en", CONFIG), "");
  assert.equal(i18n.resolveCaption(null, "en", CONFIG), "");
});

test("nextLocale cycles through available locales", () => {
  assert.equal(i18n.nextLocale("ru", ["ru", "en"]), "en");
  assert.equal(i18n.nextLocale("en", ["ru", "en"]), "ru");
  assert.equal(i18n.nextLocale("ru", []), "ru");
});

test("readLanguageParameter parses ?lang= and lang=", () => {
  assert.equal(i18n.readLanguageParameter("?lang=en"), "en");
  assert.equal(i18n.readLanguageParameter("?idle=1&lang=en-US"), "en-US");
  assert.equal(i18n.readLanguageParameter("lang=ru"), "ru");
  assert.equal(i18n.readLanguageParameter(""), "");
  assert.equal(i18n.readLanguageParameter(undefined), "");
});

test("detectInitialLocale: URL wins over everything", () => {
  assert.equal(
    i18n.detectInitialLocale(CONFIG, { search: "?lang=en", stored: "ru", languages: ["ru-RU"] }),
    "en"
  );
});

test("detectInitialLocale: stored choice beats config in the same tab", () => {
  assert.equal(
    i18n.detectInitialLocale(CONFIG, { search: "", stored: "en", languages: ["ru-RU"] }),
    "en"
  );
});

test("detectInitialLocale: config locale is the default for a new visitor", () => {
  assert.equal(
    i18n.detectInitialLocale(CONFIG, { search: "", stored: "", languages: ["en-US", "en"] }),
    "ru"
  );
});

test("detectInitialLocale: auto follows the browser language", () => {
  const config = { locale: "auto", fallbackLocale: "en", locales: { ru: {}, en: {} } };
  assert.equal(i18n.detectInitialLocale(config, { languages: ["en-GB"] }), "en");
  assert.equal(i18n.detectInitialLocale(config, { languages: ["ru-RU"] }), "ru");
  assert.equal(i18n.detectInitialLocale(config, { languages: ["de-DE"] }), "en");
});

test("detectInitialLocale: unknown stored or URL values are ignored", () => {
  assert.equal(i18n.detectInitialLocale(CONFIG, { search: "?lang=de", stored: "fr" }), "ru");
});

test("detectInitialLocale: legacy config without locales keeps working", () => {
  const legacy = { locale: "ru" };
  assert.equal(i18n.detectInitialLocale(legacy, { languages: ["en-US"] }), "ru");
  // Even without `locale`, a Russian default is returned for the kiosk shell.
  assert.equal(i18n.detectInitialLocale({}, {}), "ru");
});

test("availableLocales and fallbackLocale tolerate broken configuration", () => {
  assert.deepEqual(i18n.availableLocales({}), []);
  assert.deepEqual(i18n.availableLocales({ locales: null }), []);
  assert.deepEqual(i18n.availableLocales(CONFIG), ["ru", "en"]);
  assert.equal(i18n.fallbackLocale(CONFIG), "en");
  assert.equal(i18n.fallbackLocale({ locales: { ru: {} } }), "ru");
  assert.equal(i18n.fallbackLocale({}), "");
});
