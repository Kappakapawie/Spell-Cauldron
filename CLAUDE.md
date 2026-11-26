# Spell Cauldron – notes for Claude

A cozy spelling game in **Godot 4.7.2** (GDScript, GL Compatibility, base screen 1280 x 720). No plugins, no other dependencies.
[README.md](README.md) says how it is played, [PLAN.md](PLAN.md) holds every design decision and the roadmap. **Read PLAN.md before changing
how the game works, and keep it up to date:** it is the record of where work stopped.

## On a new computer
1. `git clone https://github.com/Kappakapawie/Spell-Cauldron.git`
2. Put Godot 4.7.2 (standard version, Windows: `Godot_v4.7.2-stable_win64.exe` **and** `..._console.exe`) in the folder **above** the project
   (or in it). Godot itself is not in git. The launchers also find `godot.exe` from winget or on the PATH, and without Godot they use SummerEngine (Godot with AI tools) from the same folders, its install folder or the PATH (`tools/find_godot.bat`).
3. Double-click `Play Spell Cauldron.bat`. The launchers import the project by themselves when needed (`tools/prepare.bat`).

Without the launchers, import once after cloning, and again after pulling or adding a script with a `class_name` or a picture.
Otherwise the game stops with "Identifier not declared": `godot --headless --path . --import`

- **`git pull` before starting work**: it may have been worked on from another computer. Commit and push when the user asks.
- The player's progress is **not** in git. It is on each computer: `%APPDATA%\Godot\app_userdata\Spell Cauldron\save.cfg`.

## Running and testing
`godot` below is the console version, e.g. `../Godot_v4.7.2-stable_win64_console.exe` (in Git Bash, from the project folder).

| What | How |
|---|---|
| Play | `Play Spell Cauldron.bat` |
| Phone version in a window | `Play Spell Cauldron (phone).bat` |
| Choose continue / reset first | `Play Spell Cauldron (choose reset).bat` |
| Smoke test (about 95 s) | `godot --headless --fixed-fps 60 --path . --script res://tests/smoke_test.gd` → `RESULT: PASS` |
| Word and picture overview | `python docs/make_icon_sheet.py` makes `docs/icon_sheet.html`. **Claude runs it and commits the page with every change to words, themes or spells**: the user only opens it, never runs it |

- **Small change = small check:** a short script or a screenshot of what was touched. The full smoke test is for changes to gameplay code,
  always with `--fixed-fps 60` (without it: 5-8 minutes) and a time limit of at least 280 s.
- **Never write the player's save.** In tests and screenshot scripts set `main.persist = false` before adding the scene. To try the real game or
  saving, point `APPDATA` at a temporary folder.
- Never kill Godot processes you did not start: the user often has the game or the editor open.
- Screenshots need a real window (not `--headless`): `--script` a small `SceneTree` script that saves `root.get_texture().get_image()`.
  Look at both the PC size and the phone size (`--resolution 1560x720 -- --phone`).
- Say in the reply what was and what wasn't checked.

## Where things are
- `scripts/main.gd`: nearly everything: game flow, screens, pets, upgrades, potions, input, drawing, save and load (sections marked `# -----`).
- `scripts/game_data.gd`: the 29 recipe books (`LEVELS`), the 20 mystery books (`MYSTERY_LIKE`, numbers 30-49; use `GameData.book(n)`, not `LEVELS[n - 1]`) and the 11 themes with their words (word, meaning, pictures).
- `scripts/parked_themes.gd`: ten more themes, parked until the game changes are done.
- `scripts/screen_layout.gd`: the phone layout. `scripts/spell_book.gd`: the Shelves (skill tree).
- `scripts/book_finale.gd`, `sand_out.gd`, `sand_timer.gd`, `level_complete.gd`: the end of a book and the hourglass.
- `art/pictures`: own drawings, used in the word list as `@name`. Other pictures are emoji, up to version 13.
- Every script starts with `##` lines that say what it is. Every script except `main.gd` has a `class_name`.

**Names:** a *book of brew recipes* is `level` / `LEVELS` in the code; the player's *level* is one word; *knowledge* is `score`.

## Rules that are easy to break
- Every new feature must also work in the **phone version**.
- A new kind of help goes in `HELPERS` and calls `_use_helper()`; `_check_helpers` in the test must learn it (see PLAN.md).
- Spells can be locked behind a word (`spell` in their upgrade entry): it has to be spelled in the game first. If the word is renamed or
  moved to another theme, the lock moves with it.
- Each word is in exactly one theme, its meaning must not give it away, and each theme needs at least 20 words for each book. The smoke test checks this.
- New saved values get a default in loading, so older saves keep working.
- `.bat` files keep Windows line endings (CRLF); all else is LF (`.gitattributes`).

## What the user wants
- **End every reply with the launchers**, each in its own `powershell` block, with the project's real folder on that computer, e.g.
  `& "C:\Claude\Spell-Cauldron-main\Play Spell Cauldron.bat"` and the same for `Play Spell Cauldron (phone).bat`.
  Don't start the game unasked. Where the game can't be run (a cloud session), say the changes must be pushed, then pulled on the PC.
- **No new drawings for now.** Later: perfect *which hints Vision shows* for each word, and in which order.
- **No Android or iPhone export**, and no downloads for it, until the game is done. Phone layout C (sideways) is in; A (upright) is the second choice.
- The ten parked themes stay parked. Knowledge per brewed word was declined: don't offer it again.
- Players: children on the easy books, adults on the hard ones. Windows first.
- Extra requests often arrive in the middle of work; do them in the same go.
- The repository is **public**: no private data, saves or keys in it.
