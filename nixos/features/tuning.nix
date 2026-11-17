# Speed tweaks borrowed from CachyOS: memory compression, process
# priorities and a few kernel settings. The kernel itself is in hosts/desktop.
{ pkgs, ... }:

{
  # --- Builds stay out of the way ---
  # Lowest priority so games win; cores is capped to keep build memory down.
  nix = {
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedClass = "best-effort";
    daemonIOSchedPriority = 7;
    settings = {
      max-jobs = 2;
      cores = 12;
    };
  };

  # --- Memory compression (zram) ---
  # Used before the swap on disk, which stays as overflow.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };

  # --- Process priorities ---
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # --- Kernel settings ---
  boot.kernel.sysctl = {
    # Tuned for zram.
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
    # Keeps big file copies from freezing the desktop.
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_writeback_centisecs" = 1500;
    "kernel.nmi_watchdog" = 0;
    "net.core.netdev_max_backlog" = 4096;
  };
}
