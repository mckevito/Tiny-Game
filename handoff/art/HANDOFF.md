# Art hand-off, 25 Oct 2026

1. **Owns:** the felt models (`data/models.json`), the palette (`data/palette.json`), the material and builder numbers
   (`data/art.json`), the light moods' colours (`data/lighting.json`), `scripts/art/` (builder and shader), `art/`
   (outside art such as a rigged camper pack) and the `--hero` mode of `scripts/tools/capture.gd`. It doesn't edit
   Gameplay or Interface files; it asks those threads instead. Placement (`data/clearing.json`) and hand and name
   positions (`data/tuning.json` "camper") belong to Gameplay; ask before moving them.
2. **State now:** the art pilot (PR "Art pilot") brings the camper, the tent, the pine and the round broadleaf tree up
   to the owner's felt reference picture, adds felt fibres to the shared material, and warms the day light and grass.
   It waits on the owner's verdict. Review images: `/mnt/project-files/tiny-game/art-pilot/` (outside the repo).
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
   2. Roll-out, one family per PR: puff tree, bush and saplings; furniture (chairs, picnic table, log bench,
      workbench, camp box) with wood-grain stitches; the fire pit and stones; the pond with cattails and lily pads;
      stitched paths, fences and a sign; rocks; animals; tools.
   3. Grass tufts and small plants as scenery (needs Gameplay to place them; MultiMesh for the laptop).
   4. A timing check of the fibre shader on the laptop floor; if it costs, the Light preset sets `bump_strength` 0.
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
