// Copies the theme colors Pywalfox sets into storage, where the page scripts read them.
const css = (c) => (Array.isArray(c) ? `rgb(${c.join(",")})` : c);

async function sync(info) {
  const theme = info && info.theme ? info.theme : await browser.theme.getCurrent();
  const c = (theme && theme.colors) || {};
  if (!c.frame) return;
  // Same roles as zen-live.css.
  const colors = {
    bg: css(c.frame),
    bgLight: css(c.sidebar || c.toolbar || c.frame),
    bgExtra: css(c.button_background_active || c.toolbar_field || c.frame),
    text: css(c.toolbar_field_text || c.toolbar_text),
    accent: css(c.tab_loading || c.icons_attention),
    accent2: css(c.icons_attention || c.tab_loading),
  };
  await browser.storage.local.set({ colors });
}

browser.theme.onUpdated.addListener(sync);
sync();
