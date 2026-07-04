{ config, pkgs, ... }:

{
  # rtkit lets PipeWire claim real-time scheduling priority safely
  security.rtkit.enable = true;

  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    alsa.support32Bit  = true;   # required for 32-bit apps and Steam (lib32-pipewire)
    pulse.enable       = true;   # PulseAudio compatibility shim
    wireplumber.enable = true;
    # jack.enable = true;        # enable if you use JACK audio apps
  };
}
