(function (root) {
  "use strict";

  function resolve(launchUrl, baseUrl) {
    if (typeof launchUrl !== "string" || !launchUrl.trim()) return null;
    let target;
    try {
      target = new URL(launchUrl, baseUrl || "http://localhost/");
    } catch (error) {
      return null;
    }

    const rawTimeout = target.searchParams.get("idle-timeout");
    const parsedTimeout = rawTimeout === null ? 0 : Number(rawTimeout);
    const timeoutSeconds = Number.isSafeInteger(parsedTimeout) && parsedTimeout > 0
      ? parsedTimeout
      : 0;
    const rawRedirect = target.searchParams.get("idle-redirect");
    let returnUrl = "";
    if (rawRedirect) {
      try {
        returnUrl = new URL(rawRedirect, target).href;
      } catch (error) {
        returnUrl = "";
      }
    }

    target.searchParams.set("onboarding", "skip");
    return {
      url: target.href,
      timeoutMs: timeoutSeconds * 1000,
      returnUrl: returnUrl
    };
  }

  const api = { resolve: resolve };
  root.KioskOnboarding = api;
  if (typeof module === "object" && module.exports) module.exports = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
