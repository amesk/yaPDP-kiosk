"use strict";

/*
 * Smoke test for js/app.js: runs the real shell script against a minimal DOM
 * stub to prove that localization applies, that the RU | EN switch only swaps
 * text, and that no DOM node is required to be non-null.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(ROOT, file), "utf8");

function createNode(id, kind, text) {
  const node = {
    id: id,
    kind: kind,
    textContent: text || "",
    hidden: false,
    attributes: Object.create(null),
    classes: new Set(),
    handlers: Object.create(null),
    children: [],
    src: "",
    currentTime: 0,
    readyState: 0,
    style: { width: "", setProperty() {} },
    classList: {
      add: (name) => node.classes.add(name),
      remove: (name) => node.classes.delete(name),
      toggle: (name, on) => (on ? node.classes.add(name) : node.classes.delete(name)),
      contains: (name) => node.classes.has(name)
    },
    setAttribute(name, value) {
      node.attributes[name] = String(value);
    },
    getAttribute(name) {
      return name in node.attributes ? node.attributes[name] : null;
    },
    removeAttribute(name) {
      delete node.attributes[name];
    },
    addEventListener(type, handler) {
      (node.handlers[type] = node.handlers[type] || []).push(handler);
    },
    querySelectorAll(selector) {
      return selector === "[data-lang]" ? node.children : [];
    },
    pause() {},
    load() {},
    play() {
      return Promise.resolve();
    },
    focus() {}
  };
  return node;
}

function createShell(defaults) {
  const nodes = {
    stage: createNode("stage", "div"),
    fallback: createNode("fallback", "div"),
    image: createNode("image", "img"),
    video: createNode("video", "video"),
    caption: createNode("caption", "div"),
    progress: createNode("progress", "span"),
    title: createNode("title", "h1", defaults.title),
    eyebrow: createNode("eyebrow", "div", defaults.eyebrow),
    subtitle: createNode("subtitle", "p", defaults.subtitle),
    footerText: createNode("footerText", "span", defaults.footerText),
    buttonText: createNode("buttonText", "span", defaults.buttonText),
    hint: createNode("hint", "p", defaults.buttonHint),
    launch: createNode("launch", "button")
  };
  nodes.stage.setAttribute("aria-label", defaults.ariaStage);
  nodes.launch.setAttribute("aria-label", defaults.ariaStart);

  const toggle = createNode("langToggle", "button");
  toggle.setAttribute("aria-label", defaults.ariaLang);
  const ru = createNode("", "span", "RU");
  ru.setAttribute("data-lang", "ru");
  const en = createNode("", "span", "EN");
  en.setAttribute("data-lang", "en");
  toggle.children = [ru, en];
  nodes.langToggle = toggle;
  return nodes;
}

const DEFAULTS = {
  title: "yaPDP",
  eyebrow: "ИНТЕРАКТИВНЫЙ ЭКСПОНАТ",
  subtitle: "Мир PDP-11",
  footerText: "Приятного знакомства с экспонатом",
  buttonText: "Запустить",
  buttonHint: "Коснитесь кнопки, чтобы начать",
  ariaStage: "Презентация экспоната",
  ariaStart: "Запустить экспонат",
  ariaLang: "Язык / Language"
};

function boot(options) {
  const settings = options || {};
  const nodes = createShell(DEFAULTS);
  const store = new Map();
  if (settings.stored) store.set("yapdp.kiosk.lang", settings.stored);

  const document = {
    title: "yaPDP — интерактивный экспонат",
    hidden: false,
    documentElement: { lang: "", style: { setProperty() {} } },
    getElementById: (id) => nodes[id] || null,
    addEventListener() {}
  };

  const sandbox = {
    console: { log() {}, warn() {}, error() {} },
    document: document,
    navigator: { languages: settings.languages || ["en-US", "en"], language: "en-US" },
    performance: { now: () => 0 },
    requestAnimationFrame: () => 1,
    cancelAnimationFrame: () => {},
    setTimeout: () => 1,
    clearTimeout: () => {},
    alert: () => {},
    window: {
      location: { search: settings.search || "", assign() {} },
      sessionStorage: {
        getItem: (key) => (store.has(key) ? store.get(key) : null),
        setItem: (key, value) => store.set(key, String(value))
      }
    }
  };
  sandbox.globalThis = sandbox;
  const context = vm.createContext(sandbox);

  vm.runInContext(read("js/i18n.js"), context, { filename: "js/i18n.js" });
  vm.runInContext("window.KioskI18n = KioskI18n;", context);
  vm.runInContext(read("config.js"), context, { filename: "config.js" });
  vm.runInContext(read("js/app.js"), context, { filename: "js/app.js" });

  return { nodes: nodes, document: document, store: store, context: context };
}

test("the shell starts in Russian even when the browser prefers English", () => {
  const shell = boot();
  assert.equal(shell.document.documentElement.lang, "ru");
  assert.equal(shell.nodes.buttonText.textContent, "Запустить");
  assert.equal(shell.nodes.hint.textContent, "Коснитесь кнопки, чтобы начать");
  assert.equal(shell.nodes.footerText.textContent, "Приятного знакомства с экспонатом");
  assert.equal(shell.nodes.langToggle.hidden, false);
});

test("the first slide caption is localized", () => {
  const shell = boot();
  assert.equal(shell.nodes.caption.textContent, "История компьютеров #1");
});

test("the language switch swaps text without touching the slide", () => {
  const shell = boot();
  const imageSrcBefore = shell.nodes.image.src;
  shell.nodes.langToggle.handlers.click[0]();
  assert.equal(shell.document.documentElement.lang, "en");
  assert.equal(shell.nodes.buttonText.textContent, "Press me to launch!");
  assert.equal(shell.nodes.hint.textContent, "Touch the button to begin");
  assert.equal(shell.nodes.caption.textContent, "A computer history story #1");
  assert.equal(shell.document.title, "yaPDP — interactive exhibit");
  assert.equal(shell.nodes.image.src, imageSrcBefore);
  assert.equal(shell.store.get("yapdp.kiosk.lang"), "en");
});

test("the stored choice is restored, and ?lang= wins over it", () => {
  const restored = boot({ stored: "en" });
  assert.equal(restored.nodes.buttonText.textContent, "Press me to launch!");

  const pinned = boot({ stored: "ru", search: "?lang=en" });
  assert.equal(pinned.nodes.buttonText.textContent, "Press me to launch!");
  assert.equal(pinned.document.documentElement.lang, "en");
});

