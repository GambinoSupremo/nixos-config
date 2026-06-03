{ config, pkgs, lib, ... }:

{
  # ── Boot ─────────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVars      = true;

  # nixos-unstable ships recent kernels.
  # linux-cachyos (BORE scheduler, NTSYNC, etc.) is NOT in nixpkgs.
  # If you need it later, look at the chaotic-nyx flake or package it yourself.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Plymouth boot animation — uncomment if you want a splash screen
  # boot.plymouth.enable = true;

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
      # Binary caches — add cachix caches here if you set them up
      # substituters      = [ "https://cache.nixos.org" ];
      # trusted-public-keys = [ ... ];
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 14d";
    };
  };

  # Required for obsidian, vivaldi, nvidia, spotify, etc.
  nixpkgs.config.allowUnfree = true;

  # ── System version ────────────────────────────────────────────────────────────
  # Do NOT change this after first install. It controls stateful service migrations.
  # See: https://nixos.org/manual/nixos/stable/#sec-upgrading
  system.stateVersion = "25.05";
}
