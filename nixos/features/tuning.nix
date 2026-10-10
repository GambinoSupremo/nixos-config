# System tuning borrowed from CachyOS: zram, ananicy-cpp with its rules, and
# VM/IO sysctls. The kernel itself is set in hosts/desktop.
{ pkgs, ... }:

{
  # zstd zram ahead of the disk swap (disk stays as overflow, prio -1).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  boot.kernel.sysctl = {
    # Tuned for zram: swap compressed pages early, no readahead clustering.
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
    # Byte-based dirty limits keep big writes from stalling the desktop.
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_writeback_centisecs" = 1500;
    "kernel.nmi_watchdog" = 0;
    "net.core.netdev_max_backlog" = 4096;
  };
}
