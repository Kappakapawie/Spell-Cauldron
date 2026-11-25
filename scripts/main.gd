extends Node2D

## Spell Cauldron - rough prototype.
## Everything is drawn with simple shapes so we can test how the game feels
## before spending time on art.

const BREW_GREEN := Color("63c56f")
const BREW_GOLD := Color("ffd45c")
const BREW_MURKY := Color("6b4f7a")

const WORD_CENTER := Vector2(640, 300)
const WORD_MAX_WIDTH := 680.0  ## long words get smaller letters, so they never reach the potions
const WORD_STEP := LetterTile.BUBBLE_RADIUS * 2.0 + 8.0
const TABLE_Y := 655.0
const TABLE_STEP := 86.0
const DROP_RADIUS := 64.0
const BREW_CENTER := Vector2(640, 380)   ## middle of the soup, seen from above
const BREW_RADIUS := Vector2(290, 115)
const PICTURE_CENTER := Vector2(640, 425)
const ENGRAVING_Y := 560.0
const STIR_SWIPE := 150.0  ## how far left (pixels) you swipe over the brew to stir

## Which screen is showing. The hut is drawn behind the title and the game;
## the pause menu, spell book and end-of-level screen open on top.
enum Screen { TITLE, LEVELS, FROG, PLAY }  # FROG: a book is open, its theme is being picked
var screen := Screen.TITLE

var level := 1
var theme := ""              ## the word theme of the book being brewed
## All themes, the one shown longest ago first. Coughed up counts as shown, brewed or not.
var theme_order: Array = []
## Themes: a new game knows two; the others are bought in the spell book, in any order and without stars.
const START_THEMES := ["Animals", "Witchcraft & magic"]  ## the pets' names are in these
const THEME_PRICE := 60
const THEME_PRICES := {"Time & calendar": 200}  ## the dearer ones: this one leads to the hourglass
const OLD_THEME_NAMES := {"Space & sky": "Universe"}  ## in older saves
var themes_owned: Array = START_THEMES.duplicate()
## Words that are in every book of their theme, whatever their length, until what they unlock is learned.
var always_words := {"Animals": ["owl", "cat"], "Witchcraft & magic": ["wisdom", "vision"], "Time & calendar": ["hourglass", "slow"],
	"Universe": ["moon"], "Body & feelings": ["eye"]}
const UNTIL_SPELLED := ["slow", "moon", "eye"]  ## these only until they are spelled once: what they unlock comes late
const THEME_LUCK := 3.0        ## how far luck can move a theme forward in that order
const REROLL_COST := 4         ## potions to feed the frog (half Wisdom, half Vision)
## book -> themes on offer. Kept until the book is brewed to the end, so going back and
## opening it again is no free reroll.
var book_offers := {}
var frog_uses := {}            ## book -> how often the frog was fed there since it was last brewed to the end
var frog: ThemeFrog
var pocket_frog: PocketFrog   ## the little frog beside the cauldron, while playing
var swapping := false         ## it is eating the word and coughing up a new theme
var theme_cards: Control      ## the themes it coughed up, when there is a choice
var theme_hint: Label
var dealer := WordDealer.new()  ## picks each book's words, with as few repeats as possible
var theme_label: Label
var word_number := 0
var session_words: Array = []
var session_themes: Array = []  ## the theme of each of those words (all the same, unless the book is mixed)
var puzzle: Dictionary = {}
var round_id := 0  ## changes every new word, so old animations know to stop

var row: Array[Node2D] = []        ## the word in the cauldron, left to right
var tiles: Array[LetterTile] = []  ## every movable letter (on table or placed)
var row_step := WORD_STEP
var row_scale := 1.0

var dragged: LetterTile = null
var drag_offset := Vector2.ZERO
var busy := false

var pointer := Vector2.ZERO    ## the last place of the mouse or the finger
var stirring := false
var stir_start := Vector2.ZERO
var stir_last_x := 0.0
var swirl_angle := 0.0:
	set(value):
		swirl_angle = value
		queue_redraw()
var brew_color: Color = BREW_GREEN:
	set(value):
		brew_color = value
		if bubbles:
			bubbles.color = value.lightened(0.35)
		queue_redraw()

var pieces: Node2D
var insert_marker: Marker
var swirl_tween: Tween
var brew_tween: Tween
var bubbles: CPUParticles2D
var sparkles: CPUParticles2D
var smoke: CPUParticles2D

var picture_alphas: Array[float] = []  ## for each picture in the brew: 0 = hidden, 1 = shown
var picture_tween: Tween

## Potion stock. Earned by brewing words, spent on the Wisdom / Vision buttons.
var potions := {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
var wisdom_level := 0      ## Wisdom potions drunk for this word (max _wisdom_steps())
var wisdom_order: Array = []  ## order in which the meaning's words get revealed
var vision_level := 0      ## Vision potions drunk for this word (max _vision_steps())

## Every way of getting help with a word. A word is worth 1 point, shared evenly between all
## helpers here: each one used takes 1 / HELPERS.size() off, so using them all leaves 0.
## A NEW KIND OF HELP: add it here and call _use_helper() when it helps. Nothing else to change.
## The pets (owl, cat, frog) are not in it: they cost no score, only time or potions.
const HELPERS: Array[String] = ["wisdom", "vision"]
var helpers_used := {}     ## helpers used on this word (however often): name -> true
var plain_points := 0.0    ## points for guessing in the current run (perfect = level_max(): no help on any word)
var time_points := 0.0     ## points for words brewed in time in the current run (hourglass spell)
## level (recipe book) -> {"best", "plain", "time": float, "conquered": bool}
## plain and time are the best of all runs, each on its own; best = both added together.
var level_records := {}
var word_results: Array = []  ## this run's brewed words: {word, picture, points}
const SAVE_PATH := "user://save.cfg"
var persist := true        ## false in tests, so they never touch the player's save
var incoming := {}         ## kind -> reward potions still flying to their shelf
var shelves := {}          ## kind -> PotionShelf
var potion_buttons := {}   ## kind -> Button
var potion_tips := {}          ## kind -> what its button says when it can be drunk
var cost_icons := {}       ## kind -> CostIcons on that button
var emoji_font: SystemFont
var engrave_font: FontVariation
var spoon: Spoon

var progress_label: Label
var thought: ThoughtCloud   ## the Wisdom hint, floating above the cauldron
var score_label: Label

const START_SLOTS := 3        ## potions of one kind a shelf holds at first
const MAX_SLOTS := 10         ## the most a shelf can be upgraded to
const POINTS_PER_POTION := 10 ## every potion earned beyond a full shelf becomes points
var shelf_slots := {PotionArt.WISDOM: START_SLOTS, PotionArt.VISION: START_SLOTS}
var shop_panel: SpellBook     ## the Shelves menu: a spell book with a skill tree

## Star upgrades: unlocked by your total stars (sum of the best scores, max 290 with 29 x 10 words, 580 with the hourglass),
## then bought with score points in the Shelves menu.
## Every spell has ranks; each rank costs more: price = base * growth^rank (rounded to 10).
## "needs" = another spell that must be learned first.
const UPGRADES := [
	{"id": "wisdom", "name": "Wisdom potion", "stars": 0, "base": 0, "growth": 1.0, "max": 1, "spell": "wisdom",
		"desc": "Lets you drink Wisdom potions: they tell you what the word means."},
	{"id": "vision", "name": "Vision potion", "stars": 0, "base": 0, "growth": 1.0, "max": 1, "spell": "vision",
		"desc": "Lets you drink Vision potions: they show you pictures of the word in the brew."},
	{"id": "hourglass", "name": "Enchanted hourglass", "stars": 30, "base": 150, "growth": 1.0, "max": 1, "spell": "hourglass",
		"desc": "Brew a level before the sand runs out for 1 extra star, however much help you used. If it runs out once, it stays empty for the rest of the book. Your best guessing and best timing are added together."},
	{"id": "more_sand", "name": "Slow sand", "stars": 30, "base": 120, "growth": 1.5, "max": 5, "spell": "slow",
		"needs": "hourglass", "desc": "The hourglass gives you 25% more time for every level per rank."},
	{"id": "golden_sand", "name": "Golden sand", "stars": 60, "base": 600, "growth": 1.0, "max": 1, "spell": "immediately",
		"needs": "hourglass", "desc": "The quicker you brew a level, the more extra stars: up to 5 while the hourglass is almost full, fewer the more sand is gone. They come on top of the hourglass's own star."},
	{"id": "discount", "name": "Potion discount", "stars": 20, "base": 80, "growth": 2.0, "max": 2, "spell": "orchard",
		"desc": "Every drink costs 1 potion less per rank (never below 1)."},
	{"id": "sage", "name": "Whispering sage", "stars": 30, "base": 150, "growth": 2.0, "max": 2,
		"needs": "wisdom", "desc": "Each rank: the full meaning takes one Wisdom potion fewer."},
	{"id": "sight", "name": "Clear sight", "stars": 30, "base": 150, "growth": 2.0, "max": 2, "spell": "kettle",
		"needs": "vision", "desc": "Each rank: all pictures are shown one Vision potion sooner."},
	{"id": "frog", "name": "Hungry frog", "stars": 0, "base": 0, "growth": 1.0, "max": 1, "spell": "frog",
		"desc": "Once in every book you can feed the frog potions: it swallows the theme and coughs up another one. Click the little frog to do it while you play."},
	{"id": "frog_more", "name": "Second helping", "stars": 20, "base": 70, "growth": 1.8, "max": 2,
		"needs": "frog", "desc": "The frog can be fed one more time per rank in every book."},
	{"id": "frog_choice", "name": "Frog buffet", "stars": 40, "base": 90, "growth": 2.0, "max": 2,
		"needs": "frog", "desc": "The frog coughs up one more theme per rank, and you choose the one you like."},
	{"id": "frog_cheap", "name": "Frog snacks", "stars": 30, "base": 50, "growth": 1.6, "max": 3,
		"needs": "frog", "desc": "Feeding the frog for another theme costs 1 potion less per rank."},
	{"id": "familiar", "name": "Owl familiar", "stars": 10, "base": 50, "growth": 1.0, "max": 1, "spell": "owl",
		"desc": "Every 20 seconds the owl points out a letter that is surely in the word. Click the owl to pause it."},
	{"id": "owl_speed", "name": "Swift wings", "stars": 10, "base": 30, "growth": 1.25, "max": 10,
		"needs": "familiar", "desc": "The owl is 1 second quicker per rank."},
	{"id": "owl_all", "name": "Full moon", "stars": 40, "base": 100, "growth": 1.5, "max": 5, "spell": "moon",
		"needs": "familiar", "desc": "Whenever the owl helps, there is a chance that it points out ALL the letters the word needs: 2% per rank."},
	{"id": "cat", "name": "Cat familiar", "stars": 15, "base": 80, "growth": 1.0, "max": 1, "spell": "cat",
		"desc": "Every 8 seconds the cat's paw opens a space where a letter is missing (hidden gaps only). Click the cat to pause it."},
	{"id": "cat_speed", "name": "Quick paws", "stars": 15, "base": 40, "growth": 1.25, "max": 10, "spell": "curious",
		"needs": "cat", "desc": "The cat is 0.5 seconds quicker per rank."},
	{"id": "raven", "name": "Raven familiar", "stars": 40, "base": 100, "growth": 1.0, "max": 1, "spell": "raven",
		"needs": "cat", "desc": "Every 20 seconds a small raven settles over an empty space you can see, shown or opened by the cat: red = a vowel belongs there, black = a consonant. Click the raven to pause it."},
	{"id": "mouse", "name": "Kitchen mouse", "stars": 25, "base": 120, "growth": 1.0, "max": 1, "spell": "mouse",
		"desc": "The mouse brings you a random potion every 30 seconds while you brew. When both shelves are full it becomes knowledge. Click the mouse to pause it."},
	{"id": "mouse_speed", "name": "Cheese", "stars": 25, "base": 120, "growth": 1.5, "max": 5, "spell": "cheese",
		"needs": "mouse", "desc": "The mouse is 5 seconds quicker per rank, up to a potion every 5 seconds."},
	{"id": "raven_speed", "name": "Keen eyes", "stars": 40, "base": 45, "growth": 1.25, "max": 10, "spell": "eye",
		"needs": "raven", "desc": "The raven is 1 second quicker per rank."},
	{"id": "chameleon", "name": "Chameleon", "stars": 55, "base": 170, "growth": 1.0, "max": 1, "spell": "chameleon",
		"desc": "When it is charged, it shows whether the next letter you let go of is in the right place: green or red. It charges again in 10 seconds. Click the chameleon to pause it."},
	{"id": "chameleon_speed", "name": "Quick colors", "stars": 55, "base": 60, "growth": 1.3, "max": 8,
		"needs": "chameleon", "desc": "The chameleon charges 1 second quicker per rank."},
	{"id": "raccoon", "name": "Raccoon", "stars": 70, "base": 220, "growth": 1.0, "max": 1, "spell": "raccoon",
		"desc": "Every 20 seconds the raccoon steals a wrong letter from your table. Click the raccoon to pause it."},
	{"id": "raccoon_speed", "name": "Sneaky paws", "stars": 70, "base": 60, "growth": 1.25, "max": 10,
		"needs": "raccoon", "desc": "The raccoon is 1 second quicker per rank."},
	{"id": "hallucination", "name": "Hallucination", "stars": 40, "base": 100, "growth": 1.5, "max": 5, "spell": "condense",
		"desc": "At the start of a word there is a chance of a free Vision, without a potion and without losing stars: 10% per rank."},
	{"id": "lucky", "name": "Your cauldron", "stars": 80, "base": 150, "growth": 1.7, "max": 3,
		"desc": "Every brewed word gives 1 extra potion per rank."},
]
## The hourglass spell: points for a level (word) brewed before the sand runs out, help or no help.
const TIME_POINT := 1.0
const SAND_BASE := 12.0        ## seconds for any word...
const SAND_PER_LETTER := 9.0   ## ...more for every missing letter...
const SAND_HIDDEN := 6.0       ## ...and more when the gaps are hidden
const SAND_RANK := 0.25        ## share of that time extra per Slow sand rank
var sand_timer: SandTimer
var sand_out: SandOut
var sand_fails := 0            ## how often it ran out, ever: the first times it is shown big
var sand_lost := false         ## it ran out once in this book: no more stars for time until the next run
const FAMILIAR_BASE_INTERVAL := 20.0
const FAMILIAR_SPEEDUP := 1.0
## The pets stand together left of the cauldron.
var familiar_pos := Vector2(58, 326)
var raven_pos := Vector2(58, 424)
var raccoon_pos := Vector2(254, 424)
const RACCOON_INTERVAL := 20.0
const RACCOON_SPEEDUP := 1.0
var chameleon_pos := Vector2(156, 424)
const CHAMELEON_INTERVAL := 10.0
const CHAMELEON_SPEEDUP := 1.0
var chameleon_flash := 0.0    ## seconds its verdict still shows on itself
var chameleon_right := false
const RAVEN_INTERVAL := 20.0
const RAVEN_SPEEDUP := 1.0
var mouse_pos := Vector2(254, 326)
const OWL_ALL_CHANCE := 0.02       ## that the owl shows all letters at once, per rank
const HALLUCINATION_CHANCE := 0.1  ## of a free Vision at the start of a word, per rank
const MOUSE_INTERVAL := 30.0
const MOUSE_SPEEDUP := 5.0
var mouse_time := 0.0         ## seconds since the mouse brought its last potion
var owned_upgrades := {}      ## upgrade id -> rank (0 = not learned)
var potions_known := {PotionArt.WISDOM: false, PotionArt.VISION: false}  ## learned, so they can be drunk
## The owl, the cat and the raven help by themselves, each after its own cooldown, one letter or spot at a
## time; their upgrades only make them quicker. A click on a pet pauses it (it keeps its progress) or wakes it.
var pet_time := {"familiar": 0.0, "cat": 0.0, "raven": 0.0, "chameleon": 0.0, "raccoon": 0.0}  ## seconds since each last helped
var pets_paused := {}         ## pet -> true
var spelled := {}             ## words brewed at least once: only the pet names are kept
var new_names: Array = []     ## pets whose name was spelled for the first time in this run
var word_age := 0.0           ## seconds this word is in the cauldron
const PET_PATIENCE := 1.5     ## pets wait this long before they help with a new word
const CAT_BASE_INTERVAL := 8.0    ## much quicker than the raven, which also tells vowel or consonant
const CAT_SPEEDUP := 0.5
var cat_pos := Vector2(156, 326)
var frog_pos := Vector2(156, 524)
const SPLIT_ROOM := 0.75      ## how far the cat pushes letters apart (1 = a whole letter)
var cat_aims := {}            ## gap -> how many paws are on their way to it
var cat_splits := {}          ## spaces the cat opened: gap (number of given letters before it) -> how many
var claws: CatPaw.ClawMarks
var raven_marks: RavenMarks
var raven_spots := {}         ## missing letters the raven points at: index in the word -> seconds shown (-1: on its way)
var raven_at := {}            ## where those pointers are now
var spot_gaps: Array[int] = []  ## which gap each of the claw marks is in
const START_KNOWLEDGE := 100    ## what a new game begins with
var score := START_KNOWLEDGE                ## "Knowledge" to the player: spent on spells and shelves
var score_incoming := 0       ## points still flying to the score counter

var hud: Control              ## everything shown only while playing a level
var level_label: Label
var hud_star: LevelStar       ## best result of the level being played
var title_screen: TitleScreen
var picker: LevelPicker
var pause_menu: PauseMenu
## The first steps of a new game: spell FROG in book 1, learn the frog (free, and nothing else can be learned
## before it), then feed it once for free. Kept in the save; DONE for everyone who played before.
enum Tutorial { SPELL, LEARN, USE, DONE }
const FIRST_WORD := "frog"
const FIRST_THEME := "Animals"
var tutorial := Tutorial.SPELL
var tutorial_note: TutorialNote
var use_note_seen := false  ## a word was brewed since the frog was learned: no more message about it
var shop_button: Button
var ui_layer: CanvasLayer
var turn_hint: Label  ## on a phone held upright
var open_spells := {}          ## spells that could be learned (or are) at the last look
var unlock_queue: Array = []   ## what was unlocked and not shown yet: {icon, text}
var unlock_wait := 0.0         ## seconds until the next one may be shown
var unlock_layer: Control
var stir_tip: Label
var start_choice: StartChoice  ## reset the game?
static var _choice_made := false  ## the scene is loaded again after a reset: don't ask twice
var complete_panel: LevelComplete


func _ready() -> void:
	ScreenLayout.phone = ScreenLayout.detect()
	if ScreenLayout.phone:
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_fit_screen()
	_place_pets()
	get_window().size_changed.connect(_fit_screen)
	var dot := _make_soft_circle(32)
	bubbles = _make_bubbles(dot)
	claws = CatPaw.ClawMarks.new()
	add_child(claws)
	pocket_frog = PocketFrog.new()
	pocket_frog.position = frog_pos
	pocket_frog.scale = Vector2.ONE * ScreenLayout.icons()
	pocket_frog.visible = false
	add_child(pocket_frog)
	pieces = Node2D.new()
	add_child(pieces)
	raven_marks = RavenMarks.new()
	add_child(raven_marks)
	insert_marker = Marker.new()
	insert_marker.color = Color(1, 0.95, 0.75, 0.95)
	insert_marker.visible = false
	add_child(insert_marker)
	sparkles = _make_sparkles(dot)
	smoke = _make_smoke(dot)
	spoon = Spoon.new()
	spoon.visible = false
	add_child(spoon)
	emoji_font = SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
	engrave_font = FontVariation.new()
	engrave_font.base_font = ThemeDB.fallback_font
	engrave_font.variation_embolden = 0.9
	engrave_font.spacing_glyph = 4
	_load_game()
	theme = themes_owned.pick_random()
	_build_ui()
	_find_unlocks(false)
	_show_screen(Screen.TITLE)
	if "--ask-reset" in OS.get_cmdline_user_args() and not _choice_made and FileAccess.file_exists(SAVE_PATH):
		_choice_made = true
		start_choice.open(total_stars(), score)


## Keeps the 1280 x 720 of the game in the middle of a wider screen.
func _fit_screen() -> void:
	if not is_inside_tree():
		return
	ScreenLayout.measure(get_viewport().get_visible_rect().size)
	get_viewport().canvas_transform = Transform2D(0.0, ScreenLayout.extra)
	if ui_layer:
		ui_layer.offset = ScreenLayout.extra
	if turn_hint:
		var view := get_viewport().get_visible_rect().size
		turn_hint.visible = ScreenLayout.phone and view.y > view.x


## The pets stand left of the cauldron: further out, bigger and further apart on a phone.
func _place_pets() -> void:
	if not ScreenLayout.roomy():
		return
	var left := 64.0 - ScreenLayout.edge()
	var step := Vector2(127, 150)
	var spots: Array[Vector2] = []
	for i in 9:
		spots.append(Vector2(left, 152) + Vector2(i % 3, i / 3) * step)
	familiar_pos = spots[0]
	cat_pos = spots[1]
	mouse_pos = spots[2]
	raven_pos = spots[3]
	chameleon_pos = spots[4]
	raccoon_pos = spots[5]
	frog_pos = spots[7] + Vector2(0, 4)


## The back gesture of a phone does what Esc does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if screen == Screen.TITLE and not shop_panel.visible and not start_choice.visible:
			get_tree().quit()
		else:
			var esc := InputEventAction.new()
			esc.action = "ui_cancel"
			esc.pressed = true
			Input.parse_input_event(esc)


## Puts the save aside and begins again as if the game was never played.
func _reset_game() -> void:
	if not _move_save_away():
		start_choice.show_problem("The old save could not be put aside,
so nothing was reset.")
		return
	persist = false  # nothing of the old game is written any more
	start_choice.close()
	get_tree().reload_current_scene()


## The save becomes a backup next to it, named after the time, so an earlier backup is never overwritten.
func _move_save_away() -> bool:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return true  # nothing to keep (tests never touch the save)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var backup := "user://save_before_reset_%s.cfg" % stamp
	return not FileAccess.file_exists(backup) and DirAccess.rename_absolute(SAVE_PATH, backup) == OK


func _process(delta: float) -> void:
	queue_redraw()  # keeps the brew, picture and engraving alive
	if stirring:
		spoon.position = pointer
	_run_pets(delta)
	_run_mouse(delta)
	pocket_frog.visible = screen == Screen.PLAY and rank_of("frog") > 0
	pocket_frog.awake = not busy
	_run_sand(delta)
	_run_tutorial()
	_run_unlocks(delta)
	claws.visible = not busy
	_update_raven_marks(delta)


# ---------------------------------------------------------------- something new is unlocked

## Looks for spells that can be learned now and could not before. What opens while you look at the spell
## book needs no announcement: you see it there.
func _find_unlocks(announce: bool) -> void:
	for u in UPGRADES:
		var open: bool = rank_of(u.id) > 0 or _upgrade_lock_reason(u.id) == ""
		if open and not open_spells.has(u.id) and announce and rank_of(u.id) == 0:
			_announce(u.id, "%s unlocked!" % u.name)
		if open:
			open_spells[u.id] = true
		else:
			open_spells.erase(u.id)


func _announce(id: String, text: String) -> void:
	for n in SKILL_TREE:
		if n.id == id or (n.id == "root" and id == ROOT_UPGRADE):
			unlock_queue.append({"icon": n.icon, "text": text})


## Shows what was unlocked, one after the other: its icon flies into the button of the spell book.
func _run_unlocks(delta: float) -> void:
	_find_unlocks(not shop_panel.visible)
	unlock_wait = maxf(0.0, unlock_wait - delta)
	if unlock_queue.is_empty() or unlock_wait > 0.0 or shop_panel.visible or complete_panel.visible or swapping:
		return
	var button: Button = {Screen.PLAY: shop_button, Screen.LEVELS: picker.book_button}.get(screen)
	if button == null:
		return
	var what: Dictionary = unlock_queue.pop_front()
	var flight := UnlockFlight.new()
	flight.icon = what.icon
	flight.text = what.text
	flight.emoji_font = emoji_font
	unlock_layer.add_child(flight)
	flight.start(Vector2(640, 390), button)
	unlock_wait = UnlockFlight.POP_TIME + UnlockFlight.SHOW_TIME + 0.25


# ---------------------------------------------------------------- the first mission

func _run_tutorial() -> void:
	if tutorial == Tutorial.DONE:
		tutorial_note.say("")
		return
	if tutorial == Tutorial.SPELL and spelled.has(FIRST_WORD):
		_set_tutorial(Tutorial.LEARN)
	if tutorial < Tutorial.USE and rank_of("frog") > 0:
		_set_tutorial(Tutorial.USE)
		_update_potion_ui()  # its first meal is free
	stir_tip.visible = not _must_learn()
	var note_size := Vector2(340, 190) if ScreenLayout.roomy() else Vector2(264, 160)
	if screen != Screen.PLAY or shop_panel.visible or complete_panel.visible or puzzle.is_empty() or swapping:
		tutorial_note.say("")
	elif tutorial == Tutorial.SPELL and not busy:
		tutorial_note.say("Your first mission: spell FROG!\n\nDrag the missing letter into the word, then stir the pot.",
			Rect2(Vector2(24 - ScreenLayout.edge(), ScreenLayout.pick(330, 250)), note_size), Vector2(318, 330))
	elif _must_learn() and not busy:
		tutorial_note.say("You spelled FROG, so you can unlock the frog!\n\nOpen the Shelves and learn it. It is free.",
			Rect2(940 + ScreenLayout.edge(), 488, 336, 164) if ScreenLayout.roomy() else Rect2(1000 + ScreenLayout.edge(), 458, 260, 134), shop_button.get_global_rect().get_center() + Vector2(0, shop_button.size.y * 0.5 + 4))
	elif tutorial == Tutorial.USE and not use_note_seen:
		tutorial_note.say(ScreenLayout.say("The frog is yours, now you can use it!\n\nClick it to swap this word and its theme, once in every book. The first meal is free."),
			Rect2(Vector2(24 - ScreenLayout.edge(), frog_pos.y - 44 * ScreenLayout.icons() - 20 - note_size.y), note_size), frog_pos + Vector2(0, -44 * ScreenLayout.icons()))
	else:
		tutorial_note.say("")


func _set_tutorial(step: Tutorial) -> void:
	tutorial = step
	_save_game()


## FROG was spelled: the game waits for you to learn the frog.
func _must_learn() -> bool:
	return tutorial == Tutorial.LEARN and screen == Screen.PLAY


## Play on the title: a new game goes straight to its first word.
func _play() -> void:
	if tutorial == Tutorial.SPELL:
		_open_book(1)
	else:
		_show_screen(Screen.LEVELS)


## What the spell book says at the foot of the page during the first mission ("" = its usual line).
func book_tip() -> String:
	if tutorial == Tutorial.LEARN:
		return ScreenLayout.say("Hold the mouse on the frog to learn it. It is free!")
	if tutorial == Tutorial.USE and not use_note_seen:
		return "You learned the frog! Close the book: now you can use it."
	return ""


## The spell the book points a finger at ("" = none).
func book_points_at() -> String:
	return "frog" if tutorial == Tutorial.LEARN else ""


# ---------------------------------------------------------------- screens

func _show_screen(s: Screen) -> void:
	pause_menu.close()
	if s != screen:
		for f in unlock_layer.get_children():
			f.queue_free()
	screen = s
	sand_out.stop()
	complete_panel.visible = false
	shop_panel.close_book()
	if screen != Screen.PLAY:
		_clear_word()
	title_screen.visible = screen == Screen.TITLE
	picker.visible = screen == Screen.LEVELS
	if screen != Screen.FROG:
		frog.close()
	hud.visible = screen == Screen.PLAY
	_update_level_stars()


func _open_pause() -> void:
	if screen != Screen.PLAY or complete_panel.visible or shop_panel.visible:
		return
	if dragged:
		_drop()
	_stop_stirring()
	pause_menu.open(word_results.size())


## Esc: close the book, pause the level, or go one screen back.
func _go_back() -> void:
	if shop_panel.visible:
		shop_panel.close_book()
	elif complete_panel.visible:
		_show_screen(Screen.LEVELS)
	elif screen == Screen.PLAY:
		_open_pause()
	elif screen == Screen.FROG:
		_show_screen(Screen.LEVELS)
	elif screen == Screen.LEVELS:
		_show_screen(Screen.TITLE)


## Stirring the cauldron on the title screen opens the level picker.
func _stir_title() -> void:
	busy = true
	var id := round_id
	sparkles.position = BREW_CENTER
	_burst(sparkles)
	brew_tween = create_tween()
	brew_tween.tween_property(self, "brew_color", BREW_GOLD, 0.3)
	swirl_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swirl_tween.tween_property(self, "swirl_angle", swirl_angle - TAU, 0.9)
	await swirl_tween.finished
	if id == round_id:
		_play()


# ---------------------------------------------------------------- Ctrl / Alt shortcuts

## Ctrl+click (fill = true) fills up or completes the value under the mouse;
## Alt+click (fill = false) removes its progress. Returns true if something was hit.
func _cheat_click(p: Vector2, fill: bool) -> bool:
	var hit := false
	if shop_panel.visible:
		# Spell book: shelf spells, upgrade spells, and the cauldron in the middle (all stars).
		var id := shop_panel.node_at(p)
		if id == "root":
			for n in range(1, GameData.LEVELS.size() + 1):
				if fill:
					level_records[n] = {"best": float(GameData.word_count(n)), "conquered": true}
				else:
					level_records.erase(n)
			hit = true
		elif id == "wisdom_shelf" or id == "vision_shelf":
			var kind := PotionArt.WISDOM if id == "wisdom_shelf" else PotionArt.VISION
			shelf_slots[kind] = MAX_SLOTS if fill else START_SLOTS
			potions[kind] = mini(potions[kind], shelf_slots[kind])
			hit = true
		elif id == "themes":
			themes_owned = GameData.THEMES.keys() if fill else START_THEMES.duplicate()
			hit = true
		elif _theme_of(id) != "":
			var t := _theme_of(id)
			if not (t in START_THEMES):
				themes_owned.erase(t)
				if fill:
					themes_owned.append(t)
			hit = true
		elif id != "":
			if fill:
				_set_rank(id, int(_upgrade_info(id).max))  # top rank
			else:
				_set_rank(id, 0)
			hit = true
	elif screen == Screen.LEVELS:
		# Stars on the picker (the whole book card).
		var n := picker.level_at(p)
		if n > 0:
			if fill:
				level_records[n] = {"best": float(GameData.word_count(n)), "conquered": true}
			else:
				level_records.erase(n)
			hit = true
	elif screen == Screen.PLAY and not complete_panel.visible:
		# Potion rows: the shelf of flasks and its button.
		for kind in shelves:
			if ((shelves[kind] as Control).get_parent() as Control).get_global_rect().has_point(p):
				potions[kind] = shelf_slots[kind] if fill else 0
				incoming[kind] = 0
				hit = true
		if theme_label.get_global_rect().has_point(p):
			# Testing: Ctrl = next theme, Alt = previous theme, then the level starts over.
			var names: Array = themes_owned
			var i := names.find(theme)
			theme = names[(i + (1 if fill else -1) + names.size()) % names.size()]
			_start_level(level)
			hit = true
		if score_label.get_global_rect().has_point(p):
			score = score + 1000 if fill else 0
			score_incoming = 0
			hit = true
		if progress_label.get_global_rect().has_point(p):
			if fill:
				plain_points = float(level_max())
				time_points = 0.0
				word_results = []
				for e in session_words:
					word_results.append({"word": String(e[0]).to_upper(), "picture": GameData.pictures(e)[0], "points": 1.0, "fast": false, "time": 0.0})
				_show_level_complete()  # finish the level with full marks
			else:
				_start_level(level)  # start the level over
			hit = true
	if not hit:
		return false
	var fx := sparkles if fill else smoke
	fx.position = p
	_burst(fx)
	_save_game()
	_update_level_stars()
	_update_potion_ui()
	if shop_panel.visible:
		_update_shop()
	return true


# ---------------------------------------------------------------- owl and cat familiars

## Seconds between the owl's helps: 20, minus 1 per Swift wings rank.
func familiar_interval() -> float:
	return FAMILIAR_BASE_INTERVAL - FAMILIAR_SPEEDUP * rank_of("owl_speed")


## Seconds between the cat's helps: 8, minus 0.5 per Quick paws rank.
func cat_interval() -> float:
	return CAT_BASE_INTERVAL - CAT_SPEEDUP * rank_of("cat_speed")


func pet_interval(id: String) -> float:
	if id == "raven":
		return RAVEN_INTERVAL - RAVEN_SPEEDUP * rank_of("raven_speed")
	if id == "raccoon":
		return RACCOON_INTERVAL - RACCOON_SPEEDUP * rank_of("raccoon_speed")
	if id == "chameleon":
		return CHAMELEON_INTERVAL - CHAMELEON_SPEEDUP * rank_of("chameleon_speed")
	return familiar_interval() if id == "familiar" else cat_interval()


## Seconds for the current word.
func sand_time() -> float:
	var seconds: float = SAND_BASE + SAND_PER_LETTER * puzzle.missing.size() + (0.0 if puzzle.gaps_visible else SAND_HIDDEN)
	return seconds * (1.0 + SAND_RANK * rank_of("more_sand"))


## Was the word brewed before the sand ran out?
func in_time() -> bool:
	return rank_of("hourglass") > 0 and sand_timer.left > 0.0


## The sand only runs while you can play: not while stirring, in the spell book or paused.
func _run_sand(delta: float) -> void:
	sand_timer.visible = rank_of("hourglass") > 0
	sand_timer.golden = rank_of("golden_sand") > 0
	sand_timer.running = sand_timer.visible and screen == Screen.PLAY and not puzzle.is_empty() and not busy \
		and not complete_panel.visible and not shop_panel.visible
	if sand_timer.running:
		sand_timer.left = maxf(0.0, sand_timer.left - delta)
		if sand_timer.left <= 0.0 and not sand_lost:
			sand_lost = true
			sand_fails += 1
			if sand_fails <= SandOut.SHOWS:
				sand_out.start(sand_timer)
				_save_game()


## Are the pets at work at all? Only while a book is being brewed.
func _pets_at_work() -> bool:
	return screen == Screen.PLAY and not puzzle.is_empty() and not complete_panel.visible and not shop_panel.visible


## The cooldowns run on from word to word. A pet that is ready helps as soon as it can do something
## and you are not just moving a letter or stirring.
func _run_pets(delta: float) -> void:
	if not _pets_at_work():
		return
	word_age += delta
	chameleon_flash = maxf(0.0, chameleon_flash - delta)
	for id in pet_time:
		if rank_of(id) == 0 or pets_paused.get(id, false):
			continue
		pet_time[id] = minf(pet_time[id] + delta, pet_interval(id))
		if id == "chameleon":
			continue  # it waits for a letter, see _chameleon_look()
		if pet_time[id] >= pet_interval(id) and word_age >= PET_PATIENCE and dragged == null and not stirring:
			if _pet_help(id):
				pet_time[id] = 0.0


## Seconds between the mouse's potions: 30, minus 5 per Cheese rank.
func mouse_interval() -> float:
	return MOUSE_INTERVAL - MOUSE_SPEEDUP * rank_of("mouse_speed")


## The mouse is only busy while a book is being brewed. A potion for a full shelf goes to the other one;
## when both are full it turns into knowledge.
func _run_mouse(delta: float) -> void:
	if rank_of("mouse") == 0 or pets_paused.get("mouse", false) or not _pets_at_work():
		return
	mouse_time += delta
	if mouse_time < mouse_interval():
		return
	mouse_time = 0.0
	var kinds := [PotionArt.WISDOM, PotionArt.VISION]
	var room: Array = kinds.filter(func(k: String) -> bool: return potions[k] < shelf_slots[k])
	_bring_potion((kinds if room.is_empty() else room).pick_random(), mouse_pos, 0.0)
	_save_game()
	_update_potion_ui()


## Could the owl or the cat do anything for this word now?
func _can_help(id: String) -> bool:
	if puzzle.is_empty():
		return false
	if id == "familiar":
		return _familiar_next_tile() != null
	if id == "raven":
		return not _raven_free().is_empty()
	if id == "raccoon":
		return not _wrong_on_table().is_empty()
	return not _cat_free_gaps().is_empty()


## The pet helps once, if it can.
func _pet_help(id: String) -> bool:
	if rank_of(id) == 0 or busy or complete_panel.visible or not _can_help(id):
		return false
	if id == "familiar":
		_familiar_reveal()
		if randf() < OWL_ALL_CHANCE * rank_of("owl_all"):
			while _familiar_next_tile() != null:
				_familiar_reveal()
	elif id == "raven":
		_raven_fly(_raven_free().pick_random())
	elif id == "raccoon":
		_raccoon_steal(_wrong_on_table().pick_random())
	else:
		_cat_swipe(_cat_free_gaps().pick_random())
	return true


## Letters on the table that are not in the word at all. Decoys never share a letter with the missing ones.
func _wrong_on_table() -> Array:
	var word: String = puzzle.word
	var needed := {}
	for i in puzzle.missing:
		needed[word[i]] = true
	return tiles.filter(func(t: LetterTile) -> bool: return not t.in_word and t != dragged and not needed.has(t.letter))


## The raccoon runs to the letter, grabs it and takes it home.
func _raccoon_steal(t: LetterTile) -> void:
	tiles.erase(t)  # gone for you from now on
	_kill_tween(t)
	var thief := EmojiSprite.new()
	thief.emoji = "🦝"
	thief.font = emoji_font
	thief.position = raccoon_pos
	pieces.add_child(thief)
	var tw := thief.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(thief, "position", t.position + Vector2(0, -34), 0.5)
	tw.tween_property(thief, "scale", Vector2(1.15, 0.85), 0.08)
	tw.tween_property(thief, "scale", Vector2.ONE, 0.08)
	tw.tween_property(thief, "position", raccoon_pos, 0.55)
	tw.tween_property(thief, "modulate:a", 0.0, 0.15)
	tw.tween_callback(thief.queue_free)
	var grab := t.create_tween().set_trans(Tween.TRANS_SINE)
	grab.tween_interval(0.66)
	grab.tween_property(t, "position", raccoon_pos, 0.55)
	grab.parallel().tween_property(t, "scale", Vector2.ONE * 0.3, 0.55)
	grab.parallel().tween_property(t, "rotation", 0.6, 0.55)
	grab.tween_callback(t.queue_free)


## A letter was let go of in the word: a charged chameleon shows whether it is in the right place.
func _chameleon_look(t: LetterTile) -> void:
	if rank_of("chameleon") == 0 or pets_paused.get("chameleon", false) or pet_time["chameleon"] < pet_interval("chameleon"):
		return
	pet_time["chameleon"] = 0.0
	chameleon_right = _in_right_place(t)
	chameleon_flash = LetterTile.VERDICT_TIME
	t.judge(chameleon_right)


## Is this placed letter where it belongs?
func _in_right_place(t: LetterTile) -> bool:
	var word: String = puzzle.word
	if puzzle.gaps_visible:
		for item in row:
			var slot := item as GapSlot
			if slot and slot.tile == t:
				return word[slot.index] == t.letter
		return false
	# Hidden gaps: the right gap, and enough room before and after it for the other missing letters.
	var at := row.find(t)
	var gap := _row_gap(at)
	var wanted := ""
	for i in puzzle.missing:
		if _gap_of(i) == gap:
			wanted += word[i]
	var before := 0
	var after := 0
	for i in row.size():
		if i != at and _is_placed(row[i]) and _row_gap(i) == gap:
			if i < at:
				before += 1
			else:
				after += 1
	var open := maxi(0, cat_splits.get(gap, 0) - before - after - 1)
	if before + after + 1 + open == wanted.length():
		# The cat opened a space for every letter, so its exact place is known.
		return wanted[before + mini(int(t.get_meta("before", 0)), open)] == t.letter
	for k in range(before, wanted.length() - after):
		if wanted[k] == t.letter:
			return true
	return false


## A click on a pet: it goes to sleep, or wakes up and carries on where it was.
func _toggle_pet(id: String) -> void:
	pets_paused[id] = not pets_paused.get(id, false)
	_save_game()


## Missing letters the raven does not point at yet and whose space you can see: shown gaps, or hidden
## ones where the cat has opened a space for every letter that is missing there.
func _raven_free() -> Array:
	return puzzle.missing.filter(func(i: int) -> bool: return not raven_spots.has(i) and _space_known(i))


func _space_known(index: int) -> bool:
	if puzzle.gaps_visible:
		return true
	var gap := _gap_of(index)
	var missing_here := 0
	for i in puzzle.missing:
		missing_here += 1 if _gap_of(i) == gap else 0
	return cat_splits.get(gap, 0) >= missing_here


## The raven flies to the spot and leaves its pointer there. It stays until the word is brewed,
## so it never tells whether the letter you put there is right.
func _raven_fly(index: int) -> void:
	var id := round_id
	raven_spots[index] = -1.0
	var bird := Sprite2D.new()
	bird.texture = MenuKit.drawing("@crow")
	bird.scale = Vector2.ONE * 0.28
	bird.position = raven_pos
	bird.flip_h = true
	add_child(bird)
	var goal := _raven_spot(index, false) - Vector2(0, 110)
	var tw := bird.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(bird, "position", goal, 0.5)
	tw.tween_callback(func() -> void:
		if id == round_id:
			raven_spots[index] = 0.0)
	tw.tween_property(bird, "position", goal + Vector2(60, -70), 0.35)
	tw.parallel().tween_property(bird, "modulate:a", 0.0, 0.35)
	tw.tween_callback(bird.queue_free)


## Where an item of the word is right now, floating and all; or, not live, where it comes to rest.
func _spot_of(item: Node2D, live: bool) -> Vector2:
	if not live:
		return _target_of(item)
	var slot := item as GapSlot
	if slot and slot.tile and slot.tile != dragged:
		item = slot.tile
	return item.position + LetterTile.bob_offset(item._phase) * item.scale.x


## The middle of the space where a missing letter belongs. It follows the bubbles around it.
func _raven_spot(index: int, live := true) -> Vector2:
	if puzzle.gaps_visible:
		for item in row:
			var slot := item as GapSlot
			if slot and slot.index == index:
				return _spot_of(slot, live)
		return WORD_CENTER
	# Hidden gaps: between the given letters on both sides.
	var gap := _gap_of(index)
	var mates: Array = puzzle.missing.filter(func(i: int) -> bool: return _gap_of(i) == gap)
	var nth := mates.find(index)
	var left := Vector2.INF
	var right := Vector2.INF
	var inside: Array[Vector2] = []  # letters you put in this gap, and spaces the cat opened in it
	for i in row.size():
		var g := _row_gap(i)
		if _is_placed(row[i]):
			if g == gap:
				inside.append(_spot_of(row[i], live))
		elif g == gap - 1:
			left = _spot_of(row[i], live)
		elif g == gap:
			right = _spot_of(row[i], live)
	for i in claws.spots.size():
		if spot_gaps[i] == gap:
			inside.append(claws.spots[i])
	inside.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	if inside.size() == mates.size():
		return inside[nth]  # a place for each of them
	# Otherwise spread over the room between the neighbors.
	if left == Vector2.INF:
		left = (right if inside.is_empty() else inside[0]) - Vector2(row_step, 0)
	if right == Vector2.INF:
		right = (left if inside.is_empty() else inside[-1]) + Vector2(row_step, 0)
	return left.lerp(right, (nth + 1.0) / (mates.size() + 1.0))


## How big the mark is: smaller when several share one narrow gap.
func _raven_size(index: int) -> float:
	if puzzle.gaps_visible:
		return 1.0
	var gap := _gap_of(index)
	var mates := 0
	for i in puzzle.missing:
		mates += 1 if _gap_of(i) == gap else 0
	var places := spot_gaps.count(gap)
	for i in row.size():
		places += 1 if _is_placed(row[i]) and _row_gap(i) == gap else 0
	return 1.0 if mates == 1 or places >= mates else (0.8 if mates == 2 else 0.62)


func _update_raven_marks(delta: float) -> void:
	raven_marks.visible = not busy and not swapping
	var marks: Array[Dictionary] = []
	for i in raven_spots:
		if raven_spots[i] >= 0.0 and not puzzle.is_empty():
			raven_spots[i] += delta
			var goal := _raven_spot(i) - Vector2(0, (LetterTile.BUBBLE_RADIUS + 6.0) * row_scale)
			# Glides along when the letters make room, instead of jumping.
			var at: Vector2 = goal if not raven_at.has(i) else raven_at[i].lerp(goal, 1.0 - exp(-14.0 * delta))
			raven_at[i] = at
			marks.append({"at": at, "vowel": LetterTile.is_vowel(String(puzzle.word)[i]), "age": raven_spots[i], "size": _raven_size(i)})
	raven_marks.marks = marks
	raven_marks.mark_scale = maxf(0.7, row_scale)
	raven_marks.queue_redraw()


func rank_of(id: String) -> int:
	if potions_known.has(id):
		return int(potions_known[id])
	return int(owned_upgrades.get(id, 0))


func _set_rank(id: String, rank: int) -> void:
	if potions_known.has(id):
		potions_known[id] = rank > 0
	elif rank > 0:
		owned_upgrades[id] = rank
	else:
		owned_upgrades.erase(id)


## The next letter on the table the owl would point out, or null if there is nothing to tell.
## Decoys never share a letter with the missing ones, so a matching tile is surely needed.
func _familiar_next_tile() -> LetterTile:
	var word: String = puzzle.word
	var needed := {}
	for i in puzzle.missing:
		needed[word[i]] = true
	for t in tiles:
		if needed.has(t.letter) and not t.in_word and not t.revealed:
			return t
	return null


## The owl makes one needed letter on the table glow. Where it goes is up to you.
func _familiar_reveal() -> void:
	var t := _familiar_next_tile()
	if t == null:
		return
	t.revealed = true
	_kill_tween(t)
	var tw := t.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "scale", Vector2.ONE * 1.35, 0.2)
	tw.tween_property(t, "scale", Vector2.ONE, 0.3)
	t.set_meta("tween", tw)


## The gap a missing letter belongs to = how many given letters come before it.
func _gap_of(index: int) -> int:
	var before := 0
	for i in index:
		if not (i in puzzle.missing):
			before += 1
	return before


## Gaps the cat could still open. Spots between two letters come first; the ends of the
## word are only used once those are done. Gaps you already filled right are left alone.
## A gap with two missing letters can be opened twice.
func _cat_gaps(count_aims := false) -> Array[int]:
	var inner: Array[int] = []
	var ends: Array[int] = []
	if puzzle.gaps_visible:
		return inner  # the empty bubbles already show where letters go
	var word: String = puzzle.word
	var given: int = word.length() - puzzle.missing.size()
	var wanted := {}  # gap -> the letters that belong there
	for i in puzzle.missing:
		var g := _gap_of(i)
		wanted[g] = wanted.get(g, "") + word[i]
	var placed := {}  # gap -> the letters the player put there
	var fixed := 0
	for item in row:
		var t := item as LetterTile
		if t.movable:
			placed[fixed] = placed.get(fixed, "") + t.letter
		else:
			fixed += 1
	for g in wanted:
		var opened: int = cat_splits.get(g, 0) + (cat_aims.get(g, 0) if count_aims else 0)
		if opened >= String(wanted[g]).length() or placed.get(g, "") == wanted[g]:
			continue
		if g > 0 and g < given:
			inner.append(g)
		else:
			ends.append(g)
	return ends if inner.is_empty() else inner


## Gaps the cat could still open, counting the paws already on their way.
func _cat_free_gaps() -> Array[int]:
	return _cat_gaps(true)


## Before the first or after the last letter there is nothing to split: the cat taps there instead.
func _is_end_gap(gap: int) -> bool:
	return gap == 0 or gap == String(puzzle.word).length() - puzzle.missing.size()


## The paw swipes between the two letters, or taps beside the word; a space opens when it hits.
func _cat_swipe(gap: int) -> void:
	var id := round_id
	cat_aims[gap] = cat_aims.get(gap, 0) + 1
	var paw := CatPaw.new()
	pieces.add_child(paw)
	var hit := func() -> void:
		if id == round_id:
			_cat_split(gap)
	var spot := Vector2(_gap_x(gap), WORD_CENTER.y)
	if _is_end_gap(gap):
		paw.tap(spot, hit)
	else:
		paw.swipe(spot, hit)


func _cat_split(gap: int) -> void:
	cat_splits[gap] = cat_splits.get(gap, 0) + 1
	cat_aims[gap] = maxi(0, cat_aims.get(gap, 0) - 1)
	if cat_aims[gap] == 0:
		cat_aims.erase(gap)
	if not busy:  # letters that are being stirred part once they settle
		_layout_row(true)


## Where a gap is on screen: between the given letters around it.
func _gap_x(gap: int) -> float:
	var fixed: Array[Node2D] = []
	for item in row:
		var lt := item as LetterTile
		if lt and not lt.movable:
			fixed.append(lt)
	if gap == 0:
		return _target_of(fixed[0]).x - row_step * 0.5
	if gap >= fixed.size():
		return _target_of(fixed[-1]).x + row_step * 0.5
	return (_target_of(fixed[gap - 1]).x + _target_of(fixed[gap]).x) * 0.5


# ---------------------------------------------------------------- levels & words

## Opens a recipe book: the frog coughs up its theme, or themes to choose from.
func _open_book(n: int) -> void:
	if tutorial == Tutorial.SPELL:  # the first mission, whatever book is clicked
		level = 1
		book_offers[1] = [FIRST_THEME]
		picker.show_book(1)
		_start_book(FIRST_THEME)
		return
	level = n
	if _is_mixed():
		# Every word has its own random theme: nothing to pick, the book starts at once.
		picker.show_book(n)
		_start_level(n)
		return
	var want := 1 + (rank_of("frog_choice") if rank_of("frog") > 0 else 0)
	var offer: Array = book_offers.get(n, [])
	if offer.size() < want:
		offer = offer + _roll_themes(n, want - offer.size(), offer)
		book_offers[n] = offer
		_save_game()
	picker.show_book(n)
	_show_screen(Screen.FROG)
	_update_frog()
	frog.open(n, offer)


## Books whose words each come from another theme.
func _is_mixed() -> bool:
	return GameData.LEVELS[level - 1].get("mixed", false)


## The entries of `always_words` that still belong in every book of theme t.
func _always_in(t: String) -> Array:
	var words: Array = always_words.get(t, []).filter(func(w: String) -> bool:
		for u in UPGRADES:
			if u.get("spell", "") == w:
				return rank_of(u.id) == 0 and not (w in UNTIL_SPELLED and spelled.has(w))
		return false)
	return GameData.THEMES[t].filter(func(e: Array) -> bool: return e[0] in words)


## `count` words of theme t for the open book, none of those in `used` if that is possible.
func _pick_words(t: String, count: int, used: Array = []) -> Array:
	var words: Array = dealer.pick(t, GameData.LEVELS[level - 1], _names_to_spell()).slice(0, count)
	var missing: Array = _always_in(t).filter(func(e: Array) -> bool: return not (e in words) and not (e in used))
	for i in mini(missing.size(), count):
		# In the place of an ordinary word.
		var places: Array = range(words.size()).filter(func(k: int) -> bool:
			return not (words[k] in missing) and not (words[k][0] in _names_to_spell()))
		if not places.is_empty():
			words[places.pick_random()] = missing[i]
	return words


## One word of theme t for the open book, none of those in `used`.
func _one_word(t: String, used: Array) -> Array:
	for e in _always_in(t):
		if not (e in used):
			return e
	var names := _names_to_spell()
	var words := dealer.pick(t, GameData.LEVELS[level - 1], names)
	var free := words.filter(func(e: Array) -> bool: return not (e in used))
	for e in free:
		if e[0] in names:
			return e
	return words[0] if free.is_empty() else free[0]


## Random themes for a book out of the ones you own, none of those in `avoid`. Themes shown longest ago come
## first, with some luck mixed in: with all of them, one can't come back until at least 6 others were shown.
## Themes with enough words you have not seen yet are slightly preferred. Those in `rather_not` only fill up
## when there are too few others. With few themes there may be fewer than `count`.
func _roll_themes(n: int, count: int, avoid: Array, rather_not: Array = []) -> Array:
	_complete_theme_order()
	var order: Array = theme_order.filter(func(t: String) -> bool: return t in themes_owned)
	# With few themes there is less luck, so the same one still never comes twice in a row.
	var few := order.size() < 6
	var luck := clampf(THEME_LUCK * order.size() / 10.0, 1.5, THEME_LUCK) if order.size() > 2 else 0.5
	var ranks := {}
	for i in order.size():
		var t: String = order[i]
		if not (t in avoid):
			ranks[t] = i + randf() * luck + (0.0 if dealer.has_enough(t, GameData.LEVELS[n - 1]) else (0.4 if few else 0.9)) \
				+ (100.0 if t in rather_not else 0.0)
	var names := ranks.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return ranks[a] < ranks[b])
	var out: Array = names.slice(0, count)
	for t in out:
		_theme_shown(t)
	out.shuffle()
	return out


func _theme_shown(t: String) -> void:
	theme_order.erase(t)
	theme_order.append(t)


## Themes that are new to the game (or all of them, the first time) go to the front, shuffled.
func _complete_theme_order() -> void:
	theme_order = theme_order.filter(func(t: Variant) -> bool: return GameData.THEMES.has(t))
	var fresh: Array = GameData.THEMES.keys().filter(func(t: String) -> bool: return not (t in theme_order))
	fresh.shuffle()
	theme_order = fresh + theme_order


## What feeding the frog costs now: kind -> potions.
func _reroll_cost() -> Dictionary:
	var snacks := rank_of("frog_cheap") if rank_of("frog") > 0 else 0  # no snacks without the frog spell
	var total := maxi(1, REROLL_COST - snacks)
	if tutorial == Tutorial.USE:
		total = 0  # its first meal
	return {PotionArt.WISDOM: ceili(total / 2.0), PotionArt.VISION: total / 2}


## How often the frog can still be fed in this book: once, and once more per rank of Second helping.
## Leaving a book or starting it over gives nothing back; brewing it to the end does.
func frog_left() -> int:
	return maxi(0, 1 + rank_of("frog_more") - int(frog_uses.get(level, 0)))


func _can_reroll() -> bool:
	if frog_left() == 0:
		return false
	var cost := _reroll_cost()
	if screen == Screen.FROG:
		# With few themes all of them may be on offer already: then there is nothing else to cough up.
		var offer: Array = book_offers.get(level, [])
		if themes_owned.all(func(t: String) -> bool: return t in offer):
			return false
	return rank_of("frog") > 0 and potions[PotionArt.WISDOM] >= cost[PotionArt.WISDOM] and potions[PotionArt.VISION] >= cost[PotionArt.VISION]


## Pays the frog: it swallows the themes on offer and coughs up others.
func _reroll() -> void:
	if screen != Screen.FROG or frog.busy or not _can_reroll():
		return
	var cost := _reroll_cost()
	for kind in cost:
		potions[kind] -= cost[kind]
	if tutorial == Tutorial.USE:
		tutorial = Tutorial.DONE  # saved below
	frog_uses[level] = int(frog_uses.get(level, 0)) + 1
	var old: Array = book_offers[level]
	book_offers[level] = _roll_themes(level, old.size(), [], old)
	_save_game()
	_update_potion_ui()
	_update_frog()
	frog.swap(book_offers[level])


func _update_frog() -> void:
	var cost := _reroll_cost()
	frog.set_potions(potions[PotionArt.WISDOM], potions[PotionArt.VISION],
		_repeat_color(PotionArt.COLORS[PotionArt.WISDOM], cost[PotionArt.WISDOM])
		+ _repeat_color(PotionArt.COLORS[PotionArt.VISION], cost[PotionArt.VISION]), _can_reroll(), rank_of("frog") > 0)
	frog.show_left(frog_left())


## Brews the open book with this theme.
func _start_book(t: String) -> void:
	_use_theme(t)
	_start_level(level)


func _use_theme(t: String) -> void:
	theme = t
	_complete_theme_order()
	_theme_shown(t)
	_save_game()


## Feeding the little frog in the middle of a book: it swallows the theme and the word you are
## on, and coughs up another theme (or a few to choose from) for this word and the ones after it.
## It costs no score; but help already used on this level still counts.
func _feed_pocket_frog() -> void:
	if screen != Screen.PLAY or busy or dragged or complete_panel.visible or shop_panel.visible or rank_of("frog") == 0:
		return
	if not _can_reroll():
		pocket_frog.refuse()
		return
	var cost := _reroll_cost()
	for kind in cost:
		potions[kind] -= cost[kind]
	if tutorial == Tutorial.USE:
		tutorial = Tutorial.DONE  # saved below
	frog_uses[level] = int(frog_uses.get(level, 0)) + 1
	var kept: Array = book_offers.get(level, [])
	var offer := _roll_themes(level, 1 + rank_of("frog_choice"), [theme], kept)
	if not _is_mixed():
		book_offers[level] = offer
	_save_game()
	_update_potion_ui()
	busy = true
	swapping = true
	_stop_stirring()
	thought.hide_thought()
	insert_marker.visible = false
	claws.spots = []
	cat_aims = {}
	if picture_tween:
		picture_tween.kill()
	picture_alphas.fill(0.0)
	round_id += 1  # a paw in the air must not split the swallowed word
	var id := round_id
	var letters: Array[Node2D] = []
	for node: Node2D in pieces.get_children():
		_kill_tween(node)
		letters.append(node)
	await pocket_frog.eat(letters, theme_label)
	if id != round_id:
		return
	await pocket_frog.cough()
	if id != round_id:
		return
	if offer.size() == 1:
		pocket_frog.done()
		_swap_theme(offer[0])
		return
	theme_hint.visible = true
	for i in offer.size():
		var card := ThemeFrog.ThemeCard.new(offer[i], emoji_font)
		var home := Vector2(640 + (i - (offer.size() - 1) * 0.5) * 286.0, 330) - card.size * 0.5
		card.position = frog_pos - card.size * 0.5
		card.scale = Vector2.ONE * 0.08
		card.pressed.connect(func() -> void:
			if id == round_id:
				_swap_theme(card.theme_name))
		theme_cards.add_child(card)
		var tw := card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position", home, 0.5).set_delay(i * 0.15)
		tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_delay(i * 0.15)
	await get_tree().create_timer(0.3 * offer.size(), false).timeout
	if id == round_id:
		pocket_frog.done()


## The rest of this book goes on with another theme, starting with a new word for this level.
func _swap_theme(t: String) -> void:
	var helped := helpers_used
	var count := session_words.size()
	_use_theme(t)
	if _is_mixed():  # only this word gets the new theme; the next ones have their own
		session_words[word_number] = _one_word(t, session_words)
		session_themes[word_number] = t
	else:
		for i in range(word_number, session_themes.size()):
			session_themes[i] = t
		var done: Array = session_words.slice(0, word_number)
		session_words = done + _pick_words(t, count - word_number, done)
	_start_word()
	helpers_used = helped
	# The new theme's name flies from the frog to its place.
	var home := _theme_label_home()
	theme_label.position = frog_pos - theme_label.size * 0.5
	theme_label.scale = Vector2.ONE * 0.2
	var tw := theme_label.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(theme_label, "position", home, 0.6)
	tw.tween_property(theme_label, "scale", Vector2.ONE, 0.6)
	theme_label.set_meta("tween", tw)


func _theme_text(t: String) -> String:
	return "%s  %s" % [GameData.THEME_ICONS.get(t, ""), t]


func _theme_label_home() -> Vector2:
	return Vector2(640 - ScreenLayout.pick(150, 180), ScreenLayout.pick(10, 8))


## Whatever the little frog was doing is over: tidy up.
func _end_swap() -> void:
	swapping = false
	pocket_frog.calm()
	theme_hint.visible = false
	for c in theme_cards.get_children():
		c.queue_free()
	if theme_label.has_meta("tween"):
		(theme_label.get_meta("tween") as Tween).kill()
		theme_label.remove_meta("tween")
	theme_label.position = _theme_label_home()
	theme_label.scale = Vector2.ONE
	theme_label.visible = true


func _start_level(n: int) -> void:
	level = n
	_show_screen(Screen.PLAY)
	session_words = []
	session_themes = []
	if _is_mixed():
		for i in level_max():
			var t: String = _roll_themes(level, 1, session_themes.slice(-1))[0]
			session_words.append(_one_word(t, session_words))
			session_themes.append(t)
		_save_game()
	else:
		session_words = _pick_words(theme, level_max())
		for i in session_words.size():
			session_themes.append(theme)
	if tutorial == Tutorial.SPELL:
		# FROG is the first word.
		session_words = session_words.filter(func(e: Array) -> bool: return e[0] != FIRST_WORD).slice(0, level_max() - 1)
		for e in GameData.THEMES[FIRST_THEME]:
			if e[0] == FIRST_WORD:
				session_words.push_front(e)
	word_number = 0
	plain_points = 0.0
	time_points = 0.0
	sand_lost = false
	sand_out.stop()
	new_names = []
	word_results = []
	for id in pet_time:
		pet_time[id] = 0.0
	level_label.text = "Brew recipes %d" % level
	_start_word()


## Takes the current word off the cauldron and stops everything that belonged to it.
func _clear_word() -> void:
	round_id += 1
	busy = false
	dragged = null
	_stop_stirring()
	for tw in [swirl_tween, brew_tween, picture_tween]:
		if tw:
			tw.kill()
	for c in pieces.get_children():
		c.queue_free()
	row.clear()
	tiles.clear()
	puzzle = {}
	cat_splits = {}
	cat_aims = {}
	raven_spots = {}
	raven_at = {}
	claws.spots = []
	insert_marker.visible = false
	thought.hide_thought()
	_end_swap()
	brew_color = BREW_GREEN
	picture_alphas = []


func _start_word() -> void:
	_clear_word()
	var new_theme: bool = theme_label.text != _theme_text(session_themes[word_number])
	theme = session_themes[word_number]
	puzzle = PuzzleMaker.make(session_words[word_number], GameData.LEVELS[level - 1])
	dealer.mark_seen(theme, puzzle.word)
	var word: String = puzzle.word
	var missing: Array = puzzle.missing
	var gaps_visible: bool = puzzle.gaps_visible

	for i in word.length():
		if i in missing:
			if gaps_visible:
				var slot := GapSlot.new()
				slot.index = i
				pieces.add_child(slot)
				row.append(slot)
		else:
			var f := LetterTile.new(word[i], false)
			pieces.add_child(f)
			row.append(f)
	_layout_row(false)
	for i in row.size():
		var item := row[i]
		var s := item.scale
		item.scale = Vector2.ZERO
		var tw := item.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(i * 0.04)
		tw.tween_property(item, "scale", s, 0.3)

	var letters: Array = puzzle.tiles
	var step := minf(TABLE_STEP * ScreenLayout.touch(), (1180.0 + ScreenLayout.edge() * 2.0) / maxi(1, letters.size() - 1))  # many letters move closer together
	var start_x := 640.0 - step * (letters.size() - 1) / 2.0
	for i in letters.size():
		var t := LetterTile.new(letters[i], true)
		t.home_position = Vector2(start_x + i * step, TABLE_Y + randf_range(-8, 8))
		t.home_rotation = randf_range(-0.15, 0.15)
		t.position = t.home_position
		t.rotation = t.home_rotation
		t.scale = Vector2.ZERO
		pieces.add_child(t)
		tiles.append(t)
		_tween_node(t, t.home_position, ScreenLayout.touch(), t.home_rotation, 0.3)

	sand_timer.start(sand_time())
	if sand_lost:
		sand_timer.lose()
	progress_label.text = "Level %d / %d" % [word_number + 1, level_max()]
	theme_label.text = _theme_text(theme)
	if new_theme:
		theme_label.scale = Vector2.ONE * 0.6
		var pop := theme_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(theme_label, "scale", Vector2.ONE, 0.45)
		theme_label.set_meta("tween", pop)

	vision_level = 0
	word_age = 0.0
	picture_alphas.resize(_vision_count())
	picture_alphas.fill(0.0)  # the pictures stay hidden until Vision potions are drunk
	wisdom_level = 0
	wisdom_order = []
	helpers_used = {}
	_update_potion_ui()
	if randf() < HALLUCINATION_CHANCE * rank_of("hallucination"):
		_hallucinate()


func _next_word() -> void:
	word_number += 1
	if word_number >= level_max():
		_show_level_complete()
	else:
		_start_word()


func _show_level_complete() -> void:
	round_id += 1  # nothing still running may start another word
	busy = true
	sand_out.stop()
	thought.hide_thought()
	_end_swap()
	# The best guessing and the best timing may come from different runs; the star adds them up.
	# Mastered = perfect guessing: no help on any word.
	var rec: Dictionary = level_records.get(level, {"best": 0.0, "conquered": false})
	var best_before: float = rec.best
	var was_conquered: bool = rec.conquered
	var stars_before := total_stars()
	frog_uses.erase(level)
	book_offers.erase(level)  # the next time this book is opened, the frog picks anew
	plain_points = _tidy(plain_points)
	var perfect := plain_points >= level_max()
	_split_best(rec)
	rec.plain = maxf(rec.plain, plain_points)
	rec.time = maxf(rec.time, time_points)
	rec.best = _tidy(rec.plain + rec.time)
	rec.conquered = was_conquered or perfect
	level_records[level] = rec
	_save_game()
	_update_level_stars()
	# Spells whose star requirement was reached by this run.
	var unlocked: Array = []
	for u in UPGRADES:
		var unspelled: bool = u.has("spell") and rank_of(u.id) == 0 and not spelled.has(u.spell)  # its stars alone open nothing
		if stars_before < int(u.stars) and total_stars() >= int(u.stars) and not unspelled:
			unlocked.append(u.name)
	for n in new_names:
		if not (n in unlocked):
			unlocked.append(n)  # its name was spelled
	complete_panel.show_result({
		"level": level,
		"plain": plain_points,
		"time": time_points,
		"best": rec.best,
		"best_plain": rec.plain,
		"best_time": rec.time,
		"best_before": best_before,
		"perfect": perfect,
		"was_conquered": was_conquered,
		"has_next": level < GameData.LEVELS.size(),
		"hourglass": rank_of("hourglass") > 0,
		"lost": sand_lost,
		"words": word_results,
		"unlocked": unlocked,
	})
	sparkles.position = Vector2(640, 360)
	_burst(sparkles)


# ---------------------------------------------------------------- word layout

func _layout_row(animated: bool) -> void:
	var n := row.size()
	if n == 0:
		return
	# Empty spaces the cat opened, before each item and after the last.
	var spaces: Array[int] = []
	spaces.resize(n + 1)
	spaces.fill(0)
	var gap_at: Array[int] = []  # the gap each of them is in
	gap_at.resize(n + 1)
	var gap := 0
	var i0 := 0
	while i0 <= n:
		var last := i0  # placed letters of this gap: i0 to last - 1
		while last < n and _is_placed(row[last]):
			last += 1
		var left: int = maxi(0, cat_splits.get(gap, 0) - (last - i0))
		var used := 0
		for i in range(i0, last):
			var before := clampi(int(row[i].get_meta("before", 0)), used, left)
			spaces[i] = before - used
			gap_at[i] = gap
			used = before
		spaces[last] = left - used
		gap_at[last] = gap
		gap += 1
		i0 = last + 1
	var room: Array[float] = []
	for k in spaces:
		room.append(k * SPLIT_ROOM)
	var width := n - 1.0
	for r in room:
		width += r
	row_step = minf(WORD_STEP * ScreenLayout.word(), WORD_MAX_WIDTH / (width + 1.0))
	row_scale = row_step / WORD_STEP
	var spots: Array[Vector2] = []
	spot_gaps.clear()
	var x := WORD_CENTER.x - row_step * width / 2.0
	for i in n:
		x += room[i] * row_step
		_add_spots(spots, gap_at[i], spaces[i], x - row_step * (1.0 + room[i]) * 0.5)
		var item := row[i]
		var pos := Vector2(x, WORD_CENTER.y)
		item.set_meta("target", pos)
		_place(item, pos, animated)
		var slot := item as GapSlot
		if slot and slot.tile:
			_place(slot.tile, pos, animated)
		x += row_step
	_add_spots(spots, gap_at[n], spaces[n], x - row_step + row_step * (1.0 + room[n]) * 0.5)
	claws.print_scale = row_scale
	claws.spots = spots


## Marks for `count` spaces of one gap, side by side around x.
func _add_spots(spots: Array[Vector2], gap: int, count: int, x: float) -> void:
	for j in count:
		spots.append(Vector2(x + (j - (count - 1) * 0.5) * SPLIT_ROOM * row_step, WORD_CENTER.y))
		spot_gaps.append(gap)


## Remembers which of the cat's spaces a letter was dropped in, so the others stay open on the
## right side of it. (meta "before" = open spaces to its left in the same gap)
func _note_space(t: LetterTile, x: float) -> void:
	var at := row.find(t)
	var gap := _row_gap(at)
	var before := 0
	for i in claws.spots.size():
		if spot_gaps[i] == gap and claws.spots[i].x < x - SPLIT_ROOM * row_step * 0.5:
			before += 1
	t.set_meta("before", before)
	if gap in spot_gaps:
		_shift_spaces(at, -1)


## Which gap row[at] is in: how many given letters come before it.
func _row_gap(at: int) -> int:
	var gap := 0
	for i in at:
		if not _is_placed(row[i]):
			gap += 1
	return gap


## A space in front of the letters right of row[at], in the same gap, was filled (-1) or opened (+1).
func _shift_spaces(at: int, by: int) -> void:
	for i in range(at + 1, row.size()):
		if not _is_placed(row[i]):
			return
		row[i].set_meta("before", maxi(0, int(row[i].get_meta("before", 0)) + by))


## A letter the player put between the given ones (hidden gaps).
func _is_placed(item: Node2D) -> bool:
	var t := item as LetterTile
	return t != null and t.movable


func _place(node: Node2D, pos: Vector2, animated: bool) -> void:
	if animated:
		_tween_node(node, pos, row_scale, 0.0, 0.18)
	else:
		_kill_tween(node)
		node.position = pos
		node.scale = Vector2.ONE * row_scale
		node.rotation = 0.0


func _target_of(node: Node2D) -> Vector2:
	return node.get_meta("target", node.position)


func _tween_node(node: Node2D, pos: Vector2, scl: float, rot: float, duration: float) -> void:
	_kill_tween(node)
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", pos, duration)
	tw.tween_property(node, "scale", Vector2.ONE * scl, duration)
	tw.tween_property(node, "rotation", rot, duration)
	node.set_meta("tween", tw)


func _kill_tween(node: Node2D) -> void:
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old and old.is_valid():
			old.kill()
		node.remove_meta("tween")


func _spelling() -> String:
	var s := ""
	for item in row:
		var slot := item as GapSlot
		if slot:
			s += slot.tile.letter if slot.tile else "_"
		else:
			s += (item as LetterTile).letter
	return s


func _word_filled() -> bool:
	var word: String = puzzle.word
	if puzzle.gaps_visible:
		return not _spelling().contains("_")
	return row.size() >= word.length()


# ---------------------------------------------------------------- input: drag & stir

## Where the mouse or the finger is, in the game's own 1280 x 720. (Taken from the event: on a phone there is no
## mouse to ask.)
func _point(event: InputEvent) -> Vector2:
	var at := event as InputEventMouse
	if at:
		pointer = get_canvas_transform().affine_inverse() * at.position
	return pointer


func _unhandled_input(event: InputEvent) -> void:
	if complete_panel.visible or shop_panel.visible or screen in [Screen.LEVELS, Screen.FROG]:
		return
	var mb := event as InputEventMouseButton
	if screen == Screen.TITLE:
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not busy:
			var at := _point(event)
			if _on_brew(at):
				_start_stir(at)
		return
	# Clicking a pet pauses it or wakes it up.
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var mouse := _point(event)
		if pocket_frog.is_at(mouse):
			_feed_pocket_frog()
			get_viewport().set_input_as_handled()
			return
		for id in ["familiar", "cat", "raven", "mouse", "chameleon", "raccoon"]:
			var spot: Vector2 = {"familiar": familiar_pos, "cat": cat_pos, "raven": raven_pos, "mouse": mouse_pos,
				"chameleon": chameleon_pos, "raccoon": raccoon_pos}[id]
			if rank_of(id) > 0 and mouse.distance_to(spot) <= 40.0 * ScreenLayout.icons():
				_toggle_pet(id)
				get_viewport().set_input_as_handled()
				return
	if busy or _must_learn():
		return
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var p := _point(event)
		var t := _tile_at(p)
		if t:
			_begin_drag(t, p)
			get_viewport().set_input_as_handled()
		elif _on_brew(p):
			_start_stir(p)


func _start_stir(p: Vector2) -> void:
	stirring = true
	stir_start = p
	stir_last_x = p.x
	spoon.position = p
	spoon.visible = true


## Is the point over the liquid in the pot?
func _on_brew(p: Vector2) -> bool:
	var d := p - BREW_CENTER
	return pow(d.x / (BREW_RADIUS.x + 20.0), 2) + pow(d.y / (BREW_RADIUS.y + 30.0), 2) <= 1.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
		return
	# Ctrl+click fills up / completes a value, Alt+click removes its progress.
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and (click.ctrl_pressed or click.alt_pressed) and dragged == null:
		if _cheat_click(_point(event), click.ctrl_pressed):
			get_viewport().set_input_as_handled()
			return
	if dragged == null and not stirring:
		return
	var p := _point(event)
	if event is InputEventMouseMotion:
		if dragged:
			_drag_to(p)
		else:
			_stir_motion(p)
	else:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if dragged:
				_drop()
			_stop_stirring()


func _stop_stirring() -> void:
	stirring = false
	if spoon:
		spoon.visible = false


func _tile_at(p: Vector2) -> LetterTile:
	for i in range(tiles.size() - 1, -1, -1):
		if tiles[i].contains_point(p):
			return tiles[i]
	return null


func _in_cauldron(p: Vector2) -> bool:
	var d := p - BREW_CENTER
	return pow(d.x / 330.0, 2) + pow(d.y / 165.0, 2) <= 1.0


func _begin_drag(t: LetterTile, p: Vector2) -> void:
	_take_out_of_word(t)
	dragged = t
	drag_offset = t.position - p
	if ScreenLayout.phone:
		drag_offset = Vector2(0, -58)  # above the finger, so you can see it
		t.position = p + drag_offset
	_kill_tween(t)
	t.scale = Vector2.ONE * 1.12 * ScreenLayout.touch()
	t.rotation = 0.0
	pieces.move_child(t, -1)
	tiles.erase(t)
	tiles.append(t)
	_layout_row(true)


func _drag_to(p: Vector2) -> void:
	dragged.position = p + drag_offset
	var c := dragged.position
	if puzzle.gaps_visible:
		var target := _nearest_slot(c)
		for item in row:
			var slot := item as GapSlot
			if slot:
				slot.glow = slot == target
	elif _over_word(c):
		insert_marker.position = Vector2(_insert_x(_insert_index(c.x)), WORD_CENTER.y)
		insert_marker.scale = Vector2.ONE * row_scale
		insert_marker.visible = true
	else:
		insert_marker.visible = false


func _drop() -> void:
	var t := dragged
	dragged = null
	insert_marker.visible = false
	var c := t.position
	var placed := false
	if puzzle.gaps_visible:
		var slot := _nearest_slot(c)
		for item in row:
			var s := item as GapSlot
			if s:
				s.glow = false
		if slot:
			if slot.tile:
				_send_home(slot.tile)
			slot.tile = t
			placed = true
	elif _over_word(c):
		row.insert(_insert_index(c.x), t)
		_note_space(t, c.x)
		placed = true
	if placed:
		t.in_word = true
		_chameleon_look(t)
	else:
		_send_home(t)
	_layout_row(true)


func _take_out_of_word(t: LetterTile) -> void:
	for item in row:
		var slot := item as GapSlot
		if slot and slot.tile == t:
			slot.tile = null
	if t in row and cat_splits.has(_row_gap(row.find(t))):
		_shift_spaces(row.find(t), 1)
	row.erase(t)
	t.in_word = false
	t.clear_verdict()
	t.set_meta("before", 0)


func _send_home(t: LetterTile) -> void:
	t.in_word = false
	t.clear_verdict()
	t.set_meta("before", 0)
	_tween_node(t, t.home_position, ScreenLayout.touch(), t.home_rotation, 0.3)


func _nearest_slot(c: Vector2) -> GapSlot:
	var best: GapSlot = null
	var best_d := DROP_RADIUS
	for item in row:
		var slot := item as GapSlot
		if slot:
			var d := c.distance_to(_target_of(slot))
			if d < best_d:
				best_d = d
				best = slot
	return best


func _over_word(c: Vector2) -> bool:
	if row.is_empty():
		return absf(c.y - WORD_CENTER.y) < 80.0
	var left := _target_of(row[0]).x - 100.0
	var right := _target_of(row[-1]).x + 100.0
	for spot in claws.spots:  # the cat's spaces beside the word belong to it
		left = minf(left, spot.x - 60.0)
		right = maxf(right, spot.x + 60.0)
	return absf(c.y - WORD_CENTER.y) < 80.0 and c.x > left and c.x < right


func _insert_index(x: float) -> int:
	var idx := 0
	for item in row:
		if _target_of(item).x < x:
			idx += 1
	return idx


func _insert_x(idx: int) -> float:
	if row.is_empty():
		return WORD_CENTER.x
	if idx <= 0:
		return _target_of(row[0]).x - row_step * 0.5
	if idx >= row.size():
		return _target_of(row[-1]).x + row_step * 0.5
	return (_target_of(row[idx - 1]).x + _target_of(row[idx]).x) * 0.5


## Stirring = one swipe to the left across the brew.
func _stir_motion(p: Vector2) -> void:
	swirl_angle += (p.x - stir_last_x) * 0.012  # the soup swirls along with the spoon
	stir_last_x = p.x
	if stir_start.x - p.x >= STIR_SWIPE and _on_brew(p):
		_stop_stirring()
		if screen == Screen.TITLE:
			_stir_title()
		else:
			_stir()


# ---------------------------------------------------------------- stirring & brewing

func _stir() -> void:
	if busy or complete_panel.visible or puzzle.is_empty():
		return
	busy = true
	var id := round_id
	await _swirl_letters()
	if id != round_id:
		return
	if not _word_filled():
		busy = false  # just a swirl; the engraving still says how many letters are missing
		_layout_row(true)
		return
	if _spelling() == puzzle.word:
		await _brew_success()
		if id != round_id:
			return
		_next_word()
	else:
		await _brew_fail()
		if id != round_id:
			return
		busy = false


func _swirl_letters() -> void:
	var homes: Array[Vector2] = []
	for item in row:
		_kill_tween(item)
		homes.append(_target_of(item))
		var slot := item as GapSlot
		if slot and slot.tile:
			_kill_tween(slot.tile)
	var start_angle := swirl_angle
	swirl_tween = create_tween()
	swirl_tween.tween_method(_swirl_step.bind(homes, start_angle), 0.0, 1.0, 1.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await swirl_tween.finished


func _swirl_step(t: float, homes: Array[Vector2], start_angle: float) -> void:
	var n := row.size()
	if n != homes.size():
		return
	var w := sin(t * PI)  # 0 at start and end, so letters always settle back in place
	for i in n:
		var a := TAU * i / n + t * TAU * 1.5
		var orbit := BREW_CENTER + Vector2(cos(a) * 220.0, sin(a) * 75.0 - 20.0)
		var pos := homes[i].lerp(orbit, w)
		row[i].position = pos
		var slot := row[i] as GapSlot
		if slot and slot.tile:
			slot.tile.position = pos
	swirl_angle = start_angle + t * TAU * 1.5


func _brew_success() -> void:
	sparkles.position = WORD_CENTER
	_burst(sparkles)
	brew_tween = create_tween()
	brew_tween.tween_property(self, "brew_color", BREW_GOLD, 0.3)
	# All pictures appear in the brew.
	_show_pictures(picture_alphas.size(), 0.5)
	if String(puzzle.word).to_lower() in _names_to_spell():
		spelled[String(puzzle.word).to_lower()] = true
		for u in UPGRADES:
			if u.get("spell", "") == String(puzzle.word).to_lower():
				new_names.append(u.name)
				if _upgrade_lock_reason(u.id) != "":  # still needs stars; otherwise it is announced as unlocked
					_announce(u.id, "You spelled %s!" % puzzle.word)
	if tutorial == Tutorial.USE:
		use_note_seen = true
	var fast := in_time()
	var time_stars := TIME_POINT + sand_timer.bonus() if fast else 0.0  # Golden sand: more for what is left
	plain_points += word_score()
	time_points += time_stars
	word_results.append({"word": puzzle.word, "picture": _main_picture(), "points": word_score(), "fast": fast, "time": time_stars})
	if fast:
		sand_timer.win()
	_award_potions()
	for i in row.size():
		var node: Node2D = row[i]
		var slot := node as GapSlot
		if slot:
			node = slot.tile
		var b := node.create_tween()
		b.tween_interval(i * 0.06)
		b.tween_property(node, "scale", Vector2.ONE * row_scale * 1.3, 0.15)
		b.tween_property(node, "scale", Vector2.ONE * row_scale, 0.2)
		b.parallel().tween_property(node, "modulate", Color(1, 0.92, 0.55), 0.2)
	await get_tree().create_timer(1.8, false).timeout


func _brew_fail() -> void:
	smoke.position = BREW_CENTER
	_burst(smoke)
	var id := round_id
	brew_tween = create_tween()
	brew_tween.tween_property(self, "brew_color", BREW_MURKY, 0.25)
	brew_tween.tween_interval(0.6)
	brew_tween.tween_property(self, "brew_color", BREW_GREEN, 0.6)
	var shake := pieces.create_tween()
	for k in 6:
		shake.tween_property(pieces, "position", Vector2(10.0 if k % 2 == 0 else -10.0, 0), 0.05)
	shake.tween_property(pieces, "position", Vector2.ZERO, 0.05)
	await shake.finished
	if id != round_id:
		return  # the level was left meanwhile
	# Wrong letters hop back to the table.
	var word: String = puzzle.word
	if puzzle.gaps_visible:
		for item in row:
			var slot := item as GapSlot
			if slot and slot.tile and slot.tile.letter != word[slot.index]:
				_send_home(slot.tile)
				slot.tile = null
	else:
		for t in tiles:
			if t.in_word:
				row.erase(t)
				_send_home(t)
	_layout_row(true)
	await get_tree().create_timer(0.4, false).timeout


# ---------------------------------------------------------------- potions

## Potions it costs to drink one, by difficulty: 1,1,1,2,2,2,3,3,3,4,4,4,5,5,...
func _potion_cost() -> int:
	var cost := mini(5, 1 + (level - 1) / 3) - rank_of("discount")
	return maxi(1, cost)


## Potions earned for brewing a word: bigger words give more (1-4), +1 per rank of the cauldron itself.
func _potion_reward() -> int:
	return _reward_for(puzzle.word) + rank_of("lucky")


func _reward_for(word: String) -> int:
	var n := word.length()
	if n <= 4:
		return 1
	if n <= 6:
		return 2
	if n <= 9:
		return 3
	return 4


## How often Wisdom and Vision can each be bought for this word: once per missing letter. The clues are
## spread over those buys, so with one missing letter the first buy shows everything.
func _clue_buys() -> int:
	return 1 if puzzle.is_empty() else puzzle.missing.size()


## Wisdom potions for the full meaning (Whispering sage takes one off per rank, min 1).
## Never more than the meaning has words, so no potion shows nothing new.
func _wisdom_steps() -> int:
	var words := String(puzzle.get("meaning", "")).split(" ", false).size()
	return clampi(_clue_buys() - rank_of("sage"), 1, maxi(1, words))


## Pictures Vision can show for this word.
func _vision_count() -> int:
	return _pictures().size()


func _pictures() -> PackedStringArray:
	return puzzle.get("pictures", PackedStringArray())


func _main_picture() -> String:
	return "" if _pictures().is_empty() else _pictures()[0]


## Vision potions to see all pictures (Clear sight takes one off per rank, min 1).
func _vision_steps() -> int:
	return clampi(_clue_buys() - rank_of("sight"), 1, maxi(1, _vision_count()))


## Pictures shown after this many Vision potions: spread evenly, all of them with the last one.
func _pictures_after(drinks: int) -> int:
	return mini(_vision_count(), ceili(_vision_count() * float(drinks) / _vision_steps()))


## Lets the first `count` pictures appear, one after the other.
func _show_pictures(count: int, time: float) -> void:
	if picture_tween:
		picture_tween.kill()
	picture_tween = create_tween().set_trans(Tween.TRANS_SINE)
	picture_tween.tween_interval(0.01)
	for i in mini(count, picture_alphas.size()):
		if picture_alphas[i] < 1.0:
			picture_tween.parallel().tween_method(_set_picture.bind(i), picture_alphas[i], 1.0, time).set_delay(i * 0.12)


func _set_picture(alpha: float, i: int) -> void:
	if i < picture_alphas.size():
		picture_alphas[i] = alpha


func _drink_wisdom() -> void:
	if complete_panel.visible or swapping or _must_learn() or rank_of(PotionArt.WISDOM) == 0:
		return
	if wisdom_level >= _wisdom_steps():
		thought.toggle()  # already know it all: reopen for free
		return
	if not _pay(PotionArt.WISDOM):
		return
	wisdom_level += 1
	_use_helper("wisdom")
	thought.show_text(_meaning_snippet())
	_update_potion_ui()


## The meaning with only some words revealed; hidden stretches become "…".
## Each Wisdom potion reveals more, longer (more useful) words first.
func _meaning_snippet() -> String:
	var words: PackedStringArray = String(puzzle.meaning).split(" ", false)
	if wisdom_order.size() != words.size():
		var long: Array = []
		var short: Array = []
		for i in words.size():
			(long if words[i].length() > 3 else short).append(i)
		long.shuffle()
		short.shuffle()
		wisdom_order = long + short
	var count := mini(words.size(), ceili(words.size() * float(wisdom_level) / _wisdom_steps()))
	var shown := {}
	for i in count:
		shown[wisdom_order[i]] = true
	var parts: Array = []
	for i in words.size():
		if shown.has(i):
			parts.append(words[i])
		elif parts.is_empty() or parts[-1] != "…":
			parts.append("…")
	return " ".join(parts)


func _drink_vision() -> void:
	if complete_panel.visible or swapping or _must_learn() or rank_of(PotionArt.VISION) == 0 or _vision_count() == 0 or vision_level >= _vision_steps():
		return
	if not _pay(PotionArt.VISION):
		return
	vision_level += 1
	_use_helper("vision")
	_show_pictures(_pictures_after(vision_level), 0.9)
	_update_potion_ui()


## A free Vision at the start of a word: no potion, and it does not count as help.
func _hallucinate() -> void:
	if _vision_count() == 0:
		return
	vision_level = 1
	_show_pictures(_pictures_after(vision_level), 1.4)
	_update_potion_ui()


func _pay(kind: String) -> bool:
	var cost := _potion_cost()
	if potions[kind] < cost:
		return false
	potions[kind] -= cost
	_save_game()
	return true


## Potions are kept between play sessions in the player's save file.
## Themes from a save, by the names they have now.
func _renamed(themes: Array) -> Array:
	return themes.map(func(t: Variant) -> Variant: return OLD_THEME_NAMES.get(t, t))


func _load_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first time playing: keep the starting potions
	for kind in potions.keys():
		potions[kind] = int(cfg.get_value("potions", kind, potions[kind]))
	score = int(cfg.get_value("progress", "score", 0))
	sand_fails = int(cfg.get_value("progress", "sand_fails", 0))
	tutorial = int(cfg.get_value("progress", "tutorial", Tutorial.DONE)) as Tutorial  # older saves: played before
	# Older saves had every theme there was then from the start: they keep them.
	themes_owned = START_THEMES.duplicate()
	for t in _renamed(cfg.get_value("progress", "themes", GameData.THEMES.keys().filter(func(t: String) -> bool: return t != "Alchemy"))):
		if GameData.THEMES.has(t) and not (t in themes_owned):
			themes_owned.append(t)
	for kind in shelf_slots.keys():
		shelf_slots[kind] = clampi(int(cfg.get_value("shelves", kind, START_SLOTS)), START_SLOTS, MAX_SLOTS)
	for kind in potions_known:
		potions_known[kind] = int(cfg.get_value("upgrades", kind, 1)) > 0  # older saves could always drink them
	for u in UPGRADES:
		# Ranks are numbers; older saves stored true for "learned" (= rank 1).
		var r := int(cfg.get_value("upgrades", u.id, 0))
		if r > 0:
			_set_rank(u.id, mini(r, int(u.max)))
		# Owl, cat and raven had three ranks once (150, 200 and 175, doubling): the extra ones are paid back.
		var paid: int = {"familiar": 150, "cat": 200, "raven": 175}.get(u.id, 0)
		for k in range(int(u.max), r):
			score += paid * int(pow(2, k))
	# Older saves: choosing between three themes was one spell, without the frog spell before it.
	if rank_of("frog_choice") > 0 and rank_of("frog") == 0:
		owned_upgrades["frog"] = 1
		owned_upgrades["frog_choice"] = 2
	# Older saves kept only the last few themes brewed ("recent_themes").
	pets_paused = cfg.get_value("upgrades", "pets_paused", {})
	for w in cfg.get_value("upgrades", "spelled", []):
		spelled[w] = true
	for u in UPGRADES:
		if u.has("spell") and rank_of(u.id) > 0:
			spelled[u.spell] = true  # pets from before their names had to be spelled
	theme_order = _renamed(cfg.get_value("progress", "theme_order", cfg.get_value("progress", "recent_themes", [])))
	var seen: Dictionary = cfg.get_value("progress", "seen_words", {})
	for old in OLD_THEME_NAMES:
		if seen.has(old):
			seen[OLD_THEME_NAMES[old]] = seen[old]
	dealer.from_save(seen)
	# Saves with 30 books: the old book 2 was the same as book 1 and is gone, the later ones moved up one place.
	var had_30: bool = not cfg.has_section_key("progress", "books")
	var old_books := 30 if had_30 else GameData.LEVELS.size()
	for saved_n in range(1, old_books + 1):
		if had_30 and saved_n == 2:
			continue
		var n: int = saved_n - 1 if had_30 and saved_n > 2 else saved_n
		var offer: Array = _renamed(cfg.get_value("offers", "book_%d" % saved_n, []))
		offer = offer.filter(func(t: Variant) -> bool: return GameData.THEMES.has(t))
		if not offer.is_empty() and not GameData.LEVELS[n - 1].get("mixed", false):
			book_offers[n] = offer
	for n in range(1, GameData.LEVELS.size() + 1):
		if cfg.has_section_key("offers", "fed_%d" % n):
			frog_uses[n] = int(cfg.get_value("offers", "fed_%d" % n))
	# Best scores: 1 point per word ("recipes" section). Older saves counted 10 per word ("stars").
	for saved_n in range(1, old_books + 1):
		var n: int = saved_n - 1 if had_30 and saved_n >= 2 else saved_n
		for old in [["recipes", 1.0], ["stars", 10.0]]:
			if cfg.has_section_key(old[0], "best_%d" % saved_n):
				var rec := {
					"best": float(cfg.get_value(old[0], "best_%d" % saved_n, 0.0)) / float(old[1]),
					"conquered": bool(cfg.get_value(old[0], "conquered_%d" % saved_n, false)),
				}
				if cfg.has_section_key(old[0], "plain_%d" % saved_n):
					rec["plain"] = float(cfg.get_value(old[0], "plain_%d" % saved_n, 0.0))
					rec["time"] = float(cfg.get_value(old[0], "time_%d" % saved_n, 0.0))
				_split_best(rec, n)
				if level_records.has(n):  # the old books 1 and 2: the best of both
					var first: Dictionary = level_records[n]
					rec.plain = maxf(rec.plain, first.plain)
					rec.time = maxf(rec.time, first.time)
					rec.best = _tidy(rec.plain + rec.time)
					rec.conquered = rec.conquered or first.conquered
				level_records[n] = rec
				break
	# More potions than shelf space (e.g. from an older save): the extra becomes points.
	for kind in potions.keys():
		if potions[kind] > shelf_slots[kind]:
			score += (potions[kind] - shelf_slots[kind]) * POINTS_PER_POTION
			potions[kind] = shelf_slots[kind]
	_save_game()


func _save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for kind in potions.keys():
		cfg.set_value("potions", kind, potions[kind])
	cfg.set_value("progress", "score", score)
	cfg.set_value("progress", "tutorial", int(tutorial))
	cfg.set_value("progress", "sand_fails", sand_fails)
	cfg.set_value("progress", "books", GameData.LEVELS.size())
	cfg.set_value("progress", "themes", themes_owned)
	cfg.set_value("progress", "theme_order", theme_order)
	cfg.set_value("upgrades", "pets_paused", pets_paused)
	cfg.set_value("upgrades", "spelled", spelled.keys())
	cfg.set_value("progress", "seen_words", dealer.to_save())
	for n in frog_uses:
		cfg.set_value("offers", "fed_%d" % n, int(frog_uses[n]))
	for n in book_offers:
		cfg.set_value("offers", "book_%d" % n, book_offers[n])
	for kind in shelf_slots:
		cfg.set_value("shelves", kind, shelf_slots[kind])
	for kind in potions_known:
		cfg.set_value("upgrades", kind, rank_of(kind))
	for id in owned_upgrades:
		cfg.set_value("upgrades", id, int(owned_upgrades[id]))
	for n in level_records:
		_split_best(level_records[n], n)
		cfg.set_value("recipes", "best_%d" % n, level_records[n].best)
		cfg.set_value("recipes", "plain_%d" % n, level_records[n].plain)
		cfg.set_value("recipes", "time_%d" % n, level_records[n].time)
		cfg.set_value("recipes", "conquered_%d" % n, level_records[n].conquered)
	cfg.save(SAVE_PATH)


func _award_potions() -> void:
	var kinds := [PotionArt.WISDOM, PotionArt.VISION]
	for i in _potion_reward():
		_bring_potion(kinds[randi() % 2], WORD_CENTER + Vector2(randf_range(-60, 60), 0), 0.25 + i * 0.18)
	_save_game()
	_update_potion_ui()


## A potion flies to its shelf, or to your knowledge when the shelf is full.
func _bring_potion(kind: String, from: Vector2, delay: float) -> void:
	var fly := FlyingPotion.new()
	fly.liquid = PotionArt.COLORS[kind]
	fly.position = from
	fly.scale = Vector2.ONE * 1.6
	add_child(fly)
	var tw := fly.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(delay)
	tw.tween_property(fly, "position", fly.position + Vector2(0, -90), 0.3)
	# Count (and save) right away; the shelf / knowledge only shows it once it lands.
	if potions[kind] < shelf_slots[kind]:
		potions[kind] += 1
		incoming[kind] = incoming.get(kind, 0) + 1
		var shelf: PotionShelf = shelves[kind]
		tw.tween_property(fly, "position", shelf.slot_global_position(potions[kind] - 1), 0.55)
		tw.parallel().tween_property(fly, "scale", Vector2.ONE, 0.55)
		tw.tween_callback(func() -> void:
			incoming[kind] -= 1
			_update_potion_ui()
			fly.queue_free())
	else:
		# Shelf is full: this potion turns into knowledge.
		score += POINTS_PER_POTION
		score_incoming += POINTS_PER_POTION
		var target := score_label.global_position + score_label.size * 0.5
		tw.tween_property(fly, "position", target, 0.55)
		tw.parallel().tween_property(fly, "scale", Vector2.ONE * 0.6, 0.55)
		tw.tween_callback(func() -> void:
			score_incoming -= POINTS_PER_POTION
			_update_potion_ui()
			_pop_score()
			fly.queue_free())


## A record from before the two scores were kept apart: up to the perfect score is guessing,
## anything above it is timing.
func _split_best(rec: Dictionary, n := level) -> void:
	if not rec.has("plain"):
		rec.plain = minf(rec.best, GameData.word_count(n))
		rec.time = maxf(0.0, rec.best - rec.plain)


## The perfect score for this recipe book: 1 point per word.
func level_max() -> int:
	return GameData.word_count(level)


## Remembers that this kind of help was used on the current word.
func _use_helper(id: String) -> void:
	assert(id in HELPERS, "%s is missing from HELPERS" % id)
	helpers_used[id] = true


## Points for the current word: 1, minus an equal share for every kind of help used.
func word_score() -> float:
	return float(HELPERS.size() - helpers_used.size()) / HELPERS.size()


## What one helper costs, in words for tooltips and the spell book.
func _helper_note() -> String:
	return "Takes %s of a star off this level." % MenuKit.points_text(1.0 / HELPERS.size())


## Adding up fractions leaves crumbs (9.999999); this sweeps them away.
func _tidy(v: float) -> float:
	return roundf(v * 1000.0) / 1000.0


func _update_level_stars() -> void:
	picker.refresh(level_records, total_stars())
	var rec: Dictionary = level_records.get(level, {})
	hud_star.set_record(not rec.is_empty(), float(rec.get("best", 0.0)), bool(rec.get("conquered", false)))


func _pop_score() -> void:
	score_label.pivot_offset = score_label.size * 0.5
	var tw := score_label.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(score_label, "scale", Vector2.ONE * 1.35, 0.1)
	tw.tween_property(score_label, "scale", Vector2.ONE, 0.25)


func _update_potion_ui() -> void:
	if shelves.is_empty():
		return
	var feed := _reroll_cost()
	pocket_frog.cost = _repeat_color(PotionArt.COLORS[PotionArt.WISDOM], feed[PotionArt.WISDOM]) \
		+ _repeat_color(PotionArt.COLORS[PotionArt.VISION], feed[PotionArt.VISION])
	pocket_frog.affordable = _can_reroll()
	pocket_frog.left = frog_left()
	var cost := _potion_cost()
	for kind in shelves:
		var shelf := shelves[kind] as PotionShelf
		shelf.capacity = shelf_slots[kind]
		shelf.count = potions[kind] - incoming.get(kind, 0)
	score_label.text = "Knowledge: %d" % (score - score_incoming)
	var none: Array[Color] = []
	for kind in potion_buttons:
		potion_buttons[kind].tooltip_text = potion_tips[kind]
	for kind in [PotionArt.WISDOM, PotionArt.VISION]:
		var icon: PotionIcon = potion_buttons[kind]
		var drunk := wisdom_level if kind == PotionArt.WISDOM else vision_level
		var steps := _wisdom_steps() if kind == PotionArt.WISDOM else _vision_steps()
		var all_text := "all known" if kind == PotionArt.WISDOM else "all shown"
		if rank_of(kind) == 0:
			# What is left to do before you can drink it.
			icon.show_locked("learn it" if spelled.has(kind) else "locked")
			icon.tooltip_text = ("You spelled %s: learn it in the Shelves." if spelled.has(kind)
				else "Spell %s in a book of Witchcraft & magic to unlock it.") % kind.to_upper()
		elif drunk >= steps:
			icon.show_drunk(drunk, steps, all_text, none, kind == PotionArt.WISDOM)  # Wisdom: free to reopen the thought
		else:
			icon.show_drunk(drunk, steps, "", _repeat_color(PotionArt.COLORS[kind], cost), potions[kind] >= cost)
	for key in cost_icons:
		cost_icons[key].queue_redraw()


func _repeat_color(c: Color, n: int) -> Array[Color]:
	var out: Array[Color] = []
	for i in n:
		out.append(c)
	return out


func _engraving_text() -> String:
	if screen == Screen.TITLE:
		return "STIR TO BEGIN"
	if puzzle.is_empty() or swapping:
		return ""
	if _must_learn() and not busy:
		return "OPEN THE SHELVES"
	if _word_filled():
		return "STIR THE POT!"
	var n: int = puzzle.missing.size()
	return "FIND %d LETTER%s" % [n, "" if n == 1 else "S"]


# ---------------------------------------------------------------- drawing the hut

func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	# Wall
	var all := ScreenLayout.rect()
	var e := ScreenLayout.edge()
	draw_rect(Rect2(all.position, Vector2(all.size.x, 600 - all.position.y)), Color("4b3226"))
	for x in range(-800, 2081, 80):
		if x >= all.position.x and x <= all.end.x:
			draw_line(Vector2(x, all.position.y), Vector2(x, 600), Color("3e291f"), 3.0)
	# Window with a moon
	var win := Rect2(70 - e * 0.75, ScreenLayout.pick(118, 92), 190, 150)
	var crowded := screen == Screen.PLAY and ScreenLayout.roomy()
	if not crowded:
		_draw_window(win)
	if not crowded:
		_draw_jars(e)
	# Fire glow under the cauldron
	_ellipse(Vector2(640, 600), 380, 100, Color(1.0, 0.55, 0.2, 0.22))
	# Cauldron body (front) with a soft shine
	_ellipse(Vector2(640, 470), 335, 175, Color("26262e"))
	_ellipse(Vector2(520, 540), 120, 40, Color(1, 1, 1, 0.04))
	# Rim seen from above: a thick dark ring around a wide pool of soup
	_ellipse(BREW_CENTER, BREW_RADIUS.x + 32, BREW_RADIUS.y + 22, Color("3b3b47"))
	_ellipse(BREW_CENTER + Vector2(0, -6), BREW_RADIUS.x + 18, BREW_RADIUS.y + 10, Color("4a4a58"))
	_ellipse(BREW_CENTER, BREW_RADIUS.x, BREW_RADIUS.y, brew_color.darkened(0.35))  # inner wall shadow
	_ellipse(BREW_CENTER + Vector2(0, 8), BREW_RADIUS.x - 8, BREW_RADIUS.y - 10, brew_color)
	# Swirls in the soup (they spin with your stirring)
	var spin := swirl_angle + time * 0.25
	for k in 3:
		var a0 := spin + k * TAU / 3.0
		var pts := PackedVector2Array()
		for j in 14:
			var a := a0 + j * 0.13
			var r := 50.0 + j * 15.0
			pts.append(BREW_CENTER + Vector2(0, 8) + Vector2(cos(a) * r, sin(a) * r * 0.36))
		draw_polyline(pts, brew_color.lightened(0.28), 3.0, true)
	_draw_picture(time)
	# Golden engraving on the front of the cauldron
	_draw_engraving()
	if screen == Screen.PLAY:
		if rank_of("familiar") > 0:
			_draw_familiar("familiar", familiar_pos, "🦉", time)
		if rank_of("cat") > 0:
			_draw_familiar("cat", cat_pos, "🐈", time + 1.3)
		if rank_of("raven") > 0:
			_draw_familiar("raven", raven_pos, "@crow", time + 2.1)
		if rank_of("mouse") > 0:
			_draw_mouse(time)
		if rank_of("chameleon") > 0:
			if chameleon_flash > 0.0:  # it takes the color of its verdict
				draw_circle(chameleon_pos, 42.0 * ScreenLayout.icons(), Color(Color("4bd15f") if chameleon_right else Color("ff4b3e"), minf(1.0, chameleon_flash)))
			_draw_familiar("chameleon", chameleon_pos, "🦎", time + 2.9)
		if rank_of("raccoon") > 0:
			_draw_familiar("raccoon", raccoon_pos, "🦝", time + 3.6)
	# Table
	draw_rect(Rect2(all.position.x, 595, all.size.x, all.end.y - 595), Color("8a5a32"))
	draw_rect(Rect2(all.position.x, 595, all.size.x, 8), Color("a8743f"))
	draw_line(Vector2(all.position.x, 640), Vector2(all.end.x, 640), Color("744a28"), 2.0)
	draw_line(Vector2(all.position.x, 690), Vector2(all.end.x, 690), Color("744a28"), 2.0)


func _draw_window(win: Rect2) -> void:
	draw_rect(win.grow(10), Color("2c1c14"))
	draw_rect(win, Color("1d2a4d"))
	draw_circle(win.position + Vector2(130, 50), 26, Color("fff4c9"))
	draw_circle(win.position + Vector2(140, 44), 22, Color("1d2a4d"))
	for s in [Vector2(30, 30), Vector2(60, 115), Vector2(100, 75), Vector2(165, 130), Vector2(40, 70)]:
		draw_circle(win.position + s, 2.5, Color("fff4c9"))
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("2c1c14"), 8.0)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color("2c1c14"), 8.0)


func _draw_jars(e: float) -> void:
	var up := ScreenLayout.pick(0, 10)
	draw_rect(Rect2(1030 + e, 150 - up, 220, 12), Color("2c1c14"))
	draw_rect(Rect2(1045 + e, 105 - up, 34, 45), Color("7fb3a8"))
	draw_rect(Rect2(1095 + e, 92 - up, 30, 58), Color("c76b5a"))
	draw_circle(Vector2(1160 + e, 128 - up), 22, Color("9b7fc4"))
	draw_rect(Rect2(1195 + e, 110 - up, 36, 40), Color("d9b45a"))


## The pictures Vision has shown, in a row in the brew. Those still to come are faint question marks.
func _draw_picture(time: float) -> void:
	var n := picture_alphas.size()
	if n == 0 or picture_alphas.max() <= 0.01:
		return
	var pics := _pictures()
	var fs: int = [110, 96, 84, 74, 66, 58][mini(n, 6) - 1]
	var step := fs * 1.3
	var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
	var font := ThemeDB.fallback_font
	for i in n:
		var c := PICTURE_CENTER + Vector2((i - (n - 1) * 0.5) * step, sin(time * 1.1 + i * 1.3) * 4.0)
		var a := picture_alphas[i]
		if a < 1.0:
			draw_string(font, c + Vector2(-40, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 80, 40, Color(0.05, 0.2, 0.1, 0.3 * (1.0 - a)))
		if a <= 0.01:
			continue
		# Pops up from the brew.
		draw_set_transform(c, 0.0, Vector2.ONE * (0.5 + 0.5 * a))
		var tint := brew_color.lightened(0.5).lerp(Color.WHITE, a)
		tint.a = a
		var art := MenuKit.drawing(pics[i])
		if art:
			var side := fs * 1.2
			draw_texture_rect(art, Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side), false, tint)
		else:
			draw_string(emoji_font, Vector2(-100, baseline), pics[i], HORIZONTAL_ALIGNMENT_CENTER, 200, fs, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The mouse, with a ring that fills up until it brings its next potion.
func _draw_mouse(time: float) -> void:
	var frac := mouse_time / mouse_interval()
	var note := "%d s" % ceili(mouse_interval() - mouse_time)
	_draw_pet(mouse_pos, 36.0 * ScreenLayout.icons(), roundi(38 * ScreenLayout.icons()), "🐭", time + 0.7, frac, pets_paused.get("mouse", false), false, note)


## A familiar beside the cauldron, with a ring that fills up until it helps. Asleep = paused.
func _draw_familiar(id: String, spot: Vector2, icon: String, time: float) -> void:
	var idle: bool = id == "cat" and not puzzle.is_empty() and puzzle.gaps_visible  # nothing for the cat to do here
	var asleep: bool = pets_paused.get(id, false)
	var left: float = pet_interval(id) - pet_time[id]
	var note := "ready" if left <= 0.0 else "%d s" % ceili(left)
	if idle:
		note = "gaps shown" if ScreenLayout.phone else "gaps are shown"
	_draw_pet(spot, 36.0 * ScreenLayout.icons(), roundi(40 * ScreenLayout.icons()), icon, time, pet_time[id] / pet_interval(id), asleep, idle, note)


func _draw_pet(spot: Vector2, radius: float, fs: int, icon: String, time: float, frac: float, asleep: bool, idle: bool, note: String) -> void:
	var c := spot + Vector2(0, 0.0 if asleep or idle else sin(time * 1.5) * 3.0)
	var hover: bool = not ScreenLayout.phone and get_global_mouse_position().distance_to(spot) <= radius + 4.0
	draw_circle(c, radius, Color(1, 0.85, 0.4, 0.22) if hover else Color(0, 0, 0, 0.25))
	draw_arc(c, radius, 0.0, TAU, 40, Color(1, 0.85, 0.4, 0.2), 4.0, true)
	if frac > 0.0:
		# While it sleeps the ring stands still and fades, to show how far it got.
		draw_arc(c, radius, -PI / 2, -PI / 2 + TAU * frac, 40, Color(BREW_GOLD, 0.45) if asleep else BREW_GOLD, 4.0, true)
	var tint := Color(1, 1, 1, 0.4) if asleep or idle else Color.WHITE
	var art := MenuKit.drawing(icon)
	if art:
		draw_circle(c, radius - 6.0, Color(0.85, 0.78, 0.62, 0.3))  # a light backdrop for the black bird
		draw_texture_rect(art, Rect2(c - Vector2(25, 25) * ScreenLayout.icons(), Vector2(50, 50) * ScreenLayout.icons()), false, tint)
	else:
		var baseline := (emoji_font.get_ascent(fs) - emoji_font.get_descent(fs)) * 0.5
		draw_string(emoji_font, c + Vector2(-60, baseline), icon, HORIZONTAL_ALIGNMENT_CENTER, 120, fs, tint)
	var font := ThemeDB.fallback_font
	if asleep:
		var drift := fmod(time, 2.0) / 2.0
		draw_string(font, c + Vector2(20, -24 - drift * 14), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 1.0 - drift))
		draw_string(font, c + Vector2(30, -36 - drift * 14), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 1.0 - drift))
		note = "click to wake" if hover else ("tap to wake" if ScreenLayout.phone else "asleep")
	elif hover:
		note = "click to pause"
	draw_string(font, spot + Vector2(-60, radius + ScreenLayout.pick(20, 22)), note, HORIZONTAL_ALIGNMENT_CENTER, 120, int(ScreenLayout.pick(13, 19)), Color(1, 0.95, 0.85, 0.65))


func _draw_engraving() -> void:
	var text := _engraving_text()
	if text == "":
		return
	var fs := 36
	var w := 600.0
	var pos := Vector2(640.0 - w * 0.5, ENGRAVING_Y + 12.0)
	var gold := Color("e8b84a")
	if text.begins_with("STIR"):
		gold = gold.lerp(Color("fff0b0"), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0))
	# Dark edge above and light edge below make it look carved into the metal.
	draw_string(engrave_font, pos + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0, 0, 0, 0.7))
	draw_string(engrave_font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(1, 0.9, 0.6, 0.35))
	draw_string(engrave_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, gold)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


# ---------------------------------------------------------------- particles

func _make_soft_circle(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func _make_bubbles(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = 18
	p.lifetime = 1.4
	p.position = BREW_CENTER
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(220, 70)
	p.direction = Vector2(0, -1)
	p.spread = 15.0
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.color = BREW_GREEN.lightened(0.35)
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _make_sparkles(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 80
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(250, 10)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 350)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.color = BREW_GOLD
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _make_smoke(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 40
	p.lifetime = 1.6
	p.position = BREW_CENTER
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(150, 10)
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -20)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color(0.55, 0.5, 0.6, 0.8)
	p.color_ramp = _fade_ramp()
	add_child(p)
	return p


func _burst(p: CPUParticles2D) -> void:
	p.restart()
	p.emitting = true


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.offset = ScreenLayout.extra
	ui_layer = layer
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	# Menu button, and the level being played with its best star
	var top := HBoxContainer.new()
	var e := ScreenLayout.edge()
	top.position = Vector2(16 - e, 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 18)
	hud.add_child(top)
	top.add_child(_button("Menu", Vector2(ScreenLayout.pick(110, 140), ScreenLayout.pick(46, 60)), _open_pause))
	level_label = _label("", int(ScreenLayout.pick(26, 30)))
	level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(level_label)
	hud_star = LevelStar.new()
	hud_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hud_star)

	progress_label = _label("", int(ScreenLayout.pick(24, 28)))
	progress_label.position = Vector2(1090 + e, 18)
	hud.add_child(progress_label)

	score_label = _label("", int(ScreenLayout.pick(24, 28)))
	score_label.position = Vector2(850 + e * 0.8, 18)
	score_label.add_theme_color_override("font_color", BREW_GOLD)
	hud.add_child(score_label)

	# The theme of the word, on a piece of parchment above the cauldron.
	theme_label = _label("", int(ScreenLayout.pick(25, 30)))
	theme_label.position = _theme_label_home()
	theme_label.size = Vector2(ScreenLayout.pick(300, 360), ScreenLayout.pick(50, 62))
	theme_label.pivot_offset = theme_label.size * 0.5
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	theme_label.add_theme_color_override("font_color", MenuKit.INK)
	var with_icons := FontVariation.new()
	with_icons.base_font = ThemeDB.fallback_font
	var more: Array[Font] = [emoji_font]
	with_icons.fallbacks = more
	theme_label.add_theme_font_override("font", with_icons)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3e2b8")
	paper.border_color = Color("c99a5b")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0, 0, 0, 0.3)
	paper.shadow_size = 4
	theme_label.add_theme_stylebox_override("normal", paper)
	theme_label.mouse_filter = Control.MOUSE_FILTER_PASS
	theme_label.tooltip_text = "The word comes from this theme."
	hud.add_child(theme_label)
	sand_timer = SandTimer.new()
	sand_timer.position = Vector2(ScreenLayout.pick(390, 350), 4)
	hud.add_child(sand_timer)
	theme_hint = _label(ScreenLayout.say("Click the theme you want to brew"), 24)
	theme_hint.position = Vector2(340, 208)
	theme_hint.size = Vector2(600, 34)
	theme_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_hint.visible = false
	hud.add_child(theme_hint)
	theme_cards = Control.new()
	theme_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(theme_cards)

	stir_tip = _label("Stir the pot: swipe\nleft across the brew!", 24 if ScreenLayout.roomy() else 18)
	stir_tip.position = Vector2(1030 + e, 496.0 if ScreenLayout.roomy() else 486.0)
	stir_tip.modulate = Color(1, 1, 1, 0.75)
	hud.add_child(stir_tip)

	# Meaning hint (Wisdom potion): a floating thought
	thought = ThoughtCloud.new()
	hud.add_child(thought)
	thought.setup(Vector2(640, 168))

	# Action buttons
	# Each potion is a round icon, like the pets; under it the potions you have of it. Then the Shelves.
	var side := VBoxContainer.new()
	var big := ScreenLayout.roomy()
	var column := PotionShelf.PER_ROW * PotionShelf.STEP * ScreenLayout.icons() + 12.0
	side.position = Vector2(1262 + e - column * 2.0 - 10.0, 90.0 if big else ScreenLayout.pick(180, 170))
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override("separation", 12)
	hud.add_child(side)
	var both := HBoxContainer.new()
	both.mouse_filter = Control.MOUSE_FILTER_IGNORE
	both.add_theme_constant_override("separation", 10)
	side.add_child(both)
	for info in [
		[PotionArt.WISDOM, "Drink to learn what the word means.\nAs often as letters are missing; the last one tells it all.\n" + _helper_note(), _drink_wisdom],
		[PotionArt.VISION, "Drink to see pictures of the word in the brew.\nAs often as letters are missing; the last one shows them all.\n" + _helper_note(), _drink_vision],
	]:
		var kind: String = info[0]
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 2)
		both.add_child(box)
		var b := PotionIcon.new(kind, column)
		b.tooltip_text = info[1]
		potion_tips[kind] = info[1]
		b.pressed.connect(info[2])
		box.add_child(b)
		potion_buttons[kind] = b
		cost_icons[kind] = b.costs
		var shelf := PotionShelf.new()
		shelf.liquid = PotionArt.COLORS[kind]
		shelf.custom_minimum_size.x = column
		box.add_child(shelf)
		shelves[kind] = shelf
	shop_button = _button("Shelves", Vector2(column * 2.0 + 10.0, 90.0 if big else ScreenLayout.pick(52, 68)))
	shop_button.add_theme_font_size_override("font_size", 28 if big else int(ScreenLayout.pick(19, 23)))
	shop_button.add_theme_color_override("font_color", BREW_GOLD)
	shop_button.tooltip_text = "Spend knowledge on spells, themes and potion slots"
	shop_button.pressed.connect(_open_shop)
	side.add_child(shop_button)
	tutorial_note = TutorialNote.new()
	hud.add_child(tutorial_note)
	sand_out = SandOut.new()
	hud.add_child(sand_out)

	title_screen = TitleScreen.new()
	title_screen.play_pressed.connect(_play)
	title_screen.book_pressed.connect(_open_shop)
	title_screen.quit_pressed.connect(get_tree().quit)
	root.add_child(title_screen)

	picker = LevelPicker.new()
	picker.level_chosen.connect(_open_book)
	picker.back_pressed.connect(_show_screen.bind(Screen.TITLE))
	picker.book_pressed.connect(_open_shop)
	root.add_child(picker)

	frog = ThemeFrog.new()
	frog.emoji_font = emoji_font
	frog.start_pressed.connect(_start_book)
	frog.reroll_pressed.connect(_reroll)
	frog.back_pressed.connect(_show_screen.bind(Screen.LEVELS))
	root.add_child(frog)

	complete_panel = LevelComplete.new()
	complete_panel.emoji_font = emoji_font
	complete_panel.again_pressed.connect(func() -> void: _open_book(level))
	complete_panel.next_pressed.connect(func() -> void: _open_book(level + 1))
	complete_panel.levels_pressed.connect(_show_screen.bind(Screen.LEVELS))
	root.add_child(complete_panel)

	pause_menu = PauseMenu.new()
	pause_menu.restart_pressed.connect(func() -> void: _start_level(level))
	pause_menu.levels_pressed.connect(_show_screen.bind(Screen.LEVELS))
	pause_menu.title_pressed.connect(_show_screen.bind(Screen.TITLE))
	root.add_child(pause_menu)

	start_choice = StartChoice.new()
	start_choice.new_game_pressed.connect(_reset_game)
	root.add_child(start_choice)
	title_screen.reset_pressed.connect(start_choice.ask)

	unlock_layer = Control.new()
	unlock_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(unlock_layer)
	turn_hint = _label("Turn your phone sideways", 60)
	turn_hint.position = Vector2(0, -180)
	turn_hint.size = Vector2(1280, 80)
	turn_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_hint.visible = false
	root.add_child(turn_hint)
	_build_shop(root)  # last, so the book opens on top of every screen


# ---------------------------------------------------------------- shelves menu

## Score points needed for the next slot on a shelf: 20, 40, 60, ... (more each time).
func _slot_price(kind: String) -> int:
	return 20 * (shelf_slots[kind] - START_SLOTS + 1)


## The spell book (upgrade menu) and the skill tree it shows.
const ROOT_UPGRADE := "lucky"  ## what holding the cauldron in the middle of the tree improves
const SKILL_TREE := [
	{"id": "root", "parent": "", "pos": Vector2(0, 0), "icon": "🍲"},
	# The animals fan out above the cauldron, each with its upgrades further out; only the raven needs another one, the cat.
	{"id": "frog", "parent": "root", "pos": Vector2(-285, -15), "icon": "🐸"},
	{"id": "frog_more", "parent": "frog", "pos": Vector2(-385, -115), "icon": "🥣"},
	{"id": "frog_choice", "parent": "frog", "pos": Vector2(-430, -8), "icon": "🍽"},
	{"id": "frog_cheap", "parent": "frog", "pos": Vector2(-400, 96), "icon": "🪰"},
	{"id": "familiar", "parent": "root", "pos": Vector2(-175, -108), "icon": "🦉"},
	{"id": "owl_speed", "parent": "familiar", "pos": Vector2(-295, -190), "icon": "💨"},
	{"id": "owl_all", "parent": "familiar", "pos": Vector2(-190, -236), "icon": "🌕"},
	{"id": "cat", "parent": "root", "pos": Vector2(-45, -122), "icon": "🐈"},
	{"id": "cat_speed", "parent": "cat", "pos": Vector2(-85, -235), "icon": "🐾"},
	{"id": "raven", "parent": "cat", "pos": Vector2(35, -235), "icon": "@crow"},
	{"id": "raven_speed", "parent": "raven", "pos": Vector2(155, -235), "icon": "👀"},
	{"id": "mouse", "parent": "root", "pos": Vector2(85, -114), "icon": "🐭"},
	{"id": "mouse_speed", "parent": "mouse", "pos": Vector2(262, -205), "icon": "🧀"},
	{"id": "chameleon", "parent": "root", "pos": Vector2(200, -84), "icon": "🦎"},
	{"id": "chameleon_speed", "parent": "chameleon", "pos": Vector2(362, -126), "icon": "🌈"},
	{"id": "raccoon", "parent": "root", "pos": Vector2(290, 5), "icon": "🦝"},
	{"id": "raccoon_speed", "parent": "raccoon", "pos": Vector2(418, -10), "icon": "🎭"},
	# Potions and time below it.
	{"id": "wisdom", "parent": "root", "pos": Vector2(-165, 100), "icon": "💡"},
	{"id": "wisdom_shelf", "parent": "wisdom", "pos": Vector2(-278, 128), "icon": "📘"},
	{"id": "sage", "parent": "wisdom_shelf", "pos": Vector2(-365, 226), "icon": "📜"},
	{"id": "discount", "parent": "wisdom_shelf", "pos": Vector2(-222, 228), "icon": "💰"},
	{"id": "hourglass", "parent": "root", "pos": Vector2(0, 126), "icon": "⏳"},
	{"id": "more_sand", "parent": "hourglass", "pos": Vector2(-70, 228), "icon": "🏜"},
	{"id": "golden_sand", "parent": "hourglass", "pos": Vector2(70, 228), "icon": "✨"},
	{"id": "vision", "parent": "root", "pos": Vector2(165, 100), "icon": "🔮"},
	{"id": "vision_shelf", "parent": "vision", "pos": Vector2(278, 128), "icon": "🖼"},
	{"id": "sight", "parent": "vision_shelf", "pos": Vector2(365, 226), "icon": "👁"},
	{"id": "hallucination", "parent": "vision_shelf", "pos": Vector2(222, 228), "icon": "🌀"},
]


## The themes grow from a starting node of their own, beside the spells, on both sides of a trunk: two in a row.
const THEMES_START := Vector2(680, -232)
const THEME_ROWS := ["Animals", "Witchcraft & magic", "Food & kitchen", "Nature & weather", "At home", "Time & calendar",
	"Ocean & sea", "Universe", "Body & feelings", "School & words", "Alchemy"]
var _tree_nodes: Array = []


func tree_nodes() -> Array:
	if _tree_nodes.is_empty():
		_tree_nodes = SKILL_TREE.duplicate()
		_tree_nodes.append({"id": "themes", "parent": "", "pos": THEMES_START, "icon": "📖"})
		var names: Array = THEME_ROWS + GameData.THEMES.keys().filter(func(t: String) -> bool: return not (t in THEME_ROWS))
		for i in names.size():
			var side := -1 if i % 2 == 0 else 1
			var x := side * 60.0
			if side < 0 and i == names.size() - 1:  # the odd one out ends the trunk
				side = 1
				x = 0.0
			_tree_nodes.append({"id": "theme:" + names[i], "parent": "themes", "icon": GameData.THEME_ICONS[names[i]], "side": side,
				"pos": THEMES_START + Vector2(x, 90.0 + 79.0 * (i / 2))})
	return _tree_nodes


## The theme behind a node ("" if it is a spell).
func _theme_of(id: String) -> String:
	return id.substr(6) if id.begins_with("theme:") else ""


func _theme_price(t: String) -> int:
	return THEME_PRICES.get(t, THEME_PRICE)


func _theme_info(t: String) -> Dictionary:
	var owned: bool = t in themes_owned
	var price := _theme_price(t)
	var words: Array = GameData.THEMES[t].map(func(e: Array) -> String: return e[0])
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length())
	var count := words.size()
	var info := {"title": t, "label": t, "plain": true, "understood": owned, "can_buy": false, "afford": 0.0,
		"desc": "%d words, such as %s, %s and %s." % [count, words[count / 5], words[count / 2], words[count * 4 / 5]],
		"status_text": "yours" if owned else "%d knowledge" % price, "hint": "You have this theme."}
	if owned:
		return info
	if tutorial < Tutorial.USE:
		info.status_text = "locked"
		info.hint = "Locked: learn the frog first"
		return info
	info.can_buy = score >= price
	info.afford = minf(1.0, score / float(price))
	info.hint = ("Hold to learn: %d knowledge" % price) if info.can_buy else ("Needs %d knowledge (you have %d)" % [price, score])
	return info


func _buy_theme(t: String) -> bool:
	if not GameData.THEMES.has(t) or not _theme_info(t).can_buy:
		return false
	score -= _theme_price(t)
	themes_owned.append(t)
	_save_game()
	_update_potion_ui()
	_update_frog()
	_update_shop()
	return true


func _build_shop(root: Control) -> void:
	shop_panel = SpellBook.new()
	shop_panel.game = self
	shop_panel.emoji_font = emoji_font
	root.add_child(shop_panel)


func _open_shop() -> void:
	if complete_panel.visible:
		return
	shop_panel.open_book()


func _update_shop() -> void:
	if shop_panel:
		shop_panel.refresh()


func _buy_slot(kind: String) -> bool:
	var price := _slot_price(kind)
	if shelf_slots[kind] >= MAX_SLOTS or score < price or tutorial < Tutorial.USE or rank_of(kind) == 0:
		return false
	score -= price
	shelf_slots[kind] += 1
	_save_game()
	_update_potion_ui()
	_update_shop()
	return true


## Sum of your best score on every recipe book.
func total_stars() -> float:
	var total := 0.0
	for n in level_records:
		total += float(level_records[n].best)
	return _tidy(total)


func _upgrade_info(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}


func book_stats_text() -> String:
	return "Knowledge: %d" % score


## Everything the spell book needs to draw and explain one spell.
func skill_info(id: String) -> Dictionary:
	var info := {"title": "", "desc": "", "status_text": "", "hint": "",
		"understood": false, "can_buy": false,
		"afford": 0.0}  # how much of the price you have, 0 to 1 (0 if it can't be bought at all)
	if id == "themes":
		info.merge({"title": "Themes", "label": "Themes", "plain": true, "understood": true, "status_text": "%d / %d" % [themes_owned.size(), GameData.THEMES.size()],
			"desc": "Your recipe books use the themes you have. Learn more for more kinds of words.", "hint": "Most themes cost %d knowledge" % THEME_PRICE}, true)
		return info
	if _theme_of(id) != "":
		return _theme_info(_theme_of(id))
	if id == "root":
		# The cauldron in the middle: better ranks give more potions for every word. Always readable.
		info = skill_info(ROOT_UPGRADE)
		info.desc = "The heart of every spell. Each rank gives 1 extra potion for every brewed word. Now: +%d." % rank_of(ROOT_UPGRADE)
		info.understood = true
		info.stars = total_stars()
	elif id == "wisdom_shelf" or id == "vision_shelf":
		var kind := PotionArt.WISDOM if id == "wisdom_shelf" else PotionArt.VISION
		var label := "Wisdom" if kind == PotionArt.WISDOM else "Vision"
		var price := _slot_price(kind)
		var maxed: bool = shelf_slots[kind] >= MAX_SLOTS
		info.title = "%s shelf" % label
		info.desc = "Makes room for one more %s potion on its shelf." % label
		info.understood = shelf_slots[kind] > START_SLOTS
		info.can_buy = not maxed and score >= price
		info.afford = 0.0 if maxed else minf(1.0, score / float(price))
		info.status_text = "%d / %d slots" % [shelf_slots[kind], MAX_SLOTS]
		if tutorial < Tutorial.USE:
			info.can_buy = false
			info.afford = 0.0
			info.hint = "Locked: learn the frog first"
		elif rank_of(kind) == 0:
			info.can_buy = false
			info.afford = 0.0
			info.hint = "Locked: learn the %s potion first" % label
		elif maxed:
			info.hint = "Full size!"
		elif info.can_buy:
			info.hint = "Hold to learn: %d knowledge" % price
		else:
			info.hint = "Needs %d knowledge (you have %d)" % [price, score]
	else:
		var u := _upgrade_info(id)
		var rank := rank_of(id)
		var max_rank := int(u.max)
		var price := _upgrade_price(id)
		var lock := _upgrade_lock_reason(id)
		info.title = u.name
		info.desc = ScreenLayout.say(String(u.desc).replace("\n", " "))
		info.understood = rank > 0
		if u.has("spell") and rank == 0 and not spelled.has(u.spell):
			info.unspelled = String(u.spell).to_upper()  # its letters float out of the spell
			info.spell_theme = _theme_with(u.spell)
		if u.has("spell"):
			info.special = _special_text(u.spell)
		info.can_buy = rank < max_rank and lock == "" and score >= price
		if rank < max_rank and lock == "":
			info.afford = 1.0 if price <= score else score / float(price)
		if id in ["owl_speed", "cat_speed", "raven_speed", "chameleon_speed", "raccoon_speed"] and rank > 0:
			var seconds := pet_interval({"owl_speed": "familiar", "cat_speed": "cat", "raven_speed": "raven", "chameleon_speed": "chameleon", "raccoon_speed": "raccoon"}[id])
			info.status_text = "%.1f s  (%d/%d)" % [seconds, rank, max_rank]
		elif id == "mouse_speed" and rank > 0:
			info.status_text = "%d s  (%d/%d)" % [roundi(mouse_interval()), rank, max_rank]
		elif id == "hallucination" and rank > 0:
			info.status_text = "%d%%  (%d/%d)" % [roundi(HALLUCINATION_CHANCE * 100.0 * rank), rank, max_rank]
		elif id == "owl_all" and rank > 0:
			info.status_text = "%d%%  (%d/%d)" % [roundi(OWL_ALL_CHANCE * 100.0 * rank), rank, max_rank]
		elif id == "more_sand" and rank > 0:
			info.status_text = "+%d%% time  (%d/%d)" % [roundi(SAND_RANK * 100.0 * rank), rank, max_rank]
		elif max_rank > 1:
			info.status_text = "rank %d/%d" % [rank, max_rank]
		else:
			info.status_text = "learned" if rank > 0 else ""
		if rank >= max_rank:
			info.hint = "Fully learned!"
		elif lock != "":
			var by_stars := total_stars() < int(u.stars) and tutorial >= Tutorial.USE
			if rank == 0:
				info.status_text = "locked"
				if by_stars:
					info.stars = float(u.stars)  # drawn as a star symbol
			info.hint = "Locked: " + lock
			if by_stars:
				info.hint = "Locked: needs"
				info.need_stars = float(u.stars)
		else:
			var what := "Hold to learn" if rank == 0 else "Hold to learn rank %d" % (rank + 1)
			info.hint = ("%s: %d knowledge" % [what, price]) if info.can_buy \
				else ("Next rank: %d knowledge (you have %d)" % [price, score])
			if rank == 0:
				info.status_text = "%d knowledge" % price
			if price == 0:
				info.hint = "Hold to learn: free"
				info.status_text = "free"
	return info


## The theme a word is in.
func _theme_with(word: String) -> String:
	for t in GameData.THEMES:
		for e in GameData.THEMES[t]:
			if e[0] == word:
				return t
	return ""


var _special_texts := {}

## What is special about unlocking this spell, in plain words: which word to spell, and where it turns up.
func _special_text(word: String) -> String:
	if spelled.has(word):
		return "Special unlock: you spelled %s." % word.to_upper()
	if not _special_texts.has(word):
		var parts: PackedStringArray = []
		var first := 0
		for n in range(1, GameData.LEVELS.size() + 2):
			var fits := n <= GameData.LEVELS.size() and GameData.length_distance(word.length(), GameData.LEVELS[n - 1]) == 0
			if fits and first == 0:
				first = n
			elif not fits and first > 0:
				parts.append("%d" % first if first == n - 1 else "%d-%d" % [first, n - 1])
				first = 0
		var always: bool = word in always_words.get(_theme_with(word), [])
		var books := "any book" if always else "book %s" % parts[0] if parts.size() == 1 and not parts[0].contains("-") else "books " + " and ".join(parts)
		_special_texts[word] = "Special unlock: spell %s in the theme %s (%s)." % [word.to_upper(), _theme_with(word), books]
	var t := _theme_with(word)
	return _special_texts[word] + ("" if t in themes_owned else " You need that theme first.")


## Score points for the next rank of a spell: base * growth^rank, rounded to 10.
func _upgrade_price(id: String) -> int:
	var u := _upgrade_info(id)
	return int(round(float(u.base) * pow(float(u.growth), rank_of(id)) / 10.0)) * 10


## Why a spell can't be learned yet ("" if it can).
func _upgrade_lock_reason(id: String) -> String:
	var u := _upgrade_info(id)
	if tutorial < Tutorial.USE and id != "frog":
		return "learn the frog first"
	if total_stars() < int(u.stars):
		return "needs %d stars (you have %s)" % [u.stars, MenuKit.points_text(total_stars())]
	if u.has("needs") and rank_of(u.needs) == 0:
		return "learn %s first" % _upgrade_info(u.needs).name
	if u.has("spell") and rank_of(id) == 0 and not spelled.has(u.spell):
		return "spell %s first" % String(u.spell).to_upper()
	return ""


## Words that unlock a spell (the names of the pets and so on) and were not spelled yet: they come up before other words.
func _names_to_spell() -> Array:
	var out: Array = []
	for u in UPGRADES:
		if u.has("spell") and not spelled.has(u.spell):
			out.append(u.spell)
	return out


## Learn a spell, or its next rank (called when the mouse has been held on it long enough).
func skill_buy(id: String) -> bool:
	if _theme_of(id) != "":
		return _buy_theme(_theme_of(id))
	if id == "wisdom_shelf":
		return _buy_slot(PotionArt.WISDOM)
	if id == "vision_shelf":
		return _buy_slot(PotionArt.VISION)
	if id == "root":
		id = ROOT_UPGRADE
	var u := _upgrade_info(id)
	if u.is_empty() or rank_of(id) >= int(u.max) or _upgrade_lock_reason(id) != "":
		return false
	var price := _upgrade_price(id)
	if score < price:
		return false
	score -= price
	_set_rank(id, rank_of(id) + 1)
	_save_game()
	_update_potion_ui()
	_update_shop()
	return true


func _label(text: String, font_size: int) -> Label:
	return MenuKit.label(text, font_size)


func _button(text: String, min_size: Vector2, on_press: Callable = Callable()) -> Button:
	return MenuKit.button(text, min_size, on_press)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = int(ScreenLayout.pick(22, 25))
	t.set_stylebox("normal", "Button", _ui_box(Color("6b4226"), Color("c99a5b")))
	t.set_stylebox("hover", "Button", _ui_box(Color("7d5030"), Color("e8c27a")))
	t.set_stylebox("pressed", "Button", _ui_box(Color("d9a441"), Color("fff0c2")))
	t.set_stylebox("hover_pressed", "Button", _ui_box(Color("e0b052"), Color("fff0c2")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _ui_box(Color("4a3226"), Color("6b5040")))
	t.set_color("font_disabled_color", "Button", Color(1, 0.95, 0.85, 0.35))
	t.set_color("font_color", "Button", Color("fff3d6"))
	t.set_color("font_hover_color", "Button", Color("ffffff"))
	t.set_color("font_pressed_color", "Button", Color("2b1a0e"))
	t.set_color("font_hover_pressed_color", "Button", Color("2b1a0e"))
	t.set_color("font_color", "Label", Color("fff3d6"))
	var parchment := _ui_box(Color("f3e2b8"), Color("8b5a2b"))
	parchment.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", parchment)
	return t


func _ui_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	return sb


# ---------------------------------------------------------------- helper node

## Draws the "drop here" bar and the golden hint marker.
class Marker extends Node2D:
	var color := Color.WHITE

	func _draw() -> void:
		var h := LetterTile.BUBBLE_RADIUS + 6.0
		draw_line(Vector2(0, -h), Vector2(0, h), color, 6.0)


## A pet on its way.
class EmojiSprite extends Node2D:
	var emoji := ""
	var font: Font

	func _draw() -> void:
		var fs := 44
		var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(-40, baseline), emoji, HORIZONTAL_ALIGNMENT_CENTER, 80, fs)


## A reward potion flying from the cauldron to its shelf.
class FlyingPotion extends Node2D:
	var liquid := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 16.0, Color(liquid, 0.25))
		PotionArt.draw_flask(self, Vector2.ZERO, 1.0, liquid)


## A wooden spoon that follows the mouse while you stir.
class Spoon extends Node2D:
	func _draw() -> void:
		var handle_end := Vector2(70, -170)
		draw_line(Vector2(0, -10), handle_end, Color("5a3a1e"), 14.0, true)
		draw_line(Vector2(0, -10), handle_end, Color("a8743f"), 9.0, true)
		draw_circle(Vector2.ZERO, 20.0, Color("5a3a1e"))
		draw_circle(Vector2(-2, -2), 16.0, Color("a8743f"))
