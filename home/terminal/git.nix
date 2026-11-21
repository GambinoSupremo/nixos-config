# Git identity, commit hooks, and SSH hosts.
{ ... }:

{
  # --- Git ---
  programs.git = {
    enable = true;
    settings = {
      user.name = "Gavin";
      user.email = "service.haiku882@passinbox.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # Side-by-side color git diffs; base16 follows the terminal theme.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      side-by-side = true;
      line-numbers = true;
      navigate = true;
      syntax-theme = "base16";
    };
  };

  # No settings here: Noctalia writes lazygit's config for the colors.
  programs.lazygit.enable = true;

  # --- SSH ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."proxmox 10.0.0.117" = {
      HostName = "10.0.0.117";
      User = "root";
      IdentityFile = "~/.ssh/id_ed25519_proxmox";
      IdentitiesOnly = true;
      # The keyring holds the key, so it works from any shell.
      IdentityAgent = "/run/user/%i/gcr/ssh";
    };
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_ed25519";
      IdentitiesOnly = true;
    };
  };
}
