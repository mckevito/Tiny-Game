# Build hand-off, 25 Oct 2026 (Milestone 2)

1. **Owns:** game code (`scripts/`), scenes (`scenes/`), tests (`tests/`), data tables (`data/`), CI
   (`.github/workflows/`), the start-up script, `docs/STATUS.md`. Proposes changes to `docs/PLAN.md` for the owner.
   Never touches the reference repos. Until an `art` role starts, Build also owns the felt models (`data/models.json`).
2. **State now:** Milestones 0 and 1 are signed off and merged. Milestone 2 (two PCs, one camp) is built in one PR
   waiting on CI, the owner's two-PC try and the merge; check its live state on GitHub before talking about it.
   - `scenes/camp.tscn` + `scripts/camp/camp.gd` is the main scene: start menu (play alone, host, join), the camp,
     and all the netcode (ENet, RPCs on the Camp node). `camp_state.gd` holds the rules (host decides),
     `camp_save.gd` the save (slots, backup, upgrades), `camp_menu.gd` the menu, `scripts/net/local_profile.gd` this
     PC's profile ID (user://profile.json).
   - Message flow: guest connects, sends `_hello(protocol, profile id, name)`; host answers `_welcome(snapshot)` or
     `_refused(text key)`. Changes go `_request` -> host `_decide` -> `_object_changed` to the guest (or `_denied`).
     Walking goes both ways with `_moved` (unreliable, 20/s). Host-only RPCs are `authority`; guest RPCs check the
     sender's profile.
3. **Open work, in order:**
   1. Milestone 2: the owner's try on two PCs over Tailscale or LAN with keyboard and DualSense, then sign-off.
   2. Milestone 3: couch drop-in on the host's PC with the dynamic split screen, and link codes. Local players are
      just more profile IDs in `CampState.online`; `_guests` maps connections to profiles, so a local player needs
      no connection. Keep the two-player total across couch and online.
   3. Stage A: day clock, sleep vote and nightly payout write into the save fields that already exist.
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
   - Never `stop()` a camp from inside an RPC or a multiplayer signal: closing the peer there breaks; defer it.
   - A test that waits on the network must check every step it depends on, or a refused step makes later checks pass
     by accident (caught by breaking `pick_up` on purpose).
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
   from the play camera (and `clip_###.png` walking frames with `--clip`; make a GIF with ffmpeg). It uses Forward+
   on software Vulkan (lavapipe, installed by the start-up script), so frames match the owner's renderer.
