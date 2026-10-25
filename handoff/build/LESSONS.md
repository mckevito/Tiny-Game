# Build lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md` and `HANDOFF.md` in this folder. Add your line to the thread list
(`/mnt/project-files/handoff/THREADS.md`). Check live PR state on GitHub before talking about PRs. If you ask the
owner something these files should answer, add the answer here.

## Owner rules (each with its reason)
- **Public repo, nothing personal in git.** The repo is public; personal data and Dead Acre material must never leak.
- **No session or thread links in commits.** Leave the `Claude-Session:` trailer out of commit messages; ids stay
  out of the public repo (CLAUDE.md). Milestone 0's commit has one; don't repeat it.
- **Reference repos are read-only, ideas only.** They are the owner's private projects.
- **Online on two PCs first; two players in total.** That's how the owner wants to play.
- **Both input methods are first-class.** The owner plays with a DualSense; others use keyboard and mouse.
- **Performance floor: the weakest PC.** A Ryzen 7 5825U laptop with built-in graphics must hold 30 fps (aim 60),
  split screen included (owner, 25 Oct 2026). Anything that draws more gets a setting in `data/graphics.json`.
- **Small PRs, never stacked; the owner merges.** Stacked PRs once merged into a branch instead of `main`.
- **No sign-off PRs.** The owner's sign-off in chat plus the merged PR is the sign-off (owner, 25 Oct 2026); record it
  in the next build PR's docs. Sign-off PRs cost a round for nothing.

## Who owns what
Build owns everything in the repo for now. Outside art (for example a rigged .glb made with another tool) goes in
`art/<kind>/<name>/` (`<name>.glb` plus its source, snake_case, animations named by verb), with a `CREDITS.md` row, in
its own art-only PR titled "Proposed:"; Build wires it into the game in a separate PR (owner, 25 Oct 2026). When an `art` role starts, it owns `art/` and the model builders, and
Build owns how the game loads them.

## Running a round
1. Read the milestone's rows in `docs/PLAN.md` and `docs/STATUS.md`.
2. Build in small steps; every number and string goes in `data/`.
3. Add or update tests for each proof row; run the full suite headless.
4. Check new files for personal data.
5. Commit, push, open or update the PR, and end the turn while CI runs.
6. Update `docs/STATUS.md`, `HANDOFF.md`, and a round-log line here.

## Craft rules
- **Art is data.** A model is a list of parts in `data/models.json`; never hand-place meshes in a scene. New looks
  are new swatches or slots, not new materials.
- **Look before telling.** Run the tests, then the capture tool, and read the frames yourself before showing the
  owner. Review from the play camera, in daylight and at dusk.
- GDScript with static types where it helps; one script per job.
- Tests are plain `test_*.gd` files extending `RefCounted` with `test_*` methods that return an empty string on a
  pass or a message on a failure.
- Prefer a failing check over a silent pass. Break the code on purpose once to see each new test fail.
- **Netcode:** the host's `CampState` decides; rules take profile IDs, never connection IDs; every refusal is a text
  key shown to the player. Test networking with two real camps over ENet in one process (`tests/test_net.gd`).

## Round log
- 25 Oct 2026: Milestone 0 skeleton: project, input map, tuning loader, sandbox, test runner, CI, method files.
- 25 Oct 2026: Milestone 1 felt art proof: felt shader, data-driven model builder, clearing, play camera, moods.
  Faults found by looking at frames: campers fell through a ground with no collider (why: only props had colliders;
  stops it: the ground model has one and the sandbox test builds the real scene); colours washed out (why: ambient
  too strong; now tuned in `data/lighting.json`); ash z-fought the dirt (why: equal tops; rule in HANDOFF traps).
- 25 Oct 2026: Milestone 2 two PCs, one camp: ENet host and join, host-decided carry and place, profile IDs, a
  whole-year camp save with slots, backup and upgrades, glyph prompts, real two-camp network tests. Faults found:
  the menu sat off-centre and too tall (why: centred before its size was known; stops it: `_fit()` on every show);
  a carried chair hid the player's name (why: label behind the chair; stops it: names draw on top); a network test
  passed with pick-up broken (why: an unchecked wait; stops it: check each step, rule in HANDOFF traps).
- 25 Oct 2026: Milestone 2 signed off by the owner after two-PC play on the home network (firewall prompt allowed).
- 25 Oct 2026: Milestone 3 couch and link codes: drop-in/drop-out by controller, LEGO-style split screen (fresh code
  from the MIT demo's idea), one-use link codes, two-player total across couch and online, picture presets and an
  F1 fps readout for the weakest laptop. Fault found: the split-side test passed with the halves swapped (why: it
  checked only which side of the line, not that the player was on screen; stops it: it checks bounds too, rule in
  HANDOFF traps).
- 25 Oct 2026: Milestone 3 signed off by the owner ("works and looks good"). Cloud captures fell back to OpenGL
  without a word (why: lavapipe was missing in that container; stops it: check the "Vulkan ... Forward+" line in the
  capture log before reading frames, rule in HANDOFF traps).
- 25 Oct 2026: Stage A core proof: day clock with light that follows it, one guest per free pitch, sleep vote from the
  menu, a night that pays once (checked through save, load and an ENet reconnect), grid placement with undo and
  pack-away. Faults found: the day's helpers kept their CampState alive (why: a two-way reference between
  RefCounteds; stops it: weakref, rule in HANDOFF traps); the ghost's tint hid under the model (why: the tile sat
  below the pitch's top; stops it: `ghost.lift_m` in data/build.json, checked in the `--stage-a` capture); the guest
  stood on the pitch's sign post (why: the stand offset was picked without a look; stops it: looking at the capture
  before the PR).
- 25 Oct 2026: Stage A signed off by the owner (PR #10 merged, defaults approved). The four Milestone 3 hands-on
  checks are still unconfirmed; carried to Stage B.
- 25 Oct 2026: Stage B three-day fun test: guests' requests with tips, fishing and grilling, water point and lantern
  post, a booking board with accept, a day later or decline, satisfaction lines, the morning report with three goals.
  Faults found: tests passed through script errors (why: GDScript carries on after an error and the test still
  returned ""; stops it: the runner fails a test that logged a script error, HANDOFF trap); the morning report showed
  an empty panel (why: an autowrapped label with no width; stops it: the label gets a minimum width, HANDOFF trap,
  checked in the `--stage-b` capture); the first capture showed no guests (why: a pitch spot was blocked by a bush, so
  the booking rightly waited; stops it: the capture prints any refused build, and known good spots are in HANDOFF).
- 25 Oct 2026: Stage B round 2 (owner: days 1 to 3 felt blank): research first (report in the project files), then a
  Today list whose firsts teach day 1, chopping with trees that fall and get replanted (owner's Animal Crossing ask),
  daily sticks and berries, the log bench, felt animals, a per-player clipboard and a long log that goes faster
  carried together. Faults found: the morning "tomorrow" line never showed (why: JSON numbers are floats and
  `Array.has(int)` is false; stops it: compare with `int()`, HANDOFF trap, the scene test checks the line); grilling
  stopped working (why: the busy step passed the interact arg on to a request that takes none; stops it: only chop
  passes its arg, HANDOFF trap, the button test grills). Lesson: a playtest with nothing to do needed many small
  things to do at once, not one big system; building the shared part while the owner chose saved a round.
- 25 Oct 2026: Title screen and settings: a title page over the clearing, one Options screen (picture, sound,
  controls with remapping on both devices, accessibility) from the title and the in-camp menu, settings kept per PC.
  Faults found by looking: a slider showed no focus (why: Godot's Slider draws no focus style; stops it: the whole
  row lights up on focus); a toggle stretched into a long bar (why: CheckButton fills its width; stops it: toggles
  are On/Off buttons like the choices); the first capture fell back to OpenGL (mesa-vulkan-drivers missing; HANDOFF
  trap).
- 25 Oct 2026: Fix: Play alone and Host crashed on main after the title screen merged. Why: rewriting `camp_menu.gd`
  dropped `slot()`, and no test pressed the real start buttons (tests called `start_solo` directly). Stops it: a test
  presses Play alone and Host on the start page; when rewriting a file, list every method other scripts call on it
  (`grep "menu\.[a-z_]*("`) and check each still exists.
