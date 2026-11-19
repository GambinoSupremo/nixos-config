# Espanso codes (service: nixos/features/espanso.nix). Every emoji by its name
# between colons, e.g. :smile: or :thumbs_up:, plus the extras below.
{ pkgs, ... }:

let
  extras = {
    matches = [
      {
        trigger = ":date:";
        replace = "{{d}}";
        vars = [
          {
            name = "d";
            type = "date";
            params.format = "%Y-%m-%d";
          }
        ];
      }
      {
        trigger = ":time:";
        replace = "{{t}}";
        vars = [
          {
            name = "t";
            type = "date";
            params.format = "%-I:%M %p";
          }
        ];
      }
      {
        trigger = ":shrug:";
        replace = "¯\\_(ツ)_/¯";
      }
      {
        trigger = ":tableflip:";
        replace = "(╯°□°)╯︵ ┻━┻";
      }
      {
        trigger = ":arrow:";
        replace = "→";
      }
    ];
  };

  py = pkgs.python3.withPackages (p: [ p.emoji ]);

  # Built from the emoji package's names and short aliases, skin-tone variants skipped.
  emoji = pkgs.runCommand "espanso-emoji.yml" { skip = map (m: m.trigger) extras.matches; } ''
    ${py}/bin/python3 - >$out <<'EOF'
    import json, os, emoji
    seen, matches = set(os.environ["skip"].split()), []
    for e, d in emoji.EMOJI_DATA.items():
        if d.get("status") != emoji.STATUS["fully_qualified"]:
            continue
        for t in [d["en"], *d.get("alias", [])]:
            if "skin_tone" in t or t in seen:
                continue
            seen.add(t)
            matches.append({"trigger": t, "replace": e})
    print(json.dumps({"matches": matches}))
    EOF
  '';
in
{
  # JSON is valid YAML, which espanso reads.
  xdg.configFile."espanso/match/emoji.yml".source = emoji;
  xdg.configFile."espanso/match/base.yml".text = builtins.toJSON extras;
  xdg.configFile."espanso/config/default.yml".text = builtins.toJSON {
    show_notifications = false; # no popup each time it starts
    search_shortcut = "off"; # typing codes only; no Alt+Space popup in games
  };
}
