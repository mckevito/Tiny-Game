# Playtest and QA hand-off, 25 Oct 2026 (new role, split from Build after Stage B round 5)

1. **Owns:** proof that the game works and looks right.
   - `tests/run_tests.gd` (the runner and its engine-log listener), the shared test helpers, `scripts/tools/
     capture.gd`, `.github/workflows/ci.yml`, `.claude/hooks/session-start.sh`.
   - The Result column of `docs/STATUS.md` proof rows, review sheets in the project files
     (`/mnt/project-files/tiny-game/stage-b/`), and turning each owner bug report into a failing test for the role
     that owns the fix. Playtest/QA does not change game code; it opens test-only PRs or hands the bug over.
2. **State now:** pass 3 (PRs #31 to #42, 26 Oct 2026) is in `FAULTS.md`. Each PR is played on its own branch from
   the title: solo, couch (keys plus pad) and, where netcode changed, host and join between two real copies. One bundled
   message goes to the owning thread, and frames go to `/mnt/project-files/tiny-game/playtest/pr<N>/`.
   `scripts/tools/playtest.gd` plays the real main scene through real key and pad presses (solo, then a couch drop-in
   with a split screen), saving a frame per step and logging any HUD piece off screen or overlapping ("BAD");
   `scripts/tools/playtest_net.gd` does host and join between two real copies (the commands are in each file's
   header). For a PR's own checks, write a throwaway probe that extends one of them, and delete it afterwards.
   `capture.gd --stage-b` saves the Stage B frames, `--menus` the title and Options pages, and `--couch` a
   split-screen walk.
3. **Open work, in order:**
   1. With the owner, confirm the four Milestone 3 checks that were never confirmed: two DualSense controllers on the
      couch, a link code moving a couch character to its own PC, a Tailscale join, and fps on the Ryzen 7 5825U
      laptop (at least 30, aim 60; tune `data/graphics.json` from it).
   2. A couch split-screen HUD overlap test (with Interface).
   3. Netcode coverage for round 5: photos and requests over a real two-camp session (`test_net.gd` pattern).
   4. A review sheet (contact sheet of the capture frames) for each owner-facing round.
4. **Owner decisions:** sign-off is the owner's word in chat plus the merged PR; no sign-off PRs.
5. **Traps:** all of `handoff/build/HANDOFF.md` section 6, plus:
   - Captures must say "Vulkan ... Forward+" in their first log line; install `mesa-vulkan-drivers` if not.
   - Headless windows are square; set the root size before a layout check.
   - Never `git stash` during a merge: it drops the merge state.
   - Tests that call `camp._unhandled_input` skip GUI focus; a focused button eats Tab, the arrows and Enter first.
     Drive real keys with `Input.parse_input_event` when checking menus (the Tab fault, pass 1).
   - The pad's Create button (`JOY_BUTTON_BACK`) is the dev panel; the clipboard is the Touchpad (`JOY_BUTTON_TOUCHPAD`).
   - The first pad to press Options drops in a couch player when player one has only used the keyboard (Proposed rule,
     Milestone 3); it does not open player one's menu.
   - Check two open PRs together: merge one into the other locally, run the tests, and name any conflicting file.
