# YubiKey tap instead of typing the password, for sudo and admin pop-ups only.
# Login and the lock screen still need the password, so a key left plugged in
# can't unlock the PC. Enrol once: mkdir -p ~/.config/Yubico && pamu2fcfg > ~/.config/Yubico/u2f_keys
{ pkgs, ... }:

{
  security.pam.u2f = {
    control = "sufficient"; # tap or password, either works
    settings.cue = true; # says "Please touch the device"
  };
  security.pam.services = {
    sudo.u2f.enable = true;
    polkit-1.u2f.enable = true;
  };
  environment.systemPackages = [ pkgs.pam_u2f ]; # pamu2fcfg
}
