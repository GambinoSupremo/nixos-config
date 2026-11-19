# Local AI models on the RX 9070 XT: `ollama run <model>` (e.g. qwen3:14b).
# Vulkan build: works on RDNA4 without the large ROCm stack.
{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
  };
}
