# Fault log

One line per fault found by a playtest pass: where, what, who fixes it, and which check should have caught it (and
now does, once the owning thread adds it). Newest pass first. Frames are in the project files, not the repo.

## Pass 2, 25 Oct 2026 (main with #22, #23, #24 and #26 merged)
105 tests pass; solo, couch, host and join play with no script errors. Fixed since pass 1: Tab closes the menu, the
F1 line sits at the bottom, split-screen Packs sit beside their campers, the walking edge holds at 14 m. Both owning
threads had closed, so these wait for the next Gameplay and Interface threads.
| Where | Fault | Owner | Check that should have caught it |
|---|---|---|---|
| main | The project board gives no prompt when you carry nothing it needs, so a player walking up can't tell what it wants | Gameplay (fixed in PR #33: "Read the camp board") | A test that the board's prompt names the open project's needs |
| main | The sell crate takes your first priced stack, even sticks or berries the open camp project needs; two presses can sell a project's materials | Gameplay (fixed: the crate keeps back what the project needs) | A test that the crate skips items the open project still needs, or asks first (owner's call) |
| main | The walking edge (14 m) is invisible and lies past the meadow, so you still walk out into bare grass with the sky band showing | Gameplay (fixed: woods ring the edge; `capture.gd --edge`) | A look at a frame from the edge; trees or a fence at the edge would show it |
| main | In split screen, player two's open clipboard still covers part of their camper and name | Interface (fixed in PR #36: the picture slides clear) | The couch HUD test, with each clipboard checked against its own camper |
| main | The hint still wraps with a dangling "·" at the end of its first line | Interface (fixed in PR #36: wraps between controls) | A look at the camp HUD frame at 1600 × 900 |

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
