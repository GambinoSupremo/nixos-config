# !! This file must be generated on the target laptop, not written by hand !!
#
# On the laptop, run:
#   sudo nixos-generate-config --show-hardware-config > /path/to/this/file
#
# Then commit the result. The placeholders below will cause a build failure
# intentionally so this isn't accidentally deployed without real hardware data.

{ config, lib, pkgs, modulesPath, ... }:

builtins.throw ''
  hosts/laptop/hardware-configuration.nix has not been generated yet.
  Run: sudo nixos-generate-config --show-hardware-config
  on the target laptop and replace this file with the output.
''
