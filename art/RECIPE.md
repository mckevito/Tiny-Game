# Recipe: knitted and felt models that match a reference

**This is the standard for every model in the game** (owner, 25 Oct 2026, after player two was made by it at medium
effort: "keep this art direction and formula because its the level of quality i want for the whole game"). The owner
picked the max-effort camper (PR #29, 25 Oct 2026) as the target quality. This file is how that camper was
made, so that a medium-effort thread can make the next character or prop just as well. It covers the order of work,
the numbers, and the mistakes not to repeat. The worked example is `art/characters/knit_camper/`.

## Tools
- `art/tools/knit_kit.py` is the shared Blender kit. It holds the mesh, the shapes (below), the baked shade and the
  export. A build script imports it and ends with `finish("<id>")`. The camper's script uses it unchanged: it builds
  byte for byte the same GLB as before the split.
- `art/tools/turnaround.sh DIR OUT [ZOOM]` runs one review round. ZOOM brings the studio camera that many times
  closer, for a model that many times smaller than the camper (about 4 for a hand-held prop). It builds the T-pose, renders eight studio views, and
  lays them beside the reference sheet. It takes about 2 minutes.
- `art/tools/compare.py` measures the renders against the sheet:
  - `sheets` lays them out (`compare8.png`, `pairs.png`, and `versus.png`, the one to show the owner).
  - `outline` gives the width at every 5 cm of height. It works on the sheet alone, before any renders exist.
  - `colours` gives the median colour of each band and the swatch that would match it.
  - `zoom` makes crops for checking the stitches.
  - `overlay` draws our outline in red over the sheet.
  - `siblings RENDERS REF.json OTHER_RENDERS` puts another model's round beside this one in each paired view
    (`siblings.png`), for a sibling made beside an approved model.
- `reference.json` sits beside each build script and gives the sheet's layout (see the camper's). The sheets stay
  in the project files under `tiny-game/reference/` and never go in git.
- Cloud set-up: Blender 4.0.2 is Ubuntu's package (`apt-get install -y blender`). The start-up hook installs Godot
  and tries to install the Vulkan software driver, but that can fail quietly (apt's lock): check with
  `dpkg -s mesa-vulkan-drivers` and install it yourself if it is missing. Without it the renders fall back to
  OpenGL, whose colours are far more saturated, and `turnaround.sh` now stops with a message. The tools also need
  Pillow and NumPy. On a fresh clone `turnaround.sh` imports the project first (it takes a minute or two).

## The loop, in order
1. **Plan from the sheet.** Write `reference.json`:
   - Each view's middle x, and the pixel row its soles touch.
   - `px_per_m`: the figure's height in pixels divided by the model's height in metres.
   - A plain background pixel, a crop box round each view, and the colour bands.

   Run `compare.py outline` on each view and turn the widths into a proportions table before you write any shape.
   Leave the three-quarter views out: the sheet is a generated picture and they disagree with the front and side.
2. **Declare the model before the first round:** the studio capture paints the T-pose from these slots, so
   `turnaround.sh` needs them.
   - In `data/models.json`, add `"<id>": {"file": "res://art/<kind>/<id>/<id>.glb", "file_slots": [...], "slots": {...}}`.
   - A file slot is either `$name`, a part the model's `slots` (or a variant) colours, or a fixed swatch.
   - New swatches go in `data/palette.json` and are Proposed.
   - Edit both files by hand. `json.dump` would reformat every line.
3. **Build big to small, one family of parts per round:** head and body masses, then the hat or other big
   silhouette, then clothes, then hair, and the face and stitches last. After each family, run `turnaround.sh` and
   look at `compare8_small.png` before reading any numbers.
4. **Fix in this order:** shape first (`outline` and `overlay`), then colour (`colours`, in the studio light), then
   material (`zoom` at 3 to 8 times). A shape change moves everything after it, but colour and material are cheap
   to tweak.
5. **Game pose and fit.**
   - Build without `--pose=t` into the model's folder, then run `godot --headless --import`.
   - For a character, `capture.gd --hero --player=<id>` gives the day and dusk shots. The play camera looks down
     at about 42°, so the face must show under the hat.
   - The hands must sit at `camper.hand_pos` in `data/tuning.json`. That file belongs to Gameplay, so ask them.
6. **Tests and hand-off.** Run `--filter=felt`, then the whole suite. Then the PR with `versus.png` and the in-camp
   shots, plus a line in `handoff/art/LESSONS.md`.

## A sibling or variant of a finished model (player two, 25 Oct 2026)
When the new model is a sibling of an approved one, and there is no sheet of its own:
- **Copy the approved script and change only the parts that make it distinct.** Player two's script keeps player
  one's head, face, sweater, arms, trousers and boots line for line, so the hands land on the same
  `camper.hand_pos`, and replaces the beanie and curls. Keep the same slot order in `file_slots`, so the game
  and the tests treat the two alike.
- **Use the approved model's `reference.json` for layout,** so `sheets` and `siblings` place the views the same
  way. `outline` and `colours` then measure against the other model's sheet: use them for the shared parts only.
- **Pick colours that differ in hue and value from the sibling,** from existing swatches where one fits. New
  swatches are Proposed. Judge them in the studio first, then in the `--hero` shot with both models
  (`--player=<one> --friend=<two>`), where they must read apart from the play camera.
- **Change the silhouette's top, not only the colours.** Players see each other from far off, so the head and its hat
  or hair carry most of the difference.
- **Player two's numbers** (the same body, 1.42 m to the top of the bun; `art/characters/knit_camper_b/`):
  - Hair cap: rings from a hairline (z 1.085 at the brow, 0.95 in front of the ears, 0.835 at the nape) over the
    crown to a pole, 12 mm off the skin. Walk the head as an ellipsoid: a unit-sphere direction maps to the surface
    (`on_head`), and directions are blended with a slerp, so paths never cut through the head.
  - Swept locks: 34 two-ply yarn locks (radius 17 to 21 mm), each slerped from the hairline to a ring round the
    bun's foot (21 degrees round the head from the bun's centre), on the same side as it started, so they never
    meet at a point. A sideways wave of 0.55 lock radii every 9 cm. They start low against the cap, so they look
    rooted.
  - Bun: a felt core (0.118 × 0.118 × 0.09) on the head, in the direction (0, -0.42, 0.91), with one fat yarn
    (radius 26 mm) wound 3.6 times from round its foot to near its top, like a cinnamon roll. A honey felt pin
    goes through it.
  - Headband: a latitude band round an axis leaning back 24 degrees, from 58 to 78 degrees off that axis. It is
    24 mm off the skin (clearing the locks under it), 32 mm thick, with 46 ribs 12 mm deep. It is built like the
    beanie's cuff (`ribbed`, sharp grooves on its outside).
  - Two loose curls in front of the ears, and flat blush cheeks (`blush_felt`).
  - Colours: sweater `mustard_knit` #B08743, headband and mittens `rust_canvas`, hair `bun_brown` #4B2D1D over
    `ink_brown`, trousers `moss_felt`. The first try with `olive_felt` trousers read as a bright green, so they
    were changed to `moss_felt`.
  - About 31k vertices: the hair is 8k (the swept locks are longer than player one's curls), the headband 3.9k
    and the bun 1.7k.

## A family of lighter characters (the guests, 25 Oct 2026)
For figures that appear several at a time, such as the camp's guests:
- **One shared body module, one small script per figure.** `art/characters/knit_guests/guest_body.py` is player one's
  head, face, sweater, sleeves, trousers and boots at a lighter level of detail; each `knit_guest_<name>/build_*.py`
  calls `body(girth)`, adds its own hat and hair, and ends with `guest_finish(name, scale)`, which scales the whole
  figure about its feet. Each folder works with `turnaround.sh` as it is.
- **Where the vertices went:** the sweater 24 columns (players 28), sleeves 10, collar 16, head 36 × 22, the felt
  masses decimated to 0.10 to 0.11, wider running stitches and no boot welts. About 15k vertices (29k to 32k
  triangles) against a player's 33k; a test keeps each guest under two thirds of a player.
- **Slots:** the players' twelve, then `$trim` for stripes, ribbons, buttons and ties.
- **Tell them apart by the top of the figure first:** a bobble with a pompom, a brimmed hat, a flat cap; then hair
  (plaits, a bob, a beard), then the sweater's colour. A test checks every guest's sweater, hat and hair against the
  players' and each other's.
- **Hats over hair:** size a hat to the hair's outside, not to the head, and keep the hair's fullness low where the
  hat sits. A hat over a face tilts back (10 to 17 degrees) and is checked from the play camera, not only in the
  studio: `capture.gd --hero --line-up` saves `play_guests_<mood>.png` at the play camera's pitch.
- **Brims and peaks:** a lathe whose profile runs under the brim out to its lip, round the lip, back along the top,
  then up the crown (the same turning sense as the beanie's cuff, so faces point out). A peak is a slab traced the
  same way, slice by slice round the front of the cap's foot.
- **Plaits:** three yarn strands round a Catmull-Rom path, each swinging side to side (`sin`) and in and out at
  twice that rate (`sin 2x`), a third of a turn apart, with a tie and a felt tuft at the end.
- **A second pose, cheaply** (Ranger Burl, 26 Oct 2026): a static model has no rig, so a pose is a second GLB from
  the same script (`--pose=talk`) and a model row that only swaps the file (`{"base": "ranger_burl", "file": ...}`).
  `body(arm_poses={side: (drop, forward)})` lifts an arm. Something held (his stick) is placed from the hand's own
  matrix, so it follows the pose.
- **A knitted beard:** a fused felt mass, then yarn locks laid on it by casting rays at the mass from in front
  (`surface_tree` and `hit`), each lifted half its radius off the hit and ending in a small curl.

## A hand-held prop (the knitted clipboard, 25 Oct 2026)
The worked example is `art/props/knit_clipboard/` (about 4.1k vertices; props go in `art/props/<id>/`).
- **Work from a brief when there is no sheet:** its size, swatches, budget, origin and how it is held. Put the
  origin where the hands hold it, and face the part people read toward the model's front (+Y in Blender, -Z in the
  game). Whoever puts it in a hand turns it from there.
- **Review with `turnaround.sh DIR OUT 4`** and look at the front, a three-quarter view, the side and the back.
  Without a `reference.json` there is nothing to measure against, so judge by eye against the knitted campers.
- **Flat felt pieces are slabs:** rings of a rounded rectangle (`ring_points` with `n_exp` 5) from the back, round
  the edge, to the front. Those rings run round the x-z plane, not round +Z as a lathe's do, so reverse each ring, or
  every face looks inward. Check the normals of a new kind of shape before judging any render: an inside-out board
  showed the writing through its back.
- **Fuzz shells poke through thin layers.** Every face grows fibre tips 6 mm out (data/art.json "shells"), so a
  face lying under a layer thinner than that (the board under the knitted page) speckles through it. Don't build the
  hidden face: the board's front is a frame that stops 4 mm inside the page's edge, and the page closes it.
- **A flat knit panel** is a `grid` with `closed=False` whose stitch map is (x / column width, height / row height).
  It needs only 2 vertices per column, because the shader draws the stitches from the stitch map. Run x from right
  to left so the faces look out of the front. The page's columns are 12.5 mm, finer than the sweater's, as small
  knitting would be.
- **Embroidered writing is a solid cord,** never a running stitch: at this size a running stitch reads as dots. Use
  `tube` with the yarn weave (radius 2 mm, 2.8 mm for a heading line) on a slight double wave. Set it into the
  surface by half its radius.

## How a model is made
- **One mesh, one material.** Each vertex carries:
  - UV.x: its weave (data/art.json "weaves": felt 0, knit_map 5, rib_map 6, yarn 7, bead 8).
  - UV.y: its slot index. glTF flips V, so the game reads `1 - UV.y`.
  - UV2 "Stitch": the knit's (column, row), or the yarn's (ply, twist).
  - Colour "Col": a baked shade between about 0.45 and 1, which the builder multiplies into the swatch.
- **Knitted parts are grids whose columns are the knit's own columns,** with 4 vertices per column. Rows are
  `KNIT_ROW` (0.42) column widths apart. Ribs are real ridges (`rib()`, 7 to 21 mm deep) with a sharp edge at each
  groove. The shader draws a V stitch in every column from UV2, so a stitch never smears across a seam.
- **The shapes in the kit:**
  - `lathe(profile [(z, half-x, half-y)], cols, 4, row_h, n_exp, ribs)`: sweaters, collars and sleeves. An `n_exp`
    of 2.4 gives a boxy body.
  - `ribbed(rings, ribs, 4, row_h, depth_of, weights_of)`: ribs on any ring stack, with `weights_of` blending in
    decreases (ribs halve, then halve again).
  - `tube(points, radius, yarn=(plies, metres per twist), lobe_depth)`: curls, cords and the smile.
  - `ellipsoid(...)`: heads, ears, hands and beads.
  - `fused([(centre, radii, basis)])`: felt masses made of overlapping blobs. It voxel-remeshes them (7 to 8 mm),
    smooths and decimates them (0.22 to 0.25), and you add the result with `append_mesh`.
  - `running_stitch(path)`: rice-grain stitches along a ray-cast path, made with `surface_tree` and `hit`.
- **Hat crown (camper script, `crown()`):** each rib column rises from just inside the cuff's fold, swells to the
  widest ring, then follows a quarter ellipse to the top. The ribs decrease from 36 to 18 at half way over the
  dome, then to 9 at 76%. The stitch columns follow the rib count in each band.
- **Hair:** a felt mass (`HAIR_SHADE`, darker) sits at least 10 mm off the skin. Over it go yarn locks (2 plies, a
  twist every 6 cm, radius 21 to 25 mm, lobe 0.18) that come out from under the cuff, S-wave, and end in a curl.
- **Budget:** the camper is 29k vertices. Hair is 6.3k, trousers 3.3k, the cuff 3.2k, the crown 3.1k and the boots
  3k. Keep a prop under about 5k. Anything placed many times belongs in the code builder (`data/models.json`
  parts), not in Blender.

## The camper's numbers (metres, 1.48 tall; Blender axes: +Z up, +Y front)
| Part | Numbers |
|---|---|
| Head | centre (0, 0.035, 1.0), half-axes 0.295 wide, 0.27 deep, 0.24 tall |
| Eyes (bead) | x ±0.117, z 0.972, half-axes 0.029 × 0.039 × 0.016; a glint 0.007 × 0.009 up and to one side |
| Smile (bead) | arc of radius 0.086 round z 0.951, from 215° to 325°, cord radius 0.0135 |
| Ears | (±0.262, −0.045, 0.918), 0.034 × 0.044 × 0.022, bare |
| Beanie cuff | tipped back 22° about (0, −0.005, 1.02); outside 0.395 × 0.37; 0.15 tall; a 0.05 fold; 40 ribs 17 mm deep; brow 1.16, nape 0.88 |
| Beanie crown | top (0, −0.03, 1.47); widest 0.35 at the sides, 0.29 at the front and 0.37 at the back, at z 1.15, 1.28 and 1.12; 36 → 18 → 9 ribs, 21 mm deep; a knot 0.024 |
| Hairline | z 1.07 at the brow, 0.93 in front of the ears, 0.98 over them, 0.82 at the nape; 26 locks |
| Sweater | z 0.39 to 0.75, widest 0.263 × 0.221, 28 columns; hem rib to z 0.47 (7 mm); mock neck to z 0.80, 24 ribs |
| Sleeves | pivot (±0.205, 0, 0.652), 0.38 long, radius 0.089, 12 columns; ribbed cuff from 0.205 along the arm |
| Mittens | 0.345 along the arm, 0.061 × 0.06 × 0.068; game pose arms down 58° and forward 8° |
| Trousers | hips at z 0.405; legs from x 0.117 at z 0.38 to x 0.142 at z 0.16; rolled cuffs at z 0.148 (0.116 × 0.14, tube 0.027) |
| Boots | (±0.162, 0.035, 0.062) at 0.118 × 0.18 × 0.066, plus an ankle blob; toes out 7°; a stitched welt |

These ratios carry over to any figure in this style:
- The head and hat together are the top half of the height.
- The hat is 1.34 times the head's width.
- The eyes are 40% of the head's width apart, 44% of the way up the head.
- The trousers and boots are a quarter of the height.

## Material and colour
- **Knit** (data/art.json "felt"): `stitch_aspect` 1.4, `stitch_width` 0.235, `rib_narrow` 0.78, `rib_shade` 0.35,
  `rib_groove` 0.2, `knit_depth` 0.5, `ply_strength` 0.1, `stitch_vary` 0.08, `yarn_shade` 0.45. `shells.count` is 1.
  In the shader, a V's leg runs out from 0.12 to 0.365 of a column from the column's middle, and up from 0.02 to
  1.16 of a row.
- **What makes knit read as knit:**
  - Short rows.
  - Legs that lean out about 30°.
  - A dark line between a V's two legs and another between columns, so the stitches look like wheat ears.
- **Camper swatches, all in data/palette.json:**
  - Skin and mittens: `peach_felt` #DEBA99.
  - Sweater: `dusk_teal` #547C87.
  - Beanie: `beanie_teal` #668F9B, lighter than the sweater, as on the sheet.
  - Trousers: `trouser_brown` #6E3F25. Boots: `boot_brown` #6E412B.
  - Curls: `curl_brown` #7A4A2C, over the hair mass in `curl_shadow` #5C3420.
  - Eyes and smile: `button_black` #1E1714. Glint: `warm_cream`. Stitches: `honey_thread`.
- **Match colours in the studio, never in the game's light,** which warms and saturates them. `compare.py colours`
  prints the swatch that matches: the old swatch times the measured ratio, in linear light. Hat, sweater, trousers
  and boots are within 2 sRGB steps of the sheet. Changing the stitch pattern changes how dark a part looks, so
  measure again after any material change.
- **Studio** (data/art.json "turnaround", lit like the owner's sheet):
  - Backdrop #FBF5E8.
  - Key light from 35° to the camera's right and 60° up, 7° soft, energy 1.25.
  - Ambient light 0.45, floor shadow 0.22.
  - Camera 6 m away at a height of 1.6 m, aimed at 0.74 m, with a 16° lens.
  - Drawn 2 times larger and scaled down, so fuzz looks soft instead of speckled.

## Mistakes already made (don't repeat them)
- **Fringe curls sank into the head.** The radius clamp took the smaller of two values. Use the larger, and keep
  every lock at least the head's radius plus the lock's radius from the head's middle.
- **The crown bulged past the cuff and came to a point.** Build it upright from measured outlines, with round tops,
  rising from the fold's inner edge.
- **A speckled band showed on the forehead.** The hair mass sat within a few mm of the skin, so the fuzz shells
  showed through. Keep it 10 mm off.
- **Single-pixel speckle in close-ups.** Supersample the studio. Shells: the old `next_pass` loop drew only the
  last shell, so `count` 1 is the look that was approved.
- **Seams showed on the comparison sheet.** The floor's occlusion differs from the backdrop, so composite each
  render row against its own ends (`multiply_onto`).
- **The sweater read as rows of chevrons.** The V legs touched across columns and the rows were too tall. Short
  rows and legs that stop short of the middle and the edge fixed it.
- **The hem looked like teeth.** Ribs 10 mm deep plus occlusion was too much; 7 mm works.
- **Colours judged in the camp's light came out wrong.** Match in the studio first.
- **A hat that sits at eye height hides the face from the play camera.** Keep the brow at least 9 cm above the eyes.
- **`json.dump` on data/models.json reformatted the whole file.** Edit by hand.
- **Renders judged under OpenGL.** If the Vulkan driver is missing, the capture falls back to OpenGL and every
  swatch looks far too saturated (player two's first round looked black-haired and neon). `turnaround.sh` now stops
  when this happens.
- **The sheet's views disagree** (hat height and tilt). Fit the front and the side and split the difference. The
  camper's knot stands about 4 cm above the sheet's hat.

## Verify before showing the owner
- **Shape:** `outline` within 1 to 3 cm at every height in the front and side views. The bottom 5 cm also catches
  the floor's shadow.
- **Colour:** `colours` within a few sRGB steps.
- **Material:** in a `zoom` crop, count columns and rows across the same patch. The sheet's sweater has columns
  about 5 cm wide, with rows 0.4 of that.
- **In camp:** the day and dusk `--hero` shots and the play camera.
- **Budget:** the vertex counts that the build prints.
- **Tests:** `--filter=felt`, then all of them.
