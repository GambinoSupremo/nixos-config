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
