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
- None. The licence (MIT code, CC BY 4.0 art) was approved by the owner on 25 Oct 2026.

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

## Milestone 2: Two PCs, one camp
Signed off: yes, 25 Oct 2026 (PR #4 merged; the owner played on two PCs over their home network after letting Godot
through the Windows firewall).

| Proof | Test | Result |
|---|---|---|
| Host and join over the network; both players appear on both PCs, each steering only their own camper | `test_net.test_host_and_join_both_players_appear` | Passing |
| Each player's walking reaches the other PC | `test_net.test_movement_reaches_the_other_pc` | Passing |
| The guest carries and places a chair; the host decides (it refuses to take a chair out of the guest's hands); both PCs agree and the host's save holds it | `test_net.test_guest_carries_and_places_a_chair_and_the_host_decides` | Passing |
| Two players in total: a third PC is told the camp is full | `test_net.test_a_third_pc_is_told_the_camp_is_full` | Passing |
| Characters belong to profile IDs: rejoining on a new connection brings back the same character, where they left; a chair being carried goes back to its spot | `test_net.test_rejoining_brings_back_the_same_character`, `test_camp_rules.*` | Passing |
| Carry rules: one carrier per thing, one thing per player, reach, camp edge, room to put it down, scenery stays put | `tests/test_camp_rules.gd` | Passing |
| The camp save has room for the whole year (calendar, coins, wood, ledger, reservations, five areas, three staff, visitors, rating, journal, mailbox, profiles with outfits, pet and pockets) | `test_camp_save.test_new_camp_has_room_for_the_whole_year` | Passing |
| Three save slots; a backup of the previous save is used if the save breaks; older saves are upgraded; a newer save is refused and left alone | `tests/test_camp_save.gd` | Passing |
| Prompts show the button of the device the player last used; no string names a button | `tests/test_prompts.gd` | Passing |
| Host and join between the owner's two PCs | Owner's hands-on try | Passed on the home network (owner, 25 Oct 2026) |

### How to try it
1. Both PCs: open the project in Godot 4.7.2 and press F5. The camp menu opens (the M1 sandbox is still in
   `scenes/sandbox.tscn`).
2. Type your name. On the host PC pick a camp slot and choose **Host a camp**. Windows may ask to let Godot through
   the firewall the first time: allow it.
3. On the other PC type the host's address (its Tailscale name or address, or its LAN address) and choose **Join a
   friend**. The address is remembered for next time. The port is 24680 (`data/net.json`).
4. Walk with WASD or the left stick. Stand by a chair and press E or Cross to pick it up, again to put it down in
   front of you. Tab or Options opens the menu (back to camp, or leave).
5. To try on one PC: run a second copy with `-- --join=127.0.0.1 --profile=b` (a second player file), or start the
   host with `-- --host --slot=2`. `--solo` plays alone.

### Still open
- Not yet tried by the owner: the DualSense with carry and the menu, and joining over Tailscale. Check both during
  Milestone 3 (owner chose to sign off without them, 25 Oct 2026).
- Typing a name or an address needs a keyboard; a pad can do everything else. Both are remembered.
- **Proposed:** each PC steers its own camper and tells the other where it is (the host still decides every change
  to the camp). This keeps walking smooth on a slow link; the host doesn't check walking.
- The weaker PC's specs are not known yet; movement is sent 20 times a second (`data/net.json`), well within any PC.
