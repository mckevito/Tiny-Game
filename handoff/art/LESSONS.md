# Art lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md` (art direction), `docs/STATUS.md`, `handoff/build/HANDOFF.md` sections 5 and 6, and
this folder's `HANDOFF.md`. For a model built in Blender, `art/RECIPE.md` holds the method, numbers and mistakes. Add your line to the thread list (`/mnt/project-files/handoff/THREADS.md`). The owner's
reference picture is in the project's uploads; ask the coordinator if it is missing.

## Owner rules (with reasons)
All of `handoff/build/LESSONS.md` "Owner rules" apply. For art especially:
- **The whole world knitted together** (owner, 25 Oct 2026): a polish of the old look was not enough. Wool
  texture on everything, stitches everywhere, a ground full of felt plants. Aim past the reference, not near it.
- **Match the reference picture.** The owner's felt-miniature picture is the target; show every change beside it.
- **Pilot, verdict, then roll out.** A few pieces first so a wrong direction costs one round, not twenty models.
- **Gameplay never changes from art.** Keep sizes, colliders and hand positions; the size test guards heights.
- **Laptop floor.** At least 30 fps on the Ryzen 7 5825U's built-in graphics on Light; prefer data and shader detail
  over many parts, and keep anything costly switchable.
- **Original only.** Nothing from the reference repos; third-party textures need a licence and a `CREDITS.md` row.

## Running a round
1. One family of models per round. Change `data/models.json` (by hand or with a scratch generator; the JSON is the
   source of truth).
2. `--filter=felt` tests, then the full suite.
3. Capture `--hero`, the play camera (day and dusk) and `--clip`; look at every frame before showing anyone.
4. A sheet beside the reference and a GIF for anything that moves, in `/mnt/project-files/tiny-game/art-<round>/`.
5. `HANDOFF.md`, `docs/STATUS.md` and the round log here.

## Round log
- 25 Oct 2026, pilot: camper, tent, pine, broadleaf tree, felt fibres, warmer day light and grass. Faults found by
  looking: the beanie hid the face from the play camera (why: it sat at eye height; stops it: the hat sits above
  the brow, trap in HANDOFF); the sweater hem stuck out like a skirt (why: sized without measuring the body; trap);
  the smile showed as dashes (why: running stitches on a short curve; stops it: `gap: 0` cords).
- 25 Oct 2026, round 2 (owner: "we can do way better"): the knitted world. Why round 1 fell short: it changed shapes
  but kept a smooth pastel surface, and the eye reads material and colour before shape; stops it: judge the material
  and the ground first, at the play camera, beside the reference. Faults found by looking: distant fibres sparkled
  white (stops it: fibres fade by screen size); flat clover hid under the meadow (it must sit above the highest
  flat layer it covers); flames read as one pale cone (separate tongues, lower glow); greys turned purple at dusk
  under the boosted saturation (dusk keeps saturation 1).
- 25 Oct 2026, round 3 (owner: "a miniature faking kind of look... real felt"): the look of a photo of a tabletop set
  comes from the camera and light as much as from the models: tilt-shift blur, soft shadows, deep occlusion and
  fuzz on every edge. Faults found by looking: the flame tongues cast a star of shadows over the fire circle (the
  fire light sat inside them; it now sits above).
- 25 Oct 2026, the camper from the owner's turnaround (max-effort attempt): measure the sheet's outlines (width of
  hat, head and body at each height, front and side) and fit them within 1 to 3 cm; light the studio as the sheet
  is (key from the camera's right, soft, short shadow) before comparing colours, then match colours by measured
  ratios. Faults found by looking: fringe curls sank into the head (a radius clamp took the smaller value); the crown
  bulged past the cuff and peaked (rebuilt as an upright egg with round tops); a speckled band on the forehead (the
  hair mass sat too close to the skin); seams on the sheet (the floor's occlusion; composite each row by its own
  backdrop); the sweater knit read as chevron rows (V legs touched across columns; short rows, legs stopping short).
- 25 Oct 2026, the recipe (owner: "get the recipe... so we can create the same output on medium"): the method is
  written down in `art/RECIPE.md`, the shared Blender code moved into `art/tools/knit_kit.py` (the camper builds the
  same file byte for byte) and the review scripts into `art/tools/`. Lesson: keep review tools in the repo from the
  first round; scratch copies die with the session. Measuring again after the new stitch showed the knit parts 5 to
  9% darker than the sheet (more shade between stitches); the two teals were lifted to match.
- 25 Oct 2026, player two's camper (a test of whether a medium-effort thread can repeat the recipe): following
  `art/RECIPE.md` took two review rounds. The recipe covered the body and the knit, but not a model without its own
  sheet, or hair with no hat over it; both are now in the recipe ("A sibling or variant"). Faults found by looking:
  the first round rendered under OpenGL (the hook's Vulkan install had failed quietly), so its colours were wrong;
  `olive_felt` trousers read as a bright green next to the mustard sweater.
