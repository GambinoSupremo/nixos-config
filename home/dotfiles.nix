# Dotfiles deployment: patch the dotfiles input for NixOS + Noctalia v5, deploy
# into ~/.config. Every mustSed matches exact line text in the dotfiles repo.
{
  config,
  pkgs,
  lib,
  inputs,
  host,
  ...
}:

let
  inherit (host) isVM;

  # niri-style scrollable overview for Hyprland, built against pkgs.hyprland so
  # the plugin ABI matches (the upstream flake pins Hyprland master).
  scrollOverview = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "scrolloverview";
    version = "0-unstable";
    src = inputs.hyprland-scroll-overview;
    buildInputs = [ pkgs.lua5_4 ]; # Makefile pkg-configs lua5.4
    installPhase = ''
      runHook preInstall
      install -Dm644 ./*scrolloverview.so $out/lib/libscrolloverview.so
      runHook postInstall
    '';
    meta.description = "Scrollable niri-like overview plugin for Hyprland";
  };

  # Hyprland has no session target without uwsm, so nothing pulls
  # graphical-session.target; restart (not start) recovers from start-limit-hit.
  hyprSessionBootstrap = pkgs.writeShellScript "hypr-session-bootstrap" ''
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
    systemctl --user reset-failed
    systemctl --user restart noctalia.service
    # Sunshine needs the compositor env for wlr screen capture.
    systemctl --user restart sunshine.service
  '';

  # Hyprland's .conf fallback, written whole (hyprland.lua normally wins): the
  # Noctalia colours source line, a minimal usable session, and on the desktop
  # the scroll-overview plugin. Nix strips a leading blank line, hence the "\n".
  hyprFallbackConf = pkgs.writeText "hyprland.conf" (
    "\n"
    + ''
      source = optional:/home/gav/.config/hypr/noctalia/noctalia-colors.conf

      # ── NixOS additions ─────────────────────────────────────────────────────────
      # Minimal fallback so the session is never a dead end if hyprland.lua fails.
      # NVIDIA wlroots vars scoped here so they don't poison KWin.
      env = GBM_BACKEND,nvidia-drm
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia
      env = WLR_NO_HARDWARE_CURSORS,1
      # Matched by EDID description (connector names renumber); wildcard catch-all.
      monitor = desc:Dell Inc. Dell AW3423DW #tBszGDAYBQUH, 3440x1440@174, 0x0, 1
      monitor = desc:Philips Consumer Electronics Company PHL 278E1 0x0000065F, 3840x2160@60, 3440x0, 1.5
      monitor = , preferred, auto, 1
      misc {
          vrr = 2    # fullscreen-only (always-on gamma-flickers the QD-OLED)
      }
      exec-once = systemctl --user start noctalia.service
      exec-once = sleep 5 && mullvad-exclude vesktop
      bind = SUPER, Return, exec, ghostty
      bind = SUPER, Q, killactive
      bind = SUPER SHIFT, E, exit
      bind = SUPER SHIFT, D, exec, mullvad-exclude vesktop
      bind = SUPER, code:51, exec, noctalia msg panel-toggle control-center audio
      # Per-app opacity, same values as niri
      windowrule = match:class ^(signal)$, opacity 0.95 0.90
      windowrule = match:class ^(vesktop)$, opacity 0.95 0.90
      windowrule = match:class ^(obsidian)$, opacity 0.95 0.90
    ''
    + lib.optionalString (!isVM) (
      "\n"
      + ''
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
      ''
    )
  );

  # Desktop only; the dotfiles' hyprland.lua loads it with pcall(require, "nixos").
  hyprNixosLua = pkgs.writeText "nixos.lua" ''
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
  '';

  # Dotfiles copied for NixOS: Hyprland session bootstrap patch plus NixOS-only
  # additions. Files Noctalia regenerates are removed here and seeded writable below.
  dotfiles = pkgs.runCommandLocal "dotfiles-patched" { } ''
    mkdir -p $out
    for d in niri hypr ghostty; do
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

    # ── niri ─────────────────────────────────────────────────────────────
    # Keep the dotfiles' `spawn-at-startup "noctalia"`: under niri the session
    # doesn't reliably reach graphical-session.target, so the service alone
    # left niri with no shell.
    # ── hypr ─────────────────────────────────────────────────────────────
    # hyprland.lua is the effective config; hyprland.conf is only a fallback.
    cp ${hyprFallbackConf} $out/hypr/hyprland.conf
    ${lib.optionalString (!isVM) "cp ${hyprNixosLua} $out/hypr/nixos.lua"}
    # Replace the async env-import exec_cmds with the sequential bootstrap.
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      's|hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")|hl.exec_cmd("${hyprSessionBootstrap}")|'
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      '/hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")/d'

    # ── ghostty ──────────────────────────────────────────────────────────
    # Runtime-generated by Noctalia — never deploy read-only (seeded instead)
    rm $out/niri/noctalia.kdl
    rm $out/ghostty/themes/noctalia

    # No v4-era Noctalia invocations may reach the deployed dotfiles.
    if grep -rn 'qs -c\|noctalia-shell ipc' $out; then
      echo "dotfiles patch FAILED: v4 Noctalia references remain (see above)" >&2
      exit 1
    fi
  '';
in
{
  # ── Noctalia v5 ──────────────────────────────────────────────────────────────
  # Upstream HM module runs noctalia.service (WantedBy graphical-session.target);
  # settings left empty so ~/.config/noctalia/config.toml stays runtime-writable.
  # package is the flake's own build, patched so compositor blur covers only the
  # bar capsules (from Spike-dotfiles). Patching misses noctalia.cachix.org: local build per bump.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./noctalia/bar-capsule-blur.patch
        ./noctalia/history-click-focus.patch # history card click → open/focus sender app
      ];
    });
  };

  # ── Dotfiles deployment ───────────────────────────────────────────────────────
  # recursive keeps directories writable for runtime-generated files; force
  # overwrites leftovers from pre-declarative deployments.
  xdg.configFile = {
    "niri" = {
      source = "${dotfiles}/niri";
      recursive = true;
      force = true;
    };
    "hypr" = {
      source = "${dotfiles}/hypr";
      recursive = true;
      force = true;
    };
    "ghostty" = {
      source = "${dotfiles}/ghostty";
      recursive = true;
      force = true;
    };
    # Noctalia user templates (wired in noctalia/config.toml [theme.templates.user]).
    "noctalia/templates/tidal-hifi.css".source = ./noctalia/templates/tidal-hifi.css;
    "noctalia/templates/cider.scss".source = ./noctalia/templates/cider.scss;
    "sh.cider.genten/themes/noctalia/theme.yml".source = ./noctalia/templates/cider-theme.yml;
    # Suppress the stale XDG autostart entry so the mullvad-gui systemd user
    # service (services.nix) controls launch timing instead.
    "autostart/mullvad-vpn.desktop" = {
      force = true;
      text = "[Desktop Entry]\nHidden=true\n";
    };
    # niri runs XDG autostart too; these duplicated its spawn-at-startup lines,
    # and two Signals racing at login locked its database.
    "autostart/signal.desktop" = {
      force = true;
      text = "[Desktop Entry]\nHidden=true\n";
    };
    "autostart/vesktop.desktop" = {
      force = true;
      text = "[Desktop Entry]\nHidden=true\n";
    };
    "autostart/tidal-hifi.desktop" = {
      force = true;
      text = "[Desktop Entry]\nHidden=true\n";
    };
    # Ad-hoc nix-shell/nix-env read this instead of the system config
    # (nixpkgs.config.allowUnfree in nixos/base/core.nix).
    "nixpkgs/config.nix" = {
      force = true;
      text = "{ allowUnfree = true; }\n";
    };
  };

  # ── Wallpapers ───────────────────────────────────────────────────────────────
  # Noctalia reads this path from [wallpaper] directory in config.toml; read-only is fine.
  home.file."Pictures/backgrounds".source = "${inputs.wallpapers}";

  # ── Noctalia runtime seed ─────────────────────────────────────────────────────
  # Seed Noctalia's runtime templates once as writable copies; rebuilds skip
  # existing files so runtime edits survive.
  home.activation.seedNoctaliaTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seedNoctalia() {
      if [ ! -e "$2" ]; then
        run mkdir -p "$(dirname "$2")"
        run cp "$1" "$2"
        run chmod u+w "$2"
      fi
    }
    seedNoctalia ${inputs.dotfiles}/niri/noctalia.kdl       ${config.xdg.configHome}/niri/noctalia.kdl
    seedNoctalia ${inputs.dotfiles}/ghostty/themes/noctalia ${config.xdg.configHome}/ghostty/themes/noctalia
    # hypr/noctalia.lua has no template — seed an empty stub so hyprland.lua's
    # require("noctalia") loads before Noctalia's first run overwrites it.
    seedNoctalia ${pkgs.writeText "noctalia-lua-stub" ''
      -- Seeded by home-manager; Noctalia overwrites with theme colors.
    ''} ${config.xdg.configHome}/hypr/noctalia.lua

    seedNoctalia ${./noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
  '';

  # ── Starship config ───────────────────────────────────────────────────────────
  # Noctalia sed-edits starship.toml at runtime, so it stays a writable file: each
  # rebuild re-asserts the dotfiles layout and carries over Noctalia's palette block.
  home.activation.starshipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
    PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          gnugrep
          gnused
          gawk
          diffutils
        ]
      )
    }:$PATH
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
