# Spell Cauldron – plan

## Design decisions
- **Engine:** Godot 4 (GDScript), 2D, Compatibility renderer. Windows first; browser and phone later.
- **Players:** kids on easy levels, adults on hard levels.
- **Core loop:** a word with missing letters floats in the cauldron. Drag letters from the table into it, then stir.
  Correct → the brew turns gold and sparkles, next word. Wrong → smoke and fizzle, wrong letters hop back. No penalty.
- **Stirring:** draw a circle on the cauldron (works with touch later), or press *Stir!*.
  Letters swirl, then always settle back into their correct order.
- **Gaps:** visible empty slots on levels 1–4, hidden on levels 5–10 (you work out where letters go).
- **Letters:** used up when placed. Duplicates appear when the word needs them (two E's for "tree").
  Decoys are never letters that could spell a *different* real word.
- **Hints (unlimited):** *Where?* shows only the position. *Meaning?* shows what the word means.
- **Session:** 10 words = one difficulty level complete.
- **Look:** cozy and simple, a witch's hut. Sound and music come later.

## Difficulty (tune in `scripts/game_data.gd`)
| Level | Word length | Missing | Decoys | Gaps |
|---|---|---|---|---|
| 1 | 3–4 | 1 | 2 | shown |
| 2 | 3–4 | 1 | 3 | shown |
| 3 | 4–5 | 1–2 | 4 | shown |
| 4 | 4–5 | 2 | 4 | shown |
| 5 | 5–7 | 2 | 5 | hidden |
| 6 | 6–7 | 2 | 5 | hidden |
| 7 | 6–9 | 2–3 | 6 | hidden |
| 8 | 7–9 | 3 | 6 | hidden |
| 9 | 8–11 | 3–4 | 8 | hidden |
| 10 | 9–14 | 4 | 8 | hidden |

## Roadmap
- [x] 1. Setup: Godot project, git, GitHub
- [x] 2. Rough prototype: word, slots, table letters, drag & drop, stir check
- [x] 3. Word list + difficulty 1–10 puzzle maker (first version, ~90 words)
- [x] 4. Game loop: 10 words per level, hints, wrong-answer effects
- [ ] 5. Menus: title screen, nicer difficulty picker, end-of-level screen
- [ ] 6. Cozy look: real art for the hut, cauldron, letters; nicer brew effects
- [ ] 7. Export: Windows .exe, then web and phone
- [ ] Later: sound and music, a bigger word list, a larger dictionary for decoy checks
