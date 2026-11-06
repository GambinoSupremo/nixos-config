# Umbriel trial

`gav.sessions.umbriel` adds an Umbriel session styled after Mango, with Hyprland
filling gaps. Hyprland stays the default; Mango and Hyprland remain on the greeter.
Disable the option and rebuild to remove the trial.

Files:
- `home/umbriel/config.toml`: main config. It includes `noctalia.toml`
  (Noctalia's palette, written at runtime), `games.toml` and `stream.toml`.
- `home/umbriel/games.toml`: Steam and game placement, and the X11 primary output.
- `~/.config/umbriel/stream.toml`: written by Sunshine during a stream.

Includes are applied in list order, and the main file is applied last.

Try it: log out normally and pick Umbriel in the greeter. Don't start a second
compositor inside a running session. To go back, log out and pick Hyprland or Mango.

## Status

Checked before going live:
- Umbriel 0.1.0 (`c6ad18d`) is locked from the cachix branch.
- `umbriel config validate` passes on the rendered config with all three include files present.
- The full desktop system builds.
- The output identities use the same EDID make/model/serial that Hyprland reports.

Not yet checked live: everything under "Live checklist" below.

## Ported from Mango / Hyprland

- **Monitors:**
  - AW3423DW 3440x1440@174 at 0,0, scale 1. Workspace 1 is dwindle; workspaces 2–6 scroll.
  - PHL 278E1 4K@60 at 3440,0, scale 1.5.
  - VRR and HDR are off. Workspaces run vertically and wrap around.
- **Look:**
  - Border 2, radius 6, no title bars.
  - Gaps 5 inside and 10 at the edges.
  - Blur on, matching Mango's settings.
  - Unfocused windows at 0.98 opacity. Comms and media at 0.9/0.95; Zen opaque.
- **Shadows:** floating windows only, softness 15, no offset.
- **Animations:** Mango's curves and timings.
  - Open: zoom from 0.4, 400 ms. Close: 100 ms.
  - Move and resize: 500 ms. Workspace switch: 350 ms.
  - Border and focus-opacity changes are instant.
- **Input:**
  - US layout, repeat 25/600, numlock on.
  - Flat acceleration; focus follows the mouse.
  - The cursor warps to the focused window (`follows_focus`).
  - Bibata-Modern-Ice cursor at size 24.
- **Session:**
  - TERMINAL=ghostty and QT_QPA_PLATFORMTHEME=qt6ct are set.
  - The startup cheatsheet is off, and windows don't grab focus when they activate.
  - The bootstrap restarts Noctalia and Sunshine with Umbriel's environment and clears stale Hyprland/Mango signatures.
  - Startup also runs: dark colour scheme, the cliphist watcher, Vesktop (outside Mullvad), Signal and Tidal.
- **Portals:** Umbriel's portal, with gtk as fallback. Secret goes to gnome-keyring, as on Mango.
- **Scratchpads:**
  - Alt+Z toggles the terminal (ghostty).
  - Alt+Shift+Z stashes a window; Alt+Ctrl+Z toggles the stash.
  - Scratchpads float at 0.8×0.9.
- **Rules:**
  - Steam goes to the Alienware's workspace 2 without stealing focus; its dialogs float.
  - Games (`steam_app_*`, `*.exe`) go to the Alienware's workspace 2, tiled, with the pointer confined.
  - Game Launcher/broken windows and Battle.net float.
  - Vesktop, Signal and Tidal go to the Philips' workspace 2.
  - Satty, Noctalia settings and floating ghostty windows float.
- **Master layout:** new windows become master, at a 0.5 split.

## Shortcuts

| Keys | Action |
|---|---|
| Super+Return | Terminal |
| Super+Space | Launcher |
| Super+Q | Close window |
| Super+Escape | Session panel |
| Ctrl+Alt+Delete | Quit Umbriel |
| Super+1–6 | Switch workspace |
| Super+Ctrl+1–6 | Move window there, staying put |
| Super+Ctrl+Left/Right | Focus the other monitor (add Alt to move the window) |
| Super+Ctrl+Up/Down | Previous/next workspace (add Alt to move the window) |
| Super+Shift+arrows | Swap windows |
| Super+W | Float |
| Super+F | Fullscreen |
| Super+M | Maximize |
| Super+Tab | Overview |
| Super+Ctrl+D/S/A | Dwindle/scrolling/master layout |
| Super+left-drag | Move window (built in) |
| Super+right-drag | Resize window (built in) |

## Sunshine

`sunshine-stream-display` runs `sunshine-umbriel-stream` when `XDG_CURRENT_DESKTOP=umbriel`.

On start:
1. Creates a virtual `SUNSHINE` output at the client's mode.
2. Writes `stream.toml`, which sends new Steam/game windows to `SUNSHINE` workspace 1, focused, with games fullscreen. Launcher windows are excluded, and `SUNSHINE` becomes the X11 primary.
3. Reloads the config.
4. Moves windows that are already open there.

On stop:
1. Removes `stream.toml` and reloads.
2. Moves the Steam/game windows back to the Alienware's workspace 2.
3. Destroys the output.

Steam Remote Play uses the same path. If a stream crashes, the session bootstrap clears a leftover `stream.toml` at the next login.

Differences from Hyprland:
- No game watcher: rules handle new windows.
- Noctalia's palette reloads don't reset the mode.

## Known gaps

- **Discord keys aren't ported.** Hyprland sends KP3 to Vesktop as Ctrl+Shift+M and runs KP0 push-to-talk on key press and release, without consuming the keys. Umbriel binds always consume the key, have no release or pass-through binds, and can't send shortcuts. Unbound keys still reach the focused window, so use Vesktop's own keybinds there.
- **Monitor directions** follow real geometry; Mango's flipped-direction workaround isn't needed.
- **Resizing** steps by 2% instead of Mango's 50 px.
- **Pinned windows** stand in for Mango's global windows.
- **Fake fullscreen and overlay** have no binds.
- **Super+wheel** steps through every workspace, not only populated ones.

## Live checklist (not yet done)

- [ ] `umbriel outputs` lists both monitors at the right mode, position and scale.
- [ ] Workspace 1 is dwindle and workspaces 2–6 scroll; the Philips has the comms windows.
- [ ] Shortcuts, both scratchpads and floating-only shadows work, and the animations feel right.
- [ ] Steam and a game land on the Alienware's workspace 2; the pointer is confined; fullscreen works.
- [ ] Screenshots work: Super+Shift+S and Alt+Shift+S.
- [ ] Screen sharing in Vesktop works, with the portal picker.
- [ ] Audio works, including the media keys.
- [ ] The Noctalia bar, palette and clipboard work.
- [ ] A Moonlight stream starts and stops cleanly, and games return to the Alienware.
- [ ] Logging out and picking Hyprland or Mango still works.
