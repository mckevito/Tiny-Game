# Gameplay hand-off, 25 Oct 2026 (new role, split from Build after Stage B round 5)

1. **Owns:** the rules of the camp and what players can do in it.
   - Scripts: `scripts/camp/camp_state.gd`, `camp_day.gd`, `camp_build.gd`, `camp_guests.gd`, `camp_pack.gd`,
     `camp_gather.gd`, `camp_tasks.gd`, `camp_projects.gd`, `camp_rating.gd`, `camp_save.gd`, `guest_plans.gd`, `wildlife.gd`, `clearing.gd`, `camper.gd`.
   - In `scripts/camp/camp.gd` (shared with Interface): the netcode (`ask`, `_request`, `_decide`, `_share`,
     the RPCs), `action_for` and `interact`, build mode, the day tick (`_tick_day`, arrivals, `refresh_requests`),
     stays and tents (`_sync_stays`, `_pitch_tent`, `_tick_tents`, `enter_tent`, `leave_tent`), trees, forage,
     bundles, tools (`tool_of`, `has_tool`, `hold_tool`), wildlife and photos.
   - Data: `data/guests.json`, `build.json`, `craft.json`, `items.json`, `gather.json`, `tasks.json`,
     `wildlife.json`, `projects.json`, `rating.json`, `day.json`, `fishing.json`, `save.json`, `net.json`, `clearing.json`, `models.json`,
     `palette.json`; its keys in `data/text.json`.
   - Tests: `test_camp_rules`, `test_camp_save`, `test_day`, `test_gather`, `test_guests`, `test_projects`, `test_rating`, `test_net`, `test_couch`
     (rules part), `test_stage_a`, the gameplay tests in `test_stage_b`.
2. **State now:** Stage B is merged through round 4 (PR #18); round 5 (this hand-off's PR) adds bed open all day,
   guests who ask again (a growing daily share), odd jobs that pay but never gate anything, tents to sleep in and to
   see guests asleep in, a camera tool and a field guide. Stage B is NOT signed off yet. The architecture (CampState
   and its weakref sub-objects, host decides, `_share`, save versions) is in `handoff/build/HANDOFF.md` section 2.
3. **First-minutes plan (owner, 25 Oct 18:59; picks 19:05).** The research doc "Hooked in the first minute" (Claude
   Doc, linked in the project thread and in project memory) ranks the owner's feedback into rounds, one PR each:
   Gameplay 1 chop feel and shovel (merged, PR #30: loose pieces `CampPack.lay`/`sweep`, `CampGather.dig`, tree stages
   `hole`/`cleared`, `Camper.swing`, `Camp._strike`/`_struck`/`_swept`, `capture.gd --chop`); Gameplay 2 the fire grows
   in levels (`CampBuild.next_fire`/`upgrade_fire`, camp key `fire`, `Camp._sync_fire`, `capture.gd --fire`) and the
   camp board is a building from the kit (`CampProjects.near_board(state, pos)`, save version 7); Gameplay 3 up to 3 guests at once, 2 nights each
   (owner's pick; merged, PR #37, with the clipboard reading pose `Camp.held_by`); Gameplay 4 guests fish, photograph
   animals, fly kites, play frisbee with each other and sit on chairs, the bench and the fire ring's logs
   (`GuestPlans.plan`, `Camp._tick_guests`/`_tick_frisbees`, `Camper.sit`, `capture.gd --guests`). The Interface thread owns the icon and knitted-clipboard rounds (owner, 25 Oct 21:13). Stage B stays unsigned until the owner plays these.
4. **Open work, in order:**
   1. The owner plays round 5 and signs off Stage B (chat sign-off plus the merged PR; record it in the next PR's
      `docs/STATUS.md` and the `docs/PLAN.md` decision log). Approve or change the **Proposed** numbers.
   2. Next: the clipboard's map tab with plan marks (with Interface). The star rating came in gameplay round 3
      (`camp_rating.gd`, `data/rating.json`). The sell crate and camp projects came in gameplay round 2 (`camp_projects.gd`,
      `data/projects.json`); a bigger Pack as a project reward waits on Interface growing the Pack grid.
   3. Gaps left on purpose: guests' requests have no walk-up animation. (Gameplay round 1 sent the tent visit and
      the tool in hand to the other PC and tucked sleepers into their bags; neither is saved.)
   4. Stage C (the autumn chapter) when the owner says go.
5. **Owner decisions:** the decision log in `docs/PLAN.md`. The ones that shape gameplay most: the cozy contract (no
   failure, timers or lost items); guests' requests are the core loop and gathering is optional money (25 Oct); the
   day must never be stuck (bed open all day); trees fall and are replanted like Animal Crossing; two players max.
6. **Traps:** all of `handoff/build/HANDOFF.md` section 6, plus:
   - Solo, anything that votes for bed (the tent, the menu) starts the night at once; a test that needs to stay in
     bed adds a second online player with `state.join` first.
   - What guests do is `GuestPlans.plan(state, asleep)`, a pure function of shared keys (calendar, stays, objects,
     fire, carriers): no RPC, both PCs work it out alike. Never feed it anything local (animals, cameras, time). A
     guest with an open request is always "rest" at `stand_point`, because giving is checked there. Guest campers
     (not controlled, no `remote_target`) skip physics between walks, so tents and seats never push them.
   - A guest who walks in only pitches their tent on arrival (`Camper.arrived`); tests call `_pitch_tent(stay)`.
   - Request kinds with `near` are met by the camp itself; `refresh_requests` skips ones that stay already had.
   - `_moved` carries the held thing (`held_by`: the tool, or "clipboard" while it is open) and "in the tent" as well as the position (protocol 6). Remote tent visits use
     `_lie_down`/`_get_up` (looks only); `enter_tent`/`leave_tent` are for players on this PC and send the bed vote.
     Two players both in the tent vote for bed and start the night: a test that only wants the look calls `_lie_down`.
   - `action_for` order matters near shared spots: pick-up beats everything (a chair by the crate stole its press),
     the crate and board come before the tent. Keep new interact spots more than 2 m from the camp tent's door.
   - Projects: the sell crate (`state.projects.crate()`), `shipped`, and `projects` {given, done} are SHARED keys.
     Recipes with a `project` show only via `state.build.known_recipes()`; never index `CampBuild.recipes()` from the
     bench.
   - Tents swap meshes (`_tent_look`, the model's `_open` variant), so a tent node's child 0 must stay its mesh.
   - A tree node's child 0 is its mesh too: `_topple` turns it and marks it `falling` while it tips; `_sync_trees`
     leaves a falling mesh alone. Holes and cleared spots switch the tree's collider off.
   - Loose bundles (`loose: true`, with `from`) sweep up by walking; dropped ones (G) need a press and never merge
     into loose ones. `_airborne` (host) keeps a piece from being swept before it lands; tests wait for it.
   - The fire's upgrade is the last action at the fire (after grilling, chairs, the box); `_sync_fire` stacks every
     reached level's model under the fire pit's "Upgrade" node and sets its light's "scale" meta for LightMoods.
   - `kit` is not deep-filled from new_camp on load (it would hand every old save a second camp board).
   - With the shovel in hand, dig beats taking the sapling and planting at a stump (the dig pops the sapling out); a
     hole takes a sapling whatever is in hand. A felled tree never tips toward the camera (it would fade unseen).
