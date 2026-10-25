# Gameplay hand-off, 25 Oct 2026 (new role, split from Build after Stage B round 5)

1. **Owns:** the rules of the camp and what players can do in it.
   - Scripts: `scripts/camp/camp_state.gd`, `camp_day.gd`, `camp_build.gd`, `camp_guests.gd`, `camp_pack.gd`,
     `camp_gather.gd`, `camp_tasks.gd`, `camp_projects.gd`, `camp_save.gd`, `wildlife.gd`, `clearing.gd`, `camper.gd`.
   - In `scripts/camp/camp.gd` (shared with Interface): the netcode (`ask`, `_request`, `_decide`, `_share`,
     the RPCs), `action_for` and `interact`, build mode, the day tick (`_tick_day`, arrivals, `refresh_requests`),
     stays and tents (`_sync_stays`, `_pitch_tent`, `_tick_tents`, `enter_tent`, `leave_tent`), trees, forage,
     bundles, tools (`tool_of`, `has_tool`, `hold_tool`), wildlife and photos.
   - Data: `data/guests.json`, `build.json`, `craft.json`, `items.json`, `gather.json`, `tasks.json`,
     `wildlife.json`, `projects.json`, `day.json`, `fishing.json`, `save.json`, `net.json`, `clearing.json`, `models.json`,
     `palette.json`; its keys in `data/text.json`.
   - Tests: `test_camp_rules`, `test_camp_save`, `test_day`, `test_gather`, `test_guests`, `test_projects`, `test_net`, `test_couch`
     (rules part), `test_stage_a`, the gameplay tests in `test_stage_b`.
2. **State now:** Stage B is merged through round 4 (PR #18); round 5 (this hand-off's PR) adds bed open all day,
   guests who ask again (a growing daily share), odd jobs that pay but never gate anything, tents to sleep in and to
   see guests asleep in, a camera tool and a field guide. Stage B is NOT signed off yet. The architecture (CampState
   and its weakref sub-objects, host decides, `_share`, save versions) is in `handoff/build/HANDOFF.md` section 2.
3. **Open work, in order:**
   1. The owner plays round 5 and signs off Stage B (chat sign-off plus the merged PR; record it in the next PR's
      `docs/STATUS.md` and the `docs/PLAN.md` decision log). Approve or change the **Proposed** numbers.
   2. Next: the camp's star rating (with a hint line in the morning report, no mess penalty), then the clipboard's
      map tab (with Interface). The sell crate and camp projects came in gameplay round 2 (`camp_projects.gd`,
      `data/projects.json`); a bigger Pack as a project reward waits on Interface growing the Pack grid.
   3. Gaps left on purpose: guests' requests have no walk-up animation. (Gameplay round 1 sent the tent visit and
      the tool in hand to the other PC and tucked sleepers into their bags; neither is saved.)
   4. Stage C (the autumn chapter) when the owner says go.
4. **Owner decisions:** the decision log in `docs/PLAN.md`. The ones that shape gameplay most: the cozy contract (no
   failure, timers or lost items); guests' requests are the core loop and gathering is optional money (25 Oct); the
   day must never be stuck (bed open all day); trees fall and are replanted like Animal Crossing; two players max.
5. **Traps:** all of `handoff/build/HANDOFF.md` section 6, plus:
   - Solo, anything that votes for bed (the tent, the menu) starts the night at once; a test that needs to stay in
     bed adds a second online player with `state.join` first.
   - A guest who walks in only pitches their tent on arrival (`Camper.arrived`); tests call `_pitch_tent(stay)`.
   - Request kinds with `near` are met by the camp itself; `refresh_requests` skips ones that stay already had.
   - `_moved` carries the tool and "in the tent" as well as the position (protocol 6). Remote tent visits use
     `_lie_down`/`_get_up` (looks only); `enter_tent`/`leave_tent` are for players on this PC and send the bed vote.
     Two players both in the tent vote for bed and start the night: a test that only wants the look calls `_lie_down`.
   - `action_for` order matters near shared spots: pick-up beats everything (a chair by the crate stole its press),
     the crate and board come before the tent. Keep new interact spots more than 2 m from the camp tent's door.
   - Projects: the sell crate (`state.projects.crate()`), `shipped`, and `projects` {given, done} are SHARED keys.
     Recipes with a `project` show only via `state.build.known_recipes()`; never index `CampBuild.recipes()` from the
     bench.
   - Tents swap meshes (`_tent_look`, the model's `_open` variant), so a tent node's child 0 must stay its mesh.
