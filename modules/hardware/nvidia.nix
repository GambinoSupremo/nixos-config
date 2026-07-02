{ config, pkgs, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia.modesetting.enable  = true;
  # Open kernel modules (NVIDIA's recommended path for Turing+/Ampere like the
  # 3090 Ti, and what CachyOS uses by default). The proprietary modules (open=false)
  # intermittently scan the AW3423DW's desktop into a corner on Wayland — a modeset
  # bug independent of DSC (reproduces at non-DSC 144Hz too) and of the kernel
  # version. The open modules use a different modeset/scanout path.
  hardware.nvidia.open                = true;
  hardware.nvidia.nvidiaSettings      = true;
  # Driver branch: 610.43.02 (nvidiaPackages.latest), NOT stable (595.84).
  # The 595 branch intermittently scans the AW3423DW's desktop into a corner on
  # Wayland (per-boot race in the modeset/scanout path) — reproduced with BOTH
  # proprietary and open kernel modules, at DSC 175Hz and non-DSC 144Hz, and on
  # kernel 6.18.36. So it is the driver branch, not the kernel, DSC, or open-vs-
  # proprietary. The 600-series carries upstream Wayland modeset/DSC fixes that 595
  # lacks. If 610 is clean, this can later move back to .stable once stable >= 610.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;

  hardware.graphics.enable       = true;
  hardware.graphics.enable32Bit  = true;   # 32-bit libs for Steam/Proton
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver              # VA-API via NVIDIA NVDEC
  ];

  # Single-GPU box: the Ryzen iGPU is disabled in BIOS, so the RTX 3090 Ti is the
  # only GPU and every compositor (mango, niri, hyprland, KWin) selects it
  # deterministically. (An earlier theory blamed a dual-GPU/amdgpu render race and
  # blacklisted amdgpu for it; that was wrong — the real DSC scanout bug was the
  # kernel, fixed in modules/core.nix. With the iGPU off in BIOS there is no amdgpu
  # to blacklist.) nvidia-drm modeset/fbdev are left at the NixOS module defaults.

  environment.sessionVariables = {
    NIXOS_OZONE_WL    = "1";       # Electron apps use Wayland
    LIBVA_DRIVER_NAME = "nvidia";  # VA-API driver selection
    PROTON_ENABLE_NVAPI              = "1";  # NVAPI for DLSS / Reflex under Proton
    DXVK_ENABLE_NVAPI                = "1";  # NVAPI for DXVK D3D11/D3D12 path
    PROTON_FORCE_LARGE_ADDRESS_AWARE = "1";  # stops 32-bit games from OOMing
    __GL_VRR_ALLOWED                 = "1";  # enable G-Sync / VRR across all sessions
    __GL_GSYNC_ALLOWED               = "1";  # enable G-Sync-compatible path
    # GBM_BACKEND / __GLX_VENDOR_LIBRARY_NAME / WLR_NO_HARDWARE_CURSORS are
    # wlroots-specific and must NOT be set globally — they poison KWin.
    # They are instead injected per-compositor: Hyprland via hyprland.conf
    # env= lines, Mango via mango/env.conf.
    #
    # WLR_DRM_DEVICES is intentionally NOT set: NVIDIA is the only GPU, so wlroots
    # selects it on its own. Pinning a device path would only add a failure mode
    # (compositor refuses to start if the path isn't present yet).
  };
}
