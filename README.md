# PKSEI

*Paddla Kanot Som En Idiot* ("paddle a canoe like an idiot"). A rage game: four drunk guys on a catamaran made of two canoes have to cross a huge lake to an island, and you control all four at once. Nobody dies; a bad stretch drifts you back toward the shore, drunker.

Play it at https://freakling.itch.io/pksei.

PKSEI is also a tech demo for [Godot Director](https://github.com/Freakling/Godot-Director): the human directs the design, the AI builds, one project check proves every change. The design lives in [design/gdd.md](design/gdd.md), the reasons in [design/decisions.md](design/decisions.md), the work in [TASKS.md](TASKS.md), the architecture in [AGENTS.md](AGENTS.md).

## Development

Godot 4.7, GDScript, GL Compatibility, a 640×360 pixel-art canvas, exported to the web.

```bash
git clone https://github.com/Freakling/PKSEI.git
cd PKSEI
bash tools/setup-clone.sh        # finds Godot 4.3+, installs the pre-commit hook
bash tools/check.sh              # the project check: tests, scene loads, screen rules
bash tools/ship.sh --export-only # web build into build/web
bash tools/ship.sh               # export and push to itch.io (needs butler, logged in)
```

Sprites and sounds are generated: `godot --headless --path . -s tools/gen_sprites.gd` and `-s tools/gen_audio.gd` rewrite `assets/`. In a debug build F5/F6 knock a beer overboard, F7 shows the guaranteed path.
