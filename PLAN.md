# Spell Cauldron – plan

## Design decisions
- **Engine:** Godot 4 (GDScript), 2D, Compatibility renderer. Windows first; browser and phone later.
- **Players:** kids on easy levels, adults on hard levels.
- **Core loop:** a word with missing letters floats in the cauldron. Drag letters from the table into it, then stir.
  Correct → the brew turns gold and sparkles, next word. Wrong → smoke and fizzle, wrong letters hop back. No penalty.
- **Stirring:** swipe left across the brew with the mouse (a wooden spoon follows).
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
  - **Level stars (out of 100):** each word is worth 10 points; drinking any Vision potion on it
    removes 5, any Wisdom potion removes 5 (both = 0). *Where?* or the owl also count as help (-5).
    The best run is saved as a number in a star under the level button; 100 = solid gold star,
    level *conquered*.
  - **Shelves:** each shelf starts with 3 slots (empty slots shown faintly). Potions earned beyond
    a full shelf become 10 score points. The *Shelves* menu spends score on extra slots
    (30, 60, 90, ... points), up to 10 per shelf.
  - **Star upgrades** (in the Shelves spell book): unlocked by total stars across all levels (max 1000),
    then bought with score points. Every spell has ranks; each rank costs more.
    | Stars | Spell | Per rank | Ranks | First price, growth |
    |---|---|---|---|---|
    | – | Wisdom / Vision shelf | +1 slot | 7 (3→10) | 30, +30 each |
    | 200 | Potion discount | drinks cost 1 less (min 1) | 2 | 100, ×2.5 |
    | 300 | Whispering sage | full meaning takes 1 Wisdom potion fewer (min 1) | 2 | 120, ×2.2 |
    | 300 | Clear sight | clearest picture takes 1 Vision potion fewer (min 1) | 2 | 120, ×2.2 |
    | 500 | Owl familiar | places a right letter every 10 s; click the owl to pause; counts as help (-5) | 1 | 150 |
    | 500 | Swift wings (needs owl) | owl helps 0.5 s sooner | 10 (10 s→5 s) | 60, ×1.35 |
    | 800 | Lucky cauldron | +1 potion per brewed word | 3 | 250, ×1.9 |
  - Potion costs on the buttons are shown as small potion icons (blue = Wisdom, pink = Vision).
- **Decoy letters per level** (slow growth): 2, 2, 3, 3, 3, 4, 4, 5, 5, 6.
  - *Vision* makes a blurry picture appear in the brew; each extra one makes it clearer.
    The picture turns sharp when the word is brewed. (Placeholder: Windows emoji; replace with art later.)
  - Cost per drink rises with difficulty: 1 (levels 1-3), 2 (4-6), 3 (7-9), 4 (10). Start with 2 of each.
  - The potion stock and score are saved between play sessions (`user://save.cfg`).
  - *Where?* costs 1 Wisdom + 1 Vision potion once per word (then free for that word); on hidden-gap
    levels it also pushes the letters apart where a letter belongs.
- **Gaps:** visible empty slots on levels 1–4, hidden on levels 5–10 (you work out where letters go).
- **Letters:** used up when placed. Duplicates appear when the word needs them (two E's for "tree").
  Decoys are never letters that could spell a *different* real word.
- **Hints:** Wisdom and Vision potions, and *Where?* (see Potions).
- **Session:** 10 words = one difficulty level complete.
- **Look:** cozy and simple, a witch's hut. Sound and music come later.

## Difficulty (tune in `scripts/game_data.gd`)
| Level | Word length | Missing | Decoys | Gaps |
|---|---|---|---|---|
| 1 | 3–4 | 1 | 2 | shown |
| 2 | 3–4 | 1 | 2 | shown |
| 3 | 4–5 | 1–2 | 3 | shown |
| 4 | 4–5 | 2 | 3 | shown |
| 5 | 5–7 | 2 | 3 | hidden |
| 6 | 6–7 | 2 | 4 | hidden |
| 7 | 6–9 | 2–3 | 4 | hidden |
| 8 | 7–9 | 3 | 5 | hidden |
| 9 | 8–11 | 3–4 | 5 | hidden |
| 10 | 9–14 | 4 | 6 | hidden |

## Roadmap
- [x] 1. Setup: Godot project, git, GitHub
- [x] 2. Rough prototype: word, slots, table letters, drag & drop, stir check
- [x] 3. Word list + difficulty 1–10 puzzle maker (first version, ~90 words)
- [x] 4. Game loop: 10 words per level, hints, wrong-answer effects
- [ ] 5. Menus: title screen, nicer difficulty picker, end-of-level screen
- [ ] 6. Cozy look: real art for the hut, cauldron, letters; nicer brew effects
- [ ] 7. Export: Windows .exe, then web and phone
- [ ] Later: sound and music, a bigger word list, a larger dictionary for decoy checks
- **Shelves = spell book:** a leather book with a skill tree of spell medallions you can drag around.
  Hover a spell to read it (in a strange tongue until learned; cost and requirements stay plain),
  hold the mouse on it to learn it: a gold ring fills and the words decipher.
