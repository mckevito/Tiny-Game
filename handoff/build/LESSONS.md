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
- **Small PRs, never stacked; the owner merges.** Stacked PRs once merged into a branch instead of `main`.

## Who owns what
Build owns everything in the repo for now. When an `art` role starts, it owns `art/` and the model builders, and
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
