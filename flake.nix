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
    # Rolling unstable; NVIDIA driver branch selected in nixos/features/nvidia.nix.
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

    # Noctalia v5 — native Wayland shell; homeModules.default provides
    # programs.noctalia.* + the noctalia.service user unit.
    noctalia = {
      url   = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not in nixpkgs; homeModules.beta provides programs.zen-browser.
    zen-browser = {
      url   = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows      = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # qylock — SDDM themes (login screen), "last-of-us" selected in desktop/configuration.nix
    qylock = {
      url   = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # plasma-manager — declarative KDE Plasma configuration via home-manager
    plasma-manager = {
      url   = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # For the laptop's AMD module; follows keeps a second stale nixpkgs
    # copy out of the lock file.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Consumed as a plain source tree and built against the system Hyprland so
    # the plugin ABI matches (the repo's own flake targets Hyprland master).
    hyprland-scroll-overview = {
      url   = "github:yayuuu/hyprland-scroll-overview";
      flake = false;
    };

    # Dotfiles deployed declaratively via home-manager (see home/default.nix)
    dotfiles = {
      url   = "path:/home/gav/Projects/dotfiles";
      flake = false;
    };

    # Millennium — Steam client theming/plugin patcher; not in nixpkgs.
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, mangowm, noctalia, zen-browser, nixos-hardware, ... }@inputs:
  let
    # Shared home-manager config block applied to every host. (A commonOverlay
    # of throw-alias shims was removed 2026-07-14 — git history has it.)
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
