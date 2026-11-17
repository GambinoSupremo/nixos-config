# Basics for every host: time zone, Nix settings, cleanup of old builds.
# Boot loader and kernel are per host (nixos/hosts/).
{ pkgs, ... }:

{
  # --- Locale and time ---
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Nix ---
  # nh shows the progress tree and package diff when switching.
  programs.nh = {
    enable = true;
    flake = "/home/gav/nixos-config";
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      warn-dirty = false;
      # Stops "download buffer is full" stalls on big updates.
      download-buffer-size = 1024 * 1024 * 1024;
      # Under 5 GiB free, clean up during builds until 15 GiB is free.
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 15 * 1024 * 1024 * 1024;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
      persistent = true; # catch up after the PC was off
    };
  };

  # Obsidian, Steam, Spotify and friends.
  nixpkgs.config.allowUnfree = true;

  # --- Prebuilt programs ---
  # nix-ld lets downloaded binaries find the libraries they expect.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    icu
  ];

  # --- System version ---
  # Never change this after install.
  system.stateVersion = "26.05";
}
