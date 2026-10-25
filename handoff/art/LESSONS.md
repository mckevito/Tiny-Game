# Art lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md` (art direction), `docs/STATUS.md`, `handoff/build/HANDOFF.md` sections 5 and 6, and
this folder's `HANDOFF.md`. Add your line to the thread list (`/mnt/project-files/handoff/THREADS.md`). The owner's
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
