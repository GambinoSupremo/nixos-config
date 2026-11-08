# PipeWire audio stack: ALSA + PulseAudio shims, WirePlumber, rtkit.
_:

{
  # rtkit lets PipeWire claim real-time scheduling priority safely
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # required for 32-bit apps and Steam (lib32-pipewire)
    pulse.enable = true; # PulseAudio compatibility shim
    # jack.enable = true;        # enable if you use JACK audio apps

    # x11-bell module segfaults PipeWire when Xwayland exits (kills Vesktop audio)
    extraConfig.pipewire."99-no-x11-bell" = {
      "context.properties"."module.x11.bell" = false;
    };

    # let the graph switch to the stream's native rate instead of resampling to 48k
    extraConfig.pipewire."99-sample-rates" = {
      "context.properties"."default.clock.rate" = 44100;
      "context.properties"."default.clock.allowed-rates" = [
        44100
        48000
        88200
        96000
        176400
        192000
        352800
        384000
      ];
    };

    # best-quality resampler for when streams at different rates share the DAC (default 4)
    extraConfig.client."99-resample-quality" = {
      "stream.properties"."resample.quality" = 10;
    };
    extraConfig.pipewire-pulse."99-resample-quality" = {
      "stream.properties"."resample.quality" = 10;
    };
  };
}
