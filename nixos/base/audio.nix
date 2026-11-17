# Sound: PipeWire, sample rates, and friendly names for my devices.
_:

{
  security.rtkit.enable = true; # lets PipeWire run at high priority

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # Steam and other 32-bit apps
    pulse.enable = true;

    # This module crashes PipeWire when Xwayland exits (kills Vesktop audio).
    extraConfig.pipewire."99-no-x11-bell" = {
      "context.properties"."module.x11.bell" = false;
    };

    # --- Sample rates ---
    # Play each stream at its own rate instead of converting everything to 48k.
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

    # Best conversion quality when two rates do have to share the DAC.
    extraConfig.client."99-resample-quality" = {
      "stream.properties"."resample.quality" = 10;
    };
    extraConfig.pipewire-pulse."99-resample-quality" = {
      "stream.properties"."resample.quality" = 10;
    };

    # --- Devices ---
    # Hide the monitor's audio and the onboard line-in; name the rest.
    wireplumber.extraConfig."99-audio-devices"."monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_03_00.1"; } ];
        actions.update-props."device.disabled" = true;
      }
      {
        matches = [ { "node.name" = "~alsa_output.usb-iFi__by_AMR_.*"; } ];
        actions.update-props = {
          "node.description" = "Headphones";
          "node.nick" = "Headphones";
        };
      }
      {
        matches = [ { "node.name" = "alsa_output.pci-0000_12_00.6.analog-stereo"; } ];
        actions.update-props = {
          "node.description" = "Speakers";
          "node.nick" = "Speakers";
        };
      }
      {
        matches = [ { "node.name" = "~alsa_input.usb-Native_Instruments_Komplete_Audio_2.*"; } ];
        actions.update-props = {
          "node.description" = "Mic";
          "node.nick" = "Mic";
        };
      }
      {
        matches = [ { "node.name" = "alsa_input.pci-0000_12_00.6.analog-stereo"; } ];
        actions.update-props."node.disabled" = true;
      }
    ];
  };
}
