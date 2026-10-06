# Math Blaster (working title): Design Doc

A real-time, retro pixel-art math shooter with roguelike runs, inspired by
*Math Blaster*. Built in Godot 4, browser-first.

## Pillars

1. **Math is the weapon.** Every shot is an answer. Fluency is power.
2. **Fun at every age.** A 7-year-old and an adult can both be challenged by the same game.
3. **Short runs, long mastery.** A run lasts 10–15 minutes. Mastery comes from builds, relics, and ascension.
4. **Crisp and readable.** Pixel art, but the numbers are always legible.

## Target

| | |
|---|---|
| Engine | Godot 4.3+ with GDScript only (C# can't export to the web) |
| Platform | Browser first: single-threaded web export, hosted on itch.io / GitHub Pages |
| Art | Retro pixel art, 320×180 base resolution, integer scaling, nearest filtering |
| Audience | All ages: kids through adults |
| Run length | 10–15 minutes |

## Difficulty: three dials

Challenge comes from three independent dials, not just harder topics.

1. **Content:** what math appears (the tiers below).
2. **Pressure:** enemy speed, how many problems are on screen, time to answer.
3. **Modifiers:** relics and curses that change how the math behaves.

Kids mostly turn the content dial. Adults turn all three.

### Content tiers

| Tier | Content | Example |
|---|---|---|
| 1 | Add/subtract within 20 | `8 + 5` |
| 2 | Times tables, two-digit add/subtract | `7 × 8`, `46 + 37` |
| 3 | Division, simple fractions, negatives | `56 ÷ 7`, `1/2 + 1/4`, `-3 - 5` |
| 4 | Order of operations, percents, one-step equations | `3 + 4 × 2`, `25% of 80`, `x + 7 = 12` |
| 5 | Exponents, roots, multi-step algebra, primes/factors | `2^6`, `√144`, `3x - 4 = 11` |
| 6 | Mental-math gauntlet | `17 × 23`, `2^10 - 3^5`, `47 mod 6` |

- The player picks a starting tier; a short placement round can suggest one.
- **Adaptive per skill:** the game tracks accuracy and speed per skill (for example
  "multiplication by 7" or "fraction addition") and brings back missed facts more
  often. This is spaced repetition in disguise.

## Core loop (real time)

1. Enemies descend or advance in waves. Each enemy carries a problem.
2. The player answers to fire at that enemy.
3. Correct answer: the enemy takes damage. Speed and streaks add bonuses.
4. Wrong answer or a timeout: the player loses shield or HP, or the enemy advances.
5. Clear the wave, then pick a reward, then move to the next node on the map.

**Combo meter:** consecutive correct answers raise a score/damage multiplier. A miss resets it.

### Open question: input method

This is deferred for now. Candidates:
- **Shoot the answer:** answer targets float around, and the player aims and shoots the right one.
  Friendly for kids and touch screens, and closest to the original game.
- **Type the answer:** the player types the number, and it auto-targets the matching enemy.
  Fast, skill-expressive, and good for adults.
- **Hybrid:** offer both as modes, or decide by tier.

Prototype the core loop so input is swappable (an `AnswerInput` interface).

## Run structure (~10–15 min)

- **3 sectors per run**, about 4–5 minutes each.
- Each sector is a short branching map of roughly 5–6 nodes, ending in a boss.
- Combat encounters last about 45–75 seconds.

| Node | Description |
|---|---|
| ⚔️ Combat | Standard wave fight |
| 💀 Elite | Harder problems, better loot, may apply a curse |
| 🛒 Shop | Spend coins on relics, weapons, repairs |
| ❓ Event | Puzzle or gamble: "solve this riddle for a relic, or take damage" |
| 🔧 Repair Bay | Heal, or upgrade a weapon |
| 👾 Boss | Multi-phase fight; each phase is a problem chain |

## Weapons: your build is your math

The weapon loadout decides which problem types the player faces.
Harder math pays out more, so risk vs. reward is a player choice.

| Weapon | Problems | Behavior |
|---|---|---|
| Adder Blaster | Addition/subtraction | Fast fire, low damage |
| Multiplier Cannon | Multiplication | Slower, high damage |
| Fraction Laser | Fractions | Pierces through enemies |
| Equation Railgun | Solve for x | Huge damage, long problems |

Weapons scale with the content tier. For example, the Multiplier Cannon at tier 2 asks
`6 × 7`, and at tier 6 it asks `38 × 47`.

## Relics (passive modifiers)

| Relic | Effect |
|---|---|
| Even Steven | Even answers deal double damage |
| Prime Directive | Prime-number answers pierce all enemies |
| Carry the One | Overkill damage carries to the next enemy |
| Rounding Error | Answers within 5% hit for half damage |
| Square Dance | Perfect-square answers heal 1 HP |
| Streak Engine | Every 5 correct in a row fires a free bomb |

## Curses

Curses come from elites and events, or the player can take them voluntarily for bonus rewards.

| Curse | Effect |
|---|---|
| Fog | One digit of each problem is hidden until the enemy is close |
| Roman Holiday | Some numbers appear as Roman numerals |
| Mirror | Problems display reversed |
| Rush Hour | Enemies move 25% faster |

## Meta-progression

- Unlock ships, each with a starting weapon and a quirk.
- Unlock new relics into the pool.
- **Ascension levels:** stacking difficulty modifiers for mastered runs. This is the main adult endgame.
- Stats screen: accuracy and speed per skill.

## Technical architecture (initial)

- `ProblemGenerator`: pure GDScript, no scene dependencies, unit-testable.
  Inputs are skill, tier, and an RNG seed. Output is a problem (display text, answer, skill tag).
- `SkillTracker`: per-skill accuracy and speed, which feeds adaptive selection.
- `RunState`: seed, sector, map, HP, coins, weapons, relics, curses.
- `ModifierSystem`: relics and curses hook into events such as `on_answer`, `on_damage`, and `on_problem_generated`.
- `AnswerInput`: a swappable input strategy (shoot, type, or hybrid).
- **Seeded RNG everywhere**, so runs can be reproduced (useful for daily challenges and debugging).

## Milestones

1. **Scaffold:** Godot project, pixel-art settings, single-threaded web export, CI build.
2. **Problem generator:** tiers 1–6 with unit tests.
3. **Core loop prototype:** one combat encounter, real time, one weapon, placeholder art.
4. **Run structure:** sector map, node types, a 3-sector run.
5. **Build systems:** weapons, relics, curses.
6. **Meta-progression and polish:** unlocks, ascension, art, audio.
