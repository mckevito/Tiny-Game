# Status

What each milestone has, what the owner has signed off and what is open. Updated by whoever finishes work on a
milestone. Proof rows name the test that covers them.

## Milestone 0: Project setup
Signed off: no.

| Proof | Test | Result |
|---|---|---|
| Tuning tables load and read typed values with a fallback | `tests/test_tuning.gd` | Passing (headless, Godot 4.7.2) |
| Every input action has a keyboard or mouse binding and a joypad binding | `tests/test_input_map.gd` | Passing |
| The sandbox scene loads | `tests/test_sandbox.gd` | Passing |
| CI runs the tests on each push and PR | `.github/workflows/ci.yml` | To confirm on the first PR |
| A DualSense and the keyboard both move the test capsule | Owner's hands-on try | Open |

### How to try it
1. Open the project in Godot 4.7.2 and press F5 to open the sandbox.
2. Move the capsule with WASD, then with the DualSense left stick.

### Still open
- The owner's hands-on try with a DualSense over USB and Bluetooth.
- Licence choice is Proposed (MIT code, CC BY 4.0 art).
