# Build lessons (read before every round)

## Start here (fresh thread)
Read `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md` and `HANDOFF.md` in this folder. Add your line to the thread list
(`/mnt/project-files/handoff/THREADS.md`). Check live PR state on GitHub before talking about PRs. If you ask the
owner something these files should answer, add the answer here.

## Owner rules (each with its reason)
- **Public repo, nothing personal in git.** The repo is public; personal data and Dead Acre material must never leak.
- **Reference repos are read-only, ideas only.** They are the owner's private projects.
- **Online on two PCs first; two players in total.** That's how the owner wants to play.
- **Both input methods are first-class.** The owner plays with a DualSense; others use keyboard and mouse.
- **Small PRs, never stacked; the owner merges.** Stacked PRs once merged into a branch instead of `main`.

## Who owns what
Build owns everything in the repo for now. When an `art` role starts, it owns `art/` and the model builders, and
Build owns how the game loads them.

## Running a round
1. Read the milestone's rows in `docs/PLAN.md` and `docs/STATUS.md`.
2. Build in small steps; every number and string goes in `data/`.
3. Add or update tests for each proof row; run the full suite headless.
4. Check new files for personal data.
5. Commit, push, open or update the PR, and end the turn while CI runs.
6. Update `docs/STATUS.md`, `HANDOFF.md`, and a round-log line here.

## Craft rules
- GDScript with static types where it helps; one script per job.
- Tests are plain `test_*.gd` files extending `RefCounted` with `test_*` methods that return an empty string on a
  pass or a message on a failure.
- Prefer a failing check over a silent pass.

## Round log
- 25 Oct 2026: Milestone 0 skeleton: project, input map, tuning loader, sandbox, test runner, CI, method files.
