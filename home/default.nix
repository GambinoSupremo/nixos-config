{ config, pkgs, inputs, lib, osConfig ? { }, ... }:

let
  # Host-awareness: hosts/vm enables the QEMU guest agent, physical hosts
  # won't — used to skip the heavy chat/media autostarts inside the VM while
  # keeping them for the future desktop host.
  isVM = osConfig.services.qemuGuest.enable or false;

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
    # The dotfiles reference the Arch dotfiles path; on NixOS the script lands
    # in ~/.config/niri/scripts/ via the xdg.configFile "niri" block.
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
    # Unfocused windows get opacity < 1; focused windows return to fully opaque
    # (Niri defaults to 1.0 so no explicit focused rule needed).
    # Niri doesn't support blur — that requires Hyprland or KDE.
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
    # The .lua config is loaded by an Arch-only plugin, so the effective
    # config on NixOS is just hyprland.conf; the lua files are still patched
    # to v5 so nothing in the deployed tree references the v4 CLI.
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
exec-once = systemctl --user start noctalia.service
bind = SUPER, Return, exec, ghostty
bind = SUPER, Q, killactive
bind = SUPER SHIFT, E, exit
EOF

    # ── ghostty ──────────────────────────────────────────────────────────
    # Drop the Arch zsh/pokemon-colorscripts command; the login shell on
    # NixOS is fish.
    mustSed $out/ghostty/config '^command = ' '/^command = /d'

    # ── monitor layout ───────────────────────────────────────────────────────
    # The NVIDIA DP connector index depends on GPU probe order, which has been
    # seen both ways on this box (DP-1/DP-2 when NVIDIA probes first, DP-3/DP-4
    # when the iGPU did). amdgpu is now blacklisted so it should be stable, but
    # rather than gamble on the exact number we list BOTH names for each panel —
    # mango ignores a monitorrule whose connector isn't present, so the unused
    # rule is a harmless no-op.
    # Physical layout: Dell ultrawide left @ 0,0; Philips 4K right @ 3440,0.
    # Scale 1.5 on the 4K gives a 2560×1440 logical surface.
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
    # any line long enough to be eaten (this is what broke the inline
    # session bootstrap before it was moved into a script).
    if grep -rn '.\{256,\}' $out/mango; then
      echo "dotfiles patch FAILED: mango config line exceeds the 255-char parser limit" >&2
      exit 1
    fi
  '';
in
{
  imports = [
    # Noctalia v5 upstream HM module → programs.noctalia.*
    inputs.noctalia.homeModules.default
    # MangoWM upstream HM module → wayland.windowManager.mango.*
    inputs.mangowm.hmModules.mango
    # plasma-manager: declares programs.plasma.* options
    inputs.plasma-manager.homeModules.plasma-manager
    ./plasma.nix
  ];

  home.username      = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;

  # ── Noctalia v5 ──────────────────────────────────────────────────────────────
  # Upstream HM module: installs the package and runs noctalia.service,
  # WantedBy graphical-session.target. `settings` is deliberately left empty
  # so ~/.config/noctalia/config.toml stays runtime-writable and Noctalia
  # keeps managing its own configuration (matches the CachyOS setup).
  # Start coverage per session:
  #   - mango:    patched autostart.conf starts mango-session.target, which
  #               binds graphical-session.target
  #   - niri:     niri-session starts graphical-session.target
  #   - hyprland: hyprland-session.target pulls graphical-session.target,
  #               plus an explicit exec-once in the patched hyprland.conf
  # Logs: journalctl --user -b -u noctalia.service
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  # Noctalia runs in all sessions (KDE, Niri, Mango, Hyprland) as the universal
  # bar + launcher layer. In KDE, remove the default Plasma panel once manually
  # (right-click panel → Remove Panel) so Noctalia is the only bar.

  # ── Mango systemd session plumbing ──────────────────────────────────────────
  # The mango *session* (binary + SDDM entry) comes from the NixOS module in
  # modules/desktop.nix. This HM module is used only for its systemd unit:
  # mango-session.target (BindsTo graphical-session.target), started from the
  # patched autostart.conf above. `settings` stays empty, so the module does
  # NOT generate mango/config.conf — the dotfiles below remain authoritative.
  wayland.windowManager.mango = {
    enable = true;
    systemd.enable = true;
  };

  # ── Dotfiles (GambinoSupremo/dotfiles) ───────────────────────────────────────
  # recursive = true links each file individually so the directories stay
  # writable for runtime-generated files; force = true overwrites leftovers
  # from earlier non-declarative deployments instead of aborting.
  xdg.configFile = {
    "mango"   = { source = "${dotfiles}/mango";   recursive = true; force = true; };
    "niri"    = { source = "${dotfiles}/niri";    recursive = true; force = true; };
    "hypr"    = { source = "${dotfiles}/hypr";    recursive = true; force = true; };
    "ghostty" = { source = "${dotfiles}/ghostty"; recursive = true; force = true; };
    # Suppress the stale XDG autostart entry (hardcoded store path, wrong daemon version);
    # mullvad-gui systemd user service below manages launch timing instead.
    "autostart/mullvad-vpn.desktop" = { force = true; text = "[Desktop Entry]\nHidden=true\n"; };
  };

  # ── Wallpapers ───────────────────────────────────────────────────────────────
  # The CachyOS Noctalia settings.json points wallpaper.directory at
  # /home/gav/Pictures/backgrounds; mirror that exact path as a symlink into
  # the flake input. Read-only is fine — Noctalia only reads it — and
  # `nix flake update dotfiles` pulls new wallpapers.
  home.file."Pictures/backgrounds".source = "${inputs.dotfiles}/backgrounds";

  # Seed Noctalia's runtime template files once, as writable copies, so the
  # first boot has colors and mango's `source = .../noctalia.conf` resolves.
  # Noctalia overwrites them whenever the theme changes.
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

    # Noctalia v5 config. Noctalia mutates this directory at runtime (plugin
    # manager, templates), so every file is seeded as a writable copy and only
    # when missing — later rebuilds preserve runtime edits.
    #
    # config.toml comes from home/noctalia/config.toml in this repo
    # (bar layout, opacity, shortcuts, etc.) — the dotfiles version is skipped.
    find ${inputs.dotfiles}/noctalia -type f -not -name "config.toml" -print0 \
      | while IFS= read -r -d "" src; do
          seedNoctalia "$src" "${config.xdg.configHome}/noctalia/''${src#${inputs.dotfiles}/noctalia/}"
        done
    seedNoctalia ${../home/noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
  '';

  # ── Niri monitor layout ───────────────────────────────────────────────────────
  # outputs.kdl is deployed from the dotfiles (via xdg.configFile "niri" below)
  # with correct EDID-matched mode strings (174.963 / 59.997) and
  # variable-refresh-rate on-demand=true. No override needed here.

  # ── Pywalfox native messaging host ───────────────────────────────────────────
  # Registers pywalfox-native with Zen (and any Gecko browser) without needing
  # programs.firefox.enable, which would pull in Firefox alongside Zen.
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text =
    builtins.toJSON {
      name                = "pywalfox";
      description         = "Pywalfox native app";
      path                = "${pkgs.pywalfox-native}/bin/pywalfox";
      type                = "stdio";
      allowed_extensions  = [ "pywalfox@frewacom.org" ];
    };

  # ── GTK / Qt theming ─────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name    = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    name       = "Bibata-Modern-Ice";
    package    = pkgs.bibata-cursors;
    size       = 24;
  };

  # qt home-manager block intentionally disabled. Setting qt.style globally
  # causes QT_STYLE_OVERRIDE=kvantum, which makes KDE's QML code (Kirigami,
  # KWin effects, plasmashell wallpaper) try to import "kvantum" as a QML
  # module — it's not on KDE's QML path → black screen. KDE manages its own
  # Qt style (Breeze by default, configurable in System Settings). For
  # Mango/Niri, qt6ct + kvantum are set in the compositor-specific env files.

  # ── Fish ─────────────────────────────────────────────────────────────────────
  # pokemon-colorscripts: CachyOS parity (the dotfiles' ghostty command line
  # used it); package exists in nixpkgs (pkgs/by-name/po/pokemon-colorscripts).
  home.packages = [ pkgs.pokemon-colorscripts ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      # pokemon-colorscripts on launch — guarded so a missing package can
      # never break the shell startup
      command -q pokemon-colorscripts; and pokemon-colorscripts --no-title -r 2>/dev/null || true
    '';
    shellAliases = {
      ls      = "eza --icons --group-directories-first";
      la      = "eza -la --icons --group-directories-first";
      ll      = "eza -l --icons --group-directories-first";
      tree    = "eza --tree --icons --group-directories-first";
      cat     = "bat --style=plain";
      grep    = "rg";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    };
  };

  # ── Starship ──────────────────────────────────────────────────────────────────
  programs.starship = {
    enable                = true;
    enableFishIntegration = true;
    # Put `starship init fish | source` into fish's shellInitLast — the very
    # last line of the generated config.fish, run in every fish shell — rather
    # than the is-interactive-gated interactiveShellInit. This guarantees
    # nothing sourced later can shadow fish_prompt, runs for `fish -lc` too,
    # and matches the CachyOS dotfiles (top-level init in config.fish).
    enableInteractive     = false;
    # settings is left unset: ~/.config/starship.toml is managed by
    # home.activation.starshipConfig below (dotfiles layout + Noctalia's
    # runtime palette block), which needs a writable regular file.
  };

  # ── Starship config ──────────────────────────────────────────────────────────
  # ~/.config/starship.toml = dotfiles prompt layout + Noctalia palette block.
  # Noctalia's starship template only manages the `palette = "noctalia"` line
  # and its marker-delimited [palettes.noctalia] block appended at the end —
  # it preserves the rest, but sed -i's the file, so it must stay a writable
  # regular file (not a store symlink). Each rebuild re-asserts the dotfiles
  # layout (dotfiles win) and carries over the palette block Noctalia last
  # generated for the current theme.
  home.activation.starshipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Subshell so the PATH override cannot leak into later activation
    # entries; the HM activation environment does not provide awk/cmp.
    (
    PATH=${lib.makeBinPath (with pkgs; [ coreutils gnugrep gnused gawk diffutils ])}:$PATH
    starshipSrc=${inputs.dotfiles}/starship/starship.toml
    starshipDst=${config.xdg.configHome}/starship.toml
    starshipMb="# >>> NOCTALIA STARSHIP PALETTE >>>"
    starshipMe="# <<< NOCTALIA STARSHIP PALETTE <<<"
    starshipTmp=$(mktemp)
    starshipBlk=$(mktemp)
    # Layout from the dotfiles, minus the palette block committed with it
    # (the CachyOS file was committed live, Noctalia block included).
    awk -v mb="$starshipMb" -v me="$starshipMe" \
      '$0 == mb {skip=1} !skip {print} $0 == me {skip=0}' \
      "$starshipSrc" > "$starshipTmp"
    # Exactly one palette block: prefer the one Noctalia generated on this
    # machine (current theme), fall back to the one from the dotfiles.
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

  # ── fzf ───────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    # Fish integration disabled — it binds Ctrl+T which conflicts with
    # Fish's built-in transpose-chars. Handled manually: bind ctrl-t fzf-file-widget
    enableFishIntegration = false;
  };

  # ── zoxide ────────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable                = true;
    enableFishIntegration = true;
  };

  # ── bat ───────────────────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "plain";
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────────
  programs.git = {
    enable   = true;
    settings = {
      user.name            = "Gavin";
      user.email           = "";
      init.defaultBranch   = "main";
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ────────────────────────────────────────────────────────────────────
  # LazyVim manages plugins via lazy.nvim and writes lazy-lock.json into
  # ~/.config/nvim, so the nvim dotfiles are NOT deployed declaratively —
  # clone/stow them manually, or migrate to programs.neovim.plugins later.
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    vimAlias      = true;
  };

  # ── OBS Studio plugins ────────────────────────────────────────────────────────
  # programs.obs-studio = {
  #   enable  = true;
  #   plugins = with pkgs.obs-studio-plugins; [
  #     obs-vaapi
  #     obs-vkcapture
  #   ];
  # };

  # ── Signal ────────────────────────────────────────────────────────────────────
  # Force gnome-libsecret so the keyring backend is consistent across all
  # compositors. Without this Electron autodetects kwallet6 in KDE, then falls
  # back to basic_text in Niri/Mango/Hyprland, triggering "keyring backend
  # changed" and losing the stored encryption key on every cross-session launch.
  xdg.desktopEntries.signal-desktop = {
    name           = "Signal";
    exec           = "signal-desktop --password-store=gnome-libsecret %U";
    icon           = "signal-desktop";
    comment        = "Private messaging from your desktop";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType   = [ "x-scheme-handler/sgnl" "x-scheme-handler/signalcaptcha" ];
  };

  # ── Mullvad VPN GUI ───────────────────────────────────────────────────────────
  # Replaces the XDG autostart entry (Hidden=true in xdg.configFile above) with
  # a systemd user service. ExecStartPre polls until the system daemon is active
  # before presenting the GUI, fixing the "App is out of sync" error at login.
  # Both ExecStart and the daemon come from pkgs.mullvad-vpn so versions match.
  systemd.user.services.mullvad-gui = lib.mkIf (!isVM) (
    let
      waitDaemon = pkgs.writeShellScript "mullvad-daemon-wait" ''
        until systemctl is-active --quiet mullvad-daemon.service; do
          sleep 1
        done
      '';
    in {
      Unit = {
        Description = "Mullvad VPN GUI";
        After       = [ "graphical-session.target" ];
        PartOf      = [ "graphical-session.target" ];
      };
      Service = {
        Type         = "simple";
        ExecStartPre = toString waitDaemon;
        ExecStart    = "${pkgs.mullvad-vpn}/bin/mullvad-vpn";
        Restart      = "on-failure";
        RestartSec   = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  );
}
