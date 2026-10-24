{
  description = "gav's nixos configuration";

  inputs = {
    # Rolling unstable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not in nixpkgs; homeModules.beta provides programs.zen-browser.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Consumed as a plain source tree and built against the system Hyprland so
    # the plugin ABI matches (the repo's own flake targets Hyprland master).
    hyprland-scroll-overview = {
      url = "github:yayuuu/hyprland-scroll-overview";
      flake = false;
    };

    # Dotfiles deployed declaratively via home-manager (see home/default.nix)
    dotfiles = {
      url = "github:GambinoSupremo/dotfiles";
      flake = false;
    };

    wallpapers = {
      url = "github:GambinoSupremo/wallpapers";
      flake = false;
    };

    # Deadlock Mod Manager from upstream, pinned to a release tag (nixpkgs lags at 1.1.0).
    # No nixpkgs.follows so the build matches their Cachix cache (gaming.nix).
    # Go back to pkgs.deadlock-mod-manager once nixpkgs catches up.
    deadlock-mod-manager.url = "github:deadlock-mod-manager/deadlock-mod-manager/v2.1.1";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      # Shared home-manager config block applied to every host. (A commonOverlay
      # of throw-alias shims was removed 2026-07-14 — git history has it.)
      hmModule =
        { host, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs host; };
            users.gav = import ./home/default.nix;
            # Pre-existing files that home-manager would clobber are moved aside
            # as *.hm-bak instead of aborting the activation.
            backupFileExtension = "hm-bak";
          };
        };

      # Per-host facts live only here; NixOS and home-manager get them as `host`
      # (host.name is the flake output, which differs from hostName).
      mkHost =
        name:
        { hostName, isVM }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            host = { inherit name hostName isVM; };
          };
          modules = [
            ./nixos/hosts/${name}/configuration.nix
            { networking.hostName = hostName; }
            home-manager.nixosModules.home-manager
            hmModule
          ];
        };
    in
    {
      nixosConfigurations = {

        # Build-only target for the shared modules (no VM deployed)
        vm = mkHost "vm" {
          hostName = "nix-vm";
          isVM = true;
        };

        # Physical desktop
        desktop = mkHost "desktop" {
          hostName = "gavos";
          isVM = false;
        };
      };
    };
}
