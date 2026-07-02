{ config, pkgs, lib, inputs, osConfig ? {}, ... }:

let
  isVM = osConfig.services.qemuGuest.enable or false;

  # niri-style scrollable overview for Hyprland. Built against pkgs.hyprland
  # (the same package programs.hyprland uses) so the plugin ABI matches; the
  # upstream flake pins Hyprland master, which would be rejected at load time.
  scrollOverview = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "scrolloverview";
    version    = "0-unstable";
    src        = inputs.hyprland-scroll-overview;
    buildInputs = [ pkgs.lua5_4 ];   # Makefile pkg-configs lua5.4
    installPhase = ''
      runHook preInstall
      install -Dm644 ./*scrolloverview.so $out/lib/libscrolloverview.so
      runHook postInstall
    '';
    meta.description = "Scrollable niri-like overview plugin for Hyprland";
  };

  # Session bootstrap run from mango's autostart.conf. Mango executes each
  # exec-once value via `sh -c`, but its config parser truncates values at
  # 255 chars (char value[256] in parse_config.h) — an inline one-liner here
  # was silently cut mid-command, so the bootstrap lives in a script and the
  # exec-once line stays short. Mango's own set_activation_env() imports the
  # env too, but asynchronously and without --systemd for dbus, so the script
  # re-does it to make the ordering deterministic before the target starts.
  mangoSessionBootstrap = pkgs.writeShellScript "mango-session-bootstrap" ''
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY
    systemctl --user reset-failed
    systemctl --user start mango-session.target
  '';

  # Hyprland has no session target on NixOS (that was uwsm's job, and uwsm is
  # gone), so nothing pulls graphical-session.target → noctalia.service.
  # Import the session env synchronously, then hand noctalia to its service.
  # restart (not start) also recovers from an earlier start-limit-hit.
  hyprSessionBootstrap = pkgs.writeShellScript "hypr-session-bootstrap" ''
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
    systemctl --user reset-failed
    systemctl --user restart noctalia.service
  '';

  # GambinoSupremo/dotfiles with Arch-specific and Noctalia-v4-era bits
  # patched for NixOS + Noctalia v5 (binary `noctalia`, IPC via
  # `noctalia msg ...`, run as noctalia.service).
  # Files that Noctalia regenerates at runtime (mango/noctalia.conf,
  # niri/noctalia.kdl, ghostty/themes/noctalia) are removed here so they are
  # never deployed as read-only store symlinks; they are seeded as writable
  # copies by home.activation.seedNoctaliaTemplates below.
  dotfiles = pkgs.runCommandLocal "dotfiles-patched" { } ''
    mkdir -p $out
    for d in mango niri hypr ghostty; do
      cp -r ${inputs.dotfiles}/$d $out/$d
    done
    chmod -R u+w $out

    # Guarded sed: fail the build if the dotfiles no longer contain the line
    # a patch targets, instead of silently deploying an unpatched config.
    mustSed() { # mustSed <file> <grep-pattern> <sed-expression>
      grep -q -e "$2" "$1" || {
        echo "dotfiles patch FAILED: pattern not found in $1: $2" >&2
        exit 1
      }
      sed -i -e "$3" "$1"
    }

    # ── mango ────────────────────────────────────────────────────────────
    # Portals are dbus-activated on NixOS (no /usr/lib path).
    mustSed $out/mango/autostart.conf \
      '^exec-once=/usr/lib/xdg-desktop-portal-wlr$' \
      '\|^exec-once=/usr/lib/xdg-desktop-portal-wlr$|d'
    # Mango launched from SDDM does not activate the systemd user session by
    # itself: run the bootstrap script (import session env, then start
    # mango-session.target from the mangowm HM module below, which binds
    # graphical-session.target and thereby pulls up noctalia.service).
    mustSed $out/mango/autostart.conf \
      '^exec-once=systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP$' \
      's|^exec-once=systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP$|exec-once=${mangoSessionBootstrap}|'
    # v4 launched the shell directly; v5 comes up via mango-session.target.
    mustSed $out/mango/autostart.conf \
      '^exec-once=qs -c noctalia-shell$' \
      '/^exec-once=qs -c noctalia-shell$/d'

    ${lib.optionalString isVM ''
      # VM only: don't autostart the heavy chat/media apps. The lines are
      # mustSed-guarded so a wording change in the dotfiles fails the build
      # instead of silently re-enabling them.
      mustSed $out/mango/autostart.conf \
        '^exec-once=sleep 5 && mullvad-exclude vesktop$' \
        '/^exec-once=sleep 5 && mullvad-exclude vesktop$/d'
      mustSed $out/mango/autostart.conf \
        '^exec-once=sleep 5 && signal-desktop$' \
        '/^exec-once=sleep 5 && signal-desktop$/d'
      mustSed $out/mango/autostart.conf \
        '^exec-once=sleep 5 && tidal-hifi$' \
        '/^exec-once=sleep 5 && tidal-hifi$/d'
    ''}

    ${lib.optionalString (!isVM) ''
      mustSed $out/mango/autostart.conf \
        '^exec-once=sleep 5 && signal-desktop$' \
        's|^exec-once=sleep 5 && signal-desktop$|& --password-store=gnome-libsecret|'
    ''}

    mustSed $out/mango/bind.conf '/usr/bin/ghostty' 's|/usr/bin/ghostty|ghostty|g'
    # v4 `qs -c noctalia-shell ipc call ...` → v5 `noctalia msg ...`
    mustSed $out/mango/bind.conf \
      'qs -c noctalia-shell ipc call launcher toggle' \
      's|qs -c noctalia-shell ipc call launcher toggle|noctalia msg panel-toggle launcher|'
    mustSed $out/mango/bind.conf \
      'qs -c noctalia-shell ipc call launcher emoji' \
      's|qs -c noctalia-shell ipc call launcher emoji|noctalia msg panel-open launcher /emo|'
    mustSed $out/mango/bind.conf \
      'qs -c noctalia-shell ipc call wallpaper toggle' \
      's|qs -c noctalia-shell ipc call wallpaper toggle|noctalia msg panel-toggle wallpaper|'
    mustSed $out/mango/bind.conf \
      '^bind=SUPER+ALT,r,spawn,bash' \
      's|^bind=SUPER+ALT,r,spawn,bash .*$|bind=SUPER+ALT,r,spawn,systemctl --user restart noctalia.service|'
    mustSed $out/mango/bind.conf \
      'zen-browser' \
      's|zen-browser|zen-beta|g'

    # ── niri ─────────────────────────────────────────────────────────────
    # Keep the dotfiles' `spawn-at-startup "noctalia"`: under niri the user
    # session does NOT reliably reach graphical-session.target, so the
    # noctalia.service (WantedBy that target) doesn't start — observed as "niri
    # came up with no noctalia". Letting niri spawn it directly is the reliable
    # path; mango/hyprland still use the service via their session targets.
    mustSed $out/niri/config.kdl \
      '/home/gav/dotfiles/niri/scripts/stack-comms.sh' \
      's|/home/gav/dotfiles/niri/scripts/stack-comms.sh|${config.xdg.configHome}/niri/scripts/stack-comms.sh|'
    mustSed $out/niri/binds.kdl \
      'spawn "qs" "-c" "noctalia-shell" "ipc" "call" "launcher" "emoji"' \
      's|spawn "qs" "-c" "noctalia-shell" "ipc" "call" "launcher" "emoji"|spawn "noctalia" "msg" "panel-open" "launcher" "/emo"|'
    mustSed $out/niri/binds.kdl \
      'spawn "qs" "-c" "noctalia-shell" "ipc" "call" "wallpaper" "toggle"' \
      's|spawn "qs" "-c" "noctalia-shell" "ipc" "call" "wallpaper" "toggle"|spawn "noctalia" "msg" "panel-toggle" "wallpaper"|'
    mustSed $out/niri/binds.kdl \
      'spawn-sh "killall qs' \
      's|spawn-sh "killall qs.*$|spawn-sh "systemctl --user restart noctalia.service"; }|'
    mustSed $out/niri/binds.kdl \
      'zen-browser' \
      's|zen-browser|zen-beta|g'
    mustSed $out/niri/config.kdl \
      'spawn-at-startup "signal-desktop"' \
      's|spawn-at-startup "signal-desktop"|spawn-at-startup "signal-desktop" "--password-store=gnome-libsecret"|'
    mustSed $out/niri/binds.kdl \
      'spawn "signal-desktop"' \
      's|spawn "signal-desktop"|spawn "signal-desktop" "--password-store=gnome-libsecret"|'

    # Append NixOS window-rule additions to niri config.
    cat >> $out/niri/config.kdl <<'EOF'

// ── NixOS additions ──────────────────────────────────────────────────────────
// Match MangoWM: focused=0.95 unfocused=0.85
window-rule {
    match app-id="signal"
    match is-focused=true
    opacity 0.95
}
window-rule {
    match app-id="signal"
    match is-focused=false
    opacity 0.85
}
window-rule {
    match app-id="vesktop"
    match is-focused=true
    opacity 0.95
}
window-rule {
    match app-id="vesktop"
    match is-focused=false
    opacity 0.85
}
window-rule {
    match app-id="zen-beta"
    match is-focused=true
    opacity 0.95
}
window-rule {
    match app-id="zen-beta"
    match is-focused=false
    opacity 0.85
}
window-rule {
    match app-id="obsidian"
    match is-focused=true
    opacity 0.95
}
window-rule {
    match app-id="obsidian"
    match is-focused=false
    opacity 0.85
}
EOF

    # ── hypr ─────────────────────────────────────────────────────────────
    # Hyprland prefers hyprland.lua over hyprland.conf when both exist
    # (confirmed in the session log: "[cfg] Using lua config found at
    # …/hyprland.lua"), so the lua tree IS the effective config on NixOS.
    # The hyprland.conf additions below remain only as a fallback for a
    # broken lua config.
    mustSed $out/hypr/workspaces.lua '/usr/bin/ghostty' 's|/usr/bin/ghostty|ghostty|g'
    mustSed $out/hypr/bind.lua \
      'qs -c noctalia-shell ipc call launcher emoji' \
      's|qs -c noctalia-shell ipc call launcher emoji|noctalia msg panel-open launcher /emo|'
    mustSed $out/hypr/bind.lua \
      'qs -c noctalia-shell ipc call wallpaper toggle' \
      's|qs -c noctalia-shell ipc call wallpaper toggle|noctalia msg panel-toggle wallpaper|'
    mustSed $out/hypr/bind.lua \
      '" + ALT + R"' \
      's|^hl.bind(mod .. " + ALT + R".*$|hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd("systemctl --user restart noctalia.service"))|'
    mustSed $out/hypr/bind.lua \
      'zen-browser' \
      's|zen-browser|zen-beta|g'
    mustSed $out/hypr/autostart.lua \
      'sleep 5 && signal-desktop"' \
      's|sleep 5 && signal-desktop"|sleep 5 \&\& signal-desktop --password-store=gnome-libsecret"|'
    mustSed $out/hypr/bind.lua \
      'hl.dsp.exec_cmd("signal-desktop")' \
      's|hl.dsp.exec_cmd("signal-desktop")|hl.dsp.exec_cmd("signal-desktop --password-store=gnome-libsecret")|'
    # noctalia is owned by the HM noctalia.service (graphical-session.target);
    # the raw lua spawn raced it (service died with start-limit-hit and the
    # SUPER+ALT+R restart bind managed nothing).
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("noctalia")' \
      '/hl\.exec_cmd("noctalia")/d'
    # Replace the two async env-import exec_cmds with the sequential session
    # bootstrap (env import → reset-failed → restart noctalia.service).
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      's|hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")|hl.exec_cmd("${hyprSessionBootstrap}")|'
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      '/hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")/d'

    # Append a minimal usable fallback so the session is never a dead end.
    cat >> $out/hypr/hyprland.conf <<'EOF'

# ── NixOS additions ─────────────────────────────────────────────────────────
# The lua-based config in this directory needs an Arch-only plugin; keep a
# minimal fallback so the Hyprland session is usable on NixOS.
# NVIDIA wlroots vars scoped here so they don't poison KWin when using KDE.
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
# Dell ultrawide left @ 0,0; Philips 4K right @ 3440,0. The NVIDIA DP index
# varies by probe order, so list both names per panel; the catch-all wildcard
# at the end handles whichever name is actually present.
monitor = DP-2, 3440x1440@174, 0x0, 1
monitor = DP-4, 3440x1440@174, 0x0, 1
monitor = DP-1, 3840x2160@60, 3440x0, 1.5
monitor = DP-3, 3840x2160@60, 3440x0, 1.5
monitor = , preferred, auto, 1
misc {
    vrr = 1    # enable VRR / G-Sync globally; use 2 for fullscreen-only
}
exec-once = systemctl --user start noctalia.service
exec-once = sleep 5 && mullvad-exclude vesktop
bind = SUPER, Return, exec, ghostty
bind = SUPER, Q, killactive
bind = SUPER SHIFT, E, exit
bind = SUPER SHIFT, D, exec, mullvad-exclude vesktop
bind = SUPER, code:51, exec, noctalia msg panel-toggle control-center audio
# Opacity rules — match mango (global 0.95/0.85) and niri/KDE (per-app rules)
windowrulev2 = opacity 0.95 0.85, class:^(signal)$
windowrulev2 = opacity 0.95 0.85, class:^(vesktop)$
windowrulev2 = opacity 0.95 0.85, class:^(zen-beta)$
windowrulev2 = opacity 0.95 0.85, class:^(obsidian)$
EOF

    ${lib.optionalString (!isVM) ''
      # scroll-overview plugin — desktop only (skip the compile on the VM).
      # Wired into hyprland.lua (the effective config); the hyprland.conf
      # lines are the same wiring for the fallback path.
      # Unquoted heredocs: ''${scrollOverview} must interpolate.
      cat >> $out/hypr/hyprland.lua <<EOF

-- ── scroll-overview plugin (NixOS addition) ─────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl plugin load ${scrollOverview}/lib/libscrolloverview.so")
end)
hl.config({
    plugin = {
        scrolloverview = {
            scale = 0.5,
            workspace_gap = 100,
            layout = "vertical",
        },
    },
})
-- Callback form defers the hl.plugin lookup to keypress time, after the
-- plugin has loaded.
hl.bind("SUPER + Tab", function()
    hl.plugin.scrolloverview.overview("toggle")
end)
EOF

      cat >> $out/hypr/hyprland.conf <<EOF

# ── scroll-overview plugin ───────────────────────────────────────────────────
plugin = ${scrollOverview}/lib/libscrolloverview.so
plugin {
    scrolloverview {
        scale = 0.5
        workspace_gap = 100
        layout = vertical
    }
}
bind = SUPER, Tab, scrolloverview:overview, toggle
EOF
    ''}

    # ── ghostty ──────────────────────────────────────────────────────────
    # Drop the Arch zsh/pokemon-colorscripts command; the login shell on
    # NixOS is fish.
    mustSed $out/ghostty/config '^command = ' '/^command = /d'

    # ── monitor layout ───────────────────────────────────────────────────────
    # The NVIDIA DP connector index depends on GPU probe order, which has been
    # seen both ways on this box (DP-1/DP-2 when NVIDIA probes first, DP-3/DP-4
    # when the iGPU did). Both names are listed so mango silently ignores the
    # one that isn't present.
    cat > $out/mango/monitor.conf <<'EOF'
# Monitors — Dell AW3423DW ultrawide (left). Name is DP-2 or DP-4 by probe order.
monitorrule=name:DP-2,width:3440,height:1440,refresh:174,x:0,y:0,scale:1,vrr:1
monitorrule=name:DP-4,width:3440,height:1440,refresh:174,x:0,y:0,scale:1,vrr:1
# Philips 278E1 4K (right). Name is DP-1 or DP-3 by probe order.
monitorrule=name:DP-1,width:3840,height:2160,refresh:60,x:3440,y:0,scale:1.5,vrr:0
monitorrule=name:DP-3,width:3840,height:2160,refresh:60,x:3440,y:0,scale:1.5,vrr:0
EOF

    # Runtime-generated by Noctalia — never deploy read-only (seeded instead)
    rm $out/mango/noctalia.conf
    rm $out/niri/noctalia.kdl
    rm $out/ghostty/themes/noctalia

    # No v4-era Noctalia invocations may survive the patching above.
    if grep -rn 'qs -c\|noctalia-shell ipc' $out; then
      echo "dotfiles patch FAILED: v4 Noctalia references remain (see above)" >&2
      exit 1
    fi

    # Mango's config parser silently truncates values at 255 chars; reject
    # any line long enough to be eaten.
    if grep -rn '.\{256,\}' $out/mango; then
      echo "dotfiles patch FAILED: mango config line exceeds the 255-char parser limit" >&2
      exit 1
    fi
  '';
in
{
  # ── Noctalia v5 ──────────────────────────────────────────────────────────────
  # Upstream HM module installs the package and runs noctalia.service,
  # WantedBy graphical-session.target. settings left empty so
  # ~/.config/noctalia/config.toml stays runtime-writable.
  # Session start coverage:
  #   mango     → patched autostart.conf starts mango-session.target
  #   niri      → niri-session starts graphical-session.target
  #   hyprland  → hyprland-session.target + explicit exec-once in patched conf
  #   KDE       → noctalia.service is WantedBy plasma-core.target via systemd
  # Logs: journalctl --user -b -u noctalia.service
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  # ── Mango systemd session plumbing ───────────────────────────────────────────
  # The session binary + SDDM entry come from the NixOS module (modules/desktop.nix).
  # This HM module is used only for mango-session.target (BindsTo
  # graphical-session.target). settings is empty → the module does NOT generate
  # mango/config.conf; the dotfiles below remain authoritative.
  wayland.windowManager.mango = {
    enable = true;
    systemd.enable = true;
  };

  # ── Dotfiles deployment ───────────────────────────────────────────────────────
  # recursive = true links each file individually so directories stay writable
  # for runtime-generated files. force = true overwrites leftovers from earlier
  # non-declarative deployments instead of aborting.
  xdg.configFile = {
    "mango"   = { source = "${dotfiles}/mango";   recursive = true; force = true; };
    "niri"    = { source = "${dotfiles}/niri";    recursive = true; force = true; };
    "hypr"    = { source = "${dotfiles}/hypr";    recursive = true; force = true; };
    "ghostty" = { source = "${dotfiles}/ghostty"; recursive = true; force = true; };
    # Suppress the stale XDG autostart entry so the mullvad-gui systemd user
    # service (services.nix) controls launch timing instead.
    "autostart/mullvad-vpn.desktop" = { force = true; text = "[Desktop Entry]\nHidden=true\n"; };
  };

  # ── Wallpapers ───────────────────────────────────────────────────────────────
  # Symlink the dotfiles backgrounds/ into ~/Pictures/backgrounds — the path
  # Noctalia's settings.json points at. Read-only is fine; Noctalia only reads it.
  home.file."Pictures/backgrounds".source = "${inputs.dotfiles}/backgrounds";

  # ── Noctalia runtime seed ─────────────────────────────────────────────────────
  # Seed Noctalia's runtime template files once as writable copies so the first
  # boot has colors and mango's `source = .../noctalia.conf` resolves.
  # Noctalia overwrites them whenever the theme changes; later rebuilds skip
  # files that already exist (preserving runtime edits).
  home.activation.seedNoctaliaTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seedNoctalia() {
      if [ ! -e "$2" ]; then
        run mkdir -p "$(dirname "$2")"
        run cp "$1" "$2"
        run chmod u+w "$2"
      fi
    }
    seedNoctalia ${inputs.dotfiles}/mango/noctalia.conf     ${config.xdg.configHome}/mango/noctalia.conf
    seedNoctalia ${inputs.dotfiles}/niri/noctalia.kdl       ${config.xdg.configHome}/niri/noctalia.kdl
    seedNoctalia ${inputs.dotfiles}/ghostty/themes/noctalia ${config.xdg.configHome}/ghostty/themes/noctalia

    # Noctalia v5 config dir. config.toml comes from home/noctalia/config.toml
    # in this repo (bar layout, opacity, shortcuts) — the dotfiles version is skipped.
    find ${inputs.dotfiles}/noctalia -type f -not -name "config.toml" -print0 \
      | while IFS= read -r -d "" src; do
          seedNoctalia "$src" "${config.xdg.configHome}/noctalia/''${src#${inputs.dotfiles}/noctalia/}"
        done
    seedNoctalia ${./noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
  '';

  # ── Starship config ───────────────────────────────────────────────────────────
  # ~/.config/starship.toml = dotfiles prompt layout + Noctalia palette block.
  # Noctalia sed-edits this file at runtime, so it must stay a writable regular
  # file (not a store symlink). Each rebuild re-asserts the dotfiles layout and
  # carries over the palette block Noctalia last generated.
  home.activation.starshipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
    PATH=${lib.makeBinPath (with pkgs; [ coreutils gnugrep gnused gawk diffutils ])}:$PATH
    starshipSrc=${inputs.dotfiles}/starship/starship.toml
    starshipDst=${config.xdg.configHome}/starship.toml
    starshipMb="# >>> NOCTALIA STARSHIP PALETTE >>>"
    starshipMe="# <<< NOCTALIA STARSHIP PALETTE <<<"
    starshipTmp=$(mktemp)
    starshipBlk=$(mktemp)
    awk -v mb="$starshipMb" -v me="$starshipMe" \
      '$0 == mb {skip=1} !skip {print} $0 == me {skip=0}' \
      "$starshipSrc" > "$starshipTmp"
    if [ -f "$starshipDst" ] && grep -qF "$starshipMb" "$starshipDst"; then
      starshipBlkSrc=$starshipDst
    else
      starshipBlkSrc=$starshipSrc
    fi
    awk -v mb="$starshipMb" -v me="$starshipMe" \
      '$0 == mb {keep=1} keep {print} $0 == me {keep=0}' \
      "$starshipBlkSrc" > "$starshipBlk"
    if [ -s "$starshipBlk" ]; then
      echo "" >> "$starshipTmp"
      cat "$starshipBlk" >> "$starshipTmp"
    fi
    if ! cmp -s "$starshipTmp" "$starshipDst" 2>/dev/null; then
      run install -m644 "$starshipTmp" "$starshipDst"
    fi
    rm -f "$starshipTmp" "$starshipBlk"
    )
  '';
}
