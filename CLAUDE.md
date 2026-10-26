# Our Little Campground: notes for Claude

A tiny, cozy two-player co-op game in felt-and-fabric miniature style, built in Godot 4.7.2 (standard build, GDScript).
The goal is a small game that is easy to build and cheap in tokens. The plan is `docs/PLAN.md`; it is the source of
truth, and any departure from it is marked "Proposed" until the owner approves it.

## Where things stand
`docs/STATUS.md` says what each milestone has, what is signed off and what is open. Never put status in this file.

## Start here (fresh thread)
Work from files, not old chats: this file, `docs/PLAN.md`, `docs/STATUS.md`, then your role's
`handoff/<role>/HANDOFF.md` and `LESSONS.md` (the method is in `handoff/README.md`). If you have to ask the owner
something these files should have answered, write the answer into them in the same turn.

**Keep this file current.** It is the running brief for any Claude team that picks the work up. When a standing rule,
the build steps or a top-level folder changes, update this file in the same PR. Status goes in `docs/STATUS.md`,
per-role state and lessons go in `handoff/<role>/`, never here.

**A new team joining** picks a role (`gameplay`, `interface`, `playtest`, `art`; `handoff/README.md`), reads that
role's files and works one round at a time. The list of running threads lives outside the repo (see
`handoff/README.md`); check it so two teams don't take the same job.

## Rules that always apply
- **Public repo.** Nothing personal goes into git: no real names or emails (commits use a no-reply address), no
  Windows user paths, IP addresses, keys, tokens, saves or logs. Thread and session ids stay out of the repo too.
- **`mckevito/dead-acre` and `mckevito/dermont-atlas-workshop` are read-only references.** Use their ideas, never
  their code, assets, names, text or docs. Never push, branch or open PRs there.
- **Every number and every player-facing string lives in a table under `data/`**, never in code. Code comments name
  the table key.
- **Two players in total**: both on one PC (dynamic split screen) or one on each of two PCs online. The host decides
  every change to the shared camp; clients ask. Characters belong to a profile ID, never a connection ID.
- **Both input methods are first-class**: keyboard and mouse, and the PS5 DualSense. Prompts show the glyph of the
  device the player last used. Never write "Press A" in a string.
- **Cozy contract** (`docs/PLAN.md`): no combat, failure, timers or lost items.
- Every asset is original or under a licence that allows redistribution, with a row in `CREDITS.md`. Licences
  (owner): MIT for code, CC BY 4.0 for original art.
- **Art quality bar** (owner): every model follows the knitted-camper recipe in `art/RECIPE.md` with the kit in
  `art/tools/`; medium effort is enough. New colours and looks stay Proposed until the owner gives a verdict.
- **Names** use the recommended defaults, and players can rename them in-game at any time (staff, ranger, camp
  sign); the new name is kept in the save.
- **Performance floor**: a Ryzen 7 5825U laptop with built-in Radeon graphics holds at least 30 fps at 1080p (aim
  for 60), split screen included (`docs/PLAN.md`). Cloud runs can't measure real fps; compare draw calls and
  primitives against `main` instead (`handoff/playtest/LESSONS.md`).
- **Playtest each PR**: the Playtest role plays every build PR from the title and logs faults in
  `handoff/playtest/FAULTS.md`; fix a fault so it can't come back (`handoff/README.md`).
- One sandbox scene (`scenes/sandbox.tscn`) for trying things; no extra test scenes. Dev tools go on F1, never Pause.
- Each milestone ships headless tests for its proof rows, and updates `docs/STATUS.md`.
- One branch and one PR per change, based on `main`, never stacked. The owner merges.
- **Sign-off needs no PR of its own** (owner, 25 Oct 2026): the owner's sign-off in chat plus the merged build PR is the
  sign-off. Record it in the next build PR's docs (`docs/STATUS.md`, the `docs/PLAN.md` decision log).

## Saving tokens
- Idle is free; turns cost. While waiting on CI, a merge or the owner, end the turn. No polling or sleep loops.
- Close a thread when its job ends, after updating its `HANDOFF.md` and `LESSONS.md`; the next one starts from them.
- Build small: one feature or one family of models per round. Run tests before taking screenshots.
- New ideas go to the "Later" list in `docs/PLAN.md`, not into the current build.

## Build and test
The cloud start-up script (`.claude/hooks/session-start.sh`) installs Godot 4.7.2 in the background; progress is in
`/tmp/session-start.log`.
```
godot --headless --import
godot --headless --script res://tests/run_tests.gd     # every test; add -- --filter=name to run some
```
Results print to the console and go to `user://test_results.txt`; the exit code is the number of failures.
CI (`.github/workflows/ci.yml`) runs the same on GitHub-hosted Linux for each push and PR. Run it locally first.
Review captures from the play camera (daylight and dusk) come from `scripts/tools/capture.gd`; the command is in
`handoff/build/HANDOFF.md`. Captures need Vulkan (`mesa-vulkan-drivers`): the first log line must say
"Vulkan ... Forward+", or Godot quietly falls back to OpenGL and the frames are wrong.

## Layout
- `scripts/core/`: shared plumbing (tuning tables, text, input, this PC's settings).
- `scripts/art/`: the felt material and the builder that makes models from `data/models.json`.
- `scripts/camp/`: the camp scene, its rules and save, the clearing, campers, play camera and light moods.
- `scripts/ui/`: the shared menu look (fonts and the season colour presets in `data/look.json`), felt lettering and
  the one Options screen.
- `scripts/net/`: online identity (the local profile ID); the netcode itself is in `scripts/camp/camp.gd`.
- `scripts/tools/`: dev-only scripts, such as the review capture (`capture.gd`).
- `art/`: models built in Blender from code (`art/<kind>/<id>/build_<id>.py` makes `<id>.glb`), the shared Blender
  kit and review tools (`art/tools/`), and the method (`art/RECIPE.md`).
- `scenes/`: the camp (the main scene) and the sandbox.
- `data/`: tuning tables and text.
- `tests/`: headless tests, `test_*.gd`, run by `tests/run_tests.gd`.
- `docs/`: the plan and the status doc.
- `handoff/`: each role's hand-off and lessons files.
