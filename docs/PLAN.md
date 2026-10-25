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
Everything looks like one handmade camping set. Readable silhouettes and cohesive matte materials first; no fibres,
cloth simulation or translucent fuzz. Rounded campers with mitten hands and embroidered faces, stacked felt-cone pines,
soft round crowns, thick stitched tent panels. One character rig; hats, hair, outfits and colours swap.

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

## Milestones
Each passes before the next starts. No dates. Stages A to E replace the old Milestones 4 to 6.

| # | Milestone | Passes when |
|---|---|---|
| 0 | Project setup | Done (signed off 25 Oct 2026) |
| 1 | Look and feel | Done: felt art proof, a first draft (signed off 25 Oct 2026) |
| 2 | Two PCs, one camp | Host and join over Tailscale or LAN; both players move, carry and place a chair; the host decides; save and load with profile IDs; the camp save already has room for the whole year (day, season, coins, wood, ledger, reservations, areas, staff, profiles with outfits and pets) |
| 3 | Couch and link codes | Couch drop-in and drop-out on the host's PC, dynamic split screen, a link code moves a character to the other PC |
| A | Core proof | One pitch, one guest, day clock, sleep vote, nightly payout, grid placement with undo; a night pays exactly once, even after save, load or a reconnect |
| B | Three-day fun test | Small requests, one improvement choice, a short advance booking, fishing or cooking, satisfaction lines, the morning report; both players want a fourth day and can explain the next booking |
| C | Autumn chapter | 14 days of fall: tent pitches, washroom, water point, fire circle, the group campout, staff, a small shop, the first RV pad, weather looks, one together action; a lazy-play headless test still affords the RV loop; playable start to end on either input alone |
| D | The other three seasons | Spring, summer and winter areas, events and visitors; dollhouse cabins on Cabin Hill; the camp rating; the lantern-night finale and the turn into year two |
| E | Rich content and cozy polish | The full content list, journal and scrapbook, pets, sound, remapping, accessibility, pacing; v1 ships to the two of us |

## If it grows too large
Cut in this order: decoration count toward 40, fish and recipes toward 12, visitor count toward 8, seasonal outfits,
together actions. Never cut both input methods, two-player reliability, decorating, the four seasons, progression or
save recovery.

## Later (not in v1)
A free photo mode, text chat, walk-in interiors, weather that changes gameplay, more shops or worker roles, more than
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
- 25 Oct 2026, **Proposed**: licence MIT for code and CC BY 4.0 for original art; three save slots; thank-you letters;
  background wildlife; upkeep never below zero.
