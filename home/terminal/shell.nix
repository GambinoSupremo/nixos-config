# Fish shell: shared dotfiles config, the apply/update commands, and small helpers.
{
  pkgs,
  host,
  inputs,
  ...
}:

let
  # The script behind apply, update, dotsync and save.
  nixosSync = pkgs.writeShellApplication {
    name = "nixos-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
      pkgs.nh
      pkgs.coreutils
      pkgs.gnused
      pkgs.util-linux # script(1): keeps the sudo prompt on a TTY while logging
      pkgs.dix
    ];
    runtimeEnv.NIXOS_SYNC_HOST = host.name;
    text = builtins.readFile ./nixos-sync.sh;
  };

  # Shared by iso2usb and format-drive: only USB disks, chosen by typing the name.
  pickUsb = ''
    mapfile -t disks < <(lsblk -dnpo PATH,TRAN,SIZE,MODEL | awk '$2 == "usb"')
    [ "''${#disks[@]}" -gt 0 ] || { echo "No USB drive plugged in."; exit 1; }
    printf '%s\n' "''${disks[@]}"
    read -rp "Type the drive to ERASE (e.g. /dev/sdX): " dev
    printf '%s\n' "''${disks[@]}" | awk '{print $1}' | grep -qx -- "$dev" \
      || { echo "$dev is not a USB drive in the list."; exit 1; }
    read -rp "Everything on $dev will be lost. Type yes: " ok
    [ "$ok" = yes ] || exit 1
  '';

  iso2usb = pkgs.writeShellApplication {
    name = "iso2usb";
    runtimeInputs = [
      pkgs.util-linux
      pkgs.gawk
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      [ -f "''${1:-}" ] || { echo "usage: iso2usb file.iso"; exit 1; }
      ${pickUsb}
      sudo dd if="$1" of="$dev" bs=4M status=progress conv=fsync oflag=direct
      echo "Done. You can unplug $dev."
    '';
  };

  format-drive = pkgs.writeShellApplication {
    name = "format-drive";
    runtimeInputs = [
      pkgs.util-linux
      pkgs.gawk
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.parted
      pkgs.exfatprogs
    ];
    text = ''
      ${pickUsb}
      label=''${1:-USB}
      sudo wipefs -a "$dev"
      sudo parted -s "$dev" mklabel gpt mkpart "$label" 1MiB 100%
      sudo udevadm settle
      part=$(lsblk -lnpo PATH "$dev" | sed -n 2p)
      sudo mkfs.exfat -L "$label" "$part"
      echo "Wiped and formatted $dev as exFAT ($label); works on Linux, Mac and Windows."
    '';
  };
in
{
  home.packages = [
    pkgs.krabby # the Pokémon in the greeting
    pkgs.ouch # compress / decompress any archive type
    iso2usb
    format-drive
  ];

  # --- Fish ---
  # Shared greeting, abbreviations and krabby live in dotfiles/fish/conf.d/shared.fish.
  xdg.configFile."fish/conf.d/shared.fish".source = "${inputs.dotfiles}/fish/conf.d/shared.fish";

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#${host.name}";
    };
    functions = {
      apply = "${nixosSync}/bin/nixos-sync apply";
      update = "${nixosSync}/bin/nixos-sync update";
      dotsync = "${nixosSync}/bin/nixos-sync dotsync";
      save = "${nixosSync}/bin/nixos-sync save";
    };
  };

  # Searchable shell history on Ctrl+R (Up arrow stays Fish's default).
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      auto_sync = false;
      update_check = false;
      style = "compact";
      inline_height = 16;
    };
  };

  # --- Helpers ---
  # `tldr <cmd>`: short example-first help.
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };

  programs.tmux = {
    enable = true;
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    terminal = "tmux-256color";
    # Theme colors, written + reloaded by Noctalia on every theme change.
    extraConfig = "source-file -q ~/.config/tmux/themes/noctalia.conf";
  };
  xdg.configFile."noctalia/templates/tmux.conf".source = ./tmux-noctalia.conf;

  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # it would take over Ctrl+T
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Auto-load Nix dev shells when entering a project folder.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "plain";
    };
  };

  # Lets one-off nix-shell / nix-env use unfree packages too.
  xdg.configFile."nixpkgs/config.nix" = {
    force = true;
    text = "{ allowUnfree = true; }\n";
  };
}
