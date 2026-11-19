// Points YouTube's own color variables at the theme colors; updates live.
const style = document.createElement("style");
document.documentElement.appendChild(style);

const mix = (a, b, pct) => `color-mix(in srgb, ${a} ${pct}%, ${b})`;

function apply(c) {
  if (!c || !c.bg || !c.text) {
    style.textContent = "";
    return;
  }
  const muted = mix(c.text, c.bg, 65);
  const layer = (pct) => mix(c.text, "transparent", pct);
  style.textContent = `
    html, html[dark], html:not([dark]) {
      --yt-spec-base-background: ${c.bg} !important;
      --yt-spec-raised-background: ${c.bgLight} !important;
      --yt-spec-menu-background: ${c.bgLight} !important;
      --yt-spec-inverted-background: ${c.text} !important;
      --yt-spec-general-background-a: ${c.bg} !important;
      --yt-spec-general-background-b: ${c.bg} !important;
      --yt-spec-general-background-c: ${c.bgLight} !important;
      --yt-spec-brand-background-solid: ${c.bg} !important;
      --yt-spec-brand-background-primary: ${c.bg} !important;
      --yt-spec-brand-background-secondary: ${c.bgLight} !important;
      --yt-spec-snackbar-background: ${c.bgExtra} !important;
      --yt-spec-additive-background: ${layer(8)} !important;
      --yt-spec-10-percent-layer: ${layer(12)} !important;
      --yt-spec-badge-chip-background: ${layer(10)} !important;
      --yt-spec-button-chip-background-hover: ${layer(18)} !important;
      --yt-spec-touch-response: ${layer(20)} !important;
      --yt-spec-outline: ${layer(20)} !important;
      --yt-spec-text-primary: ${c.text} !important;
      --yt-spec-text-primary-inverse: ${c.bg} !important;
      --yt-spec-text-secondary: ${muted} !important;
      --yt-spec-text-disabled: ${mix(c.text, c.bg, 40)} !important;
      --yt-spec-icon-active-other: ${c.text} !important;
      --yt-spec-icon-inactive: ${muted} !important;
      --yt-spec-icon-disabled: ${mix(c.text, c.bg, 40)} !important;
      --yt-spec-call-to-action: ${c.accent} !important;
      --yt-spec-themed-blue: ${c.accent} !important;
      --yt-spec-suggested-action: ${mix(c.accent, "transparent", 20)} !important;
      --yt-spec-static-brand-red: ${c.accent} !important;
      --yt-spec-brand-icon-active: ${c.accent} !important;
      --yt-spec-brand-link-text: ${c.accent} !important;
      --yt-spec-wordmark-text: ${c.text} !important;
      --yt-spec-shadow: ${mix(c.bg, "transparent", 60)} !important;
      --yt-spec-error-indicator: ${c.accent2} !important;
      --yt-spec-static-overlay-background-brand: ${c.accent} !important;
    }
    ytd-app, ytd-browse, ytd-watch-flexy, #masthead-container, #background.ytd-masthead,
    tp-yt-app-drawer #contentContainer, ytd-mini-guide-renderer {
      background: ${c.bg} !important;
    }
    .ytp-play-progress, .ytp-swatch-background-color, .ytp-volume-slider-handle,
    .ytp-volume-slider-handle::before, .ytProgressBarLineProgressBarPlayed,
    .ytThumbnailOverlayProgressBarHostWatchedProgressBarSegment,
    #progress.ytd-thumbnail-overlay-resume-playback-renderer {
      background: ${c.accent} !important;
    }
    .ytp-scrubber-button, .ytProgressBarPlayheadProgressBarPlayheadDot {
      background: ${c.accent} !important;
    }
  `;
}

browser.storage.local.get("colors").then((r) => apply(r.colors));
browser.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.colors) apply(changes.colors.newValue);
});
