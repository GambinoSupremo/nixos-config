# Git identity, commit hooks, and SSH hosts.
{ ... }:

{
  # ── Git ──────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "Gavin";
      user.email = "service.haiku882@passinbox.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # Colours come from Noctalia's lazygit template, which owns config.yml; keep settings empty.
  programs.lazygit.enable = true;

  # ── SSH ──────────────────────────────────────────────────────────────────────
  # Only the hosts listed here; no HM catch-all defaults (GitHub uses ssh's own).
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."proxmox 10.0.0.117" = {
      HostName = "10.0.0.117";
      User = "root";
      IdentityFile = "~/.ssh/id_ed25519_proxmox";
      IdentitiesOnly = true;
      # GNOME Keyring's agent, so shells without SSH_AUTH_SOCK can still use the key
      IdentityAgent = "/run/user/%i/gcr/ssh";
    };
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_ed25519";
      IdentitiesOnly = true;
    };
  };
}
