# Shared basics for every host: locale/time, nix daemon + GC settings,
# allowUnfree, stateVersion. Kernel and boot loader are per-host.
{ config, pkgs, lib, ... }:

{
  # ── Boot ─────────────────────────────────────────────────────────────────────
  # Boot loader is configured per-host (nixos/hosts/*/configuration.nix) since VM and
  # physical machines need different loaders.

  # Kernel: this shared module sets NOTHING, so each host gets the nixpkgs DEFAULT
  # (pkgs.linuxPackages) unless it overrides. The VM stays on the default (stable,
  # conservative). The desktop overrides to pkgs.linuxPackages_latest (mainline
  # 7.x) in nixos/hosts/desktop/configuration.nix.
  #
  # Historical note: an earlier theory blamed linuxPackages_latest (kernel 7.1.1)
  # for the AW3423DW scanout bug. That was WRONG — the bug is intermittent and was
  # isolated to the NVIDIA 595 driver branch (now on 610); the kernel is exonerated.
  # So linuxPackages_latest is a fine, fully-cached way to be on kernel 7.
  #
  # linux-cachyos (BORE, etc.) is NOT in nixpkgs. We tried it via the chaotic-nyx
  # flake and abandoned it: its broad module forces a from-source rebuild of the
  # whole base system, and its cache-friendly overlay drops allowUnfree (breaks
  # NVIDIA). Don't re-add chaotic without solving both.

  # Plymouth boot animation is configured per-host (desktop has it; the VM
  # doesn't need a splash).

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
      # Build one derivation per CPU core — the default (1) makes rebuilds
      # painfully sequential on a multi-core Ryzen.
      max-jobs              = "auto";
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
  system.stateVersion = "26.05";
}
