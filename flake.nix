{
  description = "gav's nixos configuration";

  # Noctalia binary cache — prebuilt noctalia packages when available.
  nixConfig = {
    extra-substituters      = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    # nixpkgs tracks rolling unstable. Stays fully current; nothing is frozen
    # with it. The NVIDIA driver branch is selected (not frozen) in
    # nixos/features/nvidia.nix.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url   = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MangoWM — provides nixosModules.mango and programs.mango.enable
    mangowm = {
      url   = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia v5 — native Wayland shell (C++/OpenGL ES; no longer built on
    # Quickshell). home/default.nix imports homeModules.default, which
    # provides programs.noctalia.* and the noctalia.service user unit.
    noctalia = {
      url   = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen-browser is not in nixpkgs. home/zen.nix imports homeModules.beta,
    # which provides programs.zen-browser (mirrors programs.firefox).
    zen-browser = {
      url   = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows      = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # SilentSDDM — Wayland SDDM theme with multiple presets
    silentSDDM = {
      url   = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma-manager — declarative KDE Plasma configuration via home-manager
    plasma-manager = {
      url   = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # nixos-hardware — used by nixos/hosts/laptop for AMD CPU module.
    # follows keeps its (otherwise unused) nixpkgs pin out of the lock file —
    # without it a second, months-stale nixpkgs copy lingers there.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hyprland-scroll-overview — niri-style overview plugin for Hyprland.
    # Consumed as a plain source tree (flake = false) and built with
    # pkgs.hyprlandPlugins.mkHyprlandPlugin against the system Hyprland, so the
    # plugin ABI always matches; the repo's own flake targets Hyprland master.
    hyprland-scroll-overview = {
      url   = "github:yayuuu/hyprland-scroll-overview";
      flake = false;
    };

    # Dotfiles deployed declaratively via home-manager (see home/default.nix)
    dotfiles = {
      url   = "path:/home/gav/Projects/dotfiles";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, mangowm, noctalia, zen-browser, nixos-hardware, ... }@inputs:
  let
    # (Removed 2026-07-14: a commonOverlay with qt6ct/noto-fonts-emoji
    # throw-alias shims and a fish create_manpage_completions.py stub —
    # a full desktop build without it passed, so the stale expressions it
    # papered over are gone from the inputs. Resurrect from git history if
    # an input update ever reintroduces one of those references.)

    # Shared home-manager config block applied to every host.
    hmModule = {
      home-manager = {
        useGlobalPkgs    = true;
        useUserPackages  = true;
        extraSpecialArgs = { inherit inputs; };
        users.gav        = import ./home/default.nix;
        # Pre-existing files that home-manager would clobber are moved aside
        # as *.hm-bak instead of aborting the activation.
        backupFileExtension = "hm-bak";
      };
    };
  in
  {
    nixosConfigurations = {

      # Proxmox VM — primary target for now
      vm = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/hosts/vm/configuration.nix
          home-manager.nixosModules.home-manager
          hmModule
        ];
      };

      # Physical desktop — gavos
      desktop = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/hosts/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          hmModule
        ];
      };
    };
  };
}
