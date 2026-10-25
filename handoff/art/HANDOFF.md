# Art hand-off, 25 Oct 2026

1. **Owns:** the felt models (`data/models.json`), the palette (`data/palette.json`), the material and builder numbers
   (`data/art.json`), the light moods' colours (`data/lighting.json`), `scripts/art/` (builder and shader), `art/`
   (outside art such as a rigged camper pack) and the `--hero` mode of `scripts/tools/capture.gd`. It doesn't edit
   Gameplay or Interface files; it asks those threads instead. Placement (`data/clearing.json`) and hand and name
   positions (`data/tuning.json` "camper") belong to Gameplay; ask before moving them.
2. **State now:** the art pilot (PR "Art pilot") brings the camper, the tent, the pine and the round broadleaf tree up
   to the owner's felt reference picture, adds felt fibres to the shared material, and warms the day light and grass.
   Owner's verdict on that first pass (25 Oct 2026): "we can do way better... it should literally look like the whole
   world was knitted together". Round 2 (same PR) is the knitted world: weaves in the material (knit, wood, water,
   grass), hairy edges, colour grading, a ground covered in felt clover, flowers, grass and ferns, and every model in
   view reworked. It waits on the owner's verdict. Review images: `/mnt/project-files/tiny-game/art-knit/` (round 2)
   and `art-pilot/` (round 1), outside the repo.
   - Weaves: a part's (or model's) `weave` names one of data/art.json "weaves"; the builder writes its number into
     UV.x and the shader draws knit V-stitches, wood grain along X, wavy water strands or patchy grass felt from it.
     Fibres fade with distance (no sparkle). `hair_edge` cuts fibres out of outlines.
   - Builder: `scatter` strews copies of a part over an area (seeded; `avoid` circles, `keep_in`, `keep_out`);
     `pivot` makes `repeat` spin round a plant's own stem; `segments` lowers detail for tiny, many-copied parts.
   - Ground scatter: inside the camp (12.5 m) only flat clover and flowers lower than a pitch's top, so nothing
     pokes through what players build; taller grass and ferns only past 13 m, and plants at the feet of trees and
     rocks (inside their build blockers). The avoid circles follow data/clearing.json; if Gameplay moves scenery,
     update them in the ground model.
   - Round 3 (owner: "a miniature faking kind of look... a real felt kind of look"): a tilt-shift blur that keeps
     the players sharp (`scripts/art/miniature.gd`, data/art.json "miniature"), two fuzz shells drawn as next passes
     of the one material (data/art.json "shells"), finer close-up fibres, soft sun shadows and deeper ambient
     occlusion (data/lighting.json), khaki grass. Both the blur and the shells are off on the "low" preset.
   - Files outside `scripts/art/` the Art role touched: `scripts/camp/light_moods.gd` (`_adjust`, `_soften`) and
     one call in `scripts/camp/play_camera.gd` `_place` (`Miniature.focus`). Tell Gameplay if either changes.
   - Blender pilot (owner's pick, 25 Oct 2026): `art/characters/knit_camper/build_knit_camper.py` builds
     `knit_camper.glb` (run it with `blender --background --factory-startup --python ... -- OUT.glb`, then
     `godot --headless --import`). Overlapping primitives are fused by a voxel remesh and smoothed, ribs and real knit
     bumps are pushed into the beanie and sweater, and every vertex carries (weave, slot) in its UV. A model with
     `file` and `file_slots` in data/models.json loads it, and the builder paints it from the palette (glTF flips V,
     so the slot is 1 - UV.y). It is only the `knit_camper` model so far; the capture's `--player=ID --friend=ID` puts
     it beside the code camper. Its proportions follow the owner's "Beanie Camper" turnaround (big head, beanie wider
     than the head with a folded cuff, separate sleeves, short trousers, boots); `--turn=knit_camper` renders front,
     right, back and left on a cream backdrop to compare with it. About 14k vertices (28k triangles) after the
     per-part `decimate` ratios were lowered; the ribs survive that, check a turnaround before lowering further.
   - Camper from the turnaround, second build (PR "Proposed: knitted camper rebuilt from the turnaround", one of two
     attempts the owner compares): the beanie, sweater and sleeves are no longer remeshed blobs but knitted tubes made
     row by row from a profile (`knitted()`), so ribs are real grooves and every vertex has its stitch column and row
     in a second UV map ("Stitch", glTF TEXCOORD_1, Godot UV2). Weave 5 `knit_rows` (data/art.json) draws the V
     stitches from UV2 along the ribs, and `knit_rib_dark` darkens the groove between stitch columns; stitch columns
     sit half a rib off (u + 0.5) so each V lands on a rib. The beanie tilts back 23 degrees with a slouching crown
     and a lining inside (so frayed edges never show the background); the head is tucked in under the hat so it can't
     poke through the fold. Curls are a mop of felt balls drawn with tiny stitches (`stitch_round`). Trousers have
     rolled cuffs and running-stitch side seams; boots a stitched welt. `--tpose` builds arms out for the comparison
     sheet only. New Proposed swatches (beanie_teal, cocoa_felt, boot_cocoa, curl_brown, rosy_peach) are picked so
     the camper under the warm, contrasty day light reads like the sheet's neutral photo. About 18.5k vertices.
   - Trap: the fire's light sits above the flame tongues (`light.pos` y 1.1), or each tongue casts a long shadow and
     the fire circle shows a star.
   - Builder additions: the `lathe` shape (a profile of [radius, height] points turned round Y, with an optional
     `wave` [count, depth] that scallops pine tiers or ribs a knit beanie); `stitch` takes `points` (a polyline)
     as well as from/to; stitches, rings and seams take `thick`, `dash` and `gap` multipliers, and `gap: 0` makes a
     solid cord (guy ropes, the smile); `ring` takes the same `wave` as a lathe so it follows a scalloped edge.
   - Shader: `fibre_scale`, `fibre_strength` and `bump_strength` (data/art.json "felt"): stretched noise darkens
     flecks and bumps the normal with screen-space slopes (one noise, no texture).
   - Camper: bigger head, hair under the hat, a ribbed knit beanie without a pompom, a bun with bangs and strands,
     bead eyes, a stitched smile, a nose, ribbed hem and collar, boots (`$boots`, `$strand` slots).
   - Sizes and colliders are unchanged; the mittens stay at `camper.hand_pos` so held tools still fit.
3. **Open work, in order:**
   1. The owner's verdict on the pilot; fix what they name.
   2. Still plain: animals, tools, saplings, stumps, water point, lantern post, bag covers, bundles, the pitch.
   3. Ideas from the reference not yet built: a stitched fence and sign, log-stump seats, mugs, a lantern on the
      table, a soft tilt-shift blur (the play camera belongs to Gameplay; ask first).
   4. A timing check on the laptop floor: the scene is about 180k vertices (ground scatter 65k) and the shader runs
      about seven noises per pixel; if it costs, give the Light preset a lighter material.
4. **Owner decisions:** the felt reference picture (25 Oct 2026) is the target look; pilot first (3 to 5 pieces), shown
   beside the reference in day and dusk, then roll out.
5. **Traps:**
   - The play camera is high, so a hat that sits low hides the face; check faces from the play camera, not only close.
   - A rib or hem lathe wider than the body at its height reads as a frilly skirt; measure the ellipsoid's width there.
   - Running stitches on a short curve break into dashes; use `gap: 0` for a line that must read as one stroke.
   - Captures need lavapipe: install `mesa-vulkan-drivers` if the log says OpenGL (build HANDOFF trap).
6. **How to check:**
   ```
   godot --headless --script res://tests/run_tests.gd -- --filter=felt
   xvfb-run -a -s "-screen 0 1920x1080x24" godot --script res://scripts/tools/capture.gd \
     --resolution 1280x720 --fixed-fps 30 -- --out=OUT_DIR --hero     # hero_<mood>.png, face_<mood>.png
   ```
   Then the plain capture (play camera) and `--clip` for a walk GIF. Put each next to the reference picture.
