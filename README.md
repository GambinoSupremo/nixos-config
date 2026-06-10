# nixos-config

Nix translation of the CachyOS setup (pacman-explicit.txt → nixpkgs equivalents).
Targeting nixos-unstable for a rolling-adjacent experience.

## Sessions

SDDM (Wayland greeter) with three sessions; **mango** is the default
(`services.displayManager.defaultSession = "mango"`):

| Session    | Source                              | Session name |
|------------|-------------------------------------|--------------|
| MangoWM    | `inputs.mangowm` NixOS module       | `mango`      |
| Niri       | `programs.niri` (nixpkgs)           | `niri`       |
| Hyprland   | `programs.hyprland` (nixpkgs)       | `hyprland`   |

Noctalia v5 runs as a systemd user service (`noctalia.service`, binary
`noctalia`). Niri and Hyprland start it via `graphical-session.target`;
Mango starts it explicitly from its patched `autostart.conf`.

Dotfiles come from the `dotfiles` flake input (GambinoSupremo/dotfiles),
patched for NixOS in `home/default.nix` (no `/usr/bin` paths, portals via
dbus activation, Noctalia runtime theme files kept writable). To pull new
dotfiles: `nix flake update dotfiles` then rebuild.

## Validation

```bash
# Rebuild
sudo nixos-rebuild switch --flake .#vm --show-trace

# Home Manager applied?
sudo systemctl status home-manager-gav.service --no-pager

# Sessions registered? (expect mango.desktop, niri.desktop, hyprland.desktop)
ls -la /run/current-system/sw/share/wayland-sessions

# Noctalia running? (note: service is `noctalia`, not `noctalia-shell`)
systemctl --user status noctalia.service --no-pager
journalctl --user -b -u noctalia.service --no-pager -n 200
```

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
| `noctalia-git` / `noctalia-shell` | Available via flake: `github:noctalia-dev/noctalia-shell`. HM module provides `programs.noctalia` (v5; binary is `noctalia`). |
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
| `nordzy-icon-theme`          | In nixpkgs as `nordzy-icon-theme`. |
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
