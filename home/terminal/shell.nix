# Fish shell: greeting, aliases, the apply/update commands, and small helpers.
{ pkgs, host, ... }:

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
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      fish_add_path -g ~/.local/bin  # user-installed CLIs
      # A krabby Pokémon on each new shell; 1 in 40 is shiny, with a sparkle at its top right.
      if command -q krabby
        set -l shiny
        test (random 1 40) -eq 1; and set shiny --shiny
        set -l art (krabby random --no-title $shiny 2>/dev/null)
        # Drop krabby's blank padding rows so the prompt sits close under the sprite.
        while set -q art[1]; and test -z (string replace -ra '\e\[[0-9;]*m' "" -- $art[-1] | string trim)
          set -e art[-1]
        end
        while set -q art[1]; and test -z (string replace -ra '\e\[[0-9;]*m' "" -- $art[1] | string trim)
          set -e art[1]
        end
        if set -q art[1]
          set -q shiny[1]; and set art[1] "$art[1]  ✨"
          printf '%s\n' $art
        end
      end
    '';
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      la = "eza -la --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      tree = "eza --tree --icons --group-directories-first";
      cat = "bat";
      grep = "rg";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#${host.name}";
      compress = "ouch compress"; # compress file1 dir2 out.tar.zst
      decompress = "ouch decompress";
    };
    functions = {
      apply = "${nixosSync}/bin/nixos-sync apply";
      update = "${nixosSync}/bin/nixos-sync update";
      dotsync = "${nixosSync}/bin/nixos-sync dotsync";
      save = "${nixosSync}/bin/nixos-sync save";
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
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # it would take over Ctrl+T
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
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
