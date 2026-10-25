# Our Little Campground: the plan

Version 1.0, 25 October 2026. The source of truth for what we build. Anything not here goes on the Later list.
Changes are marked **Proposed** until the owner approves them; approved changes get a line in the decision log.

## The promise
Two friends arrive at a small, neglected woodland campground. Together they tidy it, restore guest pitches, decorate,
welcome visitors and leave time to fish and sit by the fire. *"Let's make one more little improvement… then go fishing."*

## The cozy contract
No combat, hunger, rent, failure, dying, scores or customer timers. Guests wait patiently. Nothing rare is ever lost.
Decorations move freely and sell back at full price. Either player can do every task. Both players confirm sleeping
and big shared purchases; either can cancel.

## Players and connection (owner decisions)
- **Two players in total.** Either both on one PC (couch co-op) or one on each of two PCs (online). Online comes first.
- **Couch drop-in and drop-out.** A second player can pick up a controller on the host's PC and join or leave anytime.
- **Dynamic split screen**, as in modern LEGO games: one shared camera while close; when a player leaves the shot the
  screen splits along a line pointing at the other player, and merges again when they meet.
- **Persistent characters without accounts.** Each character belongs to a profile ID stored in the host's camp save
  (name, look, carried items). The host can show a short **link code** for a character; entering it on another PC
  claims that character there, so a couch guest can later rejoin online as the same character.
- **Online:** Godot's built-in multiplayer (ENet), host and join. The host decides every change; clients ask. For two
  home networks, a free private-network app such as Tailscale avoids router setup; no relay service in v1.
- **Netcode is written fresh in GDScript**, using only ideas from Dead Acre (host decides, stable IDs, requests the
  host checks), none of its code.

## Input
Keyboard and mouse and the PS5 DualSense (USB and Bluetooth on Windows) are both first-class from the first build.
One action-based input layer with contexts (gameplay, menu, placement), so a menu press never also acts in the world.
Prompts show the glyph of the last-used device. Remapping, deadzones and sensitivity come in the polish milestone.
Adaptive triggers, gyro and the touchpad are optional extras, never required.

## The first evening (v1 scope)
| Area | Limit |
|---|---|
| World | One compact clearing: player camp, pond, supply board, short woodland loop |
| Pitches | 2 guest pitches + the player camp |
| Guests | 1 at a time, 2 colour looks on the camper rig |
| Tasks | 5 verbs: clear, repair, place, deliver, cook |
| Decorations | 6 (about 4 meshes with colour swaps): move, rotate, snap, pack away |
| Fishing | 3 catches, one-button reel with a visual and sound cue |
| Cooking | 2 recipes, no timing challenge |
| Economy | Camp coins + wood |
| Progress | Restore pitch 1, restore pitch 2, campfire finale, then free play |
| Length | About an hour to the campfire (a target to test, not a promise) |
| Saves | One JSON camp save with a version number and a backup; profiles live inside it |

**The loop:** arrive, pick shirt and hat colours; tidy litter and fix the picnic table; place chairs and lantern;
restore pitch one, welcome a guest, fill a request; buy and place a decoration, catch a fish, cook by the fire;
restore pitch two; light the big fire and sit down together.

## Art direction: felt and fabric miniatures
Everything looks like one handmade camping set. Readable silhouettes and cohesive matte materials first; no fibres,
cloth simulation or translucent fuzz. Rounded campers with mitten hands and embroidered faces, stacked felt-cone pines,
soft round crowns, thick stitched tent panels. One character rig; hats, hair and colours swap.

| Swatch | Hex |
|---|---|
| Moss felt | `#536B50` |
| Rust canvas | `#BB704C` |
| Honey thread | `#D6AF66` |
| Pond blue | `#6B929C` |
| Warm cream | `#EEE3CB` |

**How we make it cheaply:** models are built by code from simple rounded shapes (cones, spheres, capsules, bevelled
boxes) listed in data tables, painted only with named palette swatches. One shared felt material (soft noise, matte, a
gentle bright rim); stitches as a dashed texture strip on focal props only. Gentle tree sway in the shader. Each batch
is reviewed as one contact-sheet screenshot from the play camera, in daylight and at dusk. Elevated third-person camera,
limited zoom, trees fade when they hide a player.

**Accessibility baseline:** UI scale, separate music and effects volume, visual cues alongside sound, readable
prompts, player names as well as colours, camera shake off.

## Milestones
Each passes before the next starts. No dates; effort is judged after the first art and network proofs.

| # | Milestone | Passes when |
|---|---|---|
| 0 | Project setup | Godot project, input map, tuning table, test runner, CI green; DualSense and keyboard both move a test capsule in the sandbox |
| 1 | Look and feel | The felt art proof (2 campers, tent, 3 trees, picnic table, 2 chairs, fire pit) in a small clearing; movement and camera feel good with both inputs; the owner likes the look |
| 2 | Two PCs, one camp | Host and join over Tailscale or LAN; both players move, carry and place a chair; the host decides; save and load with profile IDs |
| 3 | Couch and link codes | Couch drop-in and drop-out on the host's PC, dynamic split screen, link code moves a character to the other PC |
| 4 | Twenty-minute slice | One pitch, one guest, one request, coins, one decoration, one fish, one recipe |
| 5 | The first evening | The full v1 scope above, from a new save to the campfire, with controller only and with keyboard only |
| 6 | Cozy polish | Sound, feedback, remapping, accessibility, pacing, recovery messages |

## If it grows too large
Cut in this order: fishing variety, guest looks, decoration variants, then the second recipe. Never cut both input
methods, two-player reliability, decorating, progression or save recovery.

## Later (not in v1)
Chapters 3 and 4 of the field guide (pitches 3 and 4, collections), more decorations, fish and recipes, three or more
materials, reconnect and late join beyond the basics, a relay or invite service, Steam, photo mode, seasons, weather,
interiors, voice acting, more than two players, consoles.

## Decision log
- 25 Oct 2026, owner: online on two separate PCs comes first; the repo is public, so no personal data or Dead Acre
  material goes into git.
- 25 Oct 2026, owner: couch drop-in and drop-out with persistent characters that can rejoin from another PC.
- 25 Oct 2026, owner: dynamic split screen like modern LEGO games; two players in total.
- 25 Oct 2026, owner: fresh GDScript netcode, ideas only from Dead Acre.
- 25 Oct 2026, owner: keep a hand-off and lessons method like the reference repos.
- 25 Oct 2026, **Proposed**: licence MIT for code and CC BY 4.0 for original art; the scope and milestone order above.
