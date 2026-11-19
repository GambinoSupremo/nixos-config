# Quieter Bluetooth notifications.
{ lib, host, ... }:

{
  # No popup every time a device connects or drops.
  dconf.settings."org/blueman/general".plugin-list = lib.mkIf (!host.isVM) [ "!ConnectionNotifier" ];
}
