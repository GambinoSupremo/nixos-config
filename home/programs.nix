# Per-app home-manager config: Zen, git, neovim (LazyVim link), OBS, Satty, mime
# defaults, and desktop-entry overrides (Signal keyring pin, Vesktop VPN bypass).
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # ── Zen Browser ──────────────────────────────────────────────────────────────
  # Firefox Sync owns extensions, bookmarks and logins (fresh machine: install
  # Keeper first, it holds the Sync password). Nix sets what Sync doesn't carry.
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    profiles.default = {
      # force: HM owns search.json.mozlz4, so hand-added engines don't survive rebuilds.
      search = {
        force = true;
        default = "kagi";
        engines = {
          kagi = {
            name = "Kagi";
            urls = [
              { template = "https://kagi.com/search?q={searchTerms}"; }
              {
                template = "https://kagi.com/api/autosuggest?q={searchTerms}";
                type = "application/x-suggestions+json";
              }
            ];
            icon = "https://kagi.com/favicon.ico";
            definedAliases = [ "@k" ];
          };
        }
        # The Kagi extension's duplicate engine plus built-ins we never use.
        //
          lib.genAttrs
            [
              "search@kagi.comdefault"
              "google"
              "bing"
              "amazondotcom-us"
              "ebay"
              "perplexity"
            ]
            (_: {
              metaData.hidden = true;
            });
      };

      settings = {
        "zen.welcome-screen.seen" = true;
        # Each window stands alone instead of mirroring tabs into new ones.
        "zen.window-sync.enabled" = false;
        # Noctalia theming: userChrome.css imports its colors, Pywalfox needs themes on.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "zen.theme.disable-lightweight" = false;
        # Mullvad owns DNS; Zen's DoH stalls on-VPN and hangs Keeper's login.
        "network.trr.mode" = 5;
        "doh-rollout.disable-heuristics" = true;

        # Privacy: strict tracking protection, GPC + DNT, HTTPS-only.
        "browser.contentblocking.category" = "strict";
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "dom.security.https_only_mode" = true;
        # Keeper fills logins and forms, not Zen.
        "signon.rememberSignons" = false;
        "browser.formfill.enable" = false;
        # No sponsored suggestions, Pocket, studies or default-browser nag.
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "extensions.pocket.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "browser.shell.checkDefaultBrowser" = false;
      };
    };
  };

  # Live Noctalia colors: zen-live.css maps Noctalia's Zen CSS onto Pywalfox's vars.
  # Noctalia rewrites userChrome.css but keeps extra lines, so append the import once.
  home.file.".config/zen/default/chrome/zen-live.css".source = ./noctalia/zen-live.css;
  home.activation.zenLiveImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chrome="${config.home.homeDirectory}/.config/zen/default/chrome/userChrome.css"
    if ! grep -qs 'zen-live.css' "$chrome"; then
      run mkdir -p "$(dirname "$chrome")"
      run sh -c "echo '@import \"zen-live.css\";' >> '$chrome'"
    fi
  '';

  # Same id as the package's entry (~/.local/share wins), minus "(Beta)" in the name.
  xdg.desktopEntries.zen-beta = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "zen-beta --name zen-beta %U";
    icon = "zen-browser";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupNotify = true;
    settings.StartupWMClass = "zen-beta";
    actions.new-private-window = {
      name = "New Private Window";
      exec = "zen-beta --private-window %U";
    };
  };

  # Pywalfox's native host for Zen, without programs.firefox pulling in Firefox.
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Pywalfox native app";
    path = "${pkgs.pywalfox-native}/bin/pywalfox";
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };

  # ── Default apps (mime associations) ─────────────────────────────────────────
  # Canon RAW opens in nomacs (loupe can't read it); declared here because
  # nomacs' .desktop doesn't advertise the RAW mime types.
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
      "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
    };
    # Text/code in Zed; mkForce beats zen's setAsDefaultBrowser claim on text/plain + json.
    defaultApplications =
      lib.genAttrs [
        "text/plain"
        "text/markdown"
        "text/x-log"
        "text/csv"
        "text/x-nix"
        "text/x-python"
        "text/x-shellscript"
        "application/x-shellscript"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-c++src"
        "text/rust"
        "text/javascript"
        "application/json"
        "application/toml"
        "application/x-yaml"
        "application/xml"
        "text/x-ini"
        "application/x-zerosize"
      ] (_: lib.mkForce [ "dev.zed.Zed.desktop" ])
      // {
        # Folders (e.g. Steam "Browse local files") — otherwise falls back to kitty-open.
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
        "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
      };
  };

  # ── Git ──────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "Gavin";
      user.email = "service.haiku882@passinbox.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ───────────────────────────────────────────────────────────────────
  # LazyVim config linked live from the dotfiles checkout (not the pinned input)
  # so lazy.nvim can write lazy-lock.json. neovim itself is in systemPackages.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/dotfiles/nvim";
  home.sessionVariables.EDITOR = "nvim";
  home.packages = [
    (pkgs.writeShellScriptBin "vim" ''exec nvim "$@"'')
    # nvim-treesitter (main branch) compiles parsers with these.
    pkgs.gcc
    pkgs.tree-sitter
  ];

  # ── OBS Studio ───────────────────────────────────────────────────────────────
  # obs-vaapi → VA-API (NVDEC) encoding; obs-vkcapture → GPU-side game capture.
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi
      obs-vkcapture
    ];
  };

  # ── Satty ────────────────────────────────────────────────────────────────────
  # Noctalia pipes region screenshots here (shell.screenshot in noctalia config.toml).
  # Enter copies + exits, Ctrl+S saves to output-filename.
  programs.satty = {
    enable = true;
    settings.general = {
      fullscreen = false;
      early-exit = true;
      copy-command = "wl-copy";
      corner-roundness = 12;
      initial-tool = "arrow";
      output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/Screenshot-%Y-%m-%d_%H-%M-%S.png";
    };
  };

  # ── Signal ───────────────────────────────────────────────────────────────────
  # Pin gnome-libsecret (key lives there); id "signal" replaces the package entry.
  xdg.desktopEntries.signal = {
    name = "Signal";
    exec = "signal-desktop --password-store=gnome-libsecret %U";
    icon = "signal-desktop";
    comment = "Private messaging from your desktop";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [
      "x-scheme-handler/sgnl"
      "x-scheme-handler/signalcaptcha"
    ];
  };

  # ── Vesktop ──────────────────────────────────────────────────────────────────
  # Every launcher path goes through mullvad-exclude or Discord won't connect.
  # Compositor autostarts handle themselves (dotfiles / home/dotfiles.nix).
  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    exec = "mullvad-exclude vesktop %U";
    icon = "vesktop";
    comment = "Vesktop — Discord via Mullvad split tunnel";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
  };

  # ── Sunshine ─────────────────────────────────────────────────────────────────
  # Runs as a user service; the menu entry opens the web UI instead of a 2nd copy.
  xdg.desktopEntries."dev.lizardbyte.app.Sunshine" = {
    name = "Sunshine";
    exec = "xdg-open https://localhost:47990";
    icon = "dev.lizardbyte.app.Sunshine";
    comment = "Sunshine web UI";
    categories = [
      "RemoteAccess"
      "Network"
    ];
  };
}
