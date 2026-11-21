# AMD graphics card (RX 9070 XT): driver, fan and undervolt tool, and the
# settings games and apps need. Desktop only.
{
  config,
  lib,
  pkgs,
  ...
}:

lib.mkIf config.gav.features.amd.enable {
  # --- Driver ---
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.initrd.enable = true; # full resolution from the boot screen on
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # Steam and Proton
  environment.systemPackages = [ pkgs.libva-utils ]; # vainfo: check video encoding for Sunshine

  # --- Fan curve and undervolt (LACT) ---
  # Tuned in the LACT app, saved to /etc/lact.
  services.lact.enable = true;
  # Unlocks undervolting. The mask is the kernel default plus the overdrive bit.
  hardware.amdgpu.overdrive = {
    enable = true;
    ppfeaturemask = "0xfff7ffff";
  };

  # --- Game and app settings ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps use Wayland
    PROTON_FORCE_LARGE_ADDRESS_AWARE = "1"; # stops 32-bit games running out of memory
    PROTON_USE_NTSYNC = "1"; # needs the ntsync module (gaming.nix)
    # The default 1 GB shader cache is too small for big UE5 games; they recompile every launch.
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
  };
}
