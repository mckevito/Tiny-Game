# Fault log

One line per fault found by a playtest pass: where, what, who fixes it, and which check should have caught it (and
now does, once the owning thread adds it). Newest pass first. Frames are in the project files, not the repo.

## Pass 1, 25 Oct 2026 (main after PR #19, PRs #20 and #21)
| Where | Fault | Owner | Check that should have caught it |
|---|---|---|---|
| main | Tab opens the in-camp menu but Tab again only moves focus (Godot's `ui_focus_next`); Escape and Back to camp close it | Interface | A test that sends real key events through `Input.parse_input_event` (tests call `camp._unhandled_input` directly, which skips GUI focus) |
| main | No walking edge: a player walks off the clearing into a bare field | Gameplay (fixed in PR #22) | `test_camp_rules.test_a_player_cannot_walk_off_the_clearing` (PR #22) |
| main | The F1 dev line overlaps the clock's second line and the hint | Interface | The HUD layout test, with the Dev label included |
| main | A toast that comes as the morning report opens draws under the report panel | Interface | The HUD layout test: a toast must not sit under the report |
| main | The hint wraps with a dangling "·" (main) or one lone word "menu" (PR #21) | Interface | A look at the camp HUD frame at 1600 × 900 |
| PR #21 | In split screen each player's open clipboard or Pack covers their own camper | Interface | The couch HUD test: a panel must not cover its own player's camper on screen |
| cloud | The start-up script stopped mid-install: Godot ready, no lavapipe, no line saying why; captures fell back to OpenGL | Playtest/QA | The start-up log now says "installing lavapipe" first; `playtest.gd` refuses to run without Vulkan Forward+ |
