# Fault log

One line per fault found by a playtest pass: where, what, who fixes it, and which check should have caught it (and
now does, once the owning thread adds it). Newest pass first. Frames are in the project files, not the repo.

## Pass 4, 26 Oct 2026 (PRs #44 to #58, each on its own branch, then main with #49 to #56 merged)
Each PR's tests pass, 147 on #58. Solo, couch (keys plus pad), 150% interface size, Low at dusk, and host and join
play with no script errors. Frames are in `playtest/pr<N>/` and `playtest/main-*`.
| Where | Fault | Owner | Check that should have caught it |
|---|---|---|---|
| PR #44 | The held knitted clipboard sat too low, so reading did not show from the play camera | Gameplay (fixed in PR #46: held at chest height) | A look at a reading frame from the play camera |
| PR #45 | At 150% the dock legend overlapped the action prompt, and the stick icon didn't read as a stick | Interface (fixed in PR #47) | `test_hud` at 150%, with the legend counted |
| PR #47 | Couch prompts were squeezed between the two docks | Interface (fixed in PR #48: couch prompts sit on their docks) | The couch HUD test at 150% |
| PR #50 | The name box hint said E paints the name, but on keys E types an "e" into the box (the box has focus) | Gameplay (fixed in PR #55: Enter on keys, Cross on a pad) | A test sending a real E key with its unicode through `Input.parse_input_event` while the box is open |
| PR #50 | At 150% on the couch, both docks drew over Burl's talk bubble | Gameplay (fixed in PR #55: docks and prompt hide while he talks) | The HUD layout test with Talk against each Dock, at 150% on the couch |
| PR #50 | A tent pitch could be built over the camp sign (`camp_sign` was not a build blocker) | Gameplay (fixed in PR #57; the sign moved to the foot of the path) | A test that no pitch fits within the sign's radius |
| PR #54 | Talking to Burl from the path, your own camper hides him and the raised arm; it only reads from the side | Gameplay (open, a framing idea) | A look at the talk frame from the front |
| main (#51) | Hold the tool key, press E by Burl, let go: the release was lost under the talk, and the ring stayed drawn round the walking camper until the next tap | Interface (fixed in PR #58) | A test that opens the ring, presses interact, releases, and finds no ring |
| main (#52) | At 150% the dev menu ran off the bottom of the screen, and the fps line ran under it over the Pack line | Interface (fixed in PR #58: rows scroll, fps line at the menu's foot) | The HUD layout test with the dev menu open at 150% |
| main (#51) | At 150% on the couch, each open ring covers its own player's legend | Interface (open, in its hand-off) | A look at both rings at 150% |

## Pass 3, 25–26 Oct 2026 (PRs #31 to #42, each played on its own branch)
Each PR's tests pass. Solo, couch (keys plus pad) and host and join play with no script errors. Frames are in
`playtest/pr<N>/`.
| Where | Fault | Owner | Check that should have caught it |
|---|---|---|---|
| PR #31 | After a keyboard start, a new pad could never become player one's | Couch (fixed by the Players page, PR #32) | A couch test that starts on keys, then plugs in a pad |
| main | A DualSense's Cross never pressed a menu button: Godot 4.7's `ui_accept` is only Enter, Kp Enter and Space | Couch (fixed in PR #34: interact and cancel pad buttons copied into `ui_accept`/`ui_cancel`) | A test that presses a focused button with a pad event through `Input.parse_input_event` |
| main | Refusal toasts were hidden while a menu page was open | Couch (fixed in PR #34) | The HUD layout test with the menu open |
| PR #33 | The stone ring's log seats clip through the folding chairs at (±1.5, 1.0–1.1), and the ring has no collider | Gameplay | A test that no placed seat overlaps another model's footprint |
| PR #35 | Player two's `reference.json` is a copy of player one's (the Beanie Camper sheet, teal colour bands) | Art | `compare.py` refusing a reference whose sheet or swatches don't match the model's own slots |
| main (#37) | The morning report with three guests is 1300–1380 px tall and runs off the screen; the welcome report does the same at 150% interface size | Interface (fixed in PR #40: long reports turn pages) | The HUD layout test with three guests' report, at 100% and 150% |
| PR #36 | The D-pad icons looked alike at real size; "( Tab )" had gaps in the brackets | Interface (fixed in PR #40) | A look at the couch frame at 1600 × 900 |
| PR #40 | At 120–150% the clipboard covered the action prompt; one-letter keycaps were thin; the hint wrapped between a keycap and its words | Interface (fixed in PR #40) | `test_hud.test_big_sizes_keep_prompts_clear_and_long_reports_turn_pages` |
| PR #40 | A one-letter keycap that starts a wrapped line loses its left padding (cosmetic) | Interface | A look at the hint at 150% |
| PR #41 | Guests walk in straight lines through chairs and past the fire ring's logs | Gameplay | A test that a guest's path to its activity spot stays clear of placed models |
| PR #39 | The edge woods add 18–56% more primitives at the edge (frame time up to a third more on lavapipe); laptop fps not yet measured | Gameplay, with the owner | Measuring fps on the Ryzen 7 5825U laptop on the Low preset |

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
