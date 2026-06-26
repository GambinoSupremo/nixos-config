{ config, pkgs, lib, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.modesetting.enable  = true;
  hardware.nvidia.open                = false;
  hardware.nvidia.nvidiaSettings      = true;
  hardware.nvidia.package             = config.boot.kernelPackages.nvidiaPackages.stable;
  hardware.graphics.enable       = true;
  hardware.graphics.enable32Bit  = true;   # 32-bit libs for Steam/Proton

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
