(() => {
  "use strict";

  const config = window.KIOSK_CONFIG || {};
  // js/i18n.js loads before this file; the stub keeps the shell alive if the
  // browser serves a cached index.html that predates the localization layer.
  const i18n = window.KioskI18n || {
    availableLocales: () => [],
    detectInitialLocale: (settings) => (settings && settings.locale) || "ru",
    buildStrings: () => ({}),
    resolveCaption: (item) => (item && item.caption) || "",
    nextLocale: (locale) => locale
  };
  const $ = (id) => document.getElementById(id);
  const image = $("image");
  const video = $("video");
  const progress = $("progress");
  const caption = $("caption");
  const stage = $("stage");
  const launchButton = $("launch");
  const langToggle = $("langToggle");
  const onboardingDialog = $("museumOnboarding");
  const onboardingTimer = $("onboardingTimer");
  const onboardingCountdown = $("onboardingCountdown");
  const onboardingTimerLabel = $("onboardingTimerLabel");
  const onboardingContinue = $("onboardingContinue");
  const onboardingBack = $("onboardingBack");
  const mediaItems = Array.isArray(config.media) ? config.media.filter(item => item && item.src) : [];
  const STORAGE_KEY = "yapdp.kiosk.lang";

  function textOf(node) {
    return node && typeof node.textContent === "string" ? node.textContent.trim() : "";
  }

  function attributeOf(node, name) {
    return node && typeof node.getAttribute === "function" ? node.getAttribute(name) || "" : "";
  }

  function setText(node, value) {
    // Ignore unresolved values so a partial dictionary never blanks the shell.
    if (node && typeof value === "string") node.textContent = value;
  }

  // index.html is authored in the default kiosk language. Capture that wording
  // before the first render so translations can fall back to it.
  const domDefaults = {
    documentTitle: document.title,
    title: textOf($("title")),
    eyebrow: textOf($("eyebrow")),
    subtitle: textOf($("subtitle")),
    footerText: textOf($("footerText")),
    buttonText: textOf($("buttonText")),
    buttonHint: textOf($("hint")),
    ariaStage: attributeOf(stage, "aria-label"),
    ariaStart: attributeOf(launchButton, "aria-label"),
    ariaLang: attributeOf(langToggle, "aria-label"),
    loadError: "",
    launchMissing: "",
    onboardingEyebrow: textOf($("onboardingEyebrow")),
    onboardingTitle: textOf($("onboardingTitle")),
    onboardingIntro: textOf($("onboardingIntro")),
    onboardingSteps: textOf($("onboardingSteps")),
    onboardingTimerLabel: textOf(onboardingTimerLabel),
    onboardingBack: textOf(onboardingBack),
    onboardingContinue: textOf(onboardingContinue)
  };

  function readStoredLocale() {
    try {
      return window.sessionStorage.getItem(STORAGE_KEY) || "";
    } catch (error) {
      return "";
    }
  }

  function storeLocale(value) {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, value);
    } catch (error) {
      // Storage can be unavailable; the kiosk still works with the default locale.
    }
  }

  const locales = i18n.availableLocales(config);
  let locale = i18n.detectInitialLocale(config, {
    search: window.location.search,
    stored: readStoredLocale(),
    languages: navigator.languages || [navigator.language || ""]
  });
  let strings = i18n.buildStrings(locale, config, domDefaults);

  let current = -1;
  let timer = null;
  let progressFrame = null;
  let slideStarted = 0;
  let slideDuration = Number(config.slideInterval) || 10000;
  let launched = false;
  let onboardingInterval = null;
  let onboardingDeadline = 0;
  let onboardingLaunch = null;

  function renderLangToggle() {
    if (!langToggle) return;
    langToggle.hidden = locales.length < 2;
    const options = langToggle.querySelectorAll("[data-lang]");
    options.forEach((option) => {
      const active = option.getAttribute("data-lang") === locale;
      option.classList.toggle("active", active);
      if (active) option.setAttribute("aria-current", "true");
      else option.removeAttribute("aria-current");
    });
  }

  // Swapping the language only rewrites text nodes: the slide, its timer, the
  // progress bar, and the running video must stay untouched.
  function applyLocale(next) {
    if (!next) return;
    locale = next;
    strings = i18n.buildStrings(locale, config, domDefaults);

    document.documentElement.lang = locale;
    if (typeof strings.documentTitle === "string") document.title = strings.documentTitle;

    setText($("title"), strings.title);
    setText($("eyebrow"), strings.eyebrow);
    setText($("subtitle"), strings.subtitle);
    setText($("footerText"), strings.footerText);
    setText($("buttonText"), strings.buttonText);
    setText($("hint"), strings.buttonHint);
    setText($("onboardingEyebrow"), strings.onboardingEyebrow);
    setText($("onboardingTitle"), strings.onboardingTitle);
    setText($("onboardingIntro"), strings.onboardingIntro);
    setText($("onboardingSteps"), strings.onboardingSteps);
    setText(onboardingTimerLabel, strings.onboardingTimerLabel);
    setText(onboardingBack, strings.onboardingBack);
    setText(onboardingContinue, strings.onboardingContinue);

    if (stage && strings.ariaStage) stage.setAttribute("aria-label", strings.ariaStage);
    if (launchButton && strings.ariaStart) launchButton.setAttribute("aria-label", strings.ariaStart);
    if (langToggle && strings.ariaLang) langToggle.setAttribute("aria-label", strings.ariaLang);

    if (current >= 0) setText(caption, i18n.resolveCaption(mediaItems[current], locale, config));

    renderLangToggle();
    storeLocale(locale);
  }

  if (langToggle) {
    langToggle.addEventListener("click", () => {
      if (locales.length < 2) return;
      applyLocale(i18n.nextLocale(locale, locales));
    });
  }

  document.documentElement.style.setProperty("--transition", Math.max(0, Number(config.transitionDuration) || 900) + "ms");

  function stopProgress() {
    if (progressFrame) cancelAnimationFrame(progressFrame);
    progressFrame = null;
  }

  function runProgress(duration) {
    stopProgress();
    slideStarted = performance.now();
    slideDuration = duration;
    const tick = (now) => {
      const fraction = Math.min(1, (now - slideStarted) / slideDuration);
      progress.style.width = (fraction * 100) + "%";
      if (fraction < 1 && !launched) progressFrame = requestAnimationFrame(tick);
    };
    progressFrame = requestAnimationFrame(tick);
  }

  function clearSlideTimer() {
    if (timer) clearTimeout(timer);
    timer = null;
  }

  function showFallback() {
    image.hidden = true;
    video.pause();
    video.hidden = true;
    image.classList.remove("visible");
    video.classList.remove("visible");
    caption.textContent = "";
    progress.style.width = "0";
  }

  function nextSlide() {
    if (launched || mediaItems.length === 0) return;
    current = (current + 1) % mediaItems.length;
    const item = mediaItems[current];
    const src = item.src;
    const isVideo = item.type === "video" || /\.(mp4|webm|ogv)(\?.*)?$/i.test(src);
    clearSlideTimer();
    stopProgress();
    image.classList.remove("visible");
    video.classList.remove("visible");
    setText(caption, i18n.resolveCaption(item, locale, config));

    if (isVideo) {
      image.hidden = true;
      video.pause();
      video.hidden = false;
      video.src = src;
      video.currentTime = 0;
      const duration = Number(item.duration) || Number(config.videoDefaultDuration) || 20000;
      const start = () => {
        video.classList.add("visible");
        const play = video.play();
        if (play && typeof play.catch === "function") play.catch(() => {
          // Muted, inline playback is normally permitted in kiosk mode.
          // The configured duration still advances the playlist if playback is blocked.
        });
      };
      if (video.readyState >= 2) start();
      else video.addEventListener("canplay", start, { once: true });
      runProgress(duration);
      timer = setTimeout(nextSlide, duration);
    } else {
      video.pause();
      video.removeAttribute("src");
      video.load();
      video.hidden = true;
      image.hidden = false;
      image.onload = () => image.classList.add("visible");
      image.onerror = () => {
        setText(caption, strings.loadError ? strings.loadError + ": " + src : src);
        timer = setTimeout(nextSlide, 2500);
      };
      image.src = src;
      const duration = Number(item.duration) || Number(config.slideInterval) || 10000;
      runProgress(duration);
      timer = setTimeout(nextSlide, duration);
    }
  }

  function formatRemaining(milliseconds) {
    const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
    return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" +
      String(seconds % 60).padStart(2, "0");
  }

  function stopOnboardingTimer() {
    if (onboardingInterval) window.clearInterval(onboardingInterval);
    onboardingInterval = null;
    onboardingDeadline = 0;
  }

  function returnToAttractMode() {
    stopOnboardingTimer();
    const destination = onboardingLaunch && onboardingLaunch.returnUrl;
    // A configured idle redirect is always used; the current page is the safe
    // fallback for older launch URLs without an idle-redirect parameter.
    window.location.assign(destination || window.location.pathname);
  }

  function updateOnboardingTimer() {
    const remaining = onboardingDeadline - Date.now();
    if (onboardingTimer) onboardingTimer.textContent = formatRemaining(remaining);
    if (remaining <= 0) returnToAttractMode();
  }

  function resumePresentation() {
    stopOnboardingTimer();
    if (onboardingDialog && onboardingDialog.open) onboardingDialog.close();
    onboardingLaunch = null;
    launched = false;
    nextSlide();
  }

  function openMuseumOnboarding() {
    if (launched || !onboardingDialog) return;
    if (!config.launchUrl) {
      alert(strings.launchMissing || "Set launchUrl in config.js before using the launch button.");
      return;
    }
    onboardingLaunch = window.KioskOnboarding.resolve(config.launchUrl, window.location.href);
    if (!onboardingLaunch) {
      alert(strings.launchMissing || "Set launchUrl in config.js before using the launch button.");
      return;
    }
    clearSlideTimer();
    stopProgress();
    video.pause();
    if (onboardingCountdown) onboardingCountdown.hidden = !(onboardingLaunch.timeoutMs > 0 && onboardingLaunch.returnUrl);
    onboardingDialog.showModal();

    if (onboardingLaunch.timeoutMs > 0 && onboardingLaunch.returnUrl) {
      onboardingDeadline = Date.now() + onboardingLaunch.timeoutMs;
      updateOnboardingTimer();
      onboardingInterval = window.setInterval(updateOnboardingTimer, 250);
    }
  }

  launchButton.addEventListener("click", openMuseumOnboarding);

  if (onboardingDialog) {
    // The visitor must explicitly choose to continue or return; Escape and
    // backdrop clicks must not silently dismiss the museum instructions.
    onboardingDialog.addEventListener("cancel", (event) => event.preventDefault());
  }

  if (onboardingContinue) {
    onboardingContinue.addEventListener("click", () => {
      if (!onboardingLaunch || launched) return;
      launched = true;
      stopOnboardingTimer();
      // The skip flag suppresses yaPDP's own first-run onboarding only for this
      // museum hand-off; normal yaPDP visits remain unchanged.
      window.location.assign(onboardingLaunch.url);
    });
  }

  if (onboardingBack) onboardingBack.addEventListener("click", resumePresentation);

  applyLocale(locale);

  if (mediaItems.length) nextSlide();
  else showFallback();

  // Keep the presentation alive if the browser tab becomes visible again.
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && !launched && mediaItems.length && !timer) nextSlide();
  });
})();
