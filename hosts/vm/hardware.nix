# Replace the contents of this file with the output of:
#   nixos-generate-config --root /mnt
# during initial install. The values below are typical Proxmox QEMU defaults
# but your actual UUIDs and disk layout will differ.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules        = [ "kvm-amd" ];  # or kvm-intel depending on Proxmox host
  boot.extraModulePackages  = [ ];

  # ── Filesystems ───────────────────────────────────────────────────────────────
  # Replace UUIDs with output from: lsblk -o NAME,UUID
  fileSystems."/" = {
    device  = "/dev/disk/by-uuid/REPLACE-ROOT-UUID";
    fsType  = "ext4";   # or "btrfs" if you formatted that way
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-uuid/REPLACE-BOOT-UUID";
    fsType  = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];  # or configure a swapfile/partition

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
