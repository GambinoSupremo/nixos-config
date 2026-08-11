# Shared basics for every host: locale/time, nix daemon + GC settings,
# allowUnfree, stateVersion. Kernel and boot loader are per-host.
{ config, pkgs, lib, ... }:

{
  # ── Boot ─────────────────────────────────────────────────────────────────────
  # Boot loader, kernel, and Plymouth are all per-host (nixos/hosts/*).
  # Don't re-add chaotic-nyx for linux-cachyos: its module forces from-source
  # rebuilds of the base system and its overlay drops allowUnfree (breaks NVIDIA).

  # ── Locale / Time ─────────────────────────────────────────────────────────────
  time.timeZone      = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # ── Nix ───────────────────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
      trusted-users         = [ "root" "gav" ];
      warn-dirty            = false;
      # Default max-jobs of 1 makes rebuilds painfully sequential on this Ryzen.
      max-jobs              = "auto";
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 14d";
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

  # electron 40 went EOL 2026-07-15; tidal-hifi/obsidian still pin it.
  # Drop once nixpkgs bumps them.
  nixpkgs.config.permittedInsecurePackages = [ "electron-40.10.5" ];

  # ── System version ────────────────────────────────────────────────────────────
  # Do NOT change after first install — controls stateful service migrations.
  system.stateVersion = "26.05";
}
