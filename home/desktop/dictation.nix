# Dictation: Super+D starts and stops it, and what I said is typed at the cursor.
# voxtype runs the Whisper speech model on the GPU.
{
  pkgs,
  lib,
  host,
  ...
}:

let
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin";
    sha256 = "1qm7zxamlvac564c3270wqqqks5wc7532q3fqi01zbfmkiq22hir";
  };
in
lib.mkIf (!host.isVM) {
  services.voxtype = {
    enable = true;
    # Temporary: the package is missing sqlite (nixpkgs, Nov 2026).
    package = pkgs.voxtype-vulkan.overrideAttrs (o: {
      buildInputs = o.buildInputs ++ [ pkgs.sqlite ];
    });
    settings = {
      state_file = "auto"; # needed by `voxtype record toggle`
      hotkey.enabled = false; # the compositor bind does it
      audio.feedback = {
        enabled = true;
        theme = "subtle";
      };
      whisper = {
        model = "${model}";
        language = "en";
      };
      # Shortcuts are off while it types, in case Super is still held down.
      output.pre_output_command = "hyprctl eval 'hl.dispatch(hl.dsp.submap(\"dictation\"))'";
      output.post_output_command = "hyprctl eval 'hl.dispatch(hl.dsp.submap(\"reset\"))'";
      output.notification = {
        on_recording_start = true;
        on_transcription = false;
      };
    };
  };
  # The service needs sh and hyprctl on its PATH for the two commands above.
  systemd.user.services.voxtype.Service.Environment = lib.mkForce [
    "PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.which
      ]
    }:/run/current-system/sw/bin"
    "XDG_RUNTIME_DIR=%t"
  ];
}
