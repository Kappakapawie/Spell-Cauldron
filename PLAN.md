# Spell Cauldron – plan

## Design decisions
- **Engine:** Godot 4 (GDScript), 2D, Compatibility renderer. Windows first; browser and phone later.
- **Players:** kids on easy levels, adults on hard levels.
- **Core loop:** a word with missing letters floats in the cauldron. Drag letters from the table into it, then stir.
  Correct → the brew turns gold and sparkles, next word. Wrong → smoke and fizzle, wrong letters hop back. No penalty.
- **Stirring:** only with the mouse: hold and draw circles on the cauldron (a wooden spoon follows).
  No stir button. Letters swirl, then always settle back into their correct order.
- **Cauldron:** seen from above. Letters float over it in gently bobbing gas bubbles.
  Golden letters engraved on the front say how many letters to find ("FIND 2 LETTERS"),
  then "STIR THE POT!" once every gap is filled. No other text instructions.
- **Potions (replace free hints):** brewing a word earns potions (1 for short words, up to 4 for long ones),
  randomly *Wisdom* (blue) or *Vision* (pink). They show as flask icons left of their buttons.
  - *Wisdom* shows what the word means as a soft, floating thought above the cauldron, in snippets:
    each potion reveals more words (hidden parts show as "…"); once all known, it reopens free.
  - Easier levels reveal more per potion: full meaning / clearest picture takes 2 potions on
    levels 1-3, 3 on levels 4-6, 4 on levels 7-10.
  - **Level stars:** the points earned during a level run are saved as a number in a star under
    that level's button (best run kept). If every reward potion in the run became points, the run
    is perfect: the star turns solid gold and the level is *conquered*.
  - You can hold at most 10 of each potion. Every potion earned beyond that becomes 10 score points.
  - *Vision* makes a blurry picture appear in the brew; each extra one makes it clearer (3 steps).
    The picture turns sharp when the word is brewed. (Placeholder: Windows emoji; replace with art later.)
  - Cost per drink rises with difficulty: 1 (levels 1-3), 2 (4-6), 3 (7-9), 4 (10). Start with 2 of each.
  - The potion stock and score are saved between play sessions (`user://save.cfg`).
  - *Where?* (shows a gap position) stays free.
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
