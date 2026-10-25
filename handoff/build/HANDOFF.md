# Build hand-off, 25 Oct 2026

1. **Owns:** game code (`scripts/`), scenes (`scenes/`), tests (`tests/`), data tables (`data/`), CI
   (`.github/workflows/`), the start-up script, `docs/STATUS.md`. Proposes changes to `docs/PLAN.md` for the owner.
   Never touches the reference repos.
2. **State now:** Milestone 0 is in its first PR (project skeleton, input map, tuning loader, sandbox with a test
   capsule, headless test runner, CI, licence). Check the PR's live state on GitHub before talking about it.
3. **Open work, in order:**
   1. Milestone 0: the owner's hands-on try with keyboard and DualSense; confirm CI is green.
   2. Milestone 1: felt material and the art proof models built by code; the play camera; movement feel.
   3. Milestone 2: GDScript netcode on Godot's multiplayer (host decides, profile IDs, stable object IDs).
4. **Owner decisions:** see the decision log in `docs/PLAN.md`.
5. **Traps already found:**
   - Godot's `--script` mode runs before autoloads exist; tests load what they need themselves.
   - The repo is public: check every new file for personal data before committing.
6. **How to check things:**
   ```
   godot --headless --import
   godot --headless --script res://tests/run_tests.gd
   ```
   The exit code is the number of failures.
