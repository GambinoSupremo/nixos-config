{ config, pkgs, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia.modesetting.enable  = true;
  hardware.nvidia.open                = false;
  hardware.nvidia.nvidiaSettings      = true;
  hardware.nvidia.package             = config.boot.kernelPackages.nvidiaPackages.stable;

  hardware.graphics.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL            = "1";
    GBM_BACKEND               = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS   = "1";
  };
}
