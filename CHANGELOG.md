# Changelog

All notable changes to the yaPDP kiosk shell are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses semantic versioning once releases are tagged.

## [Unreleased]

### Added

- Bilingual kiosk shell: Russian is the default language and an `RU | EN` switch in the top-right corner changes the wording of the welcome screen and slide captions without reloading the page.
- `locale`, `fallbackLocale`, `locales`, and `media[].captions` configuration keys. String resolution falls back to the wording in `index.html`, so a partially translated deployment never renders empty labels.
- `js/i18n.js`: DOM-free localization resolver (locale detection, fallback chain, caption lookup), covered by `tests/i18n.test.js` and runnable with `node --test tests`.
- `tests/app.smoke.test.js`: runs the real `js/app.js` against a minimal DOM stub to prove that the shell starts in Russian, that the switch only swaps text, and that the stored choice and `?lang=` are honoured.
- `?lang=` support on the kiosk URL to pin a single machine to one language from `start-kiosk.sh`.

### Changed

- `index.html` is authored in Russian (`lang="ru"`) and doubles as the fallback dictionary; visible text moved from flat `config.js` keys into `locales`.
- The visitor's language choice is stored in `sessionStorage`: it survives the hand-off to yaPDP and back, but a browser restart returns the kiosk to the default language.
- Localized `aria-label` values and runtime messages (`loadError`, `launchMissing`); `document.documentElement.lang` follows the active language.
- Stylesheet and script URLs in `index.html` carry a `?v=` suffix so an already installed kiosk picks up updated `css/kiosk.css` and `js/*.js` after an update.
- `text-wrap: balance` on the launch button and hint, because Russian wording is wider than the English original.
- Slide captions moved above the footer row, so the progress bar no longer runs beneath the caption text and captions stay readable.

### Compatibility

- `install/ubuntu-24.04.sh` is unchanged: `launchUrl` remains a single top-level line in `config.js` and the installer still rewrites it from `IDLE_TIMEOUT` and `IDLE_REDIRECT`.
- A configuration without `locales` keeps working; the shell then renders the Russian wording shipped in `index.html` and hides the language switch.
