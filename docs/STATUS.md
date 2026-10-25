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
| Fishing at the pond always catches one of three fish by weight; grilling at the fire turns a raw fish into a meal; pockets hold a few items and a full pocket refuses more without losing anything | `test_guests.test_fishing_and_grilling_fill_the_pockets_and_never_fail` | Passing |
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
| Wood is spent: the log bench costs wood (packing gives it back) and grilling burns one | `test_gather.test_the_log_bench_costs_wood_and_packing_gives_it_back`, `test_guests.test_fishing_and_grilling_fill_the_pockets_and_never_fail` | Passing |
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
- Frame rate on the weakest laptop is still unmeasured; round 2 adds up to 10 animals (no lights or physics), stump,
  sapling, stick and berry models, and the clipboard panel.
