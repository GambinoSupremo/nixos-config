{
  description = "gav's nixos configuration";

  # Noctalia binary cache — prebuilt noctalia packages when available
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

    # Noctalia v5 — native Wayland shell (C++/OpenGL ES; no longer built on
    # Quickshell). home/default.nix imports homeModules.default, which
    # provides programs.noctalia.* and the noctalia.service user unit.
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
          # TEMPORARY compatibility aliases for top-level nixpkgs attributes
          # that were converted to throw aliases (2025-10-27 cleanup batch).
          # Our own references use the modern names; these exist only so any
          # stale expression inside a flake input keeps evaluating. Applies to
          # Home Manager too via useGlobalPkgs. Remove once input updates stop
          # needing them.
          {
            nixpkgs.overlays = [
              (final: prev: {
                qt6ct            = final.qt6Packages.qt6ct;
                noto-fonts-emoji = final.noto-fonts-color-emoji;
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
