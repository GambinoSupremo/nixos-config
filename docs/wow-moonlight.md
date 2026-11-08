# WoW Forever from the Steam Machine

Sunshine exposes `WoW Forever`, launching Lutris game 6 on Gavos. That entry
launches Battle.net with `--exec="launch WoWF"`, preserving automatic login.
The existing stream display setup, game watcher, audio and controller setup
also apply to this app. Battle.net may appear briefly during startup.

Battle.net only hands WoW a sign-in if it has finished logging in, otherwise
WoW asks for the password. So the app waits up to 3 minutes for that login,
starting Battle.net if it isn't running, and only then launches WoW. The login
window can stall until it's resized, so for the first minute the app resizes it
every 5 seconds. Battle.net
stays running in the background afterwards (game launch behavior `3`; `2` exits
the client) so later launches are instant.

Run `apply` on Gavos after landing this change. Then refresh Gavos's app list
in Moonlight on the already-paired Steam Machine and test `WoW Forever`.

On the Steam Machine, switch to Desktop Mode and run:

```sh
flatpak run com.moonlight_stream.Moonlight stream gavos "WoW Forever"
```

Moonlight accepts the name of an already-added host, so `gavos` does not
need DNS if it matches the computer already saved in Moonlight. If needed,
replace it with that computer's saved name or LAN IP address.

For a SteamOS library tile, add Moonlight as a non-Steam game, rename the
entry to `WoW Forever`, and set:

- Target: `/usr/bin/flatpak`
- Start In: `/usr/bin`
- Launch Options: `run com.moonlight_stream.Moonlight stream gavos "WoW Forever"`
- Compatibility: leave forced Proton compatibility off (Moonlight is native Linux).

Alternatively, copy `wow-forever-moonlight.desktop` from this directory to
the Steam Machine's `~/.local/share/applications/`, then use Steam's
Add a Non-Steam Game dialog to add `WoW Forever`.

Gavos must be awake with its desktop session logged in. This uses the
existing Moonlight pairing and streaming preferences. Exit WoW before
ending the stream; avoid moving a running fullscreen game across a stream
disconnect/reconnect (see the existing Hyprland streaming notes).

The Sunshine entry is detached so launcher process handoffs do not end the
stream. Exit the Moonlight session after leaving WoW to return to SteamOS.
Closing Moonlight alone may leave the Sunshine session running, depending
on the client's quit-after-session setting.
