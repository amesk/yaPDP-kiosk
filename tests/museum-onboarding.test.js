"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const onboarding = require("../js/onboarding.js");

test("resolve adds the yaPDP onboarding skip flag without losing launch parameters", () => {
  const result = onboarding.resolve(
    "/yapdp/pdp11.html?idle-timeout=180&idle-redirect=%2F",
    "http://127.0.0.1:8080/"
  );
  assert.equal(result.url, "http://127.0.0.1:8080/yapdp/pdp11.html?idle-timeout=180&idle-redirect=%2F&onboarding=skip");
  assert.equal(result.timeoutMs, 180000);
  assert.equal(result.returnUrl, "http://127.0.0.1:8080/");
});

test("resolve preserves existing query parameters and replaces a stale onboarding flag", () => {
  const result = onboarding.resolve(
    "/pdp11.html?lang=en&onboarding=show",
    "http://localhost:8080/"
  );
  const url = new URL(result.url);
  assert.equal(url.searchParams.get("lang"), "en");
  assert.equal(url.searchParams.get("onboarding"), "skip");
  assert.equal(result.timeoutMs, 0);
  assert.equal(result.returnUrl, "");
});

test("resolve handles absolute redirects and a disabled or invalid timeout", () => {
  const result = onboarding.resolve(
    "https://museum.example/pdp11.html?idle-timeout=0&idle-redirect=https%3A%2F%2Fmuseum.example%2Fwelcome",
    "http://localhost/"
  );
  assert.equal(result.timeoutMs, 0);
  assert.equal(result.returnUrl, "https://museum.example/welcome");
});

test("resolve rejects missing or malformed launch URLs", () => {
  assert.equal(onboarding.resolve(""), null);
  assert.equal(onboarding.resolve(null), null);
  assert.equal(onboarding.resolve("http://[invalid"), null);
});
