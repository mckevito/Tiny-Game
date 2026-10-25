# Interface hand-off, 25 Oct 2026 (new role, split from Build after Stage B round 5; round 1 done)

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
   - Tests: `test_hud` (couch layout and the dock and Pack; its static `hud_fits` is shared), `test_settings`,
     `test_prompts`, `test_input_map`, `test_play_feel`, the HUD test in `test_stage_b`
     (`test_dropping_the_camp_box_and_a_hud_that_stays_on_screen`). Captures: `capture.gd --hud`.
2. **State now:** the HUD has a top-left hint (it stops short of the clock), a top-right clock with guests' wishes
   then odd jobs (just the clock line while the couch player's clipboard or workbench is open: `_right_panel_open`),
   toasts, a bottom-centre prompt in a centre column (`hud.prompt_width_px`; a player's own line hides while their
   Pack or workbench is open), and a corner dock per player: the tool and build piece in hand with the ones before and
   after either side (`HudDock.show_dock`, `tool_near`) and dots, then a Pack line. An open Pack, clipboard or
   workbench hides its player's dock. The Pack opens as a grid of rounded slots with kind-coloured tokens, counts and
   a name tag (I or D-pad down): low in the middle alone, in its player's bottom corner on the couch. Clipboards and
   the workbench sit below the hint (left) or clock (right) and stop above the bottom (`_fit_panel`,
   `Clipboard.fit`; a long page ends with `clipboard.more`). Tabs: Today, Bookings, Supplies, Field guide. The menu
   hides the HUD and scales to fit. Options: picture, sound, controls (remaps), access; picture and window rows wait
   for Apply.
3. **Open work, in order:**
   1. The owner plays round 5 and interface round 1; fix anything that overlaps or reads badly on their screen.
   2. The clipboard's map tab with plan marks both players see (with Gameplay), after the next gameplay round.
   3. Remaps: two actions can share a button only in different modes (D-pad left: undo in build mode). Settings
      swaps only an action's main binding.
   4. Later ideas: item icons in the Pack (render each item's felt model once), per-player prompts inside each half
      of the split; 2D panels use `FeltBuilder.swatch`, which is the linear colour (darker than the palette); the
      Pack tokens convert back with `linear_to_srgb()`, the panels were left as the owner has seen them.
4. **Owner decisions:** Animal Crossing is the model for the Pack and the tool and build cyclers; prompts show the
   glyph of the device used last; never "Press A" (the prompt test rejects "Press"); an Apply button in Options.
5. **Traps:** all of `handoff/build/HANDOFF.md` section 6, plus:
   - Headless windows are square: a layout test sets `root.size = Vector2i(1920, 1080)` and puts it back.
   - Panels docked on the same side overlap: opening the Pack or the workbench puts the clipboard away.
   - `CampMenu._fit` scales the whole panel; read its rect with `get_global_rect()` (it includes the scale).
   - A string with "Press" fails `test_prompts`; write "Choose" or name the glyph with `{action}`.
   - An autowrapped Label ignores `max_lines_visible` for its minimum height; to cut a long page, set `clip_text`
     and give it `custom_minimum_size.y` (`Clipboard.fit`).
   - At the biggest interface size (1280 x 720 of room) two clipboards and a prompt for each player don't fit side
     by side; the layout test lets the centre prompt and toasts pass under a clipboard there and nowhere else.
