# Our Little Campground: the plan

Version 2.0, 25 October 2026. The source of truth for what we build. Anything not here goes on the Later list.
Changes are marked **Proposed** until the owner approves them; approved changes get a line in the decision log.
The longer Game Development Guide (how to build each system, gaps, risks, research) lives outside the repo; this file
is the short, binding version.

## The promise
Two friends reopen a sleepy woodland campground and run it together through a full year. They restore pitches, build
amenities, welcome returning visitors, prepare for special weekends, and still leave time to fish, cook and sit by the
fire. *"Let's make one more little improvement… then go fishing."* The campground is our shared farm: instead of crop
fields we open accommodation, improve amenities and make places guests enjoy.

## The cozy contract
No combat, hunger, failure, dying, scores against the clock or customer timers. Guests wait patiently. Nothing rare is
ever lost. Decorations move freely and pack away at full refund. Either player can do every task. Both players confirm
sleeping and big shared purchases; either can cancel. Bookings are opportunities, not deadlines: every requirement is
listed before accepting, unready bookings can be declined or rescheduled, and missing a bonus never blocks progress.
No loans, tax or bankruptcy. No dependency on the real-world clock.

## The loop
**Plan the day → welcome campers → choose activities → improve the park → enjoy the evening → sleep together.**
The day runs from morning to a relaxed evening and waits there until both players sleep; the night settles stays,
income, upkeep, wages, construction and tomorrow's arrivals once. Players always have one quick task, one project for
today and one bigger dream on offer.

## Players and connection (owner decisions)
- **Two players in total.** Either both on one PC (couch co-op) or one on each of two PCs (online). Online comes first.
- **The host can play alone**; the partner's character, pockets, pet and tent wait safely in the save.
- **Couch drop-in and drop-out** with a **dynamic split screen** like modern LEGO games.
- **Persistent characters without accounts.** Each character belongs to a profile ID in the host's camp save (name,
  look, outfits, pet, carried items). A short **link code** lets a couch character be claimed later on another PC.
- **Online:** Godot's built-in multiplayer (ENet), host and join; Tailscale or LAN for two homes. The host decides
  every change to the camp; clients ask. Fresh GDScript netcode, ideas only from Dead Acre.
- **Talking without voice:** one ping button (tap: "look here"; hold: a small wheel) and 4 to 6 emotes.
- **A few optional together actions** (carry a canoe or long log, raise a big tent faster, a campfire song). Never
  required; alone, everything works at the normal pace.

## Input
Keyboard and mouse and the PS5 DualSense (USB and Bluetooth on Windows) are both first-class in every activity and
menu. One action-based input layer with contexts (gameplay, menu, placement) per player, so a menu press never also
acts in the world. Prompts show the glyph of the device that player last used. Controller disconnects pause only that
player. Remapping, deadzones and sensitivity come in the polish stage. The light bar may show the player's colour;
adaptive triggers, gyro and the touchpad stay optional extras.

## v1: one full year
| Area | v1 |
|---|---|
| Calendar | 4 seasons of 14 in-game days, about 20 real minutes per day (about 19 hours for year one). Starts in spring |
| After year one | A Year's End lantern night with returning visitors, then the years keep turning; events repeat with twists |
| Map | One valley, five areas opening through the year: Clearing (spring), Lakeside and RV loop (summer), Woodland trail and group clearing (fall), Cabin Hill (late fall, for winter) |
| Accommodation | Up to 12 tent pitches, 6 RV pads, 5 rental cabins, 1 group clearing |
| Cabins | Dollhouse style: the roof lifts away when you walk in; furnish from the normal camera. No walk-in interiors |
| Events | Two special weekends per season (8 a year), each an advance booking with essential and optional requirements |
| Amenities | About 10: sign-in post, washroom, water point, fire circle, camp kitchen, fishing dock, picnic spot, trail markers, garden corner, camp shop |
| Visitors | 12 named returning visitors (one preference, a few chats, a gift each); about 10 guests visible at once |
| Staff | Caretaker, shopkeeper, groundskeeper: one wage and one assignment each, no moods or shifts |
| Economy | Camp coins plus wood. Lodging, shop sales and event bonuses, minus supplies, wages and upkeep, in a daily summary. Three price levels per accommodation type |
| Satisfaction | Comfort, things to do, atmosphere; scored once per stay; each stay leaves a line that names its cause |
| Camp rating | 1 to 5 stars over the whole valley; a ranger visits each season with friendly hints; 5 stars unlocks a decoration set |
| Content | Rich: about 70 decorations from about 25 felt models with colour swaps, 20 fish (5 per season), 20 recipes, seasonal decoration collections |
| Characters | One felt body with colours, hats and hair, plus seasonal outfits (scarves, raincoats, winter hats) unlocked through the year |
| Pets | A pet each (dog or cat), named by its player, kept in that player's profile |
| Journal | Pages for fish, recipes, visitors and decorations, and a scrapbook with an automatic photo at every event |
| Weather | Rain, falling leaves and snow as looks and sounds only; nothing reads it |
| Saves | JSON camp save with a version number, a backup and migrations; profiles inside it. **Proposed:** three save slots |
| Audience | Just the two of us; a public release can be decided later |

**Proposed defaults:** visitors send thank-you letters (sometimes with a gift or recipe) to a camp mailbox; birds by
day, fireflies and stars at night and a deer by the trail as background life; upkeep and wages never push the balance
below zero (anything unpaid is skipped that night).

## Art direction: felt and fabric miniatures
Everything looks like one handmade camping set, knitted and felted: the whole world as if it were knitted together.
**The quality bar for the whole game (owner, 25 Oct 2026):** the two knitted campers (`art/characters/knit_camper/` and
`knit_camper_b/`) and the method that made them, `art/RECIPE.md` with `art/tools/`. Every new model is made by that
recipe and held to that level: real knit stitches, ribs and two-ply yarn on a stitch map, felt masses, bead faces,
baked shade, matched to a reference in the studio and checked in camp by day and dusk. Readable silhouettes still come
first, and anything placed many times stays in the code builder with the same weaves. Cloth simulation stays out.
The first pass at this paragraph (matte shapes, no fibres, one code-built rig) is superseded.

| Swatch | Hex |
|---|---|
| Moss felt | `#536B50` |
| Rust canvas | `#BB704C` |
| Honey thread | `#D6AF66` |
| Pond blue | `#6B929C` |
| Warm cream | `#EEE3CB` |

**Proposed:** supporting shades for grass, pine, leaves, bark, wood, stone, sand, skin, blush, embroidery ink, teal,
denim and fire, listed in `data/palette.json`, so the models never need a colour outside the table. Seasons are
palette-swap tables over these names before any new models.

**How we make it cheaply:** models are built by code from simple rounded shapes listed in data tables, painted only
with named palette swatches. One shared felt material. Each batch is reviewed as one contact-sheet screenshot from the
play camera, in daylight and at dusk. Elevated third-person camera, limited zoom, trees fade when they hide a player.

**Accessibility baseline:** UI scale, separate music and effects volume, visual cues alongside sound, readable
prompts, player names as well as colours, hold-or-toggle for held buttons, camera shake off.

## Performance target (owner)
The weakest PC is a laptop with an AMD Ryzen 7 5825U and its built-in Radeon graphics (8 compute units sharing system
memory), 32 GB RAM, Windows 11. Every stage must hold **at least 30 fps, aiming for 60**, on it at 1080p, in the
busiest scene that stage has (an event with about 10 guests; from Milestone 3, couch split screen too).

**Proposed** ways to stay there:
- A quality table (`data/graphics.json`, built in Milestone 3) with a low preset for this laptop: render scale 0.75
  with FSR upscaling, SSAO and glow off, one sun shadow at a modest size, FXAA instead of MSAA, fewer particles.
- Split screen draws the world twice, so it gets its own lower render scale (built in Milestone 3: 0.6 on low), and
  draws the second view only while split.
- Many-of-a-kind scenery (trees, grass tufts, path stones) drawn with `MultiMeshInstance3D`; guests stay at about 10.
- An fps and frame-time readout on the F1 dev menu, and a timing check on this laptop at every stage sign-off.
- If Forward+ can't hold 30 fps on the low preset, try Godot's Mobile renderer before cutting art.

## Milestones
Each passes before the next starts. No dates. Stages A to E replace the old Milestones 4 to 6.

| # | Milestone | Passes when |
|---|---|---|
| 0 | Project setup | Done (signed off 25 Oct 2026) |
| 1 | Look and feel | Done: felt art proof, a first draft (signed off 25 Oct 2026) |
| 2 | Two PCs, one camp | Done: host and join, carry and place, profile IDs, a whole-year camp save (signed off 25 Oct 2026) |
| 3 | Couch and link codes | Couch drop-in and drop-out on the host's PC, dynamic split screen, a link code moves a character to the other PC |
| A | Core proof | Done (signed off 25 Oct 2026): one pitch, one guest, day clock, sleep vote, nightly payout, grid placement with undo; a night pays exactly once, even after save, load or a reconnect |
| B | Three-day fun test | Small requests, one improvement choice, a short advance booking, fishing or cooking, satisfaction lines, the morning report; both players want a fourth day and can explain the next booking |
| C | Autumn chapter | 14 days of fall: tent pitches, washroom, water point, fire circle, the group campout, staff, a small shop, the first RV pad, weather looks, one together action; a lazy-play headless test still affords the RV loop; playable start to end on either input alone |
| D | The other three seasons | Spring, summer and winter areas, events and visitors; dollhouse cabins on Cabin Hill; the camp rating; the lantern-night finale and the turn into year two |
| E | Rich content and cozy polish | The full content list, journal and scrapbook, pets, sound, remapping, accessibility, pacing; v1 ships to the two of us |

## If it grows too large
Cut in this order: decoration count toward 40, fish and recipes toward 12, visitor count toward 8, seasonal outfits,
together actions. Never cut both input methods, two-player reliability, decorating, the four seasons, progression or
save recovery.

## Later (not in v1)
Next round (owner, 25 Oct 2026): the sell crate, camp projects, field guide and the camp's star rating are built; next the
clipboard's map tab with plan marks both players see. A free photo mode, text chat, separate remaps for each couch player, a credits page, walk-in interiors, weather that changes gameplay, more shops or worker roles, more than
two players, a public release (itch.io or Steam), Steam's relay, consoles, voice acting.

## Decision log
- 25 Oct 2026, owner: online on two separate PCs comes first; the repo is public, so no personal data or Dead Acre
  material goes into git.
- 25 Oct 2026, owner: couch drop-in and drop-out with persistent characters that can rejoin from another PC.
- 25 Oct 2026, owner: dynamic split screen like modern LEGO games; two players in total.
- 25 Oct 2026, owner: fresh GDScript netcode, ideas only from Dead Acre.
- 25 Oct 2026, owner: keep a hand-off and lessons method like the reference repos.
- 25 Oct 2026, owner: the felt art proof is a very good first draft; polish the look later.
- 25 Oct 2026, owner: the seasonal campground and co-op tycoon design is the direction; v1 is one full year, fairly
  fleshed out but not a heavy simulation; work backwards from v1 through Milestones 2 and 3 and Stages A to E.
- 25 Oct 2026, owner picks for v1: 14-day seasons; about 20 minutes per day; start in spring; lantern-night finale,
  then endless years; dollhouse cabins; looks-only weather; coins plus wood; the host can play alone; 12 named
  visitors; about 10 visible guests; three staff roles; rich content; one valley with five areas; a large camp (12
  pitches, 6 RV pads, 5 cabins); seasonal outfits; a few optional together actions; a camp star rating with hints; a
  journal with an automatic scrapbook; pings and emotes; a pet each; v1 is just for the two of us.
- 25 Oct 2026, owner: Milestone 2 is signed off after two-PC play on the home network.
- 25 Oct 2026, **Proposed** (Milestone 2): each PC steers its own camper and tells the other where it is; the host
  decides every change to the camp (carrying, placing, everything saved). A third PC is told the camp is full.
- 25 Oct 2026, owner: licence MIT for code and CC BY 4.0 for original art.
- 25 Oct 2026, owner: the weakest PC (Ryzen 7 5825U laptop, built-in Radeon graphics) must run at least 30 fps,
  aiming for 60.
- 25 Oct 2026, owner: Milestone 3 (couch and link codes) is signed off: "works and looks good".
- 25 Oct 2026, **Proposed** (Milestone 3): a controller player one hasn't used drops in with Options; couch players
  share the camera's turn and zoom; a new couch character is "Couch friend" until its own PC claims it with a
  one-use link code, after which that PC plays it under the same profile ID.
- 25 Oct 2026, **Proposed**: three save slots; thank-you letters; background wildlife; upkeep never below zero.
- 25 Oct 2026, owner approved (Stage A defaults): bed opens at 6 pm and is chosen from the menu; a player who leaves takes their
  vote; the clock waits while the menu is open with no guest PC in; 40 starting coins, a pitch costs 25 and a night
  pays 15; one guest at a time, one night each, arriving from 9 am; undo is per player and clears each night; F1 runs
  the clock 30 times faster on the host.
- 25 Oct 2026, owner: Stage A (core proof) is signed off.
- 25 Oct 2026, owner: no separate sign-off PRs. The owner's sign-off in chat plus a merged PR counts as signed off;
  the next build PR records it.
- 25 Oct 2026, owner approved (Stage B picks): each guest brings one small request (a fish, a grilled fish or a chair
  by their tent) with a tip; the improvement choice is a water point (comfort) or a lantern post (atmosphere); a
  booking board in the menu offers advance bookings to accept, move a day later or decline, with no penalty;
  fishing at the pond (3 fish, never fails) and grilling a fish at the fire; each stay leaves a line naming what the
  guest loved and wished for; a morning report with last night's coins, those lines, the bookings and three goals.
- 25 Oct 2026, owner: Stage B is not signed off after the first play: days 1 to 3 felt blank, with nothing to do or
  explore. Wanted: a clipboard (visitors, inventory, the map, planning the camp), chopping trees, more to the core loop
  and a light tutorial, decided after research.
- 25 Oct 2026, owner: little animals, deer and bears in the world to make it feel alive (cozy: never a threat).
- 25 Oct 2026, owner picked "items 1-6, map later" from the research: a Today list whose firsts are the tutorial,
  chopping and wood recipes, daily finds, animals, a per-player clipboard (Today, Bookings, Supplies) and a long log
  that goes faster carried together; the morning report says what is new tomorrow. The clipboard's map tab follows.
- 25 Oct 2026, owner: chopped trees fall and drop a sapling that players replant, like Animal Crossing.
- 25 Oct 2026, owner: basic quality of life now, alongside Stage B: a title page with Start game, an Options screen
  and controls. **Proposed** (built): one Options screen opened from the title and the in-camp menu, with picture
  (the existing presets), window, vsync, frame limit, four volumes, remapping on both devices, stick deadzone, camera
  turn speed, interface size and still trees; settings stay on each PC and are never synced. This brings remapping
  and the accessibility basics forward from Stage E.
- 25 Oct 2026, owner (round 2 play): the top-right HUD ran off the screen; the clipboard should tick off tasks as
  things are collected; an inventory and dropping were missing; a hybrid build system: craft benches, lanterns and the
  like at a table into a build inventory and cycle it as now, with the tent plot always given; the rest of the
  inventory holds gathered stacks such as sticks. Research for more rounding out (Cozy inventory and crafting, in the
  project files). Owner's pick: items 1-4 now (HUD fix, a Pack with dropping, workbench and build kit, camp box), the
  rest next. **Proposed** (built): an 8-slot Pack per player, dropped stacks lie as bundles that never vanish, a camp
  box for shared materials, the build kit shared by both players, recipe costs in data/craft.json.
- 25 Oct 2026, owner (round 3 play): the in-camp menu overlapped the Pack bar and the hint; Q and R turned the camera
  at the workbench; an inventory more like Animal Crossing's, with the build items cycled in the bottom right corner
  and the tools cycled near it, both shown; window modes (borderless, full screen, windowed). **Proposed** (built):
  the Pack opens as a grid, a corner dock shows the tool (hands, axe, rod; chopping needs the axe, fishing the rod)
  and the build piece, the menu hides the HUD and scales to fit, and Options gains a window size.
- 25 Oct 2026, owner (round 4 play): an Apply button in Options; go inside your tent and sleep the day away in a
  sleeping bag; guests go inside their tents and players can see them, with a name bubble over each occupied tent;
  day 1 must be finishable on day 1 and the day never stuck; gathering never gates progress (easy money any time)
  while guests' requests are the core loop that ramps up; binoculars or a camera to photograph and track animals.
  **Proposed** (built): bed open all day, guests ask again through the day with a growing daily share, odd jobs for
  coins, the camp's tent and guest tents open like a doll's house, a camera tool and a field guide tab.
- 25 Oct 2026, owner: after round 5, the work splits into three threads started from the hand-off files: Gameplay,
  Interface (HUD, Pack, cyclers, menus, settings) and Playtest/QA (`handoff/README.md`).
- 25 Oct 2026, **Proposed** (gameplay round 2, built from the owner's next-round pick): a sell crate that pays in the
  morning report at flat, low prices and gives back the last stack until night; three camp projects in order
  (fireside stools, flower planters, a tidy woodpile) filled by either player from their Pack and the camp box, each
  rewarding once (two new recipes, then coins); players stop at the clearing's edge.
- 25 Oct 2026, **Proposed** (gameplay round 3): the camp's star rating, worked out each night from pitches, crafted
  pieces, happy guests, photos and finished projects (each capped), never going down and with no mess penalty, with
  one hint from Ranger Ada in the Today list.
- 25 Oct 2026, owner: bring the models up to the original felt reference picture: an Art role pilots a few pieces
  beside the picture, then rolls out. **Proposed** (pilot built): a ribbed knit beanie without a pompom, hair under
  the hat, a stitched smile; scalloped pine tiers; a broadleaf crown with honey seams and leaf sprigs; a plumper
  stitched tent with pegs; felt fibres in the shared material; a warmer day light and olive grass; two new swatches
  (`olive_felt`, `sage_thread`).
- 25 Oct 2026, owner: the pilot's first pass is not enough: the world should look literally knitted together, like
  the reference. **Proposed** (built): knit, wood, water and grass weaves in the one material, hairy edges, richer
  graded colour, a ground strewn with felt clover, flowers, grass and ferns, and every model in view reworked.
- 25 Oct 2026, owner: still off; the reference looks like a photo of real little knitted characters, a miniature
  look with real felt. **Proposed** (built): a tilt-shift blur focused on the players, fuzz shells on every model,
  finer fibres up close, soft sun shadows and deeper occlusion; blur and shells are off on the Light preset.
- 25 Oct 2026, owner: try one camper made in Blender. **Proposed** (built): `knit_camper`, a sculpted model built by a
  script in `art/characters/knit_camper/` and painted from the palette, shaped from the owner's "Beanie Camper"
  turnaround (front, side and back); it sits beside the code camper until the owner decides.
- 25 Oct 2026, owner: picked the max-effort camper (merged in PR #29) and asked for its method (`art/RECIPE.md`).
  Then, after player two was made by that recipe at medium effort: "switch both and keep this art direction and
  formula because its the level of quality i want for the whole game". **Decided:** both players use the knitted
  campers (`camper_a` is now `knit_camper` and `camper_b` is `knit_camper_b`, so saves need no migration); the recipe
  is the standard for every model; `camper.hand_pos` follows the knitted mitten; the swatches `beanie_teal`,
  `mustard_knit` and `bun_brown` are approved with the campers.
- 25 Oct 2026: **Proposed** (built): the guests are knitted by the recipe too, as the three fall visitors: Bea Thistle
  (`guest_a`), Olive Ashby (`guest_b`) and Walt Hollis (`guest_c`, a third look added to the walk-in and booking
  looks). A shared, lighter body keeps each near half a player's vertices. New swatches `plum_knit`, `ginger_yarn`,
  `ginger_shadow`, `silver_yarn`, `silver_shadow`, `pewter_yarn`, `cocoa_felt` and `cranberry_knit` are Proposed.
- 26 Oct 2026: **Proposed** (built): Ranger Burl, the guide the owner picked for the opening, knitted by the recipe
  (`ranger_burl` and a talking pose, `ranger_burl_talk`). New swatches `ranger_khaki`, `ranger_olive` and `snow_yarn`
  are Proposed.
- 25 Oct 2026, owner (after playing Stage B): "if you are not right away hooked and captivated it won't be any funner
  waiting for days": wants chop animations with wood visibly dropping, a shovel to dig up stumps, more stylized,
  icon-led UI with fewer blocks of text, a visual clipboard and Pack, more than one guest at a time who stay longer
  and fish, photograph animals, fly kites, play frisbee fetch and sit on chairs, more starting money, crafting and
  upgrading a bonfire, and placing key items like the events board. Research doc "Hooked in the first minute" ranks
  the work into Gameplay rounds (1 chop feel and shovel, 2 bonfire and placeable board, 3 more guests staying longer,
  4 guest activities) and Interface rounds (1 item icons and icon pop-ups, 2 a picture clipboard and Pack).
- 25 Oct 2026, owner picks: chop feel and the shovel first; up to **3 guests at once, 2 nights each** (Gameplay round
  3); a new camp starts with **100 coins** (built in first-minutes round 1).
- 25 Oct 2026, owner merged first-minutes round 1 (PR #30, the chop feel and the shovel). Round 2 builds the campfire
  that grows (stone ring with log seats, then a big bonfire) and the camp board that players put up themselves.
  **Proposed**: the board starts in the kit; the fire is upgraded at the fire itself, not crafted at the bench.
- 25 Oct 2026, owner (Interface thread): button icons, a knitted clipboard and tidier UI; the Interface thread takes
  the icon and clipboard rounds from the first-minutes plan.
- 25 Oct 2026, owner merged first-minutes round 2 (PR #33, the growing fire and the camp board). Round 3 builds the
  owner's pick: up to 3 guests at once, 2 nights each. **Proposed**: guests arrive one by one, 40 game minutes apart;
  bookings stay 2 nights too; the camper holds the clipboard up while a player reads it, seen on both PCs.
- 25 Oct 2026, owner merged first-minutes round 3 (PR #37). Round 4 builds guest activities from the owner's list
  (fishing, photographing animals, kites, frisbee with each other, sitting on chairs). **Proposed**: a guest with an
  open request waits by their tent so players can find them; activities change every game hour and are worked out
  from the shared day, so both PCs agree without new netcode; they pay nothing yet (they show the camp being used).
- 26 Oct 2026, owner merged first-minutes round 4 (PR #41, guest activities) and Art's knitted clipboard (PR #38). The
  camper now reads the knitted clipboard; the felt stand-in is gone.
