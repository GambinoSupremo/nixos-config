# Custom options for my hosts: monitor IDs and desktop feature switches.
# Values are set in nixos/hosts/<host>/configuration.nix.
{ lib, ... }:

let
  monitorOption = name: defaults: {
    desc = lib.mkOption {
      type = lib.types.str;
      default = defaults.desc;
      description = "EDID description string for the ${name} monitor.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = defaults.model;
      description = "Short model string reported by hyprctl/ddcutil for the ${name} monitor.";
    };
  };
in
{
  options.gav = {
    monitors = {
      main = monitorOption "main" {
        desc = "Dell Inc. Dell AW3423DW #tBszGDAYBQUH";
        model = "Dell AW3423DW";
      };
      side = monitorOption "side" {
        desc = "Philips Consumer Electronics Company PHL 278E1 0x0000065F";
        model = "PHL 278E1";
      };
    };

    features = {
      amd.enable = lib.mkEnableOption "AMD GPU drivers, LACT undervolting, and Wayland/Proton env";
      gaming.enable = lib.mkEnableOption "Steam, gamescope, GameMode, scx_bpfland, and game tools";
      streaming.enable = lib.mkEnableOption "Sunshine and Steam Remote Play virtual-display streaming";
      localAi.enable = lib.mkEnableOption "Ollama local AI models (Vulkan)";
      tuning.enable = lib.mkEnableOption "zram, ananicy-cpp, and low-priority Nix builds";
      espanso.enable = lib.mkEnableOption "Espanso Wayland text expansion";
    };
  };
}
