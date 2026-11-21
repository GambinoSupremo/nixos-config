# Noctalia: the bar, launcher and wallpapers. Live state stays editable, while
# declared plugins and templates sync on apply and plugins auto-reload on change.
{
  config,
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:

let
  sessions = osConfig.gav.sessions;
  cfg = config.gav.noctalia;
  syncData = pkgs.writeText "noctalia-sync.json" (
    builtins.toJSON {
      inherit (cfg) plugins userTemplates;
      builtinTemplates = cfg.templates.builtin;
      communityTemplates = cfg.templates.community;
    }
  );
in
{
  options.gav.noctalia = {
    plugins = lib.mkOption {
      description = "Noctalia plugin IDs to ensure are enabled.";
      type = lib.types.listOf lib.types.str;
      default = [
        "gav/sysmenu"
        "gav/status"
        "omerfuyar/overview"
      ];
    };
    templates.builtin = lib.mkOption {
      description = "Enabled Noctalia built-in app templates.";
      type = lib.types.listOf lib.types.str;
      default = [
        "btop"
        "gtk3"
        "gtk4"
        "ghostty"
        "hyprland"
        "kcolorscheme"
        "niri"
        "qt"
        "starship"
      ];
    };
    templates.community = lib.mkOption {
      description = "Enabled Noctalia community app templates.";
      type = lib.types.listOf lib.types.str;
      default = [
        "claude-code"
        "sone"
        "pywalfox"
        "zen-browser"
        "discord"
        "obsidian"
        "zed"
        "heroiclauncher"
        "obs"
        "lazygit"
        "neovim"
        "spicetify-noctalia"
      ];
    };
    userTemplates = lib.mkOption {
      description = "Custom Noctalia user templates synced to live settings.";
      default = {
        papirus = {
          input_path = "~/.config/noctalia/templates/papirus-accent";
          output_path = "~/.cache/noctalia/papirus-accent";
          post_hook = "papirus-accent";
        };
        tmux = {
          input_path = "~/.config/noctalia/templates/tmux.conf";
          output_path = "~/.config/tmux/themes/noctalia.conf";
          post_hook = "tmux source-file -q ~/.config/tmux/themes/noctalia.conf 2>/dev/null || true";
        };
      };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            input_path = lib.mkOption { type = lib.types.str; };
            output_path = lib.mkOption { type = lib.types.str; };
            post_hook = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
          };
        }
      );
    };
  };

  config = {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };

    # Bar icons that only show while on (enabled via gav.noctalia.plugins).
    xdg.dataFile."noctalia/plugins/status".source = ./noctalia/plugins/status;

    # One wallpaper folder per theme.
    home.file."Pictures/themes".source = "${inputs.wallpapers}/themes";

    # --- First-run copies ---
    # Only copies a file that isn't there yet.
    home.activation.seedNoctaliaTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      seedNoctalia() {
        if [ ! -e "$2" ]; then
          run mkdir -p "$(dirname "$2")"
          run cp "$1" "$2"
          run chmod u+w "$2"
        fi
      }
      ${lib.optionalString sessions.mango "seedNoctalia ${inputs.dotfiles}/mango/noctalia.conf ${config.xdg.configHome}/mango/noctalia.conf"}
      ${lib.optionalString sessions.niri "seedNoctalia ${inputs.dotfiles}/niri/noctalia.kdl ${config.xdg.configHome}/niri/noctalia.kdl"}
      seedNoctalia ${inputs.dotfiles}/ghostty/themes/noctalia ${config.xdg.configHome}/ghostty/themes/noctalia
      # Empty placeholder so Hyprland's config loads before Noctalia's first run.
      seedNoctalia ${pkgs.writeText "noctalia-lua-stub" ''
        -- Seeded by home-manager; Noctalia overwrites with theme colors.
      ''} ${config.xdg.configHome}/hypr/noctalia.lua

      seedNoctalia ${./noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
    '';

    # Restart Noctalia when plugin code changes, and sync declared plugins + templates.
    home.activation.syncNoctalia = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
            n=${config.programs.noctalia.package}/bin/noctalia
            pdir="${config.xdg.dataHome}/noctalia/plugins"
            stamp="${config.xdg.cacheHome}/noctalia-plugin-targets"

            if [ -d "$pdir" ]; then
              cur=$(for p in "$pdir"/*; do [ -e "$p" ] && printf '%s=%s\n' "$(basename "$p")" "$(readlink -f "$p")"; done | sort)
              if [ -f "$stamp" ] && [ "$(cat "$stamp")" != "$cur" ]; then
                if ${pkgs.systemd}/bin/systemctl --user is-active -q noctalia.service 2>/dev/null; then
                  run ${pkgs.systemd}/bin/systemctl --user restart noctalia.service || true
                  for _ in 1 2 3 4 5 6; do
                    $n msg config-get plugins.enabled >/dev/null 2>&1 && break
                    sleep 0.5
                  done
                fi
              fi
              run mkdir -p "$(dirname "$stamp")"
              printf '%s\n' "$cur" >"$stamp"
            fi

            if $n msg config-get plugins.enabled >/dev/null 2>&1; then
              run ${pkgs.python3}/bin/python3 -I - "$n" "${syncData}" <<'PY' || true
      import json, subprocess, sys, tomllib

      noctalia, data_path = sys.argv[1], sys.argv[2]
      want = json.load(open(data_path))

      def get_toml(key):
          r = subprocess.run([noctalia, "msg", "config-get", key], capture_output=True, text=True)
          if r.returncode != 0 or not r.stdout.strip():
              return None
          txt = r.stdout.strip()
          try:
              return tomllib.loads(f"v = {txt}")["v"]
          except Exception:
              try:
                  return tomllib.loads(txt)
              except Exception:
                  return None

      def toml_str(s):
          return "'" + s + "'" if "'" not in s else json.dumps(s)

      def toml_list(xs):
          return "[ " + ", ".join(toml_str(x) for x in xs) + " ]"

      def set_val(key, raw):
          subprocess.run([noctalia, "msg", "config-set", key, raw], check=False, stdout=subprocess.DEVNULL)

      enabled = get_toml("plugins.enabled") or []
      for pid in want["plugins"]:
          if pid not in enabled:
              subprocess.run([noctalia, "msg", "plugins", "enable", pid], check=False, stdout=subprocess.DEVNULL)

      for key, field in [
          ("theme.templates.builtin_ids", "builtinTemplates"),
          ("theme.templates.community_ids", "communityTemplates"),
      ]:
          cur = get_toml(key)
          if cur is not None and sorted(cur) != sorted(want[field]):
              set_val(key, toml_list(want[field]))

      cur_user = get_toml("theme.templates.user") or {}
      for name, tpl in want["userTemplates"].items():
          existing = cur_user.get(name) if isinstance(cur_user, dict) else None
          cur_out = existing.get("output_path") if isinstance(existing, dict) else None
          if not isinstance(existing, dict) or existing.get("input_path") != tpl["input_path"]:
              set_val(f"theme.templates.user.{name}.input_path", toml_str(tpl["input_path"]))
          if cur_out != [tpl["output_path"]]:
              set_val(f"theme.templates.user.{name}.output_path", toml_list([tpl["output_path"]]))
          if not isinstance(existing, dict) or existing.get("post_hook", "") != tpl["post_hook"]:
              set_val(f"theme.templates.user.{name}.post_hook", toml_str(tpl["post_hook"]))
      PY
            fi
    '';
  };
}
