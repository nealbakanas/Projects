# Math Blaster (working title)

A real-time, retro pixel-art math shooter with roguelike runs. Built in Godot 4, browser-first.
See [docs/DESIGN.md](docs/DESIGN.md) for the design doc.

## Requirements

- [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET; GDScript only)
- Web export templates for 4.3 (Editor → Manage Export Templates → Download)

## Run

Open `project.godot` in Godot and press F5, or from the command line:

```sh
godot --path .
```

## How to play (prototype)

Pick a content tier and an input mode on the title screen (arrow keys + Enter, or click).
Saucers descend carrying problems; answer them before they reach your ship. Five breaches
and the ship goes down. Consecutive correct answers build a score multiplier.

- **Type the answer:** type the number (`-`, `/` and `.` work too) and press Enter. The shot
  auto-targets whichever saucer it solves.
- **Shoot the answer:** click/tap one of four answers, or press 1-4. It fires at the
  highlighted saucer, the one closest to your ship.

A wrong answer breaks your combo and pushes the target saucer forward. Orange saucers take
two hits and show a new problem after the first.

## Tests

Unit tests live in `tests/` and run headless with a small built-in runner (no addons):

```sh
godot --headless --import            # first run only: registers class names
godot --headless --script res://tests/run_tests.gd
```

The runner executes every `test_*` method in `tests/test_*.gd` and exits non-zero on failure.
Problem-generator answers are checked against an independent rational-number expression
evaluator (`tests/expression_oracle.gd`), not against the generator's own arithmetic.

## Code layout

- `scripts/problems/`: `ProblemGenerator`, `Problem`, and `Distractors` (wrong answers for
  shoot mode). Pure logic.
- `scripts/combat/`: `Encounter` (all combat rules, pure logic, driven by `step(delta)` and
  `submit(answer)`), `Weapon`, and `combat.gd` (the scene that draws an encounter).
- `scripts/input/`: `AnswerInput` and its two strategies, `TypedAnswerInput` and
  `ChoiceAnswerInput`. Combat only listens for `answer_submitted`, so modes are swappable.

## Problem generator

`ProblemGenerator` (`scripts/problems/`) is pure GDScript with no scene dependencies:

```gdscript
var gen := ProblemGenerator.new(run_seed)
var p := gen.generate(ProblemGenerator.Skill.MUL, 2)  # e.g. "7 × 8"
p.text           # display text
p.answer_text()  # "56"
p.tag            # &"mul:by_7", for per-skill tracking
p.is_correct("56")
gen.generate_for_tier(4)  # any skill unlocked at tier 4
```

Answers are exact fractions, so `is_correct` accepts `3/4`, `6/8`, or `0.75`. The same seed
always produces the same problems.

## Web build

The project uses the Compatibility renderer and a **single-threaded** web export
(`variant/thread_support=false`), so it runs on itch.io and GitHub Pages without
cross-origin isolation headers.

```sh
godot --headless --import
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # then open http://localhost:8000
```

## Pixel-art settings

- Base resolution 320×180, window 1280×720
- Stretch mode `viewport` with `integer` scaling
- Nearest texture filtering, pixel snapping, and no font antialiasing

## CI

`.github/workflows/build.yml` runs on every push and PR. It imports the project, runs the unit
tests, boots the main scene headless and fails on any script error, exports the web build, and uploads it as
the `math-blaster-web` artifact.
