(() => {
  "use strict";

  const config = window.KIOSK_CONFIG || {};
  const $ = (id) => document.getElementById(id);
  const image = $("image");
  const video = $("video");
  const progress = $("progress");
  const caption = $("caption");
  const stage = $("stage");
  const mediaItems = Array.isArray(config.media) ? config.media.filter(item => item && item.src) : [];

  document.documentElement.style.setProperty("--transition", Math.max(0, Number(config.transitionDuration) || 900) + "ms");
  $("title").textContent = config.title || "Welcome";
  $("eyebrow").textContent = config.eyebrow || "INTERACTIVE EXHIBIT";
  $("subtitle").textContent = config.subtitle || "";
  $("footerText").textContent = config.footerText || "";
  $("buttonText").textContent = config.buttonText || "Press me to launch!";
  $("hint").textContent = config.buttonHint || "Touch the button to begin";
  document.title = config.title ? config.title + " — Kiosk" : "Museum kiosk";

  let current = -1;
  let timer = null;
  let progressFrame = null;
  let slideStarted = 0;
  let slideDuration = Number(config.slideInterval) || 10000;
  let launched = false;

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
    caption.textContent = item.caption || "";

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
        caption.textContent = "Unable to load: " + src;
        timer = setTimeout(nextSlide, 2500);
      };
      image.src = src;
      const duration = Number(item.duration) || Number(config.slideInterval) || 10000;
      runProgress(duration);
      timer = setTimeout(nextSlide, duration);
    }
  }

  $("launch").addEventListener("click", () => {
    if (launched) return;
    launched = true;
    clearSlideTimer();
    stopProgress();
    video.pause();
    const target = config.launchUrl;
    if (!target) {
      launched = false;
      alert("Set launchUrl in config.js before using the launch button.");
      return;
    }
    // Navigation happens directly in the user-gesture handler, which avoids popup blockers.
    window.location.assign(target);
  });

  if (mediaItems.length) nextSlide();
  else showFallback();

  // Keep the presentation alive if the browser tab becomes visible again.
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && !launched && mediaItems.length && !timer) nextSlide();
  });
})();
