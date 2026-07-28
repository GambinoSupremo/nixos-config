# NVIDIA RTX 3090 Ti (desktop only): driver-branch pin, open kernel modules,
# Wayland/gaming session env.
{ config, pkgs, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia.modesetting.enable  = true;
  # Open modules — NVIDIA's recommended path for Ampere.
  hardware.nvidia.open                = true;
  hardware.nvidia.nvidiaSettings      = true;
  # latest (610), NOT stable (595): 595 intermittently scans the AW3423DW into
  # a corner on Wayland (proven driver-branch bug). Back to .stable once >= 610.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;

  hardware.graphics.enable       = true;
  hardware.graphics.enable32Bit  = true;   # 32-bit libs for Steam/Proton
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver              # VA-API via NVIDIA NVDEC
  ];

  # Single-GPU box (iGPU disabled in BIOS) — every compositor selects the 3090 Ti
  # deterministically; no amdgpu blacklisting needed.

  environment.sessionVariables = {
    NIXOS_OZONE_WL    = "1";       # Electron apps use Wayland
    LIBVA_DRIVER_NAME = "nvidia";  # VA-API driver selection
    PROTON_ENABLE_NVAPI              = "1";  # NVAPI for DLSS / Reflex under Proton
    DXVK_ENABLE_NVAPI                = "1";  # NVAPI for DXVK D3D11/D3D12 path
    PROTON_FORCE_LARGE_ADDRESS_AWARE = "1";  # stops 32-bit games from OOMing
    PROTON_USE_NTSYNC                = "1";  # kernel NT sync primitives (needs ntsync module)
    __GL_VRR_ALLOWED                 = "1";  # enable G-Sync / VRR across all sessions
    __GL_GSYNC_ALLOWED               = "1";  # enable G-Sync-compatible path
    # wlroots vars (GBM_BACKEND etc.) must NOT be global — they poison KWin;
    # they're injected per-compositor instead. WLR_DRM_DEVICES stays unset.
  };
}
