# Gameplay lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md`, `handoff/build/HANDOFF.md` (architecture and traps) and this
folder's `HANDOFF.md`. Add your line to the thread list (`/mnt/project-files/handoff/THREADS.md`). Check live PR
state on GitHub before talking about PRs.

## Owner rules (with reasons)
All of `handoff/build/LESSONS.md` "Owner rules" apply. For gameplay especially:
- **Never stuck, never gated.** The owner was blocked on day 1 by a task needing two guests and a bed that waited
  for the evening; anything that can block a day needs a way round it.
- **Guests are the heart of the day; gathering is easy money.** Gathering feeds crafting and odd jobs, never progress.
- **Everything in data.** Numbers and strings live in `data/`; new choices are marked Proposed in `docs/STATUS.md`.

## Who owns what
Gameplay: rules, netcode, data tables for play, the world. Interface: HUD, panels, menus, settings, input and
prompts. Playtest/QA: the test runner, the capture tool, CI and review sheets. `camp.gd` and `data/text.json` are
shared: add, don't reshuffle, and say in the PR which sections you touched. One PR per change, based on `main`.

## Running a round
1. Read the owner's ask and the open work in `HANDOFF.md`; build the smallest thing that meets it.
2. Every rule the host decides goes through `ask` and `_decide`, and is shared with `_share`.
3. Add a test per proof row; break the code once to see it fail; run the full suite headless.
4. Ask Playtest/QA for review frames, or run `scripts/tools/capture.gd --stage-b` yourself and look.
5. Update `docs/STATUS.md`, `HANDOFF.md` and the round log here.

## Round log
- 25 Oct 2026: role split from Build (owner). Stage B rounds 1 to 5 are in `handoff/build/LESSONS.md`.
- 25 Oct 2026: round 1: the tool in hand and tent visits reach the other PC on `_moved`; sleepers tucked into bags.
  Fault found: round 5's sleepers lay on top of the bag (why: the bag was part of the tent model, with nothing to
  cover a body; stops it: a sleeper is a holder with the body and a cover model, looked at before the PR).
- 25 Oct 2026: round 2: sell crate and three camp projects; walking stops at the clearing's edge (Playtest's find).
  Faults found by the button test: the crate's press picked up a chair and the board's crawled into the tent (why:
  new spots were placed by eye near older ones; stops it: a from-the-buttons test per new interact spot, HANDOFF trap).
- 25 Oct 2026: round 3: the camp star rating with Ranger Ada's hint. Faults found: the never-goes-down test passed
  with the rule broken (why: what it packed away was too little to lose a star; stops it: break each rule once and
  make the test take enough away); the report said the stars twice (why: the Today part already has them; seen in
  the frame).
- 25 Oct 2026: first-minutes round 1 (owner: hook players in the first 15 seconds): the axe swing, wood that pops
  onto the grass and sweeps up by walking over it with a +1 tag, a tree that topples, the shovel for stumps, 100
  starting coins. Faults found: loose wood beside the tree stole the next chop's press (why: pick-up comes first in
  `action_for`; stops it: loose pieces come after chop and dig, and sweep up by walking anyway); two of three pieces
  landed on the same spot (why: the fan only alternated sides; caught by the sweep test); the felled tree fell onto
  the camper (why: a fixed tip axis; seen in the review clip, so it now tips away from the nearest camper); with a
  sapling in the Pack the shovel planted instead of digging (why: plant came first; the tool in hand now wins).
- 25 Oct 2026: first-minutes round 2: the fire grows in two levels and the camp board goes up from the kit. Faults
  found: loading an old save deep-filled the kit from new_camp and gave it a second board (why: `_fill` recurses into
  every dictionary; caught by the migration test); the fire upgrade stole the camp box's press (why: the fire's reach
  covers the box and chairs; it is now last at the fire); the ring's log seats first lay radially across the path
  (seen in the dusk frame). Playtest then found the seats
  ran through the folding chairs at (±1.5, 1.0) and campers could stand on the stones (why: placed against the fire
  alone, not the chairs beside it; the seats now sit behind the fire and the collider grows with the ring).
- 25 Oct 2026: first-minutes round 3: up to 3 walk-in guests, 2 nights each, plus the clipboard reading pose. Faults:
  tests that slept one night to send a guest home had to loop over the nights (why: the stay length was assumed, not
  read from the table; read `nights` from data in tests); a build in an old test hit the new arrival gap (why: the
  clock minute carried over; set the minute in the test).
- 25 Oct 2026: first-minutes round 4: guests fish, take photos, fly kites, sit and play frisbee. Faults: picks made
  with `String.hash() & 0xFFFF` never chose one kind (why: similar keys hash to similar low bits; `GuestPlans.roll`
  now mixes the hash first); a scene test's guests stayed home (why: they asked again on the camp's tick; set
  `next_at` too when a test marks requests met); resting guests slid 5 cm off their spot (why: physics pushed them out
  of the tent's collider; guests now skip physics between walks).
- 26 Oct 2026: build round: a stitched grid and free building. The grid already existed but was invisible; pieces now
  fill whole cells (`CampBuild.snap_fit`) and the free choice rides in the build request (args[3]). Faults: a free
  pitch at 15 degrees was "too close" where a square one fitted (why: the blocking box of an angled footprint is
  wider; pick test spots with room, or test free builds square on).
- 26 Oct 2026: arrival evening (owner picks after the cozy-games case study): Ranger Burl's letter, the cold fire, the
  camp's name on a sign, the clipboard handover. Faults: Burl's lines first used {camp} and {ranger}, which the glyph
  test read as missing button glyphs (why: braces are the glyph syntax; caught by `test_prompts`, now `$camp`); the
  first naming rule wanted the player beside Burl, but the fire catches wherever they stand (why: the rule was written
  before the flow; caught by the button test, so the name is taken anywhere during that step); the sign first faced
  the camp, so the play camera saw its back (seen in the review frame; it now faces the road south).
- 26 Oct 2026: Playtest's faults on the arrival evening. The naming hint said the interact key finishes, but on
  keyboard E types a letter (why: a text field takes every key; a typing step needs its own glyph, now `type_done`,
  Enter or Cross); at 150% in couch play the docks covered Burl's bubble (why: two bottom panels never checked
  together; the docks and prompt line now step aside while he talks). Test with a real key press, not a set text.
- 26 Oct 2026: a tent pitch could be built over the camp sign (Playtest, combined pass). New scenery needs a row in
  data/build.json `blockers` (why: the build check only knows scenery listed there). The sign also sat inside the
  spot every test pitches on, so it moved to the foot of the path, where guests arrive; check new scenery against
  the test spots before placing it.
- 26 Oct 2026: Burl's story jobs. A HUD element updated in `_process` (his "!") reads a frame late in tests: wait a
  frame after an action before checking it. A job the players finished before he asks (a pitch already built) must
  not make them do it twice, so builds count what stands (`has:<kind>`) and the talk chains straight to his thanks.
- 26 Oct 2026: the scrapbook's snapshot. Grabbing the screen and hiding the HUD first still caught toasts and the new
  page's card (why: the HUD re-shows itself each frame and the ask adds new parts after the hide); the photo is now
  drawn by its own camera in a throwaway SubViewport on the same world, which has no HUD at all and can aim at the
  animal. A guest's first photo can arrive before its PC knows the book's id, so a guest always sends its snapshot
  to the host, which keeps it and sends it back. A new panel built visible counts as "showing" at once: hide it until
  it has something to show.
- 26 Oct 2026: Playtest of the scrapbook (PR #62). The photo from the play camera was mostly the photographer's own
  hat and name tag (why: the play camera sits behind the player, and you walk up to an animal to photograph it); it is
  now taken from the camper's eye, a step toward the animal. At 150% the couch books overlapped and the solo book ran
  off the top (why: a panel sized for 100% was never checked at 150% or on the couch); the book now scales itself to
  its share of the screen, re-checked on every resize because wrapped text settles a frame late. Test every new panel
  at 150% alone and on the couch.
- 26 Oct 2026: chair round (owner, with the Stage B sign-off). Guests walked straight through chairs and the ring's
  logs, the logs had no collider, and a seated guest was a standing model lifted onto the seat, legs through it. Fixes:
  grid routes round every `collide` row, a sitting pose per guest, solid logs. Faults on the way: the folding chairs
  stood so close to the grown ring that nobody fit in front of them (why: the ring came later than the chairs; caught
  by the new check that every seat has open ground in front, so the chairs moved out); new players spawned inside the
  ring's logs once they turned solid (why: spawns predate the ring; check spawns against colliders); a net test walked
  a camper onto the moved chair and never arrived (why: teleporting into a collider gets pushed out; pick clear spots).
