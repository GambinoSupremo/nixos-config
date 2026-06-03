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

    # Noctalia shell — provides homeModules.default and programs.noctalia-shell
    # Also in nixpkgs-unstable as pkgs.noctalia-shell, but flake gives the HM module
    noctalia = {
      url   = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # zen-browser is not in nixpkgs
    zen-browser = {
      url   = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs    = true;
              useUserPackages  = true;
              extraSpecialArgs = { inherit inputs; };
              users.gav        = import ./home/default.nix;
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
