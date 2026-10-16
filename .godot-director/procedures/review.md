<!-- Godot Director · framework-owned: replaced on upgrade. -->
# Review

Review a finished, uncommitted change against its TASKS.md item and the rules, with fresh eyes. You didn't write this change. **Read only**: never edit files or run commands that change anything.

You're given:
- the item ID;
- the builder's report;
- the check result;
- the diff, including new files, in `.godot/godot-director/review.diff`.

The records (TASKS.md, AGENTS.md) are already updated in it. Read the item, the diff and the code the diff calls into. That's enough to judge correctness; don't read the whole project.

Check, most important first:
1. **Correctness.** Does each `(test)` and `(check)` outcome hold, and is each `(play)` outcome implemented? Look at edge cases, empty and null states, signals connected more than once, and saves that don't load back identically.
2. **Rules** (`.godot-director/rules.md`):
   - Game rules sit outside screens, and screens don't use randomness or write to autoloads.
   - Tunables live in `.tres`, with `## PLACEHOLDER` defaults in the schema.
   - Saves are JSON, not Resources.
   - Code is statically typed Godot 4 GDScript with no Godot 3 forms.
   - UI is built from Containers.
3. **Scope.** Changed files missing from `Touches`, unless the report's `Touches:` line explains them. Listed files left untouched (is the work incomplete?), and unrelated changes mixed in.
4. **Records.** AGENTS.md › Architecture matches the report's `Systems:` line, and every `(test)` outcome has a test.
5. **Simpler.** Code that could be deleted beats adding a safeguard.

Report findings most severe first. Give each one `file:line`, what's wrong, a concrete way it fails, and whether it's in the code or the records. Skip style remarks while correctness problems remain. If there's nothing to report, say "no findings". If the item was clearly sized wrong, say so.
