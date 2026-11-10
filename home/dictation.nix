# Dictation: Super+D starts/stops voxtype, which types what you said at the cursor.
# Runs Whisper large-v3-turbo on the GPU (Vulkan); the model is pinned in the store.
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
    package = pkgs.voxtype-vulkan;
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
      output.notification = {
        on_recording_start = true;
        on_transcription = false;
      };
    };
  };
}
