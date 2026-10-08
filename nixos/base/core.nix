# Shared basics for every host: locale/time, nix daemon + GC settings,
# allowUnfree, stateVersion. Kernel and boot loader are per-host.
{ pkgs, ... }:

{
  # ── Boot ─────────────────────────────────────────────────────────────────────
  # Boot loader, kernel, and Plymouth are all per-host (nixos/hosts/*).
  # Don't re-add chaotic-nyx for linux-cachyos: its module forces from-source
  # rebuilds of the base system and its overlay drops allowUnfree (breaks NVIDIA).

  # ── Locale / Time ─────────────────────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Nix ───────────────────────────────────────────────────────────────────────
  nix = {
    # Newest Nix release rather than nixpkgs' default.
    package = pkgs.nixVersions.latest;
    settings = {
      # CachyOS kernel cache (nix-cachyos-kernel); noctalia's comes via flake nixConfig.
      extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
      extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
      # That cache is IPv6-only, unreachable through Mullvad (IPv6 off); give up fast.
      download-attempts = 2;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "gav"
      ];
      warn-dirty = false;
      # Default max-jobs of 1 makes rebuilds painfully sequential on this Ryzen.
      max-jobs = "auto";
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ── nix-ld ────────────────────────────────────────────────────────────────────
  # Lets prebuilt dynamically-linked binaries (e.g. the Claude Code agent SDK
  # that Zed downloads via npx) find a libc/loader outside the Nix store.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    icu
  ];

  # Required for obsidian, vivaldi, nvidia, spotify, etc.
  nixpkgs.config.allowUnfree = true;

  # ── System version ────────────────────────────────────────────────────────────
  # Do NOT change after first install — controls stateful service migrations.
  system.stateVersion = "26.05";
}
