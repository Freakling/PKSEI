# Devlog 1 · How PKSEI was made in two evenings (a recipe)

PKSEI (*Paddla Kanot Som En Idiot*) is a rage game about four drunk guys paddling a canoe catamaran across a lake. It is also a tech demo for [Godot Director](https://github.com/Freakling/Godot-Director), which is [Director-Driven Development](https://freakling.github.io/Director-Driven-Development/) for Godot: the human directs, AI agents build, and one automatic check decides when a task is done. This post is the log of how the game got from an empty folder to a playable build on itch.io, written as a recipe you can follow for your own game. The numbers: two evenings, about 65 commits, 56 task items, 213 tests, one web build pushed after every stage.

The loop the whole time was the same four words: **Decide, Build, Prove, Commit.**

## 1. Install the workflow (10 minutes)

Empty folder, `git init`, then the Godot Director install. It writes the files the agents read: `AGENTS.md` (instructions and architecture), `design/gdd.md` (the design document), `design/decisions.md` (why each decision was made), `TASKS.md` (the work), `tools/check.sh` (the project check) and a pre-commit hook that runs the check.

The install ends with a design interview. I was asked, as multiple-choice questions with a recommendation each: the pitch, the genre and feeling, three to five design pillars, the core loop at three scales, the platforms, input, canvas and camera, and who owns what (I own design, balance and priorities; the agent owns code, tests, placeholder art and the records; here I let it make pixel art and sound too). Every answer went into the GDD as the current design and into `decisions.md` as one line with its reason. Anything undecided became a numbered open question, Q1 to Q5.

**Recipe:** answer the interview honestly and briefly. Pillars matter most; everything later gets checked against them. Mine were *Hard but fair*, *Four bodies, one brain*, *Drunker is funnier* and *No death, only setbacks*.

## 2. Ship before there is a game (20 minutes)

Second task, not last: a web export preset and a `tools/ship.sh` that exports headless and pushes to itch.io with butler. The first push was a flat blue screen with a label. From then on, "ship it" was one command and every stage of the game went to the page.

**Recipe:** get the pipeline working while the project is trivial. Export templates, butler login and the page settings are the only steps the human has to do by hand.

## 3. Research, then decide (30 minutes)

The open questions were about the controls, the setbacks and what drunkenness does. Before deciding, the agent researched the reference games (Getting Over It, A Difficult Game About Climbing, Jump King, Pogostuck, QWOP, plus Octodad and Heave Ho for multi-limb comedy) and wrote eight principles checked against the pillars. Then each question came back as two to four options with a recommendation. I picked, and sometimes changed the proposal: the scrambled keys became a timing bar, the setback became a man-overboard rescue instead of a capsize, the current became the game's gravity.

Every answer was recorded the same way: the GDD section rewritten, a decision line appended, the question deleted, and the task items updated. That consistency is what lets a fresh agent context pick up the work later.

**Recipe:** let the agent research and propose; you decide. Write down only what you decided, including the reason. When an answer contradicts a pillar, the agent must say so and ask which gives way, not reinterpret.

## 4. Build the foundation with `/next-task` (one hour)

"Do the next task until blocked." Each item in `TASKS.md` has a size, the files it touches, and outcomes tagged *(test)*, *(check)* or *(play)*. A builder agent gets one item in a fresh context, builds it, runs the check, and returns a report of about twenty lines. The orchestrating session reads only that report, updates the records, and commits one item per commit. Small items went to a cheaper model.

Order: folder layout, the `RunState` autoload (the current attempt), then three pure rule classes with tests before any scene existed: paddling (charge-and-release strokes against the current, seats steering 80/20 back to front), drunkenness (lag, misses, the timing-bar tier) and stamina (strokes burn it, breaks are telegraphed). Only then the grey-box lake: a boat of rectangles, four coloured squares, a HUD, the island.

The large items got an independent review in a fresh context before their commit. The first review found six tunables sitting on scene scripts instead of in the data resources, exactly the kind of drift a human reviewer would also miss at 11 pm.

**Recipe:** rules in pure classes with tests first, scenes after. Let the check enforce the architecture: screens that roll randomness or write to autoloads fail the build.

## 5. Play it, and let the design change (30 minutes)

The first time I played the build, two things were wrong: the camera did not follow the boat, and the world felt like it moved around the boat instead of the boat moving through the world. The agent did not take my word for the camera; it wrote a throwaway harness that paddled the boat for ten seconds and logged positions and screenshots. The log showed the boat moving and the camera stuck at the origin: a hand-written scene file was missing the one marker Godot needs to resolve an exported node. One-line fix.

The second point was design. We moved from drifting hazards to a static map with fixed objects and timed events, a guaranteed winding path through the seeded bands, a huge lake sized for a five-minute clean crossing, a slow drift for the boat and a fast one for anything in the water, and a pause before a guy jumps after a beer. Six items, recorded and built the same evening.

**Recipe:** play early, then record what you learned as decisions, not as patches. The queue reorders itself around them.

## 6. The hazard set (one and a half hours)

Nine hazards, each a pure rule class stepped by a small scene script: the log, the angry geese guarding goslings, the rock, the fishing line, the motorboat wake, gusts and harsh-wind stretches, the cross-current stripe, the jet-ski idiot, and later the Loch-Brez beast that comes for you if you stray to the edges. Every one is telegraphed before it bites, because the first pillar says so. A shared effects palette (beer overboard, shove, snag, stop, forced break, water aboard) kept them consistent. Follow-up items came out of each build's report: events placed on the path so they can fire, objects keeping their footprint out of the corridor, a shared base script.

## 7. Art and sound, generated (two hours)

No imaging library on the machine, so the sprites are drawn pixel by pixel by a Godot script (`tools/gen_sprites.gd`) and the sounds synthesised by another (`tools/gen_audio.gd`). Both are committed, so the art is reproducible and editable in code. Telegraphs came first: every warning the rules emit got its own animation frames and its own sound before any decoration. The win cutscene, the antics (stand up, drop the paddle, nod off, pee), off-screen arrows for swimmers, the controls scratched into the sand at the launch shore, reverse strokes on eight keys, and the beast followed, each as one item, one commit.

## 8. What the check caught

Across the two evenings the pre-commit check ran about seventy times and the reviews found, among others: a design call the builder had made silently about the shore reset, a swimmer who could drift past the shoreline out of reach, a wind-up that could expire unseen while a guy was in the water, a hit that could land during the win cutscene, and a gameplay constant hiding as a cosmetic one. None of these were bugs I would have filed from playing. All became either a fix in the same item or a new item in the queue.

## The recipe, short

1. Install Godot Director; answer the interview; write the pillars.
2. Get the ship pipeline working on an empty scene.
3. Research the references; decide the open questions as options; record every decision with its reason.
4. Build rules with tests before scenes; one item, one commit; review the large ones.
5. Play, then record what changed as decisions.
6. Keep every follow-up as an item, never as silent work.
7. Generate placeholder art and sound from scripts; telegraphs first.
8. Ship after every stage.

Next: touch controls for phones, and the guys will start talking, in Swedish.
