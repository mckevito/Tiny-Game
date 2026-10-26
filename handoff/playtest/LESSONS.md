# Playtest and QA lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md`, `handoff/build/HANDOFF.md` and this folder's `HANDOFF.md`. Add your
line to the thread list (`/mnt/project-files/handoff/THREADS.md`).

## Rules
- **A test must be seen to fail.** Break the code on purpose once for each new test; tests that could not fail let
  a script error pass (round log, Stage B) and missed a menu running off the screen (round 4).
- **Look before telling.** Read every capture frame before showing the owner anything.
- **Every owner bug becomes a test** in the same round, in the owning role's test file.
- **Play like a player:** start from the title, press real keys and pad buttons, and play solo, host and join, and couch
  for every PR. The faults in pass 1 were all invisible to tests that call camp methods directly.
- **One bundled message per owning thread**, with frame paths, most important first; log each fault in `FAULTS.md`
  with the check that should have caught it.

## Who owns what
See `handoff/gameplay/LESSONS.md` "Who owns what".

## Round log
- 25 Oct 2026: role split from Build (owner).
- 25 Oct 2026, pass 1: main after #19, #20 (good), #21 (5 findings); 7 faults logged; playtest drivers added.
- 25 Oct 2026, pass 2: main with #22-#26; 4 of pass 1's faults fixed, 5 small ones logged for the next threads.
  `pgrep -f pattern` in a wait loop matches the loop's own shell: wait on the PID (`wait $!`) instead.
- 25-26 Oct 2026, pass 3: PRs #31-#42 one by one, 11 faults logged, most fixed in their own PR before merge.
  - Close the report with E (interact), not Enter. A script that pressed Enter left the report open, and the next E
    went to the report instead of the tent. That looked like a night that never passes.
  - Two game copies hold the network port: a test run started meanwhile fails `test_settings`' host test. Re-run that
    test alone before reporting it.
  - Run probes from a git worktree per PR (`git worktree add ../tgN prN`), so a long rendered run never blocks another
    PR's tests.
  - Real fps can't be measured on lavapipe. Compare draw calls, objects and primitives against main on the Low preset
    instead, and leave the laptop fps to the owner.
