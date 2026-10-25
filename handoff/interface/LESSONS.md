# Interface lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md`, `handoff/build/HANDOFF.md` (architecture and traps) and this
folder's `HANDOFF.md`. Add your line to the thread list (`/mnt/project-files/handoff/THREADS.md`).

## Owner rules (with reasons)
All of `handoff/build/LESSONS.md` "Owner rules" apply. For the interface especially:
- **Both input methods are first-class.** The owner plays on a DualSense; every panel works from the pad.
- **Nothing overlaps, nothing runs off the screen.** The owner caught both (rounds 3 and 4); the layout test must
  run at 16:9 and check pairs of pieces, and a fix must be proved by putting the fault back.
- **Animal Crossing is the reference** for the Pack, tools and build cycling.

## Who owns what
See `handoff/gameplay/LESSONS.md` "Who owns what". `camp.gd` and `data/text.json` are shared.

## Running a round
1. Build the change; every size and colour in `data/tuning.json`, every string in `data/text.json`.
2. Run the HUD test and the settings tests; then the capture tool at 1920x1080 and look at every frame.
3. Update `docs/STATUS.md`, `HANDOFF.md` and the round log here.

## Round log
- 25 Oct 2026: role split from Build (owner). Interface work so far (HUD fix, Pack, dock, menu, Apply) is in
  `handoff/build/LESSONS.md`.
- 25 Oct 2026, round 1: `test_hud` (couch split layout) failed on `main`: the couch clipboard covered the clock and
  the clipboards and docks covered the prompts. Why it got through: the only layout test was solo. What stops it:
  the couch test opens every pair of panels with a full HUD at 1920 x 1080 and at the biggest interface size, and
  each fix was proved by putting the fault back. Then the dock's neighbours and the Pack's tokens and name tag.
