# Spell Cauldron – plan

## Names
- **Book of brew recipes** ("Brew recipes 3"): one of the 29 difficulties on the shelves.
- **Level**: one word to spell. Each book holds 10 levels (a book can set its own number with `"words"`).
- In the code the older names remain: a book is `level` / `LEVELS`, a level is a word.

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
  - **Buys per word:** Wisdom and Vision can each be bought once per missing letter. The clues are spread evenly over the
    buys; the last one shows everything (with 1 missing letter the first buy does). After that they can't be bought.
  - **Level score:** a level solved without help gives 1 point, so a book's perfect score is its number
    of levels (10). The 1 point is shared evenly between **all helpers in the game** (`HELPERS` in
    `main.gd`): each kind used on a level takes its share off, however often it was used; all of them = 0.
    Now 2 helpers, so 0.5 each: Wisdom and Vision. The pets (owl, cat, frog) cost no score, only time or potions.
    **When adding a new kind of help: put it in `HELPERS` and call `_use_helper()` when it helps.**
    The shares, tooltips and scores follow by themselves; `_check_helpers` in the test must learn it too.
    Helpers that aren't learned yet count in the split too, so a level's worth never changes as you learn spells.
    The best run is saved as a number in a star beside the book; a perfect run = solid gold star,
    recipes *mastered*. With the hourglass spell a book keeps two best scores: guessing (up to 10)
    and time (1 per level in time, up to 10; with Golden sand up to 6 per level). They may come from different runs and are added together (10 + 10 = 20).
    *Mastered* means a perfect 10 for guessing. Saves from the old out-of-100 scoring are converted (95 becomes 9.5).
  - **Shelves:** each shelf starts with 3 slots (empty slots shown faintly). Potions earned beyond
    a full shelf become 10 *knowledge* (`score` in the code). The *Shelves* menu spends knowledge on extra slots
    (20, 40, 60, ...), up to 10 per shelf.
  - **Star upgrades** (in the Shelves spell book): unlocked by total stars across all books (max 290, 580 with the hourglass, 2030 with Golden sand),
    then bought with knowledge. Every spell has ranks; each rank costs more.
    | Stars | Spell | Per rank | Ranks | First price, growth |
    |---|---|---|---|---|
    | – | Wisdom / Vision shelf | +1 slot | 7 (3→10) | 20, +20 each |
    | 20 | Potion discount | spell ORCHARD first (theme Nature & weather, books 7-13). Drinks cost 1 less (min 1) | 2 | 80, ×2 |
    | 30 | Enchanted hourglass | spell HOURGLASS first (theme Time & calendar, in every book of it until learned). **one countdown for the whole book**: turned over when the book starts, it runs on from word to word; every level brewed before the sand runs out gives 1 extra star, however much help was used. The book's sand: 10 × (6 s + 4.5 s per missing letter + 3 s if gaps are hidden), e.g. 105 s for book 1 (stands still while stirring, in the spell book or paused). Empty: no more extra stars in this run | 1 | 150 |
    | 30 | Slow sand (needs hourglass) | spell SLOW first (theme Time & calendar, any book). the hourglass holds 25 % more sand | 5 | 120, ×1.5 |
    | 60 | Golden sand (needs hourglass) | spell IMMEDIATELY first (theme Time & calendar, books 19-29). up to 5 more stars for every level, by how quick it was against its share of the sand (6 s + 4.5 s per missing letter + 3 s if hidden; the first 2 s cost nothing; 5, 4, 3, 2, 1, 0; the hourglass shows what you would get now) | 1 | 600 |
    | 0 | Wisdom potion / Vision potion | lets you drink it. Spell WISDOM / VISION first (in every book of Witchcraft & magic). In play they are round icons like the pets (`scripts/potion_icon.gd`). Its shelf and Whispering sage / Clear sight need it; saves from before have both | 1 | free |
    | 0 | Hungry frog | lets you feed the frog to reroll a book's theme, once per book; learned in the first mission | 1 | free |
    | 20 | Second helping (needs frog) | the frog can be fed once more in every book (1, then 2, then 3 times; on the theme screen and in play together). Only brewing the book to the end gives the meals back | 2 | 70, ×1.8 |
    | 40 | Frog buffet (needs frog) | the frog coughs up one more theme to choose from (2, then 3) | 2 | 90, ×2 |
    | 30 | Frog snacks (needs frog) | feeding the frog costs 1 potion less (4 → 1) | 3 | 50, ×1.6 |
    | 30 | Whispering sage | full meaning takes 1 Wisdom potion fewer (min 1) | 2 | 150, ×2 |
    | 30 | Clear sight | spell KETTLE first (theme Food & kitchen, books 3 and 5-12). All pictures are shown 1 Vision potion sooner (min 1) | 2 | 150, ×2 |
    | 10 | Owl familiar | every 20 s a letter on the table that is surely needed glows (never placed); costs no score | 1 | 50 |
    | 10 | Swift wings (needs owl) | the owl is 1 s quicker | 10 (20 s→10 s) | 45, ×1.25 |
    | 40 | Full moon (needs owl) | spell MOON first (theme Universe, any book). Whenever the owl helps, 2 % chance that it points out all needed letters | 5 (10 %) | 100, ×1.5 |
    | 15 | Cat familiar | every 8 s its paw opens a space where a letter is missing; the space stays until filled, marked with a see-through paw print. Spots between two letters first; at the ends of the word it taps instead of swiping. Nothing to do in books where gaps are shown; costs no score | 1 | 80 |
    | 15 | Quick paws (needs cat) | spell CURIOUS first (theme Body & feelings, books 7-13). The cat is 0.5 s quicker | 10 (8 s→3 s) | 40, ×1.25 |
    | 25 | Kitchen mouse | brings a random potion every 30 s while brewing; when both shelves are full it becomes 10 knowledge | 1 | 120 |
    | 25 | Cheese (needs mouse) | spell CHEESE first (theme Food & kitchen, books 3 and 5-12). The mouse is 5 s quicker | 5 (30 s→5 s) | 120, ×1.5 |
    | 40 | Raven familiar (needs cat) | every 20 s a small raven (red for a vowel, black for a consonant) settles over an empty space you can see (shown, or opened by the cat for every letter missing there); it stays until the word is brewed; costs no score | 1 | 100 |
    | 40 | Keen eyes (needs raven) | spell EYE first (theme Body & feelings, any book). The raven is 1 s quicker | 10 (20 s→10 s) | 45, ×1.25 |
    | 55 | Chameleon | when charged (10 s), shows whether the next letter you let go of is in the right place: green with a tick or red with a cross; costs no score | 1 | 170 |
    | 55 | Quick colors (needs chameleon) | the chameleon charges 1 s quicker | 8 (10 s→2 s) | 60, ×1.3 |
    | 70 | Raccoon | every 20 s it steals a wrong letter from the table (never one you placed); costs no score | 1 | 220 |
    | 70 | Sneaky paws (needs raccoon) | the raccoon is 1 s quicker | 10 (20 s→10 s) | 60, ×1.25 |
    | 80 | Your cauldron (the middle of the tree; id `lucky`) | +1 potion per brewed word | 3 | 225, ×1.7 |
    | 40 | Hallucination (at the Vision shelf) | spell CONDENSE first (theme Alchemy, books 9 and 12-19). 10 % more chance of one free Vision at the start of a word: no potion, no lost stars | 5 (10→50 %) | 100, ×1.5 |
  - **Something new unlocked** (`scripts/unlock_flight.gd`): when a spell can be learned for the first time, or a pet's name was spelled, its icon pops
    up over the cauldron and flies into the Shelves button (after a book: into the picker's Spell book button).
  - **Themes are bought too** (they grow from a starting node of their own beside the spells in the spell book): a new game knows Animals and Witchcraft & magic (all pet
    names are in them); the others cost 60 knowledge each, Time & calendar 200 (`THEME_PRICES`), in any order, without stars. Saves from before keep the ten there were then.
    Their places in the tree: `THEME_ROWS`. Renamed themes: `OLD_THEME_NAMES`.
  - **Only the raven needs another animal** (the cat, which opens the spaces it looks at); the others hang on the cauldron side by side.
  - **First mission** (`Tutorial` in `main.gd`, `scripts/tutorial_note.gd`): Play in a new game goes straight to book 1 with FROG as the first
    word. Then the game waits until you open the Shelves and learn the frog: it is free, and nothing else can be learned before it.
    Small messages lead the way; after that the frog's first meal is free. Saves from before skip it.
  - Saves from when there were 30 books: the old books 1 and 2 (the same) become book 1 with the best of both, the others move up one place.
  - **OWL and CAT** are in every book of the theme Animals, **WISDOM and VISION** in every book of Witchcraft & magic, **HOURGLASS** in every book of Time & calendar, whatever their length
    (`always_words`), until they are learned. **SLOW, MOON and EYE** too in theirs, but only until they are spelled (`UNTIL_SPELLED`).
  - **Spell their names:** owl, cat, mouse, raven, chameleon, raccoon, frog, the two potions, the hourglass, Slow sand (SLOW), Golden sand (IMMEDIATELY), Clear sight (KETTLE), Potion discount (ORCHARD), Full moon (MOON), Cheese (CHEESE), Hallucination (CONDENSE), Keen eyes (EYE) and Quick paws (CURIOUS) can only be learned once you have brewed that word. Until
    then the spell is greyed out and the letters of the name float away from it. A ribbon names the theme the word is in, and the tooltip says
    "Special unlock: spell OWL in the theme Animals (book 1)." A name
    not spelled yet comes up whenever a fitting book of its theme is played. Saved; pets owned before this rule keep working.
  - **Pets work by themselves**, one help at a time (upgrades only make them quicker): owl, cat and raven help whenever their cooldown is over, the mouse brings potions. The cooldown
    starts with the book, runs on from word to word (not while paused or in the spell book), and waits when there is nothing
    to do or you are moving a letter. Clicking a pet pauses it or wakes it (saved); it keeps its progress.
  - Potion costs on the buttons are shown as small potion icons (blue = Wisdom, pink = Vision).
- **Decoy letters per level** (slow growth): from 2 in book 1 to 7 in book 29.
  - *Vision* shows sharp pictures, the most telling one first. A word has 1-6. Together the pictures point to the word
    (lumberjack: axe, tree, wood, beard, maple leaf). All of them show when the word is brewed.
    Windows emoji up to version 13, or a drawing in `art/pictures` where no emoji fits ("@mole" in the word list). `docs/make_icon_sheet.py` makes a sheet of them.
  - Cost per drink rises with difficulty: 1 (books 1-3), 2 (4-6), 3 (7-9), 4 (10-12), 5 (13-29). Start with 2 of each, and 100 knowledge.
  - The potion stock and knowledge are saved between play sessions (`user://save.cfg`).
  - **Reset game** button on the title (asks "Really start over?").
  - **Reset version:** `Play Spell Cauldron (choose reset).bat` starts the game with `-- --ask-reset`: before the title it asks
    Continue / Reset the game (then "Really start over?"). A reset renames the save to `save_before_reset_<time>.cfg`.
- **Gaps:** shown as empty slots, or hidden (you work out where letters go): see the staircase under Difficulty.
- **Vowel and consonant marks:** every letter, on the table and in the word, is colored as a whole: red for a vowel (A, E, I, O, U), black for a consonant.
- **Letters:** used up when placed. Duplicates appear when the word needs them (two E's for "tree").
  Decoys are never letters that could spell a *different* real word.
- **Hints:** Wisdom and Vision potions, the owl and the cat.
- **Session:** 10 levels (words) = one book of brew recipes complete.
- **Look:** cozy and simple, a witch's hut. Sound and music come later.

## Menus
- **Title:** the name floats in bubbles over the hut. Stir the cauldron ("STIR TO BEGIN") or press *Play*.
- **Recipe picker:** two pages (< and > turn them), leather books ten to a shelf, each with its star; what a book asks of you shows above the
  shelves when the mouse is on it (and in its tooltip). All books are always open; on each page the first one not mastered glows.
  - **Page 1:** the 29 normal books, on three shelves.
  - **Page 2: Mystery recipes** (`GameData.MYSTERY_LIKE`, book numbers 30-49 in the code, 1-20 on their covers; dark violet books with a "?"):
    each plays like a normal book, easy to hard again on the same staircase, squeezed into 20 (like books 1, 2, 4-10, 12, 14, 15, 17, 18, 20, 22, 24, 25, 27, 29:
    each number of missing letters starts with the gaps shown, twice from 2 letters on, then hidden), but it is always **mixed** (a new random theme for every
    word, never the same twice in a row) and the themes are **secret**: the sign says "Secret theme", there is no frog screen and the little
    frog is gone. The end screen tells each word's theme beside it. Their stars count like any others.
- **Pause** (*Menu* button or Esc): everything stands still. Leaving a book is only possible from here,
  so a stray click can't lose a run.
- **Stars** are always shown as the star symbol with the number in it (`LevelStar`): a book's best, all stars together, what a spell needs.
- **The big moment** (`scripts/book_finale.gd`): when a book is done, RECIPES COMPLETE! covers the screen, and the hourglass pours its stars
  into the star one by one until HOURGLASS BONUS +10 lands (5-6 s; a click skips it; 2 s without stars for time). The end screen keeps a badge with the stars for time.
- **Out of sand** (`scripts/sand_out.gd`): the first 3 times ever (`sand_fails` in the save) the hourglass comes to the middle and OUT OF SAND! is
  told with red edges; nothing is blocked. After that only the small hourglass shows "too late".
- **End of a book:** the star counts up, each level's word is listed with its points, and spells whose star
  requirement was just reached are announced.

## Difficulty (tune in `scripts/game_data.gd`)
**One thing gets harder at a time.** Each number of missing letters is first played with the gaps shown, for at least two books (one for 1 letter, so the start goes faster),
then with the gaps hidden, for at least two; only then comes one letter more. After book 9 the steps are longer (3-4 books), after book 19 longer still (5). More wrong letters never come in the same step.
The smoke test (`_check_stairs`) keeps it that way.

| Book | Word length | Missing | Decoys | Gaps |
|---|---|---|---|---|
| 1 | 3–4 | 1 | 2 | shown |
| 2 | 4–5 | 1 | 2 | hidden |
| 3 | 4–6 | 1 | 3 | hidden |
| 4 | 4–5 | 2 | 3 | shown |
| 5 | 5–6 | 2 | 3 | shown |
| 6 | 5–6 | 2 | 3 | hidden |
| 7 | 5–7 | 2 | 4 | hidden |
| 8 | 6–7 | 3 | 3 | shown |
| 9 | 6–8 | 3 | 3 | shown |
| 10 | 6–7 | 3 | 3 | hidden |
| 11 | 6–7 | 3 | 3 | hidden |
| 12 | 6–8 | 3 | 3 | hidden |
| 13 | 7–8 | 3 | 3 | hidden |
| 14 | 8–9 | 4 | 3 | shown |
| 15 | 8–9 | 4 | 3 | shown |
| 16 | 8–10 | 4 | 4 | shown |
| 17 | 8–9 | 4 | 4 | hidden |
| 18 | 8–10 | 4 | 5 | hidden |
| 19 | 8–11 | 4 | 5 | hidden |
| 20 | 9–11 | 5 | 5 | shown |
| 21 | 9–11 | 5 | 5 | shown |
| 22 | 9–11 | 5 | 6 | shown |
| 23 | 9–12 | 5 | 6 | shown |
| 24 | 9–12 | 5 | 6 | shown |
| 25 | 9–11 | 5 | 6 | hidden |
| 26 | 9–11 | 5 | 6 | hidden |
| 27 | 9–12 | 5 | 6 | hidden |
| 28 | 9–13 | 5 | 7 | hidden |
| 29 | 9–14 | 5 | 7 | hidden |

Never more than 60 % of a word is missing.

## In play: the little frog
With *Hungry frog* a small frog sits in a circle beside the other pets (`scripts/pocket_frog.gd`). Click it and pay the reroll potions: it swallows
the word and the theme's name and coughs up another theme (with *Frog buffet*: 2-3 cards to choose from) for this level and the
ones after it. Finished levels keep their points. It costs no score, but help already used on the level counts.

## Roadmap
- [x] 1. Setup: Godot project, git, GitHub
- [x] 2. Rough prototype: word, slots, table letters, drag & drop, stir check
- [x] 3. Word list + difficulty 1–10 puzzle maker (first version, ~90 words)
- [x] 4. Game loop: 10 words per level, hints, wrong-answer effects
- [x] 5. Menus: title screen, level picker, pause menu, end-of-level screen
- [ ] 6. Cozy look: real art for the hut, cauldron, letters; nicer brew effects
- [x] 7a. Phone version, held sideways (layout C, `scripts/screen_layout.gd`): the same game; on a wider screen the things at the sides move outward,
  pets, letters and buttons are bigger, a dragged letter floats above the finger, a tap reads a spell. Second choice for later: A (upright, stacked).
- [ ] 7. Export, only when the game is done: Android and iPhone (Android needs export templates + Android tools; iPhone needs a Mac), maybe Windows .exe and web
- [ ] Later: perfect the hints Vision shows for each word (which pictures, in which order); no new drawings before that
- [ ] Later: sound and music, a larger dictionary for decoy checks
- **Shelves = spell book:** a leather book with a skill tree of spell medallions you can drag around.
  Everything radiates from the cauldron in the middle: animals above it (upgrades further out), potions and hourglass below; the themes on the right.
  Hover a spell to read it (in a strange tongue until learned; cost and requirements stay plain),
  hold the mouse on it to learn it: a gold ring fills and the words decipher. Keep holding and the next rank fills at the same pace, until it is full or the knowledge runs out.
  A spell shows as open (green ring, bright icon) as soon as it is unlocked, also before you have the knowledge; it pulses once you can pay.
  With too little knowledge the ring and the words stop part-way: 200 of 400 deciphers half.
  Spells that still need stars (or another spell first) only shake.

## Word themes
- 11 themes, about 120-170 words each (1520 words): Animals, Food & kitchen, Witchcraft & magic, Nature & weather,
  At home, Ocean & sea, Universe (was Space & sky), Body & feelings, School & words, Time & calendar, Alchemy.
  Ten more are ready but **parked** in `scripts/parked_themes.gd` while the game changes: Sports & games, Clothes & style,
  Jobs & work, Music & art, Travel & vehicles, Town & city, Farm & garden, Science & inventions, Party & holidays,
  Doctor & health (43 of their words are in Alchemy now). Every word is in exactly one theme (`scripts/game_data.gd`).
- **Books 20-29 are mixed** (and all mystery books, with the themes secret): every word has its own random theme (never the same twice in a row), so they start without the frog's
  theme screen. The little frog in play then changes only the current word.
- The theme is shown with its icon on a parchment sign above the cauldron.
- **The frog** (`scripts/theme_frog.gd`): whenever a book is opened (also *Play again* and *Next recipes*) a frog coughs up
  its theme in a cloud of magic dust; click the theme to start. With *Hungry frog* you can feed it: 2 Wisdom + 2 Vision potions, and it swallows the theme and coughs up another.
  The theme stays with the book until the book is brewed to the end (also in the save), so leaving is no free reroll.
  Themes shown longest ago come first, with some luck mixed in (`theme_order`, saved): one theme at a time, none comes back
  before 6 others were shown. Coughed up counts as shown, also if you didn't brew it. Unseen words give a slight preference.
- **Few repeats** (`scripts/word_dealer.gd`): words not seen yet come first, then the ones seen longest ago. Seen words are
  saved. Playing all 29 books once with rolled themes gives hardly any repeats (the test allows 1 %).
- Every theme needs at least 20 words that fit each book (so it can be brewed twice without a repeat). The smoke test
  fails if it hasn't, or if a word is in the list twice, or a meaning gives its word away.
- Pictures: only emoji up to version 13, so older Windows can show them.
- Testing: Ctrl+click the theme name = next theme, Alt+click = previous theme.
