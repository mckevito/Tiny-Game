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

### Art pilot: toward the felt reference picture (25 Oct 2026)
Not signed off. Round 1 (camper, tent, pine, broadleaf) was "not good enough" (owner): round 2 makes the whole world
look knitted (wool weaves in the material, a ground of felt plants, every model in view reworked) and waits on the
owner's verdict. The owner asked for the models to look like their original felt
reference picture; the Art role's pilot covers the camper, the tent, the pine and the round broadleaf tree, felt
fibres on the shared material, and a warmer day light and grass (all **Proposed**). Sizes and colliders are unchanged.
The owner disliked the first Blender camper and asked for two separate rebuilds from their "Beanie Camper" turnaround
(25 Oct 2026); each is its own Proposed PR, and the owner picks one. The max-effort one knits the beanie, sweater and
curls along their own stitch map (stitch-mapped knit, ribs, two-ply yarn, bead eyes) with baked shading. The owner
picked the max-effort camper (25 Oct 2026, merged in PR #29) and asked for its method to be written down so a
medium-effort thread can repeat it: `art/RECIPE.md`, with the shared Blender kit and review tools in `art/tools/`.
A medium-effort thread then made player two by the recipe (`knit_camper_b`), and the owner signed off both campers
and the recipe as the quality bar for the whole game (25 Oct 2026): both players now use them (`camper_a` and
`camper_b` point at the knitted models), and the held tool sits in the knitted mitten (`camper.hand_pos`).

| Proof | Test | Result |
|---|---|---|
| Pilot models still build, use known shapes and swatches and keep their sizes | `tests/test_felt_models.gd` | Passing |
| The new lathe shape faces outward and its wave scallops the edge | `test_felt_models.test_lathe_faces_out_and_wave_scallops` | Passing |
| A cord stitch (the smile, guy ropes) is unbroken | `test_felt_models.test_stitch_cord_is_unbroken` | Passing |
| The sculpted camper keeps its stitch map, uses the knit, rib, yarn and bead weaves, and its baked shade only darkens | `test_felt_models.test_sculpted_camper_keeps_its_stitch_map_and_baked_shade` | Passing (fails without the shade) |
| The rebuilt camper matches the owner's turnaround | Owner's verdict (eight views beside the sheet, in-camp day and dusk) | Signed off (owner, 25 Oct 2026) |
| Both sculpted campers keep their stitch map and shade, and are painted from the palette | `test_felt_models.test_sculpted_camper_is_painted_from_the_palette` and `..._keeps_its_stitch_map_and_baked_shade` (both campers) | Passing |
| The two players look different (sweater, headwear, hair) | `test_felt_models.test_the_two_sculpted_players_look_different` | Passing |
| Player two, made by the recipe, matches player one's quality | Owner's verdict (side by side, against the sheet, in camp day and dusk) | Signed off (owner, 25 Oct 2026) |
| The pilot matches the reference closely enough to roll out | Owner's verdict (sheet beside the reference, day and dusk, walk GIF) | Waiting |

How to look: the capture's `--hero` mode (`handoff/art/HANDOFF.md`), or F5 the sandbox.
Still open: the laptop timing of the fibre shader; the roll-out to every other model, one family per PR.

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
- The DualSense with carry and the menu: tried and good (owner, 25 Oct 2026). Joining over Tailscale is still to
  try; it is checked in Milestone 3.
- Typing a name or an address needs a keyboard; a pad can do everything else. Both are remembered.
- **Proposed:** each PC steers its own camper and tells the other where it is (the host still decides every change
  to the camp). This keeps walking smooth on a slow link; the host doesn't check walking.
- Movement is sent 20 times a second (`data/net.json`), well within any PC. The weakest PC is now known (see the
  performance target in `docs/PLAN.md`).

## Milestone 3: Couch and link codes
Signed off: yes, 25 Oct 2026 (PR #8 merged; the owner: "works and looks good"). The four hands-on checks below were
not each confirmed by name; they stay open under "Still open".

| Proof | Test | Result |
|---|---|---|
| A controller player one has not used drops in with its menu button; hopping off the couch from that player's menu drops out; the character waits in the host's save and comes back next time | `test_couch.test_a_free_controller_drops_in_and_out` | Passing |
| Player one's own controller opens the menu and never drops in a second player | `test_couch.test_player_ones_own_controller_opens_the_menu_not_a_drop_in` | Passing |
| Each couch player steers and carries with their own devices only; a couch player's menu pauses only them | `test_couch.test_a_free_controller_drops_in_and_out`, `test_couch_players_carry_with_their_own_button` | Passing |
| Keyboard and controller on one couch: alone, player one plays with every device (a keyboard start can still pick up a controller); Options on a controller player one is not on drops in a second player (a stick nudge does not take a controller from a keyboard player); on the couch each player has one device | `test_couch.test_keyboard_player_one_and_a_controller_share_the_couch`, `test_a_keyboard_start_can_still_play_alone_on_a_controller`, `test_player_one_can_hand_their_controller_over_from_the_keyboard`, `test_player_one_back_on_their_controller_gets_the_menu` | Passing (owner's ask, 25 Oct 2026; PR #31, then the Players page) |
| Players page in the in-camp menu: each player chooses their device by pressing something on it (keyboard and mouse or a controller), player two's first choice drops them in, choosing the other player's device swaps, Swap devices trades them, and Player two: nobody drops player two out; a refused choice says why on the page | `test_couch.test_players_page_picks_swaps_and_clears_devices` | Passing (owner's idea, 25 Oct 2026) |
| Dynamic split screen: one shared view while close, a split at right angles to the players when apart (each on their own half), merged again when close; no jump at the moment of the split | `test_couch.test_split_screen_splits_apart_and_merges_together`, `test_split_aims_merge_close_and_lean_apart`, `test_screen_direction_matches_the_camera` | Passing |
| Two players in total across couch and online: a guest PC is told the camp is full while someone is on the couch, and a controller can't drop in while a guest PC is in | `test_couch.test_two_players_in_total_across_couch_and_online` | Passing |
| A link code moves a couch character to its own PC as the same character (same profile ID, no new character); a wrong code is refused; a used code is cleared | `test_couch.test_a_link_code_moves_the_couch_character_to_its_own_pc` | Passing |
| Link codes avoid look-alike letters and ignore case and the dash | `test_couch.test_link_codes_are_easy_to_read_and_type` | Passing |
| Picture presets: a low preset for the weakest PC reaches every view; the split screen draws its second view only while split, at a lower render scale | `test_couch.test_picture_presets_apply_to_every_view`, `test_split_screen_splits_apart_and_merges_together` | Passing |
| The owner tries the milestone | Owner's verdict | Passed: "works and looks good" (owner, 25 Oct 2026) |
| Couch play with two DualSenses, a link code to the second PC, a Tailscale join, and at least 30 fps on the weakest PC (F1 shows the fps) | Owner's hands-on try | Not confirmed one by one; see "Still open" |

### How to try it
1. Press F5 and play alone or host a camp, with the keyboard or the first DualSense.
2. Pick up a second DualSense and press Options on it: a second camper drops in. The first time it is a new couch
   character called "Couch friend"; after that it is whoever played in this camp most recently (not the host).
3. Walk apart: the screen splits along a line between you and merges when you meet again. Either player turns the
   shared camera (L1 and R1, or Q and R).
   Keyboard and controller: play on the keyboard and mouse, and hand the DualSense to your friend; their Options
   drops them in. Or open the in-camp menu, **Players**, and pick each player's device by pressing something on it
   (player two can take the keyboard too); **Swap devices** trades them.
4. Options on the second DualSense opens that player's menu: it shows the couch character's link code and has
   **Hop off the couch**. Player one's menu (Tab or Options on their own controller) shows the code too.
5. To move the couch character to its own PC: host the camp, and on the other PC type the host's address and the
   link code, then **Join a friend**. The camper leaves the couch and appears on that PC, and that PC plays it from
   now on. The code works once.
6. Tailscale: type the host's Tailscale name or address as the friend's address.
7. Press F1 for the fps counter. The in-camp menu has **Picture: Sharp / Light, for laptops**; try Light on the
   laptop, and split the screen there to see the slowest case.

### Still open
- Not confirmed by name at sign-off: couch play with two DualSenses, a link code to the second PC, a Tailscale join,
  and the fps on the weakest laptop (Light preset, split screen). Still not confirmed at Stage A's sign-off; check them
  before Stage B's sign-off. A low fps there means tuning `data/graphics.json`.
- **Proposed:** controllers are told apart by use: player one owns the keyboard, the mouse and every controller they
  have touched; a controller they haven't touched drops in with Options. If player one uses only the keyboard, the
  first controller to press Options drops in rather than opening player one's menu.
- **Proposed:** the camera turn and zoom are shared on the couch (either player can turn it), so the split line stays
  true. Trees fade only for player one's camera.
- **Proposed:** a couch character's name is "Couch friend" until it is claimed by its own PC, which keeps that PC's
  character name after that. Renaming on the couch needs the polish stage's name entry for pads.
- If a couch controller goes quiet, its camper waits; the next controller to connect that player one has not used
  takes over.
- Frame rate on the weakest PC is not measured yet (the cloud has no GPU); the presets are a first guess.

## Stage A: Core proof
Signed off: yes, 25 Oct 2026 (PR #10 merged; the owner: "i sign off"). The four Milestone 3 hands-on checks were not
mentioned; they stay open under Milestone 3's "Still open".

| Proof | Test | Result |
|---|---|---|
| The day clock runs from morning to evening over about 20 real minutes and waits at the end of the day until bed; the calendar turns days, seasons and years | `test_day.test_the_clock_runs_to_the_evening_and_waits_there`, `test_the_calendar_turns_days_seasons_and_years` | Passing |
| The light follows the clock from daylight into dusk; the HUD shows the season, day, time and coins | `tools/capture.gd --stage-a` frames; `test_stage_a.test_a_guest_walks_to_the_pitch_and_puts_up_a_tent` (coins line) | Looked at (day, 6:30 pm, 9 pm) |
| Grid placement: a pitch snaps to the grid in quarter turns, costs coins, and is refused over another building, a chair, scenery, the pond or past the camp edge | `test_day.test_grid_placement_snaps_costs_and_refuses_bad_spots` | Passing |
| Undo and pack away: each player undoes their own steps at a full refund; a packed pitch comes back on undo; a pitch with a guest stays; undo clears each night | `test_day.test_undo_and_pack_away_refund_in_full` | Passing |
| Build mode in the camp: the build button shows a ghost on the grid ahead with its price; interact builds, rotate turns, undo takes it back; nothing is picked up meanwhile; the save holds it | `test_stage_a.test_build_mode_builds_on_the_grid_and_undoes` | Passing |
| One guest: from 9 am a guest comes to a free pitch, walks in from the camp entry and puts up a tent there; after their night they head home and a new guest comes next morning | `test_day.test_a_guest_comes_to_a_free_pitch_stays_and_heads_home`, `test_stage_a.test_a_guest_walks_to_the_pitch_and_puts_up_a_tent` | Passing |
| Sleep vote: bed opens in the evening; everyone in the camp must be ready; either can cancel; a player who leaves takes their vote | `test_day.test_bed_needs_everyone_and_either_can_cancel`, `test_stage_a.test_bed_from_the_menu_needs_both_couch_players` | Passing |
| A night pays exactly once: a repeated or stale request, a save and load, and a guest PC leaving and rejoining (before or after the night) never pay it again; both PCs see the same coins | `test_day.test_a_night_pays_exactly_once`, `test_a_night_survives_save_and_load_without_paying_again`, `test_stage_a.test_a_night_pays_once_across_a_reconnect` | Passing |
| The guest PC sees the host's clock, guest and coins, and builds and undoes through the host | `test_stage_a.test_the_guest_pc_sees_the_day_and_builds_through_the_host` | Passing |
| A Milestone 3 save (version 1) is upgraded with the starting coins | `test_day.test_an_older_save_gets_the_starting_coins` | Passing |
| The owner tries the stage | Owner's verdict | Passed: signed off (owner, 25 Oct 2026) |

### How to try it
1. Press F5, then **Play alone** or **Host a camp**. The top right shows the season, day, time and coins (40 to start).
2. Press B (Triangle) for build mode. A ghost pitch sits on the grid in front of you: green means it fits, rust means
   it doesn't (the prompt says why). Walk to move it, F (Square) turns it, E (Cross) builds it for 25 coins. Z (D-pad
   left) undoes your last step; E on an empty pitch packs it away at a full refund. B again leaves build mode.
3. From 9 am a guest walks in from the path and puts up a tent on a free pitch.
4. From 6 pm open the menu (Tab or Options) and choose **Ready for bed**. Alone, the night comes at once; with a friend
   (couch or online) it waits for both, and either can choose **Not ready for bed yet**. The night pays 15 coins for
   the guest, who heads home in the morning.
5. To skip ahead, open the F1 panel on the host: the clock runs 30 times faster while it is open.

### Still open
- Defaults the plan left open, **approved by the owner** on 25 Oct 2026 (data/day.json, data/build.json): bed opens at 6 pm and is chosen from the
  menu; the clock waits while the menu is open with no guest PC in; 40 starting coins, a pitch costs 25, a night pays
  15; one guest at a time stays one night and comes from 9 am; undo is per player and clears each night; build mode is
  B or Triangle, turn F or Square, undo Z or D-pad left; F1 speeds the clock 30 times on the host.
- Guests walk in a straight line and pass through things; real paths come with more guests (Stage B or C).
- The calendar starts in spring (the plan); Stage C's autumn chapter will start its own days.
- Frame rate on the weakest laptop is still unmeasured; Stage A adds a few models and one ghost, nothing heavy.

## Stage B: Three-day fun test
Signed off: not yet. Built 25 Oct 2026 from the owner's approved picks (decision log). After the first play the owner
found days 1 to 3 blank (decision log), so round 2 below fills them; sign-off waits on playing round 2.

| Proof | Test | Result |
|---|---|---|
| Fishing at the pond always catches one of three fish by weight; grilling at the fire turns a raw fish into a meal; pockets hold a few items and a full pocket refuses more without losing anything | `test_guests.test_fishing_and_grilling_fill_the_pack_and_never_fail` | Passing |
| Each guest brings one small request (a fish, a grilled fish, a chair by their tent), shown over their head; handing the item over or setting a chair by the tent meets it and tips at once | `test_guests.test_a_request_is_met_by_a_gift_or_a_chair_and_tips_at_once` | Passing |
| One improvement choice: a water point (comfort) or a lantern post (atmosphere), built from build mode with the next-kind button | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_guests.test_each_stay_is_scored_once_with_a_line_that_names_its_cause` | Passing |
| Satisfaction: each stay is scored once when it ends (comfort, things to do, atmosphere); the guest tips by points and leaves a line naming what they loved and what they wished for | `test_guests.test_each_stay_is_scored_once_with_a_line_that_names_its_cause` | Passing |
| A short advance booking: offered on the board with its needs and nice-to-haves listed first; accept, a day later or decline with no penalty; it waits patiently for room, walk-ins leave its pitches free, and its extras bonus pays once | `test_guests.test_a_booking_waits_on_the_board_and_comes_when_there_is_room` | Passing |
| The morning report: last night's coins, each guest's line, extras bonuses, the bookings and the day's three goals (quick task, project, dream); interact starts the day | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_guests.test_the_day_offers_three_goals` | Passing |
| Three days from the buttons: fish, grill, give, accept a booking, build, sleep; morning 4 shows the next booking | `test_stage_b.test_three_days_of_play_from_the_buttons` | Passing |
| The guest PC fishes, gives and moves a booking through the host, and both PCs read the same morning report | `test_stage_b.test_the_guest_pc_fishes_gives_and_books_through_the_host` | Passing |
| Bookings and pockets survive save and load; a Stage A save (version 2) upgrades | `test_guests.test_stage_b_survives_save_and_load` | Passing |
| A test that hits a script error fails (it used to pass) | `tests/run_tests.gd` (engine log listener) | Checked by breaking a test on purpose |
| Review frames: pitches with guests and their requests (day and dusk), fishing, the morning report | `tools/capture.gd --stage-b` | Looked at |
| Both players want a fourth day and can explain the next booking | Owner's play | Waiting on the owner |

### Round 2: fuller first days (25 Oct 2026)
From the owner's feedback and the research report (Cozy first days and clipboard, in the project files), scope
"items 1-6, map later" (owner's pick). The clipboard's map tab comes next round.

| Proof | Test | Result |
|---|---|---|
| A tree gives a few wood, then falls: a stump stays and a sapling drops beside it (it waits there while pockets are full); planted at a bare stump it grows back in a couple of mornings | `test_gather.test_a_tree_falls_drops_a_sapling_and_grows_back_where_it_is_planted` | Passing |
| Forage spots refill each morning: sticks go onto the wood pile, berries into the pockets from day 2 | `test_gather.test_forage_spots_refill_each_morning_and_berries_wait_for_day_two` | Passing |
| Wood is spent: the log bench costs wood (packing gives it back) and grilling burns one | `test_gather.test_crafted_things_go_into_the_kit_and_build_mode_places_them` (round 3: the bench is crafted), `test_guests.test_fishing_and_grilling_fill_the_pack_and_never_fail` | Passing |
| The Today list: the firsts teach day 1 in order (sticks, chop, bench, fish, grill, pitch, plant), each pays a bonus, then daily tasks cycle; either player's step counts | `test_gather.test_the_today_list_teaches_with_firsts_then_cycles_daily_tasks` | Passing |
| Felt animals: rabbits and squirrels by day, deer at dawn and dusk from day 2, a bear who sits by the fire in the evening from day 3; they hop away from players, never threaten, are capped for the laptop, and spotting one goes in the journal | `test_gather.test_animals_keep_their_hours_and_days` | Passing |
| The long log: one lies at the woods' edge each morning; carried alone it is slow, with a friend beside it full pace; set down by the fire it splits into wood | `test_gather.test_the_long_log_goes_faster_together_and_splits_by_the_fire` | Passing |
| From the buttons: chop (the HUD's Today list moves on), grill with wood, fell a tree, pick up and plant its sapling, the clipboard's three tabs, the long log to the fire; the morning report says what is new tomorrow | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_stage_b.test_felling_replanting_the_clipboard_and_the_long_log_from_the_buttons` | Passing |
| Review frames: the welcome report, the animals by day and the bear at dusk, chopping, a stump with its sapling, the long log and the clipboard | `tools/capture.gd --stage-b` | Looked at |
| Days 1 to 3 feel full, and both players want a fourth day | Owner's play | Waiting on the owner |

How to try round 2 (a new slot): the welcome report lists the Today tasks. Pick up stick piles (E), chop a tree (E
by its trunk; three chops fell it), pick up its sapling and plant it at the stump, build a log bench (B, then C to
pick it), fish and grill. J (Touchpad) opens your clipboard; Q and R (L1 and R1) turn its pages; J again puts it
away. The long log lies at the west edge: carry it to the fire, faster with your friend beside you. Look for the
rabbits and squirrels, the deer at dawn and dusk from day 2, and the bear by the fire after 6 pm from day 3.

### Round 3: Pack, crafting and the camp box (25 Oct 2026)
From the owner's feedback on round 2 (the top-right HUD ran off the screen, the clipboard should tick off tasks as
things are gathered, and an inventory, dropping and a hybrid craft-then-cycle build system were missing) and the
research report (Cozy inventory and crafting, in the project files). Scope "items 1-4 now, rest next" (owner's pick).

| Proof | Test | Result |
|---|---|---|
| The top-right HUD wraps inside the screen at 16:9, 16:10 and 4:3, the Today list there is short (the clipboard has all of it), and toasts and prompts wrap instead of running off | `test_stage_b.test_dropping_the_camp_box_and_a_hud_that_stays_on_screen` | Passing (checked by breaking the toast width on purpose) |
| Each player has a Pack of 8 slots, each a stack of one item; a full Pack refuses more and nothing is lost | `test_guests.test_the_pack_stacks_drops_bundles_and_never_loses_anything`, `test_guests.test_fishing_and_grilling_fill_the_pack_and_never_fail` | Passing |
| A picked stack drops at your feet as a bundle that never goes away; dropping next to the same item joins it; picking it up takes what fits and leaves the rest | `test_guests.test_the_pack_stacks_drops_bundles_and_never_loses_anything` | Passing |
| The camp box takes every material in your Pack at once; crafting and grilling use your Pack first, then the box | `test_guests.test_the_camp_box_takes_materials_and_pays_for_crafts` | Passing |
| The workbench crafts a log bench, lantern post or water point into the shared build kit; build mode cycles what is in the kit (the tent pitch is always there, paid in coins); packing a crafted piece puts it back in the kit | `test_gather.test_crafted_things_go_into_the_kit_and_build_mode_places_them` | Passing |
| From the buttons: pick a slot, drop it, pick the bundle up, put wood in the camp box, craft at the bench and place it; the guest PC does the same through the host | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_stage_b.test_dropping_the_camp_box_and_a_hud_that_stays_on_screen`, `test_stage_b.test_the_guest_pc_fishes_gives_and_books_through_the_host` | Passing |
| Saves keep the Pack, the camp box, the kit and bundles; a round 2 save (version 4) upgrades: pockets become Pack stacks and the wood pile goes into the box | `test_guests.test_stage_b_survives_save_and_load` | Passing |
| Review frame: the workbench panel, the Pack bar and a dropped bundle | `tools/capture.gd --stage-b` (bench_pack.png) | Looked at |
| Gathering, crafting and placing feel good, and days 1 to 3 feel full | Owner's play | Waiting on the owner |

How to try round 3 (a new slot is best; an old one upgrades): your Pack is the bar along the bottom. C (D-pad right)
picks a slot and G (D-pad left) drops it; walk onto a bundle and press E to pick it up. Chop and gather, then press E
at the camp box (by the workbench, west of the fire) to put your wood and sticks in. Press E at the workbench, pick a
recipe with C or Q and R (L1 and R1), and E crafts it into the build kit. B then C cycles the kit; the tent pitch is
always there.

### Round 4: Animal Crossing style Pack, tools and a corner dock (25 Oct 2026)
From the owner's feedback on round 3 (the in-camp menu ran under the Pack bar and off the screen, Q and R turned the
camera at the workbench, and they wanted an Animal Crossing style inventory with the build piece and the tool shown
and cycled in the bottom right corner, plus window modes).

| Proof | Test | Result |
|---|---|---|
| The menu covers the HUD: the hint, toasts, docks and clipboards hide while it is open; it fits a 16:9 screen, even at the biggest interface size (it scales down); the day's goals left the menu (the morning report and clipboard have them) | `test_stage_b.test_dropping_the_camp_box_and_a_hud_that_stays_on_screen` | Passing (checked by putting the hint back and by turning the scaling off) |
| On a 16:9 screen with a full Pack, long names and toasts, no HUD piece leaves the screen or covers another (the Pack, the dock, the clipboard, the prompt, the clock, the hint) | `test_stage_b.test_dropping_the_camp_box_and_a_hud_that_stays_on_screen` | Passing (it caught the clipboard under the open Pack, so opening the Pack or the workbench now puts the clipboard away) |
| The Pack opens as a grid of 8 slots (I or D-pad down) with whole item names; the turn buttons or walking keys pick a slot, interact drops it, and the camper stands still meanwhile | `test_stage_b.test_dropping_the_camp_box_and_a_hud_that_stays_on_screen`, `test_stage_b.test_three_days_of_play_from_the_buttons` | Passing |
| The corner dock shows the tool in hand and the picked build piece, each with dots for its place in the cycle; next tool (T or D-pad up) goes hands, axe, rod; next kind (C or D-pad right) picks the piece and build mode starts on it | `test_stage_b.test_three_days_of_play_from_the_buttons` | Passing |
| Chopping needs the axe in hand and fishing the rod; without it the prompt says which tool to take out | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_stage_b.test_felling_replanting_the_clipboard_and_the_long_log_from_the_buttons` | Passing |
| At the workbench (and in the Pack and clipboard) Q and R no longer turn the camera | `test_stage_b.test_three_days_of_play_from_the_buttons` | Passing |
| Options has window, borderless and full screen (from the title-screen round) and now a window size | `test_settings` (every row has its text) | Passing |
| Review frames: the open Pack, the dock with the rod while fishing, the menu over a clean HUD | `tools/capture.gd --stage-b` (pack_dock.png, fishing.png, menu.png) | Looked at |
| The Pack, tools and dock feel like Animal Crossing's, and nothing overlaps on the owner's screen | Owner's play | Waiting on the owner |

How to try round 4: I (D-pad down) opens your Pack; Q and R or WASD pick a slot, E drops it, I closes. T (D-pad up)
cycles your tool in the bottom right: take out the axe to chop and the rod to fish. C (D-pad right) picks the build
piece shown under it, and B starts building it. Zoom moved to L3 and R3 on the controller. Options, Picture has
the window mode and a window size.

### Round 5: freedom, tents and a camera (25 Oct 2026)
From the owner's feedback on round 4: an Apply button in Options; go into your tent and sleep the day away; guests
in their tents, with a name bubble; day 1 must be finishable on day 1 and the day must never be stuck (the owner gave
a guest their fish, the guest had nothing more to ask, and bed would not open); gathering must never gate progress
(easy money any time) while guests' requests are the heart of the day; a camera to photograph the animals.

| Proof | Test | Result |
|---|---|---|
| Bed is open all day ("Sleep the day away" before the evening); it still waits for both players | `test_day.test_bed_needs_everyone_and_either_can_cancel` | Passing |
| A met request is followed by a new one a while later, up to a daily share that grows with the days; none at night; a chair request is not asked twice | `test_guests.test_guests_ask_again_up_to_a_share_that_grows`, `test_stage_b.test_guests_ask_again_tents_and_the_camera_from_the_buttons` | Passing |
| The corner lists what each guest would love first, then the odd jobs (optional, for coins); "help two guests" is gone from the odd jobs | `test_stage_b.test_guests_ask_again_tents_and_the_camera_from_the_buttons` | Passing |
| The camp's tent: crawl in at any hour, lie in a sleeping bag with the roof lifted away, ready for bed; interact gets you up; alone, it sleeps the day away | `test_stage_b.test_guests_ask_again_tents_and_the_camera_from_the_buttons` | Passing |
| Guests sleep in their tents from 8 pm with a name bubble ("Fern · zZ"); the tent opens when a player is close; sleeping guests are not asked for anything | `test_stage_b.test_guests_ask_again_tents_and_the_camera_from_the_buttons` | Passing |
| The camera (fourth tool): a photo of a nearby animal goes in the field guide (a new clipboard tab), the first of each kind pays a bonus, and a new odd job asks for photos | `test_stage_b.test_guests_ask_again_tents_and_the_camera_from_the_buttons` | Passing |
| Options: picture and window changes wait for Apply; leaving without it puts them back | `test_settings` (the in-camp Options test) | Passing |
| Review frames: a guest asleep in an opened tent with its bubble, the player in the camp's tent, the field guide | `tools/capture.gd --stage-b` (guest_tent.png, home_tent.png, guide.png) | Looked at |
| Day 1 feels free, guests carry the day, and the tents and camera are fun | Owner's play | Waiting on the owner |

How to try round 5: walk to the camp's tent (west of the fire) and press E to crawl in; E again gets you up. After
8 pm, walk up to a guest's tent to see them asleep. T to the camera, then E near a rabbit or a deer; J and Q/R to the
Field guide tab. Guests ask for something new about an hour after you help them.

### Interface round 1: a couch HUD that never overlaps, and the Animal Crossing polish (25 Oct 2026)
The first round of the Interface role (owner, 25 Oct 2026: a test for HUD overlap in couch split screen, then the Pack
and dock polished against the owner's Animal Crossing reference). On `main` the new test failed: on the couch the
couch player's clipboard covered the clock and the guests' wishes, and the clipboards and docks covered the prompts.

| Proof | Test | Result |
|---|---|---|
| Couch split screen at 1920 x 1080 with a full HUD (three guests' wishes, odd jobs, three toasts, a build prompt each, the bed line): both docks, both clipboards on every page, both Packs, a Pack with a clipboard, and the workbench with each: nothing leaves the screen, nothing covers anything else, and each player's panels stay on their own half | `test_hud.test_couch_split_screen_hud_never_overlaps` | Passing (checked by putting back the wide prompt, the dock under an open clipboard, and the full clock under the couch clipboard: each fails) |
| At the biggest interface size both clipboards still fit on screen and on their own half, clear of each other, the hint, the clock and the docks; a page too long shows what fits and says so | same test | Passing (only there may the centre prompts and toasts pass under a clipboard: there is no room for both) |
| The dock shows the tool and build piece before and after the one in hand, round the cycle, so a player sees what the next press brings | `test_hud.test_the_dock_shows_its_neighbours_and_the_pack_names_the_pick` | Passing |
| The Pack: rounded slots, a felt token coloured by the item's kind, the count in the corner, faded empty slots, and a name tag for the picked item that says what it is for | same test | Passing |
| Review frames: the dock, the open Pack, and on the couch both docks, both clipboards and both Packs | `tools/capture.gd --hud` (hud_dock.png, hud_pack.png, couch_docks.png, couch_clipboards.png, couch_packs.png) | Looked at |
| The couch HUD reads well and the Pack and dock feel like Animal Crossing's | Owner's play | Waiting on the owner |

What changed: prompts keep to a centre column 640 px wide (`hud.prompt_width_px`); an open clipboard or workbench hides
its player's dock, as the Pack already did; the clock folds to its own line while the couch player's clipboard or
workbench is open under it (the wishes and odd jobs are on the clipboard's Today page); a clipboard starts below the
hint or the clock on its side and a long page stops above the bottom of the screen; on the couch each Pack opens in its
player's bottom corner, where the dock was; a player's own prompt hides while their Pack or workbench is open; the
hint stops short of the clock. **Proposed** (data/tuning.json, data/text.json): token colours fish pond blue, meals
ember, fruit blush, plants leaf, materials wood; slot 128 px; dock 420 px wide with the neighbours at half strength.

How to try it: drop in a second controller (Options on it) and walk apart until the screen splits. Open both
clipboards (J and Touchpad), both Packs (I and D-pad down) and the workbench: nothing should sit on anything else.
Cycle the tool (T or D-pad up): the names either side of it are the one before and the one after.

Playtest's findings on round 1 (fixed in the next PR):

| Proof | Test | Result |
|---|---|---|
| Tab closes the in-camp menu it opened (a focused menu button used to take Tab and move focus instead) | `test_hud.test_the_menu_key_closes_the_menu_it_opened` (real key presses through the viewport) | Passing (fails without the fix) |
| An open clipboard, workbench or Pack never covers its own player's camper: that player's picture slides until the camper stands clear (`hud.keep_clear_*`) | `test_hud.test_couch_split_screen_hud_never_overlaps`, `test_hud.test_the_dock_shows_its_neighbours_and_the_pack_names_the_pick` | Passing (fails without the slide) |
| The F1 fps line sits at the bottom centre, clear of the clock and hint | `test_hud.test_couch_split_screen_hud_never_overlaps` | Passing |
| The hint wraps only between controls ("Tab for the menu" stays whole); a toast that comes with the morning report waits until it is put away | `test_hud.test_the_hint_wraps_between_controls_and_toasts_wait_for_the_report` | Passing |

### Interface round 2: DualSense button icons and keyboard keycaps (25 Oct 2026)
The owner (25 Oct 2026): "add the DualSense buttons instead of saying cross or triangle". Every prompt, the hint,
toasts, the dock captions and the panels' hints now draw the button itself: on a controller an original DualSense
icon (`art/ui/glyphs/`, made by `make_glyphs.py`), on keyboard and mouse a cream keycap with the key's name.

| Proof | Test | Result |
|---|---|---|
| Every default pad action draws an icon and no button word leaks through ("Cross", "Triangle"); each icon file exists; a key draws a keycap; an action on two buttons draws both | `test_prompts.test_prompts_draw_pad_icons_and_keycaps` | Passing |
| The HUD prompts, hint and Pack and clipboard hints show the icon of the device each player used last | `test_stage_b` prompt checks (now compare `Prompts.rich`) | Passing |
| Review frames: keycaps for the keyboard player and pad icons for the controller player on the couch, in the hint, prompts and both docks | `tools/capture.gd --hud` | Looked at |
| The icons read well on the owner's screen | Owner's play | Waiting on the owner |

What changed: the hint, prompt and toast are RichTextLabels; `Prompts.rich` turns `{action}` into icons or keycaps
(`Prompts.fill` still gives words, for the Options screen and the text tests); the icon map is `pad_icons` in
`data/input.json`; sizes and colours are `glyphs.*` in `data/tuning.json`. The Bookings "answer" line moved from the
page to the clipboard's hint. **Proposed:** icon height 34 px, keycaps warm cream on ink brown.

### Interface round 3: a knitted clipboard (25 Oct 2026)
The owner (25 Oct 2026): "make the clipboard look like an actual knitted clip board" with "a literally knitted piece
of paper that is used to have writing on". The clipboard (and the workbench, which shares its look) is now a knitted
wood-felt board holding a knitted cream sheet, with a ribbed honey clip across the top and a stitched rule under each
line of writing. The open tab is a honey felt tag. Keys on a cream panel are honey keycaps.

| Proof | Test | Result |
|---|---|---|
| The board and sheet are knitted (`scripts/ui/knit.gdshader`); a rule runs under every line of the page, starting where the writing starts and stopping at its end; the board shows above the sheet for the clip; keys on the sheet are honey caps that stand out from it | `test_hud.test_the_clipboard_is_a_knitted_board_with_a_ruled_sheet` | Passing (fails with the rules off by the tab row) |
| The couch layout still fits with the knitted board (the sheet's text is 16 px narrower so the whole board keeps its old width) | `test_hud.test_couch_split_screen_hud_never_overlaps` | Passing |
| Review frames: both knitted clipboards on the couch | `tools/capture.gd --hud` (couch_clipboards.png) | Looked at |
| The clipboard feels knitted on the owner's screen | Owner's play | Waiting on the owner |

The camper holding a clipboard while it is open is Gameplay's (PR #37, a felt stand-in); Art is making the knitted
prop to the same brief (wood-felt board, honey clip, cream sheet). **Proposed** (data/tuning.json `clipboard`, `glyphs`):
board wood_felt, sheet warm_cream, clip and rules honey_thread, stitches 16 x 11 px on the board and 12 x 8 px on the
sheet, paper keycaps honey_thread.

Playtest's notes on round 2, fixed here: the D-pad icons' pressed arm is now filled honey, so up, down, left and right
tell apart at prompt size; the Bookings line reads "Answer a new booking from the menu: Tab" (no gap inside brackets);
the top hint parts its controls with a wide space (text: glyphs.gap) instead of a dot, so a wrapped line never ends on
a lone dot (`test_hud.test_the_hint_wraps_between_controls_and_toasts_wait_for_the_report`). The hint crossing the
couch split and showing only player one's keys waits on the owner's controls-line pick.

Playtest's findings on round 3 (fixed in the same PR):

| Proof | Test | Result |
|---|---|---|
| A morning or welcome report too tall for the screen (three guests, or the biggest interface size) splits into pages that fit: interact turns them ("Next page (1 of 2)"), the last page's interact closes it, and cancel or the menu button still close it at once | `test_hud.test_big_sizes_keep_prompts_clear_and_long_reports_turn_pages` | Passing (fails with paging off) |
| At 120% and 150% interface size, alone on the PC, an open clipboard no longer covers the prompt: the prompt and toast column moves into the room beside it; toasts start below the hint and the clock, however many lines they wrap to; the clipboard moves down as soon as the hint grows | same test | Passing (fails without the column move) |
| A one-letter key's cap is wider (text: glyphs.key_pad_one, a no-break figure space, so the hint never wraps between a key and its words) | same test | Passing (an en space let "E" end a line at 150%) |

### Gameplay round 1: tents and tools both PCs see (25 Oct 2026)
Closes round 5's gaps: another player's tent visit and the tool in hand showed only on their own PC, and sleepers
lay on top of their bag.

| Proof | Test | Result |
|---|---|---|
| The tool in hand (axe, rod, camera) is drawn in the camper's mitten, and the other PC sees it | `test_net.test_the_other_pc_sees_the_tool_in_hand_and_the_tent` | Passing (checked by breaking it) |
| A player in the camp's tent shows on the other PC: camper hidden, lying in a bag, the tent opened, ready for bed; getting up shows there too; two players lie in two different bags | `test_net.test_the_other_pc_sees_the_tool_in_hand_and_the_tent` | Passing |
| Sleepers (players and guests) lie face up inside their sleeping bag, tucked in to the chin, head on the pillow | `tools/capture.gd --stage-b` (home_tent.png, guest_tent.png) | Looked at (cloud frames) |

The tool and the tent ride on the movement message the PCs already send 20 times a second (protocol 6, so both PCs
need this build). Neither is saved.

### Gameplay round 2: a sell crate and camp projects (25 Oct 2026)
The owner's next-round pick: places for gathered things to go. The field guide came in round 5; the star rating is
the next PR.

| Proof | Test | Result |
|---|---|---|
| The sell crate (by the camp's tent, south of the fire) takes one stack from the Pack a press, gives the last one back while there is nothing left to sell, pays at night at flat prices, and counts what was sold; saplings stay out | `test_projects.test_the_sell_crate_pays_at_night_and_gives_back_until_then` | Passing (checked by breaking it) |
| Three camp projects at the project board (west of the camp's tent), one open at a time: either player brings what it needs from their Pack and the camp box, only what is missing is taken, and a finished one opens its recipe (stool, flower planter) or pays coins, once | `test_projects.test_camp_projects_fill_from_both_players_and_open_a_recipe_once` | Passing |
| The guest PC sells and gives through the host; the clipboard's Supplies lists the crate and what was sold, the Today list names the open project, and both PCs' morning reports say what the crate paid | `test_projects.test_the_guest_pc_sells_and_gives_to_a_project_from_the_buttons` | Passing |
| A version 5 save gets an empty crate, sold list and projects (save version 6) | `test_projects.test_a_version_5_save_gets_the_crate_and_projects` | Passing |
| A stool counts as a chair for guests; a flower planter near a pitch is a new atmosphere point | `data/guests.json` | Built, not tested on its own |
| Playtest's finding on main: walking could leave the clearing into the empty field; players now stop at the edge | `test_camp_rules.test_a_player_cannot_walk_off_the_clearing` | Passing |
| Playtest pass 2: the crate keeps back what the open camp project still needs (only spare sticks or berries sell, and a press with nothing spare says so); what was already brought to the board frees that many up | `test_projects.test_the_sell_crate_keeps_back_what_the_open_project_needs` | Passing (fails when the crate takes the whole stack) |
| Playtest pass 2: woods ring the walking edge (data/clearing.json `border`: a row of bushes, then three rings of trees, the same every run) with the grass running on past them, so the edge shows and the sky band never does; no border tree is within chopping reach | `test_camp_rules.test_woods_ring_the_walking_edge_out_of_reach` | Passing (fails with no rings); frames from `capture.gd --edge` looked at |
| Review frames: the crate prompt, stools and a planter by the fire, Supplies with the crate, the morning report's sale line | Cloud frames (`stage-b/gameplay2_crate_projects.jpg` in the project files) | Looked at |

How to try round 2: carry sticks or a fish to the little crate south of the fire and press E; press E again with
nothing left to sell to take the last stack back. Sleep, and the morning report says what it paid. At the board west
of the camp's tent, E brings what the open camp project needs (J, Today, says what that is).

### Gameplay round 3: the camp's star rating (25 Oct 2026)
The last of the owner's next-round pick (the v1 pick "a camp star rating with ranger hints").

| Proof | Test | Result |
|---|---|---|
| The rating adds pitches, crafted pieces, happy guests (the last 3 nights' reviews), field-guide photos and finished projects, each up to a cap; a new camp has one star | `test_rating.test_the_rating_rises_with_the_camp_and_never_goes_down` | Passing |
| It is worked out each night and never goes down, even when things are packed away (no mess penalty) | `test_rating.test_the_rating_rises_with_the_camp_and_never_goes_down` | Passing (checked by breaking it) |
| The Today list (clipboard and morning report) gives the stars and one hint from Ranger Ada naming the first factor still short; the report says when a star is new | `test_rating.test_the_morning_report_and_today_list_show_the_stars_and_a_hint` | Passing |
| Review frame: the morning report with the stars and the hint | Cloud frame (`stage-b/gameplay3_rating_report.png` in the project files) | Looked at |

### First-minutes round 1: chopping that feels good, and a shovel (25 Oct 2026)
From the owner's feedback after playing (decision log, 25 Oct): if the first 3 to 15 seconds don't hook, waiting for
days won't help. The research doc "Hooked in the first minute" (a Claude Doc, linked in the project thread) found the
hook is hit, drop into the world, collect with +1. The owner picked this round first. Stage B is still not signed off.

| Proof | Test | Result |
|---|---|---|
| A chop pops one wood out of the tree onto the grass, fanned round the tree, never into the Pack directly; a full Pack still chops and the wood waits on the grass | `test_gather.test_a_tree_falls_drops_a_sapling_and_grows_back_where_it_is_planted` | Passing |
| Walking over a landed piece sweeps it into the Pack; a piece still in the air waits; a full Pack leaves it there (never lost) | `test_gather.test_a_tree_falls_drops_a_sapling_and_grows_back_where_it_is_planted` | Passing |
| The shovel (fifth tool) digs a stump (sapling or not) into a hole, popping its roots as wood and the sapling; a hole takes a sapling; an empty hole is grass by morning and no longer blocks building | `test_gather.test_the_shovel_digs_a_stump_into_a_hole_that_grasses_over` | Passing (checked by breaking it) |
| From the buttons: the camper swings the axe, the wood is in the air, walking onto it sweeps it up; a felled tree topples before it hides; the shovel's prompt and dig | `test_stage_b.test_three_days_of_play_from_the_buttons`, `test_stage_b.test_felling_replanting_the_clipboard_and_the_long_log_from_the_buttons` | Passing |
| Review clip: three chops, the tree toppling away from the camper, sweeping the wood with +1 tags, digging the stump | `capture.gd --chop` (`first-minutes-g1/` in the project files) | Looked at |

### First-minutes round 2: a campfire that grows, and a board you put up (25 Oct 2026)
The owner's asks "crafting like being able to make a bonfire or upgrade the existing one" and "putting up key items
like the board for events". Round 1 (PR #30) was merged by the owner on 25 Oct 2026.

| Proof | Test | Result |
|---|---|---|
| At the fire, the fire grows in two levels (a stone ring with log seats, then a big bonfire), paid like a recipe from the Pack, the camp box and coins; it says what is missing and stops at the last level; its light grows | `test_projects.test_the_fire_grows_in_levels_and_the_board_goes_up_from_the_kit` | Passing |
| Each fire level counts toward the star rating, with a ranger hint | `test_projects.test_the_fire_grows_in_levels_and_the_board_goes_up_from_the_kit` | Passing |
| The camp board starts in a new camp's kit and goes up wherever the players place it in build mode (a Today first, "Put up the camp board"); projects are given there and reading it opens the clipboard's Bookings | `test_projects.test_the_fire_grows_in_levels_and_the_board_goes_up_from_the_kit`, `test_projects.test_camp_projects_fill_from_both_players_and_open_a_recipe_once` | Passing |
| A version 6 save gets its board put up where the scenery board stood, a plain fire and no second board | `test_projects.test_the_fire_grows_in_levels_and_the_board_goes_up_from_the_kit` | Passing |
| The guest PC sees the board go up and the fire grow (the fire level is shared) | `test_projects.test_the_guest_pc_sells_and_gives_to_a_project_from_the_buttons` | Passing (checked by breaking it) |
| Review frames: the three fire levels at dusk | `capture.gd --fire` (`first-minutes-g2/` in the project files) | Looked at |

### First-minutes round 3: up to three guests at once, two nights each (25 Oct 2026)
The owner's asks "more than just one camper" and "the campers stay longer", with the owner's pick: up to 3 guests at
once, 2 nights each. Round 2 (PR #33) was merged by the owner on 25 Oct 2026.

| Proof | Test | Result |
|---|---|---|
| Up to three walk-in guests stay at once, arriving one by one (a gap between arrivals on the same day), and a fourth pitch stays empty | `test_day.test_up_to_three_guests_come_one_by_one_and_stay_two_nights` | Passing (checked by breaking it) |
| A guest stays two nights, pays each night and heads home on the second morning; bookings stay two nights and pay their bonus once | `test_day.test_up_to_three_guests_come_one_by_one_and_stay_two_nights`, `test_day`, `test_guests` | Passing |
| While a player reads the clipboard their camper holds it up, on both PCs (for the Interface round's clipboard) | `test_stage_b.test_felling_replanting_the_clipboard_and_the_long_log_from_the_buttons`, `test_stage_b.test_the_guest_pc_fishes_gives_and_books_through_the_host` | Passing |

### First-minutes round 4: guests who fish, take photos, fly kites, sit and play frisbee (25 Oct 2026)
The owner's ask "actively go fishing and take pictures of the animals and ... fly kites play fetch with a frisbee with
each other, sit on chairs". Round 3 (PR #37) was merged by the owner on 25 Oct 2026.

| Proof | Test | Result |
|---|---|---|
| Guests with nothing to ask go fishing, photographing, kite flying, sitting or resting, and two of them sometimes throw a frisbee to each other; never two on one spot; the same answer every time | `test_guests.test_free_guests_find_something_to_do_and_wait_home_with_a_request` | Passing |
| A guest with an open request, or asleep, waits by their tent; a carried chair is no seat; the grown fire adds its log seats | `test_guests.test_free_guests_find_something_to_do_and_wait_home_with_a_request` | Passing |
| In the scene, guests walk off and settle with the right prop or on their seat, a frisbee flies between a pair, and the guest PC shows the same | `test_stage_b.test_guests_go_fishing_sit_and_play_frisbee_on_both_pcs` | Passing |
| Review frames: three guests busy at three times of day, with close-ups | `capture.gd --guests` (`first-minutes-g4/` in the project files) | Looked at |

### How to try it
1. Press F5 and start a camp (a new slot is best: Stage B starts on spring day 1). Build a tent pitch (B, then E). From
   9 am a guest comes; their request floats over their head.
2. Tab (Options) opens the menu: the **Booking board** shows the Fern family for day 3 with what they need. Accept,
   ask them to come a day later, or decline.
3. Walk to the pond's edge and press E (Cross) to fish. Stand by the campfire with a fish and press E to grill it.
   Walk up to a guest with what they asked for and press E to hand it over. A chair carried next to their tent
   counts too.
4. In build mode, C (D-pad right) switches between the tent pitch, the water point and the lantern post.
5. From 6 pm choose **Ready for bed**. The morning report says what the night earned, how each guest felt and why,
   the bookings, and three goals for the day. E (Cross) starts the day.

### Still open
- **Proposed** numbers (data/guests.json, data/fishing.json, data/build.json): tips 4 for a fish, 6 for a grilled fish,
  3 for a chair, plus 2 coins per satisfaction point; things count as near within 6 m of a pitch (3.2 m for a chair,
  8 m for the pond); a water point costs 30 and a lantern post 20; the Fern family (2 pitches) is offered on day 1
  for day 3 with extras +10 (water point) and +8 (lantern post), the birdwatching club (3 pitches) on day 3 for day 5;
  pockets hold 6; a cast takes 2.5 s and grilling 2 s; next kind is C or D-pad right.
- The four Milestone 3 hands-on checks (two DualSense couch, a link code, a Tailscale join, fps on the weakest
  laptop) are still unconfirmed; ask at this stage's sign-off.
- **Proposed** round 2 numbers (data/gather.json, data/tasks.json, data/wildlife.json, data/build.json): a tree gives
  3 wood and regrows 2 mornings after planting; a chop takes 0.8 s; 4 stick piles a day and 3 berry bushes from day 2;
  grilling burns 1 wood; the log bench costs 5 wood and no coins; the long log gives 6 wood, goes at 45% pace alone
  and full pace with a friend within 2.2 m; up to 4 Today tasks, bonuses 3 to 5 coins; at most 10 animals, spotted
  within 5 m; the clipboard is J or the Touchpad. A new berries request (tip 4) opens on day 2.
- Guests still walk in a straight line. The clipboard's map tab with plan marks is the next round.
- **Proposed** round 3 numbers (data/items.json, data/craft.json, data/build.json, data/tuning.json): the Pack has 8
  slots of up to 99; a log bench takes 4 wood and 2 sticks, a lantern post 2 wood, 3 sticks and 10 coins, a water
  point 5 wood and 15 coins (crafted pieces cost no coins to place); the tent pitch stays 25 coins and is always in
  the kit; the build kit is shared by both players; drop is G or D-pad left (undo keeps D-pad left in build mode);
  the HUD shows 3 Today lines; bench and box reach 1.6 m and 1.4 m.
- Next round (owner's pick): a sell crate, camp projects, a field guide and the star rating, then the clipboard's map.
- **Proposed** round 5 numbers (data/guests.json, data/wildlife.json, data/tasks.json, data/settings.json): a guest
  asks again 60 game minutes after a met request, 3 requests a day from day 1, 4 from day 3, 5 from day 5; guests
  sleep from 8 pm; the tent opens within 2.8 m; a photo reaches 7 m and the first of each kind pays 5 coins; the
  photo odd job asks for 2 photos (4 coins); Apply covers picture, window, window size, vsync, frame limit and
  interface size.
- **Proposed** gameplay round 3 numbers (data/rating.json): pitches 4 points each up to 12, crafted pieces (lantern
  post, water point, log bench, stool, planter) 2 each up to 16, guests' satisfaction points over the last 3 nights 1
  each up to 12, animal kinds photographed 2 each up to 8, projects done 3 each up to 9; stars at 0, 10, 22, 36 and
  50 points; the ranger is Ada (renamable later, like every name). Stars never go down.
- **Proposed** gameplay round 2 numbers (data/projects.json, data/craft.json, data/tuning.json): crate prices stick 1,
  wood 2, berries 2, perch and sunfish 3, trout 4, grilled perch and sunfish 5, grilled trout 6; projects in order:
  fireside stools (8 sticks, 4 berries: the stool recipe, 2 wood and 2 sticks), flower planters (6 wood, 2 fish of any
  kind: the planter recipe, 3 wood and 2 berries), a tidy woodpile (10 wood, 10 sticks: 25 coins); crate and board
  reach 1.4 m; the walking edge is 14 m from the fire. The bigger Pack (8 to 12 slots) the research ranks as the best
  reward needs the Pack panel's grid to grow, so it waits for Interface.
- **Proposed** gameplay round 1 choices: tools are drawn 1.3 times life size so they read from the play camera
  (data/tuning.json camper.tool_scale); the camp's tent has two bags (rust and honey), a guest tent one (teal).
- **Proposed** round 4 choices: tools are hands, axe and fishing rod, every player has all three and the tool in
  hand is not saved; the Pack opens on I or D-pad down and the next tool is T or D-pad up, so zoom moved from the
  D-pad to L3 and R3 and the drop button went away (drop from the open Pack); the window size choices are 1280 × 720
  to 2560 × 1440, 1600 × 900 by default (data/settings.json); dock and Pack sizes in data/tuning.json.
- **Proposed** first-minutes round 1 numbers and choices (data/gather.json, data/items.json, data/save.json): a new
  camp starts with **100 coins** (owner's pick, was 40); wood lands 1 m from the tree, 55° then 110° either side of
  the chopper; it flies 0.45 s, sweeps up within 0.75 m once landed (0.6 s); a dig takes 1 s and pops 1 wood; the
  shovel is the last tool (hands, axe, rod, camera, shovel); a felled tree tips 84° over 0.6 s; puffs are 12 felt bits.
  Dropped bundles (G) still need a press to pick up; only pieces that popped out sweep up by walking. No sounds yet
  (the game has no audio so far). Online play needs both PCs on protocol 7.
- **Proposed** first-minutes round 2 numbers (data/craft.json, data/rating.json, data/tasks.json, data/save.json): the
  stone ring costs 6 wood, 4 sticks and 10 coins and lights 1.35 times as far; the big bonfire 12 wood, 6 sticks and
  30 coins, 1.8 times; each fire level is 3 rating points (up to 6); "Put up the camp board" is the third Today first
  (3 coins); an older camp's board goes up at (-6, 0). The fire is upgraded at the fire, after every other action
  there (a fish to grill, chairs and the camp box come first). The bigger light is one shadowed light made brighter,
  not a new light.
- Frame rate on the weakest laptop is still unmeasured; the first-minutes round adds at most a few short-lived pieces,
  12-bit puffs (CPU particles) and tweens per chop. Round 2 adds up to 10 animals (no lights or physics), stump,
  sapling, stick and berry models, and the clipboard panel.
- **Proposed** first-minutes round 3 numbers and choices (data/day.json, data/guests.json, data/items.json): up to 3
  walk-in guests at once (bookings come on top, as before), each staying 2 nights; a second guest comes no sooner than
  40 game minutes after one arrived that day; the Fern family and the birdwatchers now stay 2 nights too. The
  clipboard the camper reads is Art's knitted one (`knit_clipboard`, PR #38), held page toward the camper and tipped
  back (data/items.json tools.held.clipboard). Three guests add three campers and three tents, no lights.
- **Proposed** first-minutes round 4 numbers and choices (data/guests.json activities, data/items.json,
  data/models.json): a guest changes activity every 60 game minutes (80 real seconds); 3 fishing spots on the pond's
  bank, 3 photo spots facing where the rabbits, squirrels and deer live, 3 kite spots, seats on the two folding
  chairs, log benches (2 each), stools and the stone ring's two logs; with two free guests, half of the hours have two
  of them throwing a frisbee 5.2 m apart; a spot within 1.1 m of anything built is skipped. Guests still walk in
  straight lines. Activities pay nothing and the frisbee is seen by each PC alone (a look, not a camp change).
  The kite, raised camera and frisbee are plain felt stand-ins for Art. The cost is a disc and up to three held
  props; no lights or physics.

## Title screen and settings (quality of life, 25 Oct 2026)
Asked for by the owner alongside Stage B: a landing page with Start game, an Options screen and controls. Waits on the
owner's try. Research notes are outside the repo (project files, "Title screen and settings.md").

| Proof | Test | Result |
|---|---|---|
| The game opens on a title over the clearing (Start game, Options, Controls, Quit) with a button in focus; cancel goes back a page | `test_settings.test_title_start_options_and_back_with_focus_on_every_page` | Passing |
| Cross presses a focused menu button and Circle goes back on every menu page (Godot's ui_accept and ui_cancel take the pad buttons of interact and cancel, with remaps; found by Playtest, 25 Oct 2026) | `test_settings.test_cross_presses_menu_buttons_and_circle_goes_back` | Passing |
| One Options screen, opened from the title and the in-camp menu, and back returns to where it came from | `test_settings.test_options_from_the_camp_menu_rebinds_and_goes_back` | Passing |
| Settings are saved on this PC (user://settings.json), kept in range, and never in the camp save, the profile or the shared state | `test_settings.test_settings_are_saved_on_this_pc_and_kept_in_range`, `..._never_go_into_the_camp_save_or_to_the_other_pc` | Passing |
| Volumes reach their buses (overall, music, effects, ambience) | `test_settings.test_sound_settings_reach_their_buses` | Passing |
| Remapping on keyboard and controller swaps a clash, keeps the reserved keys, resets, and shows in prompts and in each couch player's own input | `test_settings.test_remapping_swaps_clashes_and_shows_in_prompts`, `..._pad_remaps_reach_each_couch_players_own_input` | Passing |
| Remapping from the screen: choose a key button, press the new key; the stop key keeps the old one | `test_settings.test_options_from_the_camp_menu_rebinds_and_goes_back` | Passing |
| The picture preset in Options reaches the camp's views (the existing Sharp and Light presets) | same test | Passing |
| Every option, choice and action has words | `test_settings.test_every_option_and_action_has_words` | Passing |
| Play alone and Host start a camp from the real start-page buttons, in the slot picked | `test_settings.test_play_alone_and_host_start_from_the_menu_buttons` | Passing |

### How to try it
1. Start the game: the title sits over the clearing. Move with the D-pad, the stick or the arrow keys; the focused
   button has a rust ring. **Start game** opens the familiar start menu (with **Back**).
2. **Options** has four tabs: Picture (Sharp or Light, window, vsync, frame limit), Sound, Controls and
   Accessibility (interface size, still trees). Left and right change a choice or a slider.
3. **Controls** (also a tab): choose a key or button, then press the new one. Escape or a click keeps the old key;
   on the controller, wait a moment. A clash swaps the two actions. **Reset this page** puts the defaults back.
4. In camp, the menu (Tab or Options) has **Options** too; back returns to the in-camp menu.

### Still open
- **Proposed** (docs/PLAN.md): remapping and the accessibility basics move forward from Stage E; the defaults are in
  `data/settings.json` (in a window, vsync on, 60 frames a second, volumes 80/70/80/70, deadzone 20%, interface 100%).
- There is no sound yet, so the volume sliders only set the buses that sound will use.
- Remaps are per PC, so both couch controllers share them; walking on the controller stays on the left stick.
