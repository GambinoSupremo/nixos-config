{
  description = "gav's nixos configuration";

  # Noctalia binary cache — avoids compiling quickshell from source locally
  nixConfig = {
    extra-substituters      = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
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

    # Noctalia shell — only the package output is used (home/default.nix runs
    # it via a plain systemd user service). The HM module is avoided because
    # its option namespace differs between revisions.
    noctalia = {
      url   = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen-browser is not in nixpkgs
    zen-browser = {
      url   = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dotfiles deployed declaratively via home-manager (see home/default.nix)
    dotfiles = {
      url   = "github:GambinoSupremo/dotfiles";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, mangowm, noctalia, zen-browser, ... }@inputs: {
    nixosConfigurations = {

      # Proxmox VM — primary target for now
      vm = nixpkgs.lib.nixosSystem {
        system      = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/vm/default.nix
          # Temporary compatibility overlay: top-level 'qt6ct' became a throw
          # alias in nixpkgs on 2025-10-27 (moved to qt6Packages.qt6ct), but
          # older expressions in flake inputs (e.g. home-manager's qt module
          # before it switched to the scoped path) may still reference
          # pkgs.qt6ct. Home Manager picks this up too via useGlobalPkgs.
          # Remove once all inputs are updated past the rename.
          {
            nixpkgs.overlays = [
              (final: prev: {
                qt6ct = final.qt6Packages.qt6ct;
              })
            ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs    = true;
              useUserPackages  = true;
              extraSpecialArgs = { inherit inputs; };
              users.gav        = import ./home/default.nix;
              # Pre-existing files that home-manager would clobber are moved
              # aside as *.hm-bak instead of aborting the activation.
              backupFileExtension = "hm-bak";
            };
          }
        ];
      };

      # Future: physical desktop (MangoWM primary, full GPU stack)
      # desktop = nixpkgs.lib.nixosSystem {
      #   system      = "x86_64-linux";
      #   specialArgs = { inherit inputs; };
      #   modules     = [ ./hosts/desktop/default.nix ... ];
      # };
    };
  };
}
