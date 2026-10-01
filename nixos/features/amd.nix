# AMD graphics — used only by the laptop host (which is kept as a spare
# and is not wired into flake.nix outputs).
{ ... }:
{
  # Vulkan via RADV, which Mesa ships by default — no extraPackages needed.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # Ensure the amdgpu driver is loaded
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
}
