# Gameplay lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md`, `handoff/build/HANDOFF.md` (architecture and traps) and this
folder's `HANDOFF.md`. Add your line to the thread list (`/mnt/project-files/handoff/THREADS.md`). Check live PR
state on GitHub before talking about PRs.

## Owner rules (with reasons)
All of `handoff/build/LESSONS.md` "Owner rules" apply. For gameplay especially:
- **Never stuck, never gated.** The owner was blocked on day 1 by a task needing two guests and a bed that waited
  for the evening; anything that can block a day needs a way round it.
- **Guests are the heart of the day; gathering is easy money.** Gathering feeds crafting and odd jobs, never progress.
- **Everything in data.** Numbers and strings live in `data/`; new choices are marked Proposed in `docs/STATUS.md`.

## Who owns what
Gameplay: rules, netcode, data tables for play, the world. Interface: HUD, panels, menus, settings, input and
prompts. Playtest/QA: the test runner, the capture tool, CI and review sheets. `camp.gd` and `data/text.json` are
shared: add, don't reshuffle, and say in the PR which sections you touched. One PR per change, based on `main`.

## Running a round
1. Read the owner's ask and the open work in `HANDOFF.md`; build the smallest thing that meets it.
2. Every rule the host decides goes through `ask` and `_decide`, and is shared with `_share`.
3. Add a test per proof row; break the code once to see it fail; run the full suite headless.
4. Ask Playtest/QA for review frames, or run `scripts/tools/capture.gd --stage-b` yourself and look.
5. Update `docs/STATUS.md`, `HANDOFF.md` and the round log here.

## Round log
- 25 Oct 2026: role split from Build (owner). Stage B rounds 1 to 5 are in `handoff/build/LESSONS.md`.
- 25 Oct 2026: round 1: the tool in hand and tent visits reach the other PC on `_moved`; sleepers tucked into bags.
  Fault found: round 5's sleepers lay on top of the bag (why: the bag was part of the tent model, with nothing to
  cover a body; stops it: a sleeper is a holder with the body and a cover model, looked at before the PR).
- 25 Oct 2026: round 2: sell crate and three camp projects; walking stops at the clearing's edge (Playtest's find).
  Faults found by the button test: the crate's press picked up a chair and the board's crawled into the tent (why:
  new spots were placed by eye near older ones; stops it: a from-the-buttons test per new interact spot, HANDOFF trap).
- 25 Oct 2026: round 3: the camp star rating with Ranger Ada's hint. Faults found: the never-goes-down test passed
  with the rule broken (why: what it packed away was too little to lose a star; stops it: break each rule once and
  make the test take enough away); the report said the stars twice (why: the Today part already has them; seen in
  the frame).
