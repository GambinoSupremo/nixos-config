{
  description = "gav's nixos configuration";

  inputs = {
    # Rolling unstable.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Kernel only: zen 7.3.4 panics at boot on gavos (2026-11-13). Drop once a
    # newer zen boots; see nixos/hosts/desktop/configuration.nix.
    nixpkgs-kernel.url = "github:nixos/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";

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

    # Cached upstream compositor build; keep its own nixpkgs for cache compatibility.
    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    # Dotfiles deployed declaratively via home-manager (see home/default.nix)
    dotfiles = {
      url = "github:GambinoSupremo/dotfiles";
      flake = false;
    };

    # Private; fetched over SSH. Shallow so builds skip old history.
    wallpapers = {
      url = "git+ssh://git@github.com/GambinoSupremo/wallpapers?shallow=1";
      flake = false;
    };

    # Deadlock Mod Manager from upstream, pinned to a release tag (nixpkgs lags at 1.1.0).
    # No nixpkgs.follows so the build matches their Cachix cache (gaming.nix).
    # Go back to pkgs.deadlock-mod-manager once nixpkgs catches up.
    deadlock-mod-manager.url = "github:deadlock-mod-manager/deadlock-mod-manager/v2.1.1";

    # Personal modules kept out of this public repo (private; fetched over SSH).
    private.url = "git+ssh://git@github.com/GambinoSupremo/nixos-private";
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      # Shared home-manager config applied to every host.
      hmModule =
        { host, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs host; };
            users.gav.imports = [
              ./home/default.nix
              inputs.private.homeModules.default
            ];
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
            inputs.private.nixosModules.default
          ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

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
