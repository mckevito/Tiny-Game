# Build hand-off, 25 Oct 2026 (Stage A built, waiting on the owner)

1. **Owns:** game code (`scripts/`), scenes (`scenes/`), tests (`tests/`), data tables (`data/`), CI
   (`.github/workflows/`), the start-up script, `docs/STATUS.md`. Proposes changes to `docs/PLAN.md` for the owner.
   Never touches the reference repos. Until an `art` role starts, Build also owns the felt models (`data/models.json`).
2. **State now:** Milestones 0 to 3 are signed off and merged (Milestone 3: PR #8, owner "works and looks good",
   25 Oct 2026). Four Milestone 3 checks were not confirmed by name (`docs/STATUS.md`, "Still open"). Stage A (core
   proof) is built on its own branch and PR, waiting on the owner's try and merge.
   - Stage A: `scripts/camp/camp_day.gd` (CampDay: clock, calendar, sleep vote, `settle_night`, guests' stays) and
     `scripts/camp/camp_build.gd` (CampBuild: grid, build, pack, per-player undo) hang off `CampState` as `state.day`
     and `state.build` (held weakly, so no reference cycle). Numbers in `data/day.json` and `data/build.json`. A night
     pays only if `camp.last_settled` is below today's day number, and the settle, the payout and the next morning
     are saved in one write. Camp RPCs added: `_shared` (coins, calendar, stays, votes, ledger), `_clock` (1/s,
     unreliable), `_night` (summary), `_object_removed`; `_request` takes "build", "pack", "undo" and "sleep".
     Guests are `Camper` nodes in `visitors` that walk with `walk_target`; their tents are in `_tents`. Save version 2.
   - `scenes/camp.tscn` + `scripts/camp/camp.gd` is the main scene: start menu (play alone, host, join with an
     optional link code), the camp, the couch, and all the netcode (ENet, RPCs on the Camp node). `camp_state.gd`
     holds the rules (host decides) and link codes, `camp_save.gd` the save (slots, backup, upgrades),
     `camp_menu.gd` the menu, `scripts/net/local_profile.gd` this PC's profile ID and picture preset
     (user://profile.json).
   - Message flow: guest connects, sends `_hello(protocol, profile id, name, link code)`; host answers
     `_welcome(snapshot, your id)` or `_refused(text key)`. With a link code the host hands that couch character to
     the PC (dropping it off the couch first) and the PC adopts its profile ID. Changes go `_request` -> host
     `_decide` -> `_object_changed` to the guest (or `_denied`). Walking goes both ways with `_moved` (unreliable,
     20/s), one per local player. Host-only RPCs are `authority`; guest RPCs check the sender's profile. Protocol 2.
   - Couch: `couch_id`/`couch_pad` on the Camp. `_input` sees controller events before the menus: a controller not
     in `_p1_pads` pressing `menu` calls `drop_in`; `owner_of(event)` routes buttons. `PlayerInput`
     (`scripts/core/player_input.gd`) reads one player's devices from `data/input.json`; campers use it only while
     someone is on the couch. `CouchView` (`scripts/camp/couch_view.gd` + `split.gdshader`) is the split screen: the
     main camera is player one's half, a SubViewport camera draws player two's half only while split.
   - Picture presets: `scripts/core/quality.gd` + `data/graphics.json`; F1 shows fps, preset and render scale.
3. **Open work, in order:**
   1. Stage A sign-off: the owner tries it, says yes or no to the Proposed defaults (STATUS "Still open"), and
      confirms the four Milestone 3 checks: two-DualSense couch, a link code, a Tailscale join, and the fps on the
      weakest laptop (tune `data/graphics.json` from that).
   2. Stage B (three-day fun test), after Stage A is merged and signed off.
4. **Owner decisions:** see the decision log in `docs/PLAN.md`.
5. **Where the art lives:**
   - `data/palette.json`: named swatches (the plan's five plus Proposed shades). Models use only these names.
   - `data/models.json`: every model as parts (shape, size, pos, rot, colour). Variants (`camper_a`, `chair_honey`)
     name a `base` and swap `slots` and `show` options. The `_about` line lists every field.
   - `scripts/art/felt_builder.gd`: turns a model into one merged mesh with vertex colours; `felt.gdshader` is the
     one material (noise, grain, fuzzy edges, rim, glow for flames, sway, dithered fade).
   - `data/clearing.json` places models; `data/lighting.json` holds the moods; `data/art.json` the shader numbers.
6. **Traps already found:**
   - Godot's `--script` mode runs before autoloads exist; tests load what they need themselves.
   - In `--script` mode, nodes added during `_initialize`/`_init` don't get `_ready`. The test runner and the capture
     tool wait one frame first; tests can then add nodes under `root`.
   - A test file with a parse error used to hang the runner; it now counts as a failure. Typed `:=` on a
     `surface_get_arrays()[i]` value is a parse error; give the type.
   - Anything that walks needs a floor: the ground model has a collider in `data/models.json`.
   - Flat layers (ground, meadow, dirt, ash) need a few centimetres between tops or they z-fight.
   - `pkill -f <pattern>` matches your own shell command when the pattern is in it; it killed the session's shell
     twice. Kill by PID instead.
   - The repo is public: check every new file for personal data before committing.
   - New `class_name` scripts need `godot --headless --import` before the tests see them, or every test file that
     uses them "does not load (parse error)".
   - Two camps in one test process: give each its own branch with `SceneTree.set_multiplayer(SceneMultiplayer.new(),
     path)` before adding the camp, keep the camp's node path the same under each branch, and set the branches apart
     in space so their colliders don't meet. Camp code uses `position` (relative to the Camp), never global.
   - The first time a PC hosts, Windows asks to let Godot through the firewall; it must be allowed or joins fail.
   - Never `stop()` a camp from inside an RPC or a multiplayer signal: closing the peer there breaks; defer it.
   - A test that waits on the network must check every step it depends on, or a refused step makes later checks pass
     by accident (caught by breaking `pick_up` on purpose).
   - Godot's `Input` can't fake a controller's stick in headless tests. Couch tests call the Camp's `_input` and
     `_unhandled_input` with made-up joypad events, check `PlayerInput.owns_event`, and move campers by position.
   - A test that checks "each player is on their side of the split" also passed with the halves swapped; it now also
     checks each player is on screen. Check both side and bounds for anything on screen.
   - A camp in a test must not call `LocalProfile.save` with no profile file named, or it overwrites the real
     user://profile.json; `apply_quality(..., false)` at start-up exists for that.
   - A sub-object that points back at its owner (CampDay -> CampState) leaks both RefCounteds; hold the owner with
     `weakref` (the test runner's "ObjectDB instances were leaked" warning is the tell).
   - A ghost or node removed with only `queue_free` is still a child until the frame ends; `remove_child` first when
     the same frame checks for it.
   - The capture's first log line must say "Vulkan ... Forward+". If `mesa-vulkan-drivers` is missing, Godot quietly
     uses OpenGL and the frames don't match the owner's renderer: install it (`apt-get install mesa-vulkan-drivers`).
7. **How to check things:**
   ```
   godot --headless --import
   godot --headless --script res://tests/run_tests.gd
   xvfb-run -a -s "-screen 0 1920x1080x24" godot --script res://scripts/tools/capture.gd \
     --resolution 1280x720 --fixed-fps 30 -- --out=OUT_DIR [--clip]
   ```
   The exit code of the tests is the number of failures. Two real game copies on one machine:
   `godot --headless -- --host --slot=2` and `godot --headless -- --join=127.0.0.1 --profile=b`. Add
   `--write-movie OUT.png --quit-after 90` (with xvfb, no `--headless`) to save frames of a copy. The capture saves `play_<mood>.png` and `close_<mood>.png`
   from the play camera (and `clip_###.png` walking frames with `--clip`; make a GIF with ffmpeg). `--couch` instead
   plays a couch walk that splits and merges (`couch_###.png`, about 3 minutes on lavapipe). `--stage-a` saves
   `day_11/18/21.png`: a pitch, its guest and tent, and a build ghost at three hours of the day. It uses Forward+
   on software Vulkan (lavapipe, installed by the start-up script), so frames match the owner's renderer.
