# The hand-off method

Long conversations are the biggest token cost: every step re-reads the whole history. So a thread works on one job,
writes down what the next thread needs, and closes. The next thread starts from these files, never from the old chat.

## The files
```
handoff/README.md          this method
handoff/<role>/HANDOFF.md  what the role owns, state now, open work in order, owner decisions, traps, how to check
handoff/<role>/LESSONS.md  "Start here" first; owner rules with reasons; who owns what; the steps of a round;
                           craft rules; a one-line round log
```
Roles (owner, 25 Oct 2026): `gameplay` (rules, netcode, data for play, the world), `interface` (HUD, Pack, cyclers,
menus, settings, input) and `playtest` (tests, captures, CI, review sheets). `build` is the history and the shared
architecture notes every role reads (`handoff/build/HANDOFF.md` sections 2 and 6). Add `art` when model batches start;
a new role copies these files' shape.

The live list of running threads is kept **outside the repo** in the project's shared folder
(`/mnt/project-files/handoff/THREADS.md`), because thread and session ids don't belong in a public repo.

## The cycle
1. **Close at the end of a job, never in the middle.** Update `HANDOFF.md` and `LESSONS.md`, remove your line from
   the thread list, and resolve.
2. **Start a new thread only when there is work for it.** Check the thread list first so you don't start a duplicate.
3. **A fresh thread reads files:** `CLAUDE.md`, `docs/PLAN.md`, `docs/STATUS.md`, its `HANDOFF.md` and `LESSONS.md`.
   It adds its line to the thread list.
4. **Every round ends the same way:** a round-log line (and any new rule) in `LESSONS.md`; state and traps in
   `HANDOFF.md`; `docs/STATUS.md` if a proof row changed.
5. **If you ask the owner something the files should answer, write the answer into them in the same turn.**

## After every review round: why, then a fix that stops it coming back
One line per fault: what went wrong, why it got through, what now stops it. "Be more careful" doesn't count. The fix
goes into a test, a data rule, a builder self-check or `LESSONS.md`.

## Leak rules (every thread)
- Idle is free. While waiting on CI, a merge or the owner, end the turn; events wake you.
- No polling, no sleep loops, no repeated status checks.
- A wake that changes nothing ends at once.
- Bundle notes to another thread into one message; no "done" or "thanks" pings.
- Before saying anything about a PR, check its live state on GitHub.
