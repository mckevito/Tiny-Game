# Status

What each milestone has, what the owner has signed off and what is open. Updated by whoever finishes work on a
milestone. Proof rows name the test that covers them.

## Milestone 0: Project setup
Signed off: yes, 25 Oct 2026 (PR #1 merged; the owner moved the capsule with the keyboard and a DualSense).

| Proof | Test | Result |
|---|---|---|
| Tuning tables load and read typed values with a fallback | `tests/test_tuning.gd` | Passing (headless, Godot 4.7.2) |
| Every input action has a keyboard or mouse binding and a joypad binding | `tests/test_input_map.gd` | Passing |
| The sandbox scene loads | `tests/test_sandbox.gd` | Passing |
| CI runs the tests on each push and PR | `.github/workflows/ci.yml` | Passing |
| A DualSense and the keyboard both move the test capsule | Owner's hands-on try | Passed (owner, 25 Oct 2026) |

### Still open
- Licence choice is Proposed (MIT code, CC BY 4.0 art).

## Milestone 1: Look and feel (felt art proof)
Signed off: yes, as a first draft (owner, 25 Oct 2026). Polish comes later; PR #2 waits on the owner's merge.

| Proof | Test | Result |
|---|---|---|
| Every model is built by code from `data/models.json`, painted only with palette swatches, with known shapes | `tests/test_felt_models.gd` | Passing |
| The plan's five swatches are kept exactly | `test_felt_models.test_plan_palette_is_kept` | Passing |
| The proof models (2 campers, tent, 3 trees, picnic table, 2 chairs, fire pit) stand on the ground at believable sizes | `test_felt_models.test_proof_models_stand_on_the_ground_at_believable_sizes` | Passing |
| Campers and chairs are one model with colour and hat/hair swaps | `test_felt_models.test_variants_swap_colours_and_options` | Passing |
| Everything solid shares the one felt material | `test_felt_models.test_one_shared_felt_material` | Passing |
| The sandbox clearing shows every proof model, with a fire light and fading trees | `tests/test_sandbox.gd` | Passing |
| Daylight and dusk both apply (dusk: weaker sun, stronger fire); the dev key cycles them | `test_sandbox.test_both_light_moods_apply`, `test_dev_key_cycles_the_mood` | Passing |
| Forward is away from the camera at any camera turn | `test_play_feel.test_forward_is_away_from_the_camera` | Passing |
| A tree between the camera and the player fades; one behind or aside does not | `test_play_feel.test_tree_between_camera_and_player_fades` | Passing |
| Movement and camera feel good with both inputs; the owner likes the look | Owner's verdict | Passed: "a very good first draft", polish later (owner, 25 Oct 2026) |

### How to try it
1. Open the project in Godot 4.7.2 and press F5 to open the sandbox.
2. Walk with WASD or the left stick. Turn the camera with Q and R or L1 and R1; zoom with the mouse wheel, `+` and
   `-`, or the D-pad up and down.
3. Press F1 (or the Create button) to switch between daylight and dusk.
4. Walk behind the trees near the bottom of the screen to see them fade.

### Still open
- Art polish later (owner, 25 Oct 2026: "we can always make it look better later").
- The extra palette shades in `data/palette.json` (grass, pine, wood, skin, stone, fire and so on) are Proposed.
- The prompts in the sandbox hint are words ("L1", "WASD"); real button glyphs come with the prompt system.
