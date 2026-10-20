# AMD Radeon RX 9070 XT (desktop only): amdgpu with early KMS, Mesa/RADV,
# Wayland/gaming session env.
{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.initrd.enable = true; # early KMS: full-res boot and greeter

  # LACT: fan curve, power limit and undervolt (tuned in its GUI, saved to /etc/lact).
  services.lact.enable = true;
  # Overdrive unlocks undervolting; the kernel default mask plus only the OD bit (0x4000).
  hardware.amdgpu.overdrive = {
    enable = true;
    ppfeaturemask = "0xfff7ffff";
  };

  # Mesa ships RADV (Vulkan) and radeonsi VA-API by default; no extraPackages.
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # 32-bit libs for Steam/Proton
  environment.systemPackages = [ pkgs.libva-utils ]; # vainfo: check VA-API encode for Sunshine

  # Single-GPU box (iGPU disabled in BIOS), so every compositor picks the 9070 XT.

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron apps use Wayland
    PROTON_FORCE_LARGE_ADDRESS_AWARE = "1"; # stops 32-bit games from OOMing
    PROTON_USE_NTSYNC = "1"; # kernel NT sync primitives (needs ntsync module)
    # Mesa's 1 GB default shader cache evicts big UE5 games, which then recompile every launch.
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
  };
}
