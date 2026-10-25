# Build hand-off, 25 Oct 2026 (Stage B round 2 built, waiting on the owner's play)

1. **Owns:** game code (`scripts/`), scenes (`scenes/`), tests (`tests/`), data tables (`data/`), CI
   (`.github/workflows/`), the start-up script, `docs/STATUS.md`. Proposes changes to `docs/PLAN.md` for the owner.
   Never touches the reference repos. Until an `art` role starts, Build also owns the felt models (`data/models.json`).
2. **State now:** Milestones 0 to 3 are signed off and merged (Milestone 3: PR #8, owner "works and looks good",
   25 Oct 2026). Four Milestone 3 checks were not confirmed by name (`docs/STATUS.md`, "Still open"). Stage A (core
   proof) is merged (PR #10) and signed off by the owner, 25 Oct 2026. Stage B (three-day fun test) is merged (PR #13)
   but NOT signed off: days 1 to 3 felt blank. Round 2 (owner's pick "items 1-6, map later", plus felling and
   replanting) is built on branch `claude/project-thread-s2hpsz` and waits on the owner's play and sign-off.
   - Round 2: `scripts/camp/camp_gather.gd` (CampGather: trees by clearing placement index, chop, fall to a stump
     with a sapling, take_sapling, plant, regrow in `new_day`; forage spots; the long log: `lay_log`, `log_by_fire`,
     `split_log`, `carry_speed`) and `scripts/camp/camp_tasks.gd` (CampTasks: the Today list; `note(event)` counts a
     step, an event matches a task's event or `event:sub`) hang off CampState as `state.gather`, `state.tasks`.
     `scripts/camp/wildlife.gd` (Wildlife node, made by `_build_world`) moves the animals on each PC locally (never
     sent); a local player near one asks the host "spot". `scripts/camp/clipboard.gd` is a per-player panel in
     `_boards`; while one is open `camera.hold_turn` makes Q/R (L1/R1) flip its tabs. Camp text for it is
     `clipboard_text(who, tab)`. `Clearing.placed` keeps scenery nodes by placement index (trees hide when felled;
     stumps and saplings are in `_tree_props`). `_progress(event)` after every host-approved step pays finished tasks.
     `Camper.speed_scale` slows a lone long-log carrier. New `_request` kinds: "chop", "forage", "spot",
     "take_sapling", "plant". Numbers in `data/gather.json`, `data/tasks.json`, `data/wildlife.json`. Save version 4,
     protocol 4. The welcome report shows only on menu starts (tests call `start_solo` directly and skip it).
   - Stage B: `scripts/camp/camp_guests.gd` (CampGuests: requests, `review` scoring, bookings, `goals`) and
     `scripts/camp/camp_pockets.gd` (CampPockets: fish, cook, pockets) hang off `CampState` as `state.guests` and
     `state.pockets` (weakref, like CampDay). Numbers in `data/guests.json` and `data/fishing.json`; the water point
     and lantern post are build kinds in `data/build.json` (`improvement: true`). Bookings live in the save's
     `reservations` (shared with the guest PC); pockets travel in `shared()["pockets"]`. `CampDay.arrivals()` runs a
     due booking first, then a walk-in (`maybe_arrive` keeps its Stage A shape); walk-ins leave free the pitches a
     booking due today needs. `settle_night` adds `reviews` and `bonuses` to the summary. The morning report is
     `scripts/camp/camp_report.gd` (Hud/Report), built by `camp.morning_report(summary)` on each PC from the summary
     plus its shared state, so both PCs read the same text. `action_for(who)` picks what interact does (place, give,
     cook, pick up, fish); fishing and grilling wait in `_busy` before asking the host. New `_request` kinds: "fish",
     "cook", "give", "booking". `_told` is a host-to-PC toast from a text key (`_say`, `_say_all`). Save version 3,
     protocol 3.
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
   - Picture presets: `scripts/core/quality.gd` + `data/graphics.json`; F1 shows fps, preset and render scale. The preset
     is now a setting of the PC (below); a profile from before settings existed still gives its old `quality`.
   - Title and settings: `CampMenu` holds every page in one felt panel (title, start, in-camp, and `options`, an
     `OptionsScreen` from `scripts/ui/options_screen.gd`); `page()` says which shows. `menu.visible` stays true while
     Options is open, so the clock still waits. `Settings` (`scripts/core/settings.gd`, rows in `data/settings.json`)
     keeps this PC's settings in user://settings.json and applies them; `Boot` calls `Settings.apply_all()`, which also
     registers the input actions. Remaps live in `binds` and come through `InputSetup.row(action)`, which
     `PlayerInput` (couch) and `Prompts` (glyphs) read, so read bindings through it, never from data/input.json
     directly. `UiLook` (`scripts/ui/ui_look.gd`) is the shared menu theme with the focus ring.
3. **Open work, in order:**
   1. Stage B round 2: the owner plays days 1 to 3 and signs off (or asks for changes); approve the Proposed numbers
      in `docs/STATUS.md`. Record the sign-off in the next build PR (no sign-off PR).
   2. Next round (owner): the clipboard's map tab with plan marks both players see.
   3. Still unconfirmed from Milestone 3: two-DualSense couch, a link code, a Tailscale join, and the fps on the
      weakest laptop (tune `data/graphics.json` from that). Ask at Stage B's sign-off.
   4. Stage C (autumn chapter) when the owner says go.
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
   - The test runner points `Settings` at user://test_settings.json (wiped each run) so tests never see the real
     settings; a test that changes settings calls `Settings.reset_page` for each page when done.
   - A Slider draws no focus ring; Options rows light their whole strip on focus instead (`UiLook.row_focus`).
   - A method named `remap` on a node clashes with GDScript's global `remap()` and fails to parse; pick another name.
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
   - A script error (a call on null, a bad index) does not stop a GDScript function: a test that hit one used to
     return "" and pass (a camp.gd parse error showed "64 passed"). `tests/run_tests.gd` now listens to the engine
     log (`OS.add_logger`) and fails any test during which a script error was logged.
   - An autowrapped Label in a container sizes to almost no width and the text vanishes off screen; give the Label
     itself `custom_minimum_size.x` (the morning report).
   - Godot `%` with a typed Dictionary lookup (`{...}[key]`) can't infer a type: give the variable a type.
   - Pitch spots in tests and captures: check them against `data/build.json` blockers first (a bush blocked
     (-1, 6)). Known good: (3, 5) near the fire, (-3.2, 7.9), (-4, 7); water point at (4, 8) or (0, 8). (-7.5, 5)
     is too close to the long log's morning spot since round 2.
   - Numbers read from JSON are floats: `[2, 3].has(3)` on a table array is false. Compare with `int(x) == n`.
   - `action_for` returns an `arg` for most actions; pass it on only where the request takes one (the busy chop
     did, grilling did not, and grilling silently failed).
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
   `day_11/18/21.png`: a pitch, its guest and tent, and a build ghost at three hours of the day. `--menus` saves the title, the start page, each
   Options tab and Options from the in-camp menu. `--stage-b` saves
   `camp_day.png`, `camp_dusk.png` (three pitches, guests with requests, water point, lantern), `fishing.png` and
   `report.png`, plus `welcome.png`, `chop.png` and `stump_log_clipboard.png` (round 2). It uses Forward+
   on software Vulkan (lavapipe, installed by the start-up script), so frames match the owner's renderer.
