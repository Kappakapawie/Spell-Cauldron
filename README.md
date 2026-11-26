# Spell Cauldron

A cozy spelling game made with **Godot 4**. A half-finished word floats in a witch's cauldron.
Drag the right letters from the table into the word, then stir the brew to see if you spelled it right.

## Play / run it
1. Open Godot 4, click **Import**, and pick `project.godot` in this folder.
2. Press **F5** (or the ▶ button, top right) to play.

Or double-click **Play Spell Cauldron.bat**. **Reset game** on the title screen starts over;
**Play Spell Cauldron (choose reset).bat** asks for it at every start. The old save is kept beside the new one as `save_before_reset_<time>.cfg`.

**Play Spell Cauldron (phone).bat** tries the phone version (held sideways) in a window. On a real phone it is chosen by itself.

## How to play
- **Drag** letters from the table into the word.
- **Stir** by swiping left across the brew with your mouse.
- **Wisdom / Vision** potions are unlocked by spelling WISDOM and VISION (theme Witchcraft & magic) and learning them in the Shelves. They show the meaning / pictures. Each can be bought once per missing letter; the last one shows everything.
- **Recipe books:** page 1 holds the 29 normal books; page 2 holds 20 **Mystery recipes**, easy to hard again, where every word has its own secret theme, told when the book is done.
- **Shelves** opens the spell book: hover a spell to read it, hold the mouse to learn it (keep holding for more ranks), drag to look around.
- **Themes** (on the right in the spell book): you start with two (Animals, Witchcraft & magic), the other nine cost 60 knowledge each, Time & calendar 200.
- **Stir** on the title screen (or press *Play*) and pick a book, brew recipes **1–29**. A frog picks its theme: click it to start (books 20-29 have a random theme for every word). With the frog spell you can feed it potions for another one.
- **A new game** starts with its first mission: spell FROG, then learn the frog for free in the Shelves.
- **Owl, cat, mouse, raven, chameleon, raccoon** (spells, learned after spelling their names): they help by themselves every so many seconds; click one to pause or wake it. Each book of recipes has ten levels (words).
- **Mouse** (spell): brings a random potion now and then while you brew.
- **Raccoon** (spell): steals a wrong letter from your table now and then.
- **Hourglass** (spell, after spelling HOURGLASS in the theme Time & calendar): one countdown for the whole book: brew as many levels as you can before the sand runs out, each one in time gives 1 extra star. A book's best guessing and best timing are added together. Slow sand (after spelling SLOW) gives more time. Golden sand (after spelling IMMEDIATELY) adds up to 5 more stars for a level, the quicker the more.
- **Little frog** (spell): click it while playing to swap the theme and the word you are on, for potions. Once per book, up to three times with Second helping.
- **Score:** a level solved without help is worth 1. Wisdom and Vision each take 0.5 off; the owl, cat and frog cost no score.
- **Menu** or **Esc** pauses the game; Esc also goes one screen back.

## Testing shortcuts
- **Ctrl+click** a value to fill it up / complete it, **Alt+click** to remove its progress:
  stars (on the recipe picker), a potion row (shelf or button), Knowledge (+1000 / 0), the "Level x / 10" counter
  (finish the book with a perfect 10 / restart it), and in the spell book: shelf spells, upgrade spells,
  and the cauldron in the middle of the tree (all books perfect / all stars cleared).

## Project layout
| Path | What it is |
|---|---|
| `scenes/main.tscn` | The game scene |
| `scripts/main.gd` | Game flow, drag & drop, stirring, hints, drawing, UI |
| `scripts/title_screen.gd`, `level_picker.gd`, `level_card.gd`, `pause_menu.gd`, `level_complete.gd`, `start_choice.gd` | The menu screens |
| `scripts/cat_paw.gd` | The cat's paw swipe and its claw marks |
| `scripts/raven_marks.gd` | The small red and black ravens over the word |
| `scripts/menu_kit.gd` | Shared buttons, labels and colors for the menus |
| `scripts/game_data.gd` | **Difficulty levels and the themed word lists (edit here to add words or themes)** |
| `scripts/sand_timer.gd` | The hourglass with its running sand |
| `scripts/theme_frog.gd` | The frog that swallows and coughs up themes |
| `scripts/word_dealer.gd` | Picks each book's words, with as few repeats as possible |
| `scripts/puzzle_maker.gd` | Picks missing letters and safe decoys |
| `scripts/letter_tile.gd`, `scripts/gap_slot.gd` | A letter tile, an empty gap |
| `scripts/screen_layout.gd` | The phone version: a wider screen, bigger things to touch |
| `scripts/potion_icon.gd` | Wisdom and Vision as round icons |
| `scripts/unlock_flight.gd` | The icon of something unlocked, flying to the Shelves button |
| `tools/prepare.bat` | Used by the launchers: imports the project on a new computer |
| `scripts/tutorial_note.gd` | The small messages of the first mission |
| `tests/smoke_test.gd` | Headless check (about 95 seconds): `godot --headless --fixed-fps 60 --path . --script res://tests/smoke_test.gd` (without `--fixed-fps 60` it plays in real time, 5-8 minutes) |

See [PLAN.md](PLAN.md) for the design decisions and the roadmap.
