# Git identity, commit hooks, and SSH hosts.
{ pkgs, lib, ... }:

{
  # ── Git ──────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "Gavin";
      user.email = "service.haiku882@passinbox.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      # Config-based hook, so it runs in every repo alongside any .git/hooks ones.
      hook.strip-claude-attribution = {
        event = "commit-msg";
        command = "${pkgs.writeShellScript "strip-claude-attribution" ''
          sed=${lib.getExe pkgs.gnused}
          # Whole trailer lines only, so prose that mentions them survives.
          $sed -i -E \
            -e '/^[[:space:]]*Co-Authored-By:.*\bClaude\b/Id' \
            -e '/^[[:space:]]*(🤖[[:space:]]*)?Generated with \[Claude Code\]\([^)]*\)[[:space:]]*$/d' \
            "$1"
          # Drop the blank lines the removed trailers leave at the end.
          $sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$1"
        ''}";
      };
    };
  };

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
