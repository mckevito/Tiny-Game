# Build hand-off, 25 Oct 2026

1. **Owns:** game code (`scripts/`), scenes (`scenes/`), tests (`tests/`), data tables (`data/`), CI
   (`.github/workflows/`), the start-up script, `docs/STATUS.md`. Proposes changes to `docs/PLAN.md` for the owner.
   Never touches the reference repos. Until an `art` role starts, Build also owns the felt models (`data/models.json`).
2. **State now:** Milestone 0 is signed off (PR #1 merged). Milestone 1, the felt art proof, is in its first PR:
   the felt shader and model builder, ten proof models plus scenery, the clearing in the sandbox, two campers (one
   playable), the play camera with turn, zoom and tree fade, daylight and dusk. Check the PR's live state on GitHub
   before talking about it.
3. **Open work, in order:**
   1. Milestone 1: signed off by the owner as "a very good first draft" (25 Oct 2026); art polish comes later, so
      don't block Milestone 2 on it. Merge of PR #2 is the owner's.
   2. Milestone 2: GDScript netcode on Godot's multiplayer (host decides, profile IDs, stable object IDs). Plan 2.0
      (25 Oct 2026) makes v1 a full four-season year: give the camp save room for it from the start (see the
      Milestone 2 row in `docs/PLAN.md`), and keep three save slots in mind.
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
7. **How to check things:**
   ```
   godot --headless --import
   godot --headless --script res://tests/run_tests.gd
   xvfb-run -a -s "-screen 0 1920x1080x24" godot --script res://scripts/tools/capture.gd \
     --resolution 1280x720 --fixed-fps 30 -- --out=OUT_DIR [--clip]
   ```
   The exit code of the tests is the number of failures. The capture saves `play_<mood>.png` and `close_<mood>.png`
   from the play camera (and `clip_###.png` walking frames with `--clip`; make a GIF with ffmpeg). It uses Forward+
   on software Vulkan (lavapipe, installed by the start-up script), so frames match the owner's renderer.
