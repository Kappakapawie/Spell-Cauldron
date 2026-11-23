# Spell Cauldron

A cozy spelling game made with **Godot 4**. A half-finished word floats in a witch's cauldron.
Drag the right letters from the table into the word, then stir the brew to see if you spelled it right.

## Play / run it
1. Open Godot 4, click **Import**, and pick `project.godot` in this folder.
2. Press **F5** (or the ▶ button, top right) to play.

## How to play
- **Drag** letters from the table into the word.
- **Stir** with the *Stir!* button, or draw a circle on the cauldron with your mouse.
- **Where?** shows where a missing letter goes. **Meaning?** shows what the word means.
- Choose difficulty **1–10** at the top. Ten words complete a level.

## Project layout
| Path | What it is |
|---|---|
| `scenes/main.tscn` | The game scene |
| `scripts/main.gd` | Game flow, drag & drop, stirring, hints, drawing, UI |
| `scripts/game_data.gd` | **Difficulty levels and the word list (edit here to add words)** |
| `scripts/puzzle_maker.gd` | Picks missing letters and safe decoys |
| `scripts/letter_tile.gd`, `scripts/gap_slot.gd` | A letter tile, an empty gap |
| `tests/smoke_test.gd` | Headless check: `godot --headless --path . --script res://tests/smoke_test.gd` |

See [PLAN.md](PLAN.md) for the design decisions and the roadmap.
