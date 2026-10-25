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
- 25 Oct 2026, round 1 fixes (Playtest): Tab didn't close the menu (focus took it), panels covered their own camper,
  F1 over the clock, the hint split "Tab for the / menu", toasts under the report. Why: tests called
  `_unhandled_input` directly (skipping GUI focus) and checked only HUD pieces, not the campers. What stops it: a test
  with real key presses through `Input.parse_input_event`, and `_campers_clear` in the layout test.
- 25 Oct 2026, round 2: button icons. Prompts are RichTextLabels now: `Prompts.rich` for anything shown, `Prompts.fill`
  for words (Options, text tests). Tests that compare HUD text must build the expected line with `Prompts.rich`. Keep
  bbcode tags free of spaces (the hint swaps spaces for no-break spaces). Edit `data/*.json` by hand: a json
  round-trip drops the duplicate `pack_full` key in `text.json`. The capture needs a device-0 stick event before pad 1
  drops in.
