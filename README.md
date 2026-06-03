# nixos-config

Nix translation of the CachyOS setup (pacman-explicit.txt → nixpkgs equivalents).
Targeting nixos-unstable for a rolling-adjacent experience.

## Quick start

```bash
# 1. Boot NixOS ISO, partition, mount at /mnt
# 2. Run nixos-generate-config --root /mnt
# 3. Copy the generated hardware-configuration.nix values into hosts/vm/hardware.nix
# 4. Clone this repo to /mnt/etc/nixos (or anywhere)
# 5. nixos-install --flake .#vm
# 6. Reboot, then: home-manager switch --flake .#gav (if managing separately)
```

## Not in nixpkgs — notable gaps

| CachyOS package              | Status                                              |
|------------------------------|-----------------------------------------------------|
| `mangowm`                    | Available via flake: `github:mangowm/mango`. NixOS module + `programs.mango.enable`. |
| `noctalia-git` / `noctalia-shell` | Available via flake: `github:noctalia-dev/noctalia-shell`. Also in `pkgs.noctalia-shell` (nixpkgs-unstable). HM module provides `programs.noctalia-shell`. |
| `scenefx0.4`                 | Likely bundled in the MangoWM flake output. Verify after enabling. |
| `cachyos-*` / `cachy-update` | CachyOS-specific. No NixOS equivalents needed. |
| `chwd`                       | CachyOS hardware detection. Not needed. |
| `limine-mkinitcpio-hook`     | CachyOS-specific. Not needed (using systemd-boot). |
| `millennium`                 | Steam Millennium patcher. Not in nixpkgs. |
| `moondeckbuddy-appimage`     | Not in nixpkgs. Run as AppImage or skip for VM. |
| `keeper-password-manager`    | Not in nixpkgs. Use Flatpak or web vault. |
| `lunatask`                   | Closed-source. Not in nixpkgs. |
| `cider`                      | Apple Music client. Not in nixpkgs. |
| `tidal-hifi-tidaluna`        | `tidal-hifi` (base) is in nixpkgs; tidaluna variant is not. |
| `fluxer-bin`                 | Not identified / not in nixpkgs. |
| `dgop`                       | Not identified / not in nixpkgs. |
| `shelly`                     | Not in nixpkgs (possibly proprietary SSH client). |
| `sddm-silent-theme-git`      | AUR only. Package manually or use default SDDM theme. |
| `nordzy-icon-theme`          | AUR only. Not in nixpkgs. |
| `python-pywalfox`            | AUR only. |
| `opencode-bin`               | Not in nixpkgs. |
| `gemini-cli`                 | Check nixpkgs; may be `google-gemini-cli` or absent. |

## Name changes (CachyOS → nixpkgs)

| CachyOS                    | nixpkgs                                      |
|----------------------------|----------------------------------------------|
| `adw-gtk-theme`            | `adw-gtk3`                                   |
| `bibata-cursor-theme-bin`  | `bibata-cursors`                             |
| `noto-fonts-cjk`           | `noto-fonts-cjk-sans`                        |
| `ttf-meslo-nerd`           | `nerd-fonts.meslo-lg`                        |
| `ttf-dejavu`               | `dejavu_fonts`                               |
| `ttf-liberation`           | `liberation_ttf`                             |
| `ttf-opensans`             | `open-sans`                                  |
| `ttf-bitstream-vera`       | `bitstream-vera`                             |
| `kvantum`                  | `kdePackages.qtstyleplugin-kvantum`          |
| `qt5ct-kde`                | `libsForQt5.qt5ct`                           |
| `zed`                      | `zed-editor`                                 |
| `vlc-plugins-all`          | `vlc` (plugins included)                     |
| `spotify-launcher`         | `spotify`                                    |
| `ollama-cuda`              | `services.ollama` + `acceleration = "cuda"`  |
| `openrazer-meta-git`       | `hardware.openrazer.enable = true`           |
| `xdg-desktop-portal-wlr`  | Only for wlroots compositors (MangoWM). Not applicable to Niri. |

## Managed via NixOS options (not systemPackages)

- `bluez` / `bluez-utils` → `hardware.bluetooth.enable`
- `networkmanager` → `networking.networkmanager.enable`
- `pipewire*` / `wireplumber` → `services.pipewire.*`
- `sddm` → `services.displayManager.sddm.enable`
- `keyd` → `services.keyd`
- `gamemode` → `programs.gamemode.enable`
- `openssh` → `services.openssh.enable`
- `flatpak` → `services.flatpak.enable`
- `mullvad-vpn` → `services.mullvad-vpn.enable`
- `ufw` → replaced by `networking.firewall` (nftables)
- `snapper` → `services.snapper`
- `power-profiles-daemon` → `services.power-profiles-daemon.enable`
- `profile-sync-daemon` → `services.psd.enable`
- `sunshine` → `services.sunshine.*`
- `plocate` → `services.locate.package = pkgs.plocate`
