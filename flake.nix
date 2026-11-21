# The entry point: where everything is downloaded from (inputs) and the two
# systems built from it (outputs): desktop and the vm test build.
{
  description = "gav's nixos configuration";

  # --- Where things come from ---
  inputs = {
    # The main package collection, rolling release.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Manages my home folder settings (home/).
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen browser isn't in nixpkgs.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # My desktop config files (home/desktop/dotfiles.nix puts them in place).
    dotfiles = {
      url = "github:GambinoSupremo/dotfiles";
      flake = false;
    };

    # Private repo. Shallow so it skips old history.
    wallpapers = {
      url = "git+ssh://git@github.com/GambinoSupremo/wallpapers?shallow=1";
      flake = false;
    };

    # Straight from the developers because nixpkgs has an old version.
    # No nixpkgs.follows, so it downloads prebuilt (gaming.nix).
    # Go back to pkgs.deadlock-mod-manager once nixpkgs catches up.
    deadlock-mod-manager.url = "github:deadlock-mod-manager/deadlock-mod-manager/v2.1.1";

    # Personal settings kept out of this public repo.
    private.url = "git+ssh://git@github.com/GambinoSupremo/nixos-private";

    # Firefox extensions for web apps, updated with `update`.
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # --- What gets built ---
  outputs =
    { nixpkgs, home-manager, ... }@inputs:
    let
      # Home folder settings, the same on every host.
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
            # A file already in the way is renamed to *.hm-bak instead of failing.
            backupFileExtension = "hm-bak";
          };
        };

      # Builds one system. The other files get its details as `host`
      # (host.name is "desktop" or "vm", host.hostName is the network name).
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

      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          lib = nixpkgs.lib;
          themes = import ./home/theming/theme-list.nix;
          palettes = builtins.attrNames (builtins.readDir ./home/theming/palettes);
          entries = import ./home/desktop/menu-entries.nix;
          parentOf = id: lib.concatStringsSep "." (lib.init (lib.splitString "." id));
          entryIds = map (e: e.id) entries;
          themeNames = map (t: t.name) themes;
        in
        {
          json-valid = pkgs.runCommand "check-json-valid" { nativeBuildInputs = [ pkgs.jq ]; } ''
            jq empty ${./home/apps/webapps.json}
            for f in ${./home/theming/palettes}/*.json; do
              jq empty "$f"
            done
            touch $out
          '';

          themes-valid =
            let
              dupNames = builtins.length themeNames != builtins.length (lib.unique themeNames);
              missingPalettes = map (t: t.palette) (
                builtins.filter (
                  t: t.source == "custom" && !(builtins.elem "${t.palette}.json" palettes)
                ) themes
              );
              badModes = map (t: t.name) (
                builtins.filter (t: !(builtins.elem t.mode [ "dark" "light" ])) themes
              );
            in
            assert !dupNames;
            assert missingPalettes == [ ];
            assert badModes == [ ];
            pkgs.runCommand "check-themes-valid" { } "touch $out";

          menu-valid =
            let
              dupIds = builtins.length entryIds != builtins.length (lib.unique entryIds);
              missingParents = builtins.filter (
                p: p != "" && !(builtins.elem p entryIds)
              ) (map (e: parentOf e.id) entries);
              hasChildren = id: lib.any (e: parentOf e.id == id) entries;
              deadLeaves = map (e: e.id) (
                builtins.filter (
                  e: !(hasChildren e.id) && (e.run or null) == null && (e.list or null) == null
                ) entries
              );
            in
            assert !dupIds;
            assert missingParents == [ ];
            assert deadLeaves == [ ];
            pkgs.runCommand "check-menu-valid" { } "touch $out";
        };

      nixosConfigurations = {

        # Test build only, no real VM.
        vm = mkHost "vm" {
          hostName = "nix-vm";
          isVM = true;
        };

        # My PC.
        desktop = mkHost "desktop" {
          hostName = "gavos";
          isVM = false;
        };
      };
    };
}
