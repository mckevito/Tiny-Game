# Interface hand-off, 25 Oct 2026 (new role, split from Build after Stage B round 5)

1. **Owns:** everything the player reads and presses.
   - Scripts: `scripts/ui/options_screen.gd`, `ui_look.gd`; `scripts/camp/camp_menu.gd`, `clipboard.gd`,
     `pack_panel.gd`, `hud_dock.gd`, `camp_report.gd`, `couch_view.gd`, `play_camera.gd`; `scripts/core/settings.gd`,
     `prompts.gd`, `input_setup.gd`, `player_input.gd`, `quality.gd`.
   - In `scripts/camp/camp.gd` (shared with Gameplay): the HUD (`_process` prompt and clock lines, `today_lines`,
     `guest_wants`, `_update_hint`, `_show_hud`, `_toast`, `_flash`), the docks and Pack panels (`_refresh_docks`,
     `open_pack`, `close_pack`, `_refresh_packs`), the clipboard and workbench panels (`toggle_clipboard`,
     `clipboard_text`, `field_guide`, `open_bench`, `bench_text`), `_hold_camera`, `_unhandled_input` routing.
   - `scenes/camp.tscn` (the Hud nodes), `project.godot` window and stretch settings.
   - Data: `data/settings.json`, `input.json`, `graphics.json`, the `hud`, `clipboard`, `dock`, `pack_panel` and
     `camera` sections of `data/tuning.json`; its keys in `data/text.json`.
   - Tests: `test_settings`, `test_prompts`, `test_input_map`, `test_play_feel`, the HUD test in `test_stage_b`
     (`test_dropping_the_camp_box_and_a_hud_that_stays_on_screen`, with `_hud_fits`).
2. **State now:** the HUD has a top-left hint, a top-right clock with guests' wishes then odd jobs, a bottom-centre
   prompt, toasts, and a corner dock per player (tool and build piece with dots, Pack line). The Pack opens as a grid
   (I or D-pad down). The clipboard has Today, Bookings, Supplies and Field guide tabs. The menu hides the HUD and
   scales to fit. Options: picture, sound, controls (remaps), access; picture and window rows wait for Apply.
3. **Open work, in order:**
   1. The owner plays round 5; fix anything that overlaps or reads badly on their screen.
   2. There is no overlap test for couch split screen (two docks, two clipboards, the clock): add one.
   3. The clipboard's map tab with plan marks both players see (with Gameplay), after the next gameplay round.
   4. Remaps: two actions can share a button only in different modes (D-pad left: undo in build mode). Settings
      swaps only an action's main binding.
4. **Owner decisions:** Animal Crossing is the model for the Pack and the tool and build cyclers; prompts show the
   glyph of the device used last; never "Press A" (the prompt test rejects "Press"); an Apply button in Options.
5. **Traps:** all of `handoff/build/HANDOFF.md` section 6, plus:
   - Headless windows are square: a layout test sets `root.size = Vector2i(1920, 1080)` and puts it back.
   - Panels docked on the same side overlap: opening the Pack or the workbench puts the clipboard away.
   - `CampMenu._fit` scales the whole panel; read its rect with `get_global_rect()` (it includes the scale).
   - A string with "Press" fails `test_prompts`; write "Choose" or name the glyph with `{action}`.
