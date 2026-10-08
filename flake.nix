{
  description = "gav's nixos configuration";

  # Binary caches: noctalia + CachyOS kernel. Only the CachyOS one is also in
  # core.nix nix.settings (daemon-wide); noctalia's applies only via this nixConfig.
  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  inputs = {
    # Rolling unstable; NVIDIA driver branch selected in nixos/features/nvidia.nix.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia v5 — native Wayland shell; homeModules.default provides
    # programs.noctalia.* + the noctalia.service user unit.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Not in nixpkgs; homeModules.beta provides programs.zen-browser.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # qylock — SDDM themes (login screen), "pixel-dusk-city" selected in desktop/configuration.nix
    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # CachyOS kernels (desktop host). `release` = built + cached by upstream CI.
    # No nixpkgs.follows: its pinned overlay must match the cached builds.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # For the laptop's AMD module; follows keeps a second stale nixpkgs
    # copy out of the lock file.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # Millennium — Steam client theming/plugin patcher; not in nixpkgs.
    # No nixpkgs.follows: Millennium pins its own nixpkgs on purpose because
    # its bun FOD hash breaks on any bun version change (upstream comment).
    millennium.url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
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

        # Proxmox VM — primary target for now
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
