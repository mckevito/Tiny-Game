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
- 25 Oct 2026, round 3: knitted clipboard. A CanvasItem material shades only that item's own drawing, so a knit shader
  on a panel leaves its text alone; `VERTEX` in the vertex function gives local pixels for the pattern. Draw extras
  (the clip) from the panel's `draw` signal and set layout-dependent shader values there, after the layout. Keep a
  panel's outer width when restyling it: the couch layout test is tight to the pixel (prompt column at 640).
- 25 Oct 2026, round 3 fixes (Playtest): the report had no height limit, and the centre column ignored big interface
  sizes. Why: the layout tests checked the couch at 150% (where the column may pass under panels) but never solo at
  120% or 150%, and never a long report. What stops it: a solo big-size test with a full HUD and a 60-line report.
  Panels placed under the hint must move when it resizes (`resized` signal, deferred).
- 26 Oct 2026, round 4 fix 2 (Playtest on #47): narrowing the shared prompt column to the room between the docks
  fixed the solo case but squeezed the couch at 150% to 344 px (10 lines over the campers). Why: the column was
  checked solo at 150% and on the couch at 150% only with clipboards open, never with both docks and both prompts.
  What stops it: the couch layout test now builds with both docks showing at 150%. Lifting the column above the docks
  does not work there either (the clock fills the top right); per-player things belong on the player's own dock.
- 26 Oct 2026, round 5 (tool ring): `Input.parse_input_event` takes effect on the next frame, so a test that presses
  a key or moves a stick through it must await a frame before reading `PlayerInput`. A thick antialiased `draw_arc`
  leaves a seam where it starts; draw a band as one polygon (out round the outer edge, back round the inner). A tool
  button that now acts on release (tap or hold) needs tests to send the release too.
