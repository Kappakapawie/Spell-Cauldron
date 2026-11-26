extends SceneTree

## Headless check: run with
##   godot --headless --fixed-fps 60 --path . --script res://tests/smoke_test.gd
## Generates puzzles on every level and solves one word per level through the real game scene.

var failures := 0


func _initialize() -> void:
	_check_stairs()
	_check_puzzles()
	_check_gameplay.call_deferred()


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: ", msg)


## One thing gets harder at a time: a new number of letters starts with the gaps shown, for at least
## two books, and is then played with the gaps hidden for at least two.
func _check_stairs() -> void:
	var books := GameData.LEVELS
	if books[0].missing_max != 1 or not books[0].gaps_visible:
		_fail("book 1 should have 1 missing letter with the gap shown")
	var run := 1
	for i in range(1, books.size()):
		var a: Dictionary = books[i - 1]
		var b: Dictionary = books[i]
		var more: int = b.missing_max - a.missing_max
		if b.missing_min != b.missing_max or more < 0 or more > 1:
			_fail("book %d goes from %d to %d letters" % [i + 1, a.missing_max, b.missing_max])
		if more == 1 and (a.gaps_visible or not b.gaps_visible):
			_fail("book %d gets a new letter, so its gaps should be shown (and hidden before)" % (i + 1))
		if more == 0 and b.gaps_visible and not a.gaps_visible:
			_fail("book %d shows gaps again without a new letter" % (i + 1))
		if more == 0 and a.gaps_visible == b.gaps_visible:
			run += 1
		else:
			if run < 2 and i > 1:  # one book with 1 letter shown is enough
				_fail("only %d book before the step to book %d" % [run, i + 1])
			run = 1
		var fewest: int = a.decoys - (1 if more == 1 else 0)  # a new letter may come with one wrong letter fewer
		if b.decoys < fewest or b.decoys > a.decoys + 1 or b.min_len < a.min_len:
			_fail("book %d: wrong letters or word lengths jump" % (i + 1))
		if b.decoys > a.decoys and (more == 1 or a.gaps_visible != b.gaps_visible):
			_fail("book %d gets more wrong letters in the same step" % (i + 1))
		if GameData.missing_span(b) != Vector2i(b.missing_min, b.missing_max):
			_fail("book %d has words too short for %d missing letters" % [i + 1, b.missing_max])
	print("staircase of books ok")


func _check_puzzles() -> void:
	var everything: Array = GameData.all_words()
	if GameData.THEMES.size() < 10:
		_fail("need at least 10 themes, have %d" % GameData.THEMES.size())
	for t in GameData.THEMES:
		if GameData.THEMES[t].size() < 20:
			_fail("theme %s has only %d words" % [t, GameData.THEMES[t].size()])
	print("%d themes, %d words" % [GameData.THEMES.size(), everything.size()])
	for lvl in GameData.LEVELS.size():
		var settings: Dictionary = GameData.LEVELS[lvl]
		for i in 40:
			var entry: Array = everything[randi() % everything.size()]
			var p := PuzzleMaker.make(entry, settings)
			var word: String = p.word
			var tiles: Array = p.tiles.duplicate()
			if p.missing.size() > GameData.most_missing(word.length()):
				_fail("book %d takes %d letters out of %s" % [lvl + 1, p.missing.size(), word])
			if tiles.size() > 16:
				_fail("book %d puts %d letters on the table" % [lvl + 1, tiles.size()])
			for idx in p.missing:
				var at := tiles.find(word[idx])
				if at < 0:
					_fail("level %d word %s: missing letter %s not on table" % [lvl + 1, word, word[idx]])
				else:
					tiles.remove_at(at)
	print("puzzle check done")


## Every theme can brew every book twice without a repeated word, and a whole playthrough of all
## books with rolled themes has no repeats at all.
func _check_themes(main: Node) -> void:
	for t in GameData.THEMES:
		if not GameData.THEME_ICONS.has(t):
			_fail("theme %s has no icon" % t)
		for n in range(1, GameData.LEVELS.size() + 1):
			var settings: Dictionary = GameData.LEVELS[n - 1]
			var dealer := WordDealer.new()
			var used := {}
			for round_number in 2:
				if not dealer.has_enough(t, settings):
					_fail("theme %s has too few words for book %d" % [t, n])
				for e in dealer.pick(t, settings):
					if not (e in GameData.THEMES[t]):
						_fail("theme %s book %d picked a word from another theme: %s" % [t, n, e[0]])
					if GameData.length_distance(String(e[0]).length(), settings) > 0:
						_fail("theme %s book %d: %s has the wrong length" % [t, n, e[0]])
					if used.has(e[0]):
						_fail("theme %s book %d played again repeats %s" % [t, n, e[0]])
					used[e[0]] = true
					dealer.mark_seen(t, e[0])
			if used.size() != 2 * GameData.word_count(n):
				_fail("theme %s book %d gave %d words in two rounds" % [t, n, used.size()])
			# However often it is played: always filled, never a word twice in one go.
			for i in 4:
				var again := {}
				for e in dealer.pick(t, settings):
					again[e[0]] = true
					dealer.mark_seen(t, e[0])
				if again.size() != GameData.word_count(n):
					_fail("theme %s book %d repeats a word within itself" % [t, n])
	var old_dealer: WordDealer = main.dealer
	var repeats := 0
	for run in 10:
		main.dealer = WordDealer.new()
		main.theme_order = []
		var used := {}
		for n in range(1, GameData.LEVELS.size() + 1):
			var t: String = main._roll_themes(n, 1, [])[0]
			for e in main.dealer.pick(t, GameData.LEVELS[n - 1]):
				if used.has(e[0]):
					repeats += 1
				used[e[0]] = true
				main.dealer.mark_seen(t, e[0])
		# What was seen survives the save file.
		var copy := WordDealer.new()
		copy.from_save(main.dealer.to_save())
		if str(copy.to_save()) != str(main.dealer.to_save()):
			_fail("the seen words change when saved and loaded")
	main.dealer = old_dealer
	print("playing all books ten times: %d of %d words came back" % [repeats, 10 * GameData.total_words()])
	if repeats > 10 * GameData.total_words() / 100:
		_fail("too many words came back")
	# Themes: one at a time, or three with rerolls, also when every word was seen: long rests, evenly spread.
	for setting in [[1, 6], [2, 4], [3, 3]]:
		for tired in [false, true]:
			main.dealer = WordDealer.new()
			if tired:
				for t in ["Animals", "At home", "Ocean & sea", "Universe", "Food & kitchen", "School & words"]:
					for e in GameData.THEMES[t]:
						main.dealer.mark_seen(t, e[0])
			main.theme_order = []
			var count: int = setting[0]
			var last_seen := {}
			var times := {}
			var shown := 0
			var offer: Array = []
			for i in 300:
				offer = main._roll_themes(1, count, offer)
				var now := shown
				for t in offer:
					if last_seen.has(t) and now - int(last_seen[t]) <= int(setting[1]):
						_fail("%s came back after %d other themes (%d at a time)" % [t, now - int(last_seen[t]) - 1, count])
					times[t] = times.get(t, 0) + 1
				for t in offer:
					last_seen[t] = now
				shown += count
			var fair := 300.0 * count / GameData.THEMES.size()
			for t in GameData.THEMES:
				if absf(times.get(t, 0) - fair) > fair * 0.2:
					_fail("%s was shown %d times instead of about %d" % [t, times.get(t, 0), fair])
	main.dealer = old_dealer
	main.theme_order = []
	var in_theme := {}
	for e in GameData.all_words():
		if in_theme.has(e[0]):
			_fail("%s is in the word list twice" % e[0])
		in_theme[e[0]] = true
		if String(e[1]).to_lower().contains(e[0]):
			_fail("the meaning of %s gives it away" % e[0])
	print("themes: long rests, evenly spread, hardly a repeated word")


## The phone version: wider, with bigger things to touch at the sides; nothing hidden or on top of something else.
func _check_phone() -> void:
	var window := root
	for size in [Vector2i(1560, 720), Vector2i(1600, 720), Vector2i(1280, 720)]:
		window.size = size
		ScreenLayout.forced = true
		var main: Node = load("res://scenes/main.tscn").instantiate()
		main.persist = false
		root.add_child(main)
		await process_frame
		var all := ScreenLayout.rect()
		var wide: bool = size.x > 1300
		if not ScreenLayout.phone or absf(all.size.x / all.size.y - size.x / float(size.y)) > 0.02 or (ScreenLayout.touch() > 1.3) != wide or (ScreenLayout.icons() > 1.4) != wide:
			_fail("phone %s shows %s" % [size, all])
		if main.ui_layer.offset != ScreenLayout.extra or main.get_viewport().canvas_transform.origin != ScreenLayout.extra:
			_fail("phone %s: the game is not in the middle" % size)
		main.tutorial = main.Tutorial.DONE
		main.potions_known = {PotionArt.WISDOM: true, PotionArt.VISION: true}
		main.owned_upgrades = {"familiar": 1, "cat": 1, "mouse": 1, "raven": 1, "chameleon": 1, "raccoon": 1, "frog": 1, "hourglass": 1}
		main._start_level(29)
		await create_timer(0.5).timeout
		var reach := 36.0 * ScreenLayout.icons()
		var pets: Array[Vector2] = [main.familiar_pos, main.cat_pos, main.mouse_pos, main.raven_pos, main.chameleon_pos, main.raccoon_pos, main.frog_pos]
		for i in pets.size():
			if not all.grow(-reach).has_point(pets[i]) or pets[i].y + reach > 600:
				_fail("phone %s: pet %d is at %s" % [size, i, pets[i]])
			if main._in_cauldron(pets[i] + Vector2(reach, 0)):
				_fail("phone %s: pet %d is in the cauldron" % [size, i])
			for k in i:
				if pets[i].distance_to(pets[k]) < reach * 2.0:
					_fail("phone %s: pets %d and %d overlap" % [size, i, k])
		var buttons: Array = [main.shop_button] + main.potion_buttons.values()
		for b: Button in buttons:
			var r := b.get_global_rect()
			if not all.encloses(r) or r.size.y < 60.0 or r.size.x < 115.0:
				_fail("phone %s: the button %s is at %s" % [size, b.text, r])
			for other: Button in buttons:
				if other != b and r.intersects(other.get_global_rect()):
					_fail("phone %s: buttons overlap" % size)
		for t: LetterTile in main.tiles:
			if absf(t.scale.x - ScreenLayout.touch()) > 0.02 or not all.grow(-30).has_point(t.home_position):
				_fail("phone %s: a letter at %s has size %.2f" % [size, t.home_position, t.scale.x])
		# A letter is lifted above the finger, and lands where you see it.
		main._start_level(1)
		await process_frame
		var word: String = main.puzzle.word
		var tile: LetterTile
		for t: LetterTile in main.tiles:
			if t.letter == word[main.puzzle.missing[0]]:
				tile = t
		var finger: Vector2 = tile.position
		main._begin_drag(tile, finger)
		if tile.position.y > finger.y - 40.0:
			_fail("phone: the finger hides the letter")
		finger = main._target_of(main.row[main.puzzle.missing[0]]) + Vector2(0, 58)
		main._drag_to(finger)
		main._drop()
		if main._spelling() != word:
			_fail("phone: the letter was not placed where you see it")
		# Everything behind an open screen is out of reach, also at the sides.
		for overlay: Control in [main.pause_menu, main.shop_panel, main.complete_panel, main.picker, main.frog, main.start_choice]:
			if not overlay._has_point(all.position + Vector2(5, 5)) or not overlay._has_point(all.end - Vector2(5, 5)):
				_fail("phone: the sides of %s can be touched through" % overlay)
		main._open_shop()
		await process_frame
		var book: SpellBook = main.shop_panel
		if not all.encloses(book.BOOK) or book.node_at(book.node_global_pos("frog")) != "frog":
			_fail("phone: the spell book is off the screen")
		for id in ["more_sand", "theme:Time & calendar", "raccoon_speed", "themes"]:  # all can be dragged into view
			var c: Vector2 = book.node_center(id)
			var inside := Rect2(Vector2(60, 50), book.canvas.size - Vector2(120, 110))
			var need := c.clamp(inside.position, inside.end) - c
			if absf(need.x) > book.MAX_PAN.x or absf(need.y) > book.MAX_PAN.y:
				_fail("phone: %s can't be dragged into view" % id)
		_press_spell(book, "cat", true)
		_press_spell(book, "cat", false)
		if book.hover_id != "cat":
			_fail("phone: a tap does not explain a spell")
		if not ScreenLayout.say("Click it, or hold the mouse on it").begins_with("Tap it, or hold your finger"):
			_fail("phone: it still talks about the mouse")
		main.queue_free()
		await process_frame
	ScreenLayout.forced = false
	ScreenLayout.phone = false
	ScreenLayout.extra = Vector2.ZERO
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.size = Vector2i(1280, 720)
	root.canvas_transform = Transform2D.IDENTITY
	await process_frame
	print("phone ok")


func _check_gameplay() -> void:
	await _check_phone()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.persist = false  # never touch the player's real save
	if main.score != 100:
		_fail("a new game starts with %d knowledge" % main.score)
	main.score = 0
	if main.themes_owned != ["Animals", "Witchcraft & magic"]:
		_fail("a new game knows the themes %s" % [main.themes_owned])
	main.themes_owned = GameData.THEMES.keys()  # buying them has its own check
	main.tutorial = main.Tutorial.DONE  # the first mission has its own check
	if main.potions_known != {PotionArt.WISDOM: false, PotionArt.VISION: false}:
		_fail("a new game knows the potions already")
	main.always_words = {}  # OWL and CAT in every Animals book have their own check
	main.potions_known = {PotionArt.WISDOM: true, PotionArt.VISION: true}  # learning them has its own check
	main.spelled = {"eye": true, "curious": true, "condense": true, "orchard": true, "moon": true, "cheese": true, "slow": true, "kettle": true, "immediately": true, "hourglass": true, "wisdom": true, "vision": true, "owl": true, "cat": true, "mouse": true, "raven": true, "frog": true, "chameleon": true, "raccoon": true}
	root.add_child(main)
	await process_frame
	await _check_menus(main)
	var session_theme: String = main.theme
	_check_themes(main)
	main.theme = session_theme
	for lvl in [1, 3, 4, 9]:
		main._start_level(lvl)
		await process_frame
		var word: String = main.puzzle.word
		# Wrong attempt first (only if a decoy exists), then the correct one.
		_solve(main, word, true)
		await main._stir()
		if main.word_number != 0:
			_fail("level %d: wrong answer advanced the game" % lvl)
		# Potions: drinking costs potions; brewing the word earns some.
		main.potions = {PotionArt.WISDOM: 10, PotionArt.VISION: 10}
		var cost: int = main._potion_cost()
		main._drink_vision()
		main._drink_wisdom()
		if main.potions[PotionArt.VISION] != 10 - cost or main.potions[PotionArt.WISDOM] != 10 - cost:
			_fail("level %d: drinking did not cost %d potions" % [lvl, cost])
		# Fill both shelves: every reward potion must turn into score points.
		main.potions = main.shelf_slots.duplicate()
		var score_before: int = main.score
		var before: int = main.potions[PotionArt.VISION] + main.potions[PotionArt.WISDOM]
		var reward: int = main._potion_reward()
		_solve(main, word, false)
		if main._spelling() != word:
			_fail("level %d: spelled %s, expected %s" % [lvl, main._spelling(), word])
		await main._stir()
		var after: int = main.potions[PotionArt.VISION] + main.potions[PotionArt.WISDOM]
		if after != before:
			_fail("level %d: potions went over the cap (%d -> %d)" % [lvl, before, after])
		if main.score != score_before + reward * main.POINTS_PER_POTION:
			_fail("level %d: expected +%d points, got +%d" % [lvl, reward * main.POINTS_PER_POTION, main.score - score_before])
		# With empty shelves, rewards go to the shelves; only a full shelf overflows into points.
		main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
		var score_mid: int = main.score
		main._award_potions()
		var on_shelves: int = main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION]
		var overflow: int = (main.score - score_mid) / main.POINTS_PER_POTION
		if on_shelves + overflow != main._potion_reward() \
				or (overflow > 0 and on_shelves != main.shelf_slots[PotionArt.WISDOM] \
					and main.potions[PotionArt.WISDOM] != main.shelf_slots[PotionArt.WISDOM] \
					and main.potions[PotionArt.VISION] != main.shelf_slots[PotionArt.VISION]):
			_fail("level %d: rewards with empty shelves: %d on shelves, %d overflowed" % [lvl, on_shelves, overflow])
		if main.word_number != 1:
			_fail("level %d: correct answer did not advance (word %s)" % [lvl, word])
		else:
			print("level %d ok: %s" % [lvl, word])
	# Wisdom snippets: partial first, full meaning after all steps.
	main._start_level(6)
	await process_frame
	main.potions = {PotionArt.WISDOM: 10, PotionArt.VISION: 10}
	main._drink_wisdom()
	var first: String = main._meaning_snippet()
	if not first.contains("…"):
		_fail("first Wisdom potion revealed everything: %s" % first)
	if main._wisdom_steps() != 2:
		_fail("book 6 has 2 missing letters, so 2 Wisdom buys, not %d" % main._wisdom_steps())
	for i in main._wisdom_steps():
		main.potions[PotionArt.WISDOM] = 10  # level 7 costs 3 per drink
		main._drink_wisdom()
	if main._meaning_snippet() != main.puzzle.meaning:
		_fail("all Wisdom potions did not reveal the full meaning")
	print("snippet after 1 potion: ", first)

	# A perfect level 1 run (no potions drunk) conquers it, even starting with empty shelves.
	main._start_level(1)
	await process_frame
	main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
	await _play_level(main)
	var rec: Dictionary = main.level_records.get(1, {})
	if rec.is_empty() or not rec.conquered or rec.best != 10.0:
		_fail("perfect level 1 run was not recorded as 10 and conquered: %s" % rec)
	else:
		print("book 1 mastered with ", rec.best, " points")

	# One Vision potion on one word: that word gives 0.5 -> 9.5, not conquered.
	main._start_level(2)
	await process_frame
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	await _play_level(main, ["vision"])
	_expect_level(main, 2, 9.5)

	# Vision + Wisdom on one word: that word gives 0 -> 9. Drinking twice costs no more.
	main._start_level(3)
	await process_frame
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	await _play_level(main, ["vision", "wisdom", "wisdom"])
	_expect_level(main, 3, 9.0)
	await _check_helpers(main)

	# Shelves menu: buying a slot spends score and adds room.
	main.score = 100
	var price: int = main._slot_price(PotionArt.WISDOM)
	main._buy_slot(PotionArt.WISDOM)
	if main.shelf_slots[PotionArt.WISDOM] != main.START_SLOTS + 1 or main.score != 100 - price:
		_fail("buying a slot: slots %d, score %d" % [main.shelf_slots[PotionArt.WISDOM], main.score])
	else:
		print("bought a Wisdom slot for ", price, " points")

	await _check_mixed(main)
	await _check_mystery(main)
	await _check_first_mission(main)
	await _check_theme_shop(main)
	await _check_unlocks(main)
	await _check_potion_spells(main)
	await _check_frog_limit(main)
	await _check_always_words(main)
	await _check_potion_icons(main)
	await _check_raccoon(main)
	await _check_chameleon(main)
	await _check_names(main)
	await _check_mouse(main)
	await _check_raven(main)
	await _check_vision(main)
	await _check_hourglass(main)
	await _check_pocket_frog(main)
	await _check_owl(main)
	await _check_cat(main)

	# Discount and Lucky cauldron.
	main._start_level(9)
	await process_frame
	var full_cost: int = main._potion_cost()
	var reward: int = main._potion_reward()
	main.owned_upgrades["discount"] = 1
	main.owned_upgrades["lucky"] = 1
	if main._potion_cost() != full_cost - 1 or main._potion_reward() != reward + 1:
		_fail("discount/lucky: cost %d->%d, reward %d->%d" % [full_cost, main._potion_cost(), reward, main._potion_reward()])
	main._start_level(1)
	if main._potion_cost() != 1:
		_fail("discount must never make a drink free")
	print("discount and lucky cauldron ok")

	# Ctrl+click fills, Alt+click resets.
	main.owned_upgrades = {}
	main._start_level(1)
	await process_frame
	main._show_screen(main.Screen.LEVELS)
	await process_frame
	var star_col: Control = main.picker.cards[4]
	main._cheat_click(star_col.get_global_rect().get_center(), true)
	if not main.level_records.get(5, {}).get("conquered", false):
		_fail("ctrl+click on level 5 star did not conquer it")
	main._cheat_click(star_col.get_global_rect().get_center(), false)
	if main.level_records.has(5):
		_fail("alt+click on level 5 star did not clear it")
	main._start_level(1)
	await process_frame
	var shelf_row: Control = (main.shelves[PotionArt.VISION] as Control).get_parent()
	main._cheat_click(shelf_row.get_global_rect().get_center(), true)
	if main.potions[PotionArt.VISION] != main.shelf_slots[PotionArt.VISION]:
		_fail("ctrl+click on Vision row did not fill the shelf")
	main._cheat_click(shelf_row.get_global_rect().get_center(), false)
	if main.potions[PotionArt.VISION] != 0:
		_fail("alt+click on Vision row did not empty the shelf")
	main.score = 5
	main._cheat_click(main.score_label.get_global_rect().get_center(), true)
	if main.score != 1005:
		_fail("ctrl+click on score did not add 1000")
	main._open_shop()
	await process_frame
	var book: SpellBook = main.shop_panel
	# Every spell (circle, glow and the text under it) is on the page when the book opens.
	var page := Rect2(Vector2.ZERO, book.canvas.size)
	for n in main.SKILL_TREE:
		var c: Vector2 = book.node_center(n.id)
		if not page.encloses(Rect2(c - Vector2(75, 48), Vector2(150, 114))):
			_fail("spell %s is partly off the page at %s" % [n.id, c])
	main._cheat_click(book.node_global_pos("familiar"), true)
	main._cheat_click(book.node_global_pos("root"), true)
	if not (main.rank_of("familiar") > 0) or main.total_stars() != 290.0:
		_fail("ctrl+click in spell book: owl %s, stars %.1f" % [(main.rank_of("familiar") > 0), main.total_stars()])
	main._cheat_click(book.node_global_pos("root"), false)
	main._cheat_click(book.node_global_pos("familiar"), false)
	if (main.rank_of("familiar") > 0) or main.total_stars() != 0:
		_fail("alt+click in spell book did not reset")

	# Spell book: hovering shows gibberish until learned; buying works through skill_buy.
	var info: Dictionary = main.skill_info("hallucination")
	if SpellBook.garble(info.title, 0.0) == info.title or SpellBook.garble(info.title, 1.0) != info.title:
		_fail("spell names are not garbled / revealed correctly")
	main.level_records = {1: {"best": 10.0, "conquered": true}, 2: {"best": 10.0, "conquered": true},
		3: {"best": 10.0, "conquered": true}, 4: {"best": 10.0, "conquered": true}, 5: {"best": 10.0, "conquered": true},
		6: {"best": 10.0, "conquered": true}, 7: {"best": 10.0, "conquered": true}, 8: {"best": 10.0, "conquered": true}}
	main.score = 1000
	# The cauldron in the middle is the upgrade for more potions.
	if not main.skill_info("root").understood or not main.skill_info("root").can_buy:
		_fail("the cauldron can't be improved: %s" % main.skill_info("root"))
	for n in main.SKILL_TREE:
		if n.id == "lucky":
			_fail("Lucky cauldron still has a spell of its own")
	if not main.skill_buy("root") or main.rank_of("lucky") != 1 or main.score != 775:
		_fail("improving the cauldron in the spell book failed")
	if not main.skill_buy("vision_shelf") or main.shelf_slots[PotionArt.VISION] != main.START_SLOTS + 1:
		_fail("learning a Vision shelf slot in the spell book failed")
	print("spell book: garble, learn spells ok (", SpellBook.garble("Lucky cauldron", 0.0), ")")
	await _check_partial_reveal(main, book)
	main.owned_upgrades = {}
	main.level_records = {}
	main.shelf_slots = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	book.close_book()

	# Stirring: a short swipe to the right does nothing, a swipe left across the brew stirs.
	main._start_level(1)
	await process_frame
	main._start_stir(Vector2(700, 380))
	main._stir_motion(Vector2(800, 380))
	if main.busy:
		_fail("swiping right started a stir")
	main._stop_stirring()
	main._start_stir(Vector2(760, 380))
	main._stir_motion(Vector2(560, 380))
	if not main.busy:
		_fail("swiping left across the brew did not stir")
	await create_timer(1.6).timeout

	print("swipe to stir ok")
	main._start_level(7)
	await process_frame
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	if not main.complete_panel.visible or main.level_records.get(main.level, {}).get("best", 0) != 10.0:
		_fail("ctrl+click on word counter did not finish the book with 10")
	print("ctrl/alt shortcuts ok")

	# Ranked spells: prices grow, owl speed needs the owl, ranks stop at max.
	main.owned_upgrades = {}
	main.level_records = {}
	for n in range(1, 11):
		main.level_records[n] = {"best": 10.0, "conquered": true}
	main.score = 100000
	if main.skill_buy("owl_speed"):
		_fail("Swift wings could be learned before the owl")
	main.skill_buy("familiar")
	var prices: Array = []
	for i in 12:
		prices.append(main._upgrade_price("owl_speed"))
		main.skill_buy("owl_speed")
	if main.rank_of("owl_speed") != 10 or absf(main.familiar_interval() - 10.0) > 0.01:
		_fail("Swift wings: rank %d, interval %.1f" % [main.rank_of("owl_speed"), main.familiar_interval()])
	if prices[1] <= prices[0] or prices[9] <= prices[5]:
		_fail("Swift wings prices should keep growing: %s" % [prices])
	print("swift wings prices: ", prices.slice(0, 10), " -> owl every ", main.familiar_interval(), " s")
	# Quick paws: the same for the cat, and neither speeds up the other.
	if main.skill_buy("cat_speed"):
		_fail("Quick paws could be learned before the cat")
	main.skill_buy("cat")
	if main.cat_interval() != 8.0:
		_fail("a new cat should swipe every 8 s, not %.1f" % main.cat_interval())
	for i in 12:
		main.skill_buy("cat_speed")
	if main.rank_of("cat_speed") != 10 or absf(main.cat_interval() - 3.0) > 0.01:
		_fail("Quick paws: rank %d, interval %.1f" % [main.rank_of("cat_speed"), main.cat_interval()])
	if absf(main.familiar_interval() - 10.0) > 0.01:
		_fail("Quick paws changed the owl: %.1f" % main.familiar_interval())
	# Keen eyes, and no pet has more than one rank.
	main.owned_upgrades["raven"] = 1
	for i in 12:
		main.skill_buy("raven_speed")
	if main.rank_of("raven_speed") != 10 or main.pet_interval("raven") != 10.0:
		_fail("Keen eyes rank %d: the raven every %.1f s" % [main.rank_of("raven_speed"), main.pet_interval("raven")])
	for u in main.UPGRADES:
		if u.has("spell") and int(u.max) != 1 and u.id in ["frog", "familiar", "cat", "raven", "mouse", "chameleon", "raccoon"]:
			_fail("%s has %d ranks" % [u.name, u.max])
	# Whispering sage / Clear sight shorten the reveal steps (never below 1).
	main._start_level(8)
	while String(main.puzzle.meaning).split(" ").size() < 3:  # a meaning of 1 or 2 words has no step to lose
		main._start_level(8)
	await process_frame
	var base_steps: int = main._wisdom_steps()
	main.skill_buy("sage")
	main.skill_buy("sight")
	if main._wisdom_steps() != base_steps - 1 or main._vision_steps() != main.puzzle.missing.size() - 1:
		_fail("sage/sight did not remove a step")
	main.skill_buy("sage")
	main.skill_buy("sage")
	if main.rank_of("sage") != 2:
		_fail("sage went past its max rank")
	await _check_pets(main)
	print("ranked spells, sage/sight ok")

	print("RESULT: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)


## Title -> level picker -> level -> pause -> back, and the end-of-level screen.
func _check_menus(main: Node) -> void:
	if not main.title_screen.visible or main.hud.visible or main.picker.visible:
		_fail("the game should open on the title screen")
	# A level can't be touched from the title, but stirring there opens the picker.
	main._start_stir(Vector2(760, 380))
	main._stir_motion(Vector2(560, 380))
	await create_timer(1.3).timeout
	if not main.picker.visible or main.title_screen.visible:
		_fail("stirring on the title screen did not open the level picker")
	main._go_back()
	if not main.title_screen.visible:
		_fail("Esc on the level picker did not go back to the title")
	main.title_screen.play_pressed.emit()
	if not main.picker.cards[0].suggested or main.picker.cards[1].suggested:
		_fail("level 1 should be suggested to a new player")
	main.picker.cards[2].pressed.emit()
	await process_frame
	if main.level != 3 or not main.frog.visible or main.picker.visible or main.hud.visible:
		_fail("clicking the third book did not bring up the frog")
	await _check_frog(main)
	if main.level != 3 or not main.hud.visible or main.frog.visible or main.puzzle.is_empty():
		_fail("the third book did not start after the frog")

	# Pause: everything stands still, and the word is still there afterwards.
	var word: String = main.puzzle.word
	main._open_pause()
	if not paused or not main.pause_menu.visible:
		_fail("the pause menu did not stop the game")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	if paused or main.pause_menu.visible or main.puzzle.word != word:
		_fail("Esc did not close the pause menu and keep the word")
	esc = InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	if not paused:
		_fail("Esc during a level did not pause it")
	main.pause_menu.title_pressed.emit()
	if paused or not main.title_screen.visible or not main.puzzle.is_empty():
		_fail("leaving a level from the pause menu failed")

	# Leaving while a word is being brewed must not start another word (or crash), right or wrong.
	for wrong in [false, true]:
		for wait in [0.3, 1.5, 1.9]:
			main._start_level(1)
			await process_frame
			_solve(main, main.puzzle.word, wrong)
			main._stir()
			await create_timer(wait).timeout
			main._open_pause()
			await create_timer(0.1).timeout
			main.pause_menu.levels_pressed.emit()
			await create_timer(2.2).timeout
			if not main.picker.visible or main.hud.visible or not main.puzzle.is_empty() or main.busy:
				_fail("leaving a level mid-brew (wrong=%s, %.1f s) did not stay on the picker" % [wrong, wait])

	# A brew that is paused halfway waits for the player.
	main._start_level(1)
	await process_frame
	_solve(main, main.puzzle.word, false)
	main._stir()
	await create_timer(1.6).timeout
	main._open_pause()
	await create_timer(2.5).timeout
	if main.word_number != 0:
		_fail("the next word started while the game was paused")
	main.pause_menu.close()
	await create_timer(2.5).timeout
	if main.word_number != 1 or main.word_results.size() != 1:
		_fail("the paused brew did not carry on: word %d" % main.word_number)

	# End of level: lists the words, announces spells, and offers the right buttons.
	main.level_records = {1: {"best": 10.0, "conquered": true}}
	main._start_level(29)
	await process_frame
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	var done: LevelComplete = main.complete_panel
	if not done.visible or done.next_button.visible:
		_fail("book 29 should end without a Next button")
	if done._grid.get_child_count() != GameData.WORDS_PER_LEVEL:
		_fail("the end screen lists %d words" % done._grid.get_child_count())
	if not done.unlock_label.text.contains("Potion discount") or not done.unlock_label.text.contains("Cat familiar") \
			or done.unlock_label.text.contains("sage") or done.unlock_label.text.contains("Owl"):
		_fail("going from 10 to 20 stars should announce the discount and the cat: %s" % done.unlock_label.text)
	var all_spelled: Dictionary = main.spelled
	main.spelled = {"orchard": true}
	main.level_records = {1: {"best": 10.0, "conquered": true}}
	main._show_level_complete()
	if not done.unlock_label.text.contains("Potion discount") or done.unlock_label.text.contains("Cat familiar"):
		_fail("spells whose word was not spelled are announced: %s" % done.unlock_label.text)
	main.spelled = all_spelled
	done.levels_pressed.emit()
	if not main.picker.visible or done.visible or not main.picker.cards[28].star.conquered 			or not main.picker.cards[1].suggested:
		_fail("the picker does not show the new star after a level")
	main.level_records = {}
	main.score = 0
	print("menus ok")


## Owl, cat and raven help by themselves after their cooldown, one at a time; a click pauses.
func _check_pets(main: Node) -> void:
	main.pets_paused = {}
	for id in ["familiar", "cat", "raven", "raccoon"]:
		var count := func() -> int:
			if id == "familiar":
				return _revealed(main)
			if id == "raccoon":
				return main.puzzle.tiles.size() - main.tiles.size()
			return main.cat_splits.values().reduce(func(p: int, q: int) -> int: return p + q, 0) if id == "cat" else main.raven_spots.size()
		var book := 15 if id == "raven" else 19  # 4 letters to find; gaps shown / hidden
		for rank in [1]:
			main.owned_upgrades = {id: rank}
			main._start_level(book)
			await create_timer(1.7).timeout
			if count.call() != 0 or main.pet_time[id] < 1.0 or main.pet_time[id] > 3.0:
				_fail("%s: at the start of a book it helped %d times, cooldown %.1f s" % [id, count.call(), main.pet_time[id]])
			main.pet_time[id] = main.pet_interval(id) - 0.1
			await create_timer(1.2).timeout
			if count.call() != rank or main.pet_time[id] > 1.6:
				_fail("%s rank %d helped with %d after its cooldown" % [id, rank, count.call()])
		if main.word_score() != 1.0:
			_fail("%s costs score" % id)
		# Paused: no help and no progress lost; awake again it carries on.
		main.owned_upgrades = {id: 1}
		main._start_level(book)
		await create_timer(1.6).timeout
		main._toggle_pet(id)
		main.pet_time[id] = main.pet_interval(id) - 0.2
		var before: float = main.pet_time[id]
		await create_timer(0.6).timeout
		if main.pet_time[id] != before or count.call() != 0:
			_fail("a sleeping %s went on" % id)
		main._toggle_pet(id)
		await create_timer(0.9).timeout
		if count.call() != 1:
			_fail("%s did not carry on after waking up" % id)
	# The cooldown runs on to the next word; not in the spell book or while paused; nothing to do = it waits, ready.
	main.owned_upgrades = {"familiar": 1}
	main._start_level(19)
	await process_frame
	main.pet_time["familiar"] = 5.0
	_solve(main, main.puzzle.word, false)
	await main._stir()
	if main.word_number != 1 or main.pet_time["familiar"] < 5.0:
		_fail("the owl's cooldown started over with the next word: %.1f" % main.pet_time["familiar"])
	main._open_shop()
	var t: float = main.pet_time["familiar"]
	await create_timer(0.4).timeout
	if main.pet_time["familiar"] != t:
		_fail("the owl's cooldown runs while the spell book is open")
	main.shop_panel.close_book()
	main._open_pause()
	t = main.pet_time["familiar"]
	await create_timer(0.4).timeout
	if main.pet_time["familiar"] != t:
		_fail("the owl's cooldown runs while the game is paused")
	main.pause_menu.close()
	_solve(main, main.puzzle.word, false)
	main.pet_time["familiar"] = 19.9
	await create_timer(1.8).timeout
	if _revealed(main) != 0 or main.pet_time["familiar"] < 19.99:
		_fail("an owl with nothing to tell should wait, ready: %.1f" % main.pet_time["familiar"])
	# While a letter is being dragged the pets hold still.
	main._start_level(19)
	await create_timer(1.6).timeout
	main._begin_drag(main.tiles[0], main.tiles[0].position)
	main.pet_time["familiar"] = 19.9
	await create_timer(0.5).timeout
	if _revealed(main) != 0:
		_fail("the owl helped while a letter was being dragged")
	main._drop()
	await create_timer(0.5).timeout
	if _revealed(main) != 1:
		_fail("the owl did not help after the drag")
	# The mouse can be paused too.
	main.owned_upgrades = {"mouse": 1}
	main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
	main._toggle_pet("mouse")
	main.mouse_time = 29.9
	await create_timer(0.4).timeout
	if main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION] != 0 or main.mouse_time != 29.9:
		_fail("a sleeping mouse brought a potion")
	main._toggle_pet("mouse")
	await create_timer(0.4).timeout
	if main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION] != 1:
		_fail("the mouse did not carry on after waking up")
	# Not learned: no help.
	main.owned_upgrades = {}
	main._start_level(7)
	for id in main.pet_time:
		main.pet_time[id] = 100.0
	await create_timer(2.0).timeout
	if _revealed(main) > 0 or not main.cat_splits.is_empty() or not main.raven_spots.is_empty():
		_fail("a pet that was not learned helped")
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main.mouse_time = 0.0
	print("pets help by themselves and can be paused")


## The owl only points out letters that are surely needed; it never places them.
func _check_owl(main: Node) -> void:
	main.owned_upgrades = {"familiar": 1}
	for lvl in [1, 3, 5, 7, 9, 19, 29]:
		for attempt in 4:
			main._start_level(lvl)
			await process_frame
			var word: String = main.puzzle.word
			var before: String = main._spelling()
			var missing: Array = []
			for i in main.puzzle.missing:
				missing.append(word[i])
			missing.sort()
			var guard := 0
			while main._familiar_next_tile() != null and guard < 20:
				main._familiar_reveal()
				guard += 1
			var shown: Array = []
			for t in main.tiles:
				if t.revealed:
					shown.append(t.letter)
				if t.in_word:
					_fail("the owl placed a letter in %s" % word)
			shown.sort()
			if shown != missing:
				_fail("owl on level %d revealed %s for %s, missing %s" % [lvl, shown, word, missing])
			if main._spelling() != before:
				_fail("the owl changed the word: %s -> %s" % [before, main._spelling()])
			if main.word_score() != 1.0:
				_fail("owl-helped word gives %.2f points, expected 1" % main.word_score())
	# Nothing to tell: all needed letters are already in the word.
	main._start_level(7)
	await process_frame
	_solve(main, main.puzzle.word, false)
	if main._familiar_next_tile() != null:
		_fail("the owl has something to tell about a finished word")
	# One letter at a time with rank 1.
	main._start_level(7)
	await process_frame
	main._pet_help("familiar")
	var count := 0
	for t in main.tiles:
		count += 1 if t.revealed else 0
	if count != 1:
		_fail("a click on the owl revealed %d letters, expected 1" % count)
	# Full moon: now and then all of them at once.
	main.owned_upgrades = {"familiar": 1, "owl_all": 5}
	var all_at_once := 0
	for attempt in 200:
		main._start_level(29)
		main._pet_help("familiar")
		count = main.tiles.filter(func(t: LetterTile) -> bool: return t.revealed).size()
		if count != 1 and count != main.puzzle.missing.size():
			_fail("full moon: %d letters of %d" % [count, main.puzzle.missing.size()])
		if count == main.puzzle.missing.size():
			all_at_once += 1
		for t in main.tiles:
			if t.in_word:
				_fail("full moon placed a letter")
	if all_at_once < 6 or all_at_once > 40 or main.word_score() != 1.0:  # 20 expected
		_fail("full moon: all letters %d times of 200" % all_at_once)
	if main.skill_info("owl_all").status_text != "10%  (5/5)":
		_fail("full moon says %s" % main.skill_info("owl_all").status_text)
	main.owned_upgrades = {}
	if main.skill_buy("owl_all"):
		_fail("full moon without the owl")
	print("owl reveals only needed letters, places none")


## The cat only splits the word where letters are missing, and the split stays open.
func _check_cat(main: Node) -> void:
	main.owned_upgrades = {"cat": 1}
	for lvl in [1, 5, 15]:
		main._start_level(lvl)
		await process_frame
		if main._can_help("cat") or main._pet_help("cat"):
			_fail("the cat helped in book %d, where gaps are already shown" % lvl)
	for lvl in [2, 6, 7, 11, 13, 19, 29]:
		for attempt in 8:
			main._start_level(lvl)
			await process_frame
			var word: String = main.puzzle.word
			var missing: Array = main.puzzle.missing
			var given := word.length() - missing.size()
			var wanted := {}
			for i in missing:
				var before_it: int = i - missing.find(i)  # given letters before it
				wanted[before_it] = wanted.get(before_it, 0) + 1
			var guard := 0
			var end_seen := false
			while not main._cat_gaps().is_empty() and guard < 20:
				var g: int = main._cat_gaps().pick_random()
				var at_end := g == 0 or g == given
				if end_seen and not at_end:
					_fail("the cat used an end of %s before the spots between letters" % word)
				end_seen = end_seen or at_end
				var x_gap := 0.0
				if not at_end:
					x_gap = main._target_of(main.row[g]).x - main._target_of(main.row[g - 1]).x
				main._cat_split(g)
				if not wanted.has(g):
					_fail("the cat split %s at %d, where nothing is missing (%s)" % [word, g, missing])
				if not at_end and main._target_of(main.row[g]).x - main._target_of(main.row[g - 1]).x <= x_gap:
					_fail("the cat did not push the letters apart in %s" % word)
				guard += 1
			# Every missing letter gets its own space: as many uses, as many marks.
			if main.cat_splits != wanted or guard != missing.size() or main.claws.spots.size() != missing.size():
				_fail("cat on %s: %s in %d uses, %d marks, expected %s" % [word, main.cat_splits, guard, main.claws.spots.size(), wanted])
			for spot in main.claws.spots:
				if spot.x < 60 or spot.x > 1220:
					_fail("a claw mark is off the screen in %s: %s" % [word, spot])
				# Dropping a letter on the marks puts it exactly in that gap.
				if not main._over_word(spot):
					_fail("a letter can't be dropped on the claw mark of %s at %s" % [word, spot])
				elif not wanted.has(main._insert_index(spot.x)):
					_fail("a letter dropped on the claw mark lands in the wrong gap of %s" % word)
			if main.word_score() != 1.0:
				_fail("cat-helped word gives %.2f points, expected 1" % main.word_score())
			_solve(main, word, false)
			if not main.claws.spots.is_empty() or not main._cat_gaps().is_empty():
				_fail("filled gaps should have no claw marks: %s" % word)
			if main._spelling() != word:
				_fail("a split word spelled %s, expected %s" % [main._spelling(), word])
	# A gap you filled right is left alone, also if it was never split.
	main._start_level(7)
	await process_frame
	_solve(main, main.puzzle.word, false)
	if not main._cat_gaps().is_empty():
		_fail("the cat wants to split a word that is already right")
	# One paw at a time, never more than letters are missing.
	main._start_level(7)
	await process_frame
	if not main._pet_help("cat") or main.cat_aims.size() != 1 or not main._pet_help("cat") or main._pet_help("cat"):
		_fail("the cat sent more paws than letters are missing: %s" % main.cat_aims)
	await create_timer(1.2).timeout
	if main.claws.spots.size() != 2 or not main.cat_aims.is_empty():
		_fail("two paws made %d spaces" % main.claws.spots.size())
	await _check_cat_spaces(main)
	main._start_level(7)
	await process_frame
	main._cat_swipe(main._cat_gaps()[0])
	await create_timer(0.1).timeout
	main._stir()
	await create_timer(2.0).timeout
	if main.claws.spots.size() != 1 or main.busy:
		_fail("a swipe during a stir did not settle into one split")
	for item in main.row:
		if item.position.distance_to(main._target_of(item)) > 1.0:
			_fail("letters did not settle after a swipe during a stir")
	main._start_level(7)
	await process_frame
	# Leaving the level while the paw is in the air is harmless.
	main._cat_swipe(1)
	main._show_screen(main.Screen.LEVELS)
	await create_timer(0.8).timeout
	main._start_level(7)
	await process_frame
	if not main.cat_splits.is_empty() or not main.claws.spots.is_empty():
		_fail("an old swipe split a new word")
	# Owl and cat together cost no score.
	main.owned_upgrades = {"cat": 1, "familiar": 1}
	main._familiar_reveal()
	main._cat_split(main._cat_gaps()[0])
	if main.word_score() != 1.0:
		_fail("owl + cat gives %.2f points, expected 1" % main.word_score())
	main.owned_upgrades = {}
	print("cat splits only where letters are missing")


## TO_ _UE: both missing letters are in the same gap. Two spaces, filled one by one in any order.
func _check_cat_spaces(main: Node) -> void:
	for right_first in [false, true]:
		_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
		main._cat_split(main._cat_gaps()[0])
		if main._cat_gaps() != [2] or main.claws.spots.size() != 1:
			_fail("TO__UE: after one use the cat should have one more space to open: %s" % [main._cat_gaps()])
		main._cat_split(2)
		if not main._cat_gaps().is_empty() or main.claws.spots.size() != 2:
			_fail("TO__UE: two uses should show two spaces, not %d" % main.claws.spots.size())
		var first := "G" if right_first else "N"
		var second := "N" if right_first else "G"
		_drop_at(main, first, main.claws.spots[1 if right_first else 0])
		if main.claws.spots.size() != 1:
			_fail("TO__UE: one letter placed, %d spaces left" % main.claws.spots.size())
		var placed: Node2D = main.row[2]
		if (main.claws.spots[0].x < main._target_of(placed).x) != right_first:
			_fail("TO__UE: the space left is on the wrong side of %s" % first)
		# Taking it out again opens its space again, on the same side.
		main._begin_drag(placed, placed.position)
		if main.claws.spots.size() != 2:
			_fail("TO__UE: taking %s out left %d spaces" % [first, main.claws.spots.size()])
		main.dragged.position = main.claws.spots[1 if right_first else 0]
		main._drop()
		_drop_at(main, second, main.claws.spots[0])
		if main._spelling() != "TONGUE" or not main.claws.spots.is_empty():
			_fail("TO__UE: filling the spaces spelled %s, %d marks left" % [main._spelling(), main.claws.spots.size()])
		main._begin_drag(main.row[2], main.row[2].position)  # the left one out: the space is left of the other
		if main.claws.spots.size() != 1 or main.claws.spots[0].x > main._target_of(main.row[2]).x:
			_fail("TO__UE: taking out the left letter opened the wrong space")
		main.dragged.position = Vector2(100, 650)
		main._drop()
	# At the ends the cat taps, after the spots between letters are done.
	_set_puzzle(main, "TONGUE", [0, 3, 5], ["T", "G", "E", "X"])
	if main._cat_gaps() != [2]:
		_fail("_ON_U_: the cat should start between the letters, not at %s" % [main._cat_gaps()])
	for i in 3:
		main._pet_help("cat")
	await create_timer(1.4).timeout
	if main.claws.spots.size() != 3:
		_fail("_ON_U_: 3 uses gave %d spaces" % main.claws.spots.size())
	for i in 3:
		_drop_at(main, ["T", "G", "E"][i], main.claws.spots[0])
	if main._spelling() != "TONGUE":
		_fail("_ON_U_: letters dropped on the marks spell %s" % main._spelling())


## Puts a given word in the cauldron with these letters missing and on the table (hidden gaps).
func _set_puzzle(main: Node, word: String, missing: Array, letters: Array) -> void:
	main.owned_upgrades = {"cat": 1}
	main._start_level(7)
	main.session_words[0] = [word.to_lower(), "", ""]
	main._clear_word()
	main.puzzle = {"word": word, "meaning": "", "picture": "", "missing": missing, "tiles": letters, "gaps_visible": false}
	for i in word.length():
		if not (i in missing):
			var f := LetterTile.new(word[i], false)
			main.pieces.add_child(f)
			main.row.append(f)
	for letter in letters:
		var t := LetterTile.new(letter, true)
		main.pieces.add_child(t)
		main.tiles.append(t)
	main._layout_row(false)


func _drop_at(main: Node, letter: String, spot: Vector2) -> void:
	for t in main.tiles:
		if t.letter == letter and not t.in_word:
			main._begin_drag(t, t.position)
			t.position = spot
			main._drop()
			return


## The frog: one theme, potions to reroll it, no free rerolls, and the two frog spells.
## Starts on the frog screen of book 3 and ends with that book being brewed.
func _check_frog(main: Node) -> void:
	var frog: ThemeFrog = main.frog
	if not frog.busy:
		_fail("the frog is not coughing when a book is opened")
	await create_timer(1.1).timeout
	if frog.cards.size() != 1 or not frog.cards[0].disabled:
		_fail("a theme can be clicked while the frog is still coughing it up")
	await create_timer(2.5).timeout
	if frog.busy or frog.cards.size() != 1 or frog.cards[0].theme_name != main.book_offers[3][0] or frog.cards[0].disabled:
		_fail("the frog did not offer one theme: %s" % [main.book_offers])
	# Without the Hungry frog spell there is one theme and no feeding.
	main.owned_upgrades = {"frog_choice": 2, "frog_cheap": 3}
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main._update_frog()
	main.frog_uses = {}  # the limit has its own check
	main._reroll()
	if frog.reroll_button.visible or main.potions[PotionArt.WISDOM] != 9 or main._reroll_cost()[PotionArt.WISDOM] != 2:
		_fail("the frog can be fed without its spell")
	# Too few potions: nothing happens.
	main.owned_upgrades = {"frog": 1}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 1}
	main._update_frog()
	var first: String = frog.cards[0].theme_name
	main.frog_uses = {}  # the limit has its own check
	main._reroll()
	if not frog.reroll_button.disabled or main.potions[PotionArt.WISDOM] != 2 or main.book_offers[3] != [first]:
		_fail("the frog took potions you did not have")
	# 2 + 2 potions give another theme.
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	main._update_frog()
	if frog.reroll_button.disabled:
		_fail("the frog can't be fed with 3 + 3 potions")
	main.frog_uses = {}  # the limit has its own check
	main._reroll()
	main.frog_uses = {}  # the limit has its own check
	main._reroll()  # eating: a second click costs nothing
	if main.potions[PotionArt.WISDOM] != 1 or main.potions[PotionArt.VISION] != 1:
		_fail("a reroll should cost 2 + 2, left %s" % main.potions)
	await create_timer(4.0).timeout
	if frog.busy or frog.cards.size() != 1 or main.book_offers[3][0] == first or frog.cards[0].theme_name != main.book_offers[3][0]:
		_fail("feeding the frog did not give another theme: %s after %s" % [main.book_offers[3], first])
	# Going back and opening the book again is no free reroll; leaving mid-cough is harmless.
	var second: String = frog.cards[0].theme_name
	for wait in [0.1, 0.9, 1.3]:
		main._go_back()
		if not main.picker.visible or frog.visible:
			_fail("Esc on the frog screen did not go back to the books")
		main._open_book(3)
		await create_timer(wait).timeout
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	await create_timer(2.5).timeout
	if frog.cards.size() != 1 or frog.cards[0].theme_name != second:
		_fail("opening the book again changed its theme from %s to %s" % [second, main.book_offers[3]])
	main._update_frog()
	main.frog_uses = {}  # the limit has its own check
	main._reroll()
	await create_timer(0.35).timeout  # while the tongue is out
	main._go_back()
	await create_timer(1.0).timeout
	if frog._card_layer.get_child_count() != 0:
		_fail("cards were left behind when the frog was interrupted")
	# Frog buffet: two, then three themes to choose from, the ones already on offer included.
	var before: String = main.book_offers[3][0]
	main.owned_upgrades = {"frog": 1, "frog_choice": 1}
	main._open_book(3)
	await create_timer(3.0).timeout
	if frog.cards.size() != 2 or main.book_offers[3].size() != 2 or main.book_offers[3][0] != before:
		_fail("Frog buffet rank 1 offers %s" % [main.book_offers[3]])
	main.owned_upgrades = {"frog": 1, "frog_choice": 2}
	main._open_book(3)
	await create_timer(3.0).timeout
	var offer: Array = main.book_offers[3].duplicate()
	if frog.cards.size() != 3 or offer.size() != 3 or offer[0] != before:
		_fail("Frog buffet rank 2 offers %s" % [offer])
	if offer[0] == offer[1] or offer[1] == offer[2] or offer[0] == offer[2]:
		_fail("the frog offers the same theme twice: %s" % [offer])
	main.frog_uses = {}  # the limit has its own check
	main._reroll()
	await create_timer(5.0).timeout
	for t in main.book_offers[3]:
		if t in offer:
			_fail("a reroll of three themes brought %s back" % t)
	# Frog buffet and Frog snacks need the frog first; snacks: 4 potions, then 3, 2, 1.
	for n in range(1, 11):
		main.level_records[n] = {"best": 10.0, "conquered": true}
	main.score = 10000
	main.owned_upgrades = {}
	for id in ["frog_cheap", "frog_choice", "frog_more"]:
		if main.skill_buy(id) or not main.skill_info(id).hint.contains("Hungry frog"):
			_fail("%s could be learned before the frog" % id)
	if not main.skill_buy("frog") or not main.skill_buy("frog_cheap") or not main.skill_buy("frog_choice") or not main.skill_buy("frog_choice"):
		_fail("the frog spells could not be learned in order")
	if main.skill_buy("frog") or main.skill_buy("frog_choice"):
		_fail("a frog spell went past its max rank")
	main.score = 0
	main.level_records = {}
	for rank in 4:
		main.owned_upgrades = {"frog": 1, "frog_cheap": rank}
		var cost: Dictionary = main._reroll_cost()
		if cost[PotionArt.WISDOM] + cost[PotionArt.VISION] != 4 - rank:
			_fail("with Frog snacks rank %d a reroll costs %s" % [rank, cost])
	main.owned_upgrades = {}
	var picked: String = main.book_offers[3][1]
	if frog.cards[1].disabled:
		_fail("a theme card can't be clicked")
	frog.cards[1].pressed.emit()  # clicking a theme starts the book
	await process_frame
	if main.theme != picked or main.theme_order[-1] != picked:
		_fail("the book is brewed with %s instead of %s" % [main.theme, picked])
	for e in main.session_words:
		if not (e in GameData.THEMES[picked]):
			_fail("%s is not from theme %s" % [e[0], picked])
	# The offer stays until the book is finished, and "start over" keeps the theme.
	main.pause_menu.restart_pressed.emit()
	if main.theme != picked or not main.book_offers.has(3) or not main.hud.visible:
		_fail("starting over changed the theme")
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	if main.book_offers.has(3):
		_fail("a finished book kept its old theme")
	main.complete_panel.next_pressed.emit()
	if main.level != 4 or not main.frog.visible:
		_fail("Next recipes did not bring up the frog for book 4")
	# Page 1 holds all 29 books, page 2 the 20 mystery books.
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	if not main.picker.cards[0].visible or not main.picker.cards[28].visible or main.picker.cards[29].visible or main.picker.earlier.visible:
		_fail("page 1 should show books 1-29 only")
	main.picker.later.pressed.emit()
	if main.picker.cards[28].visible or not main.picker.cards[29].visible or not main.picker.cards[48].visible or main.picker.later.visible:
		_fail("the picker did not turn to the mystery books")
	if main.picker.cards.size() != 49 or main.picker.level_at(main.picker.cards[29].get_global_rect().get_center()) != 30:
		_fail("the mystery books are not on the shelves: %d books" % main.picker.cards.size())
	main.picker.earlier.pressed.emit()
	if not main.picker.cards[0].visible or main.picker.cards[29].visible:
		_fail("the picker did not turn back to page 1")
	# No two books on a page lie on top of each other.
	for a in range(0, 49):
		for b in range(a + 1, 49):
			if GameData.is_mystery(a + 1) == GameData.is_mystery(b + 1) \
					and main.picker.cards[a].get_global_rect().grow(-2).intersects(main.picker.cards[b].get_global_rect().grow(-2)):
				_fail("books %d and %d overlap on the shelf" % [a + 1, b + 1])
	main.level_records = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._open_book(3)
	await create_timer(2.5).timeout
	frog.cards[0].pressed.emit()
	await process_frame
	print("frog: themes, rerolls and choice ok")


## The little frog: swaps the theme and the word while playing, without leaving the book.
func _check_pocket_frog(main: Node) -> void:
	main.owned_upgrades = {}
	main.theme = "Animals"
	main.book_offers.erase(7)
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main._start_level(6)
	await process_frame
	var word: String = main.puzzle.word
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	if main.busy or main.potions[PotionArt.WISDOM] != 9 or main.pocket_frog.visible:
		_fail("the little frog works without its spell")
	# One word done, help used on the next: the frog swaps that word and the rest, not the score.
	main.owned_upgrades = {"frog": 1}
	main._update_potion_ui()
	_solve(main, word, false)
	await main._stir()
	main._drink_wisdom()
	var first: Array = main.session_words.duplicate()
	word = main.puzzle.word
	var before: Dictionary = main.potions.duplicate()
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()  # it is eating: no second payment
	main._drink_vision()      # nothing to look at now
	if main.potions[PotionArt.WISDOM] != before[PotionArt.WISDOM] - 2 or main.potions[PotionArt.VISION] != before[PotionArt.VISION] - 2:
		_fail("feeding the little frog should cost 2 + 2 once: %s -> %s" % [before, main.potions])
	await create_timer(4.0).timeout
	if main.theme == "Animals" or main.busy or main.swapping or main.puzzle.word == word:
		_fail("the little frog did not change the theme and the word (%s, %s)" % [main.theme, main.puzzle.get("word", "")])
	if main.word_number != 1 or main.session_words.size() != 10 or main.session_words[0] != first[0] or absf(main.plain_points - 1.0) > 0.001:
		_fail("the little frog touched what was brewed before")
	for e in main.session_words.slice(1):
		if not (e in GameData.THEMES[main.theme]):
			_fail("after the little frog, %s is not from %s" % [e[0], main.theme])
	if absf(main.word_score() - 0.5) > 0.001 or main.wisdom_level != 0:
		_fail("help used before the little frog should still count: %.2f" % main.word_score())
	if main.book_offers[6] != [main.theme] or not main.theme_label.visible or not main.theme_label.text.contains(main.theme):
		_fail("the theme shown or kept for the book is wrong: %s" % main.theme_label.text)
	_solve(main, main.puzzle.word, false)
	await main._stir()
	if main.word_number != 2 or absf(main.plain_points - 1.5) > 0.001:
		_fail("the swapped word gave %.2f points in all" % main.plain_points)
	# Too few potions: it refuses. During a stir: nothing.
	main.potions = {PotionArt.WISDOM: 1, PotionArt.VISION: 5}
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	if main.busy or main.potions[PotionArt.VISION] != 5:
		_fail("the little frog took potions you did not have")
	# With the buffet there are cards to choose from, in the middle of the game.
	main.owned_upgrades = {"frog": 1, "frog_choice": 2, "frog_cheap": 3}
	main.potions = {PotionArt.WISDOM: 5, PotionArt.VISION: 5}
	var old_theme: String = main.theme
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	await create_timer(4.0).timeout
	if main.theme_cards.get_child_count() != 3 or not main.theme_hint.visible or not main.hud.visible or main.theme != old_theme:
		_fail("the little frog did not offer three themes")
	if main.potions[PotionArt.WISDOM] != 4 or old_theme in main.book_offers[6]:
		_fail("three themes: %s, paid %s" % [main.book_offers[6], main.potions])
	# Opening the spell book meanwhile changes nothing; then choose.
	main._open_shop()
	await create_timer(0.2).timeout
	main.shop_panel.close_book()
	var card: ThemeFrog.ThemeCard = main.theme_cards.get_child(2)
	var want := card.theme_name
	card.pressed.emit()
	await create_timer(0.8).timeout
	if main.theme != want or main.busy or main.theme_hint.visible or main.theme_cards.get_child_count() != 0 or main.word_number != 2:
		_fail("choosing a theme from the little frog failed: %s instead of %s" % [main.theme, want])
	# Leaving or restarting at any moment is harmless, and the paid themes stay with the book.
	for wait in [0.1, 0.5, 0.9, 1.4, 2.2, 3.2]:
		main.potions = {PotionArt.WISDOM: 5, PotionArt.VISION: 5}
		main.frog_uses = {}  # the limit has its own check
		main._feed_pocket_frog()
		await create_timer(wait).timeout
		var offer: Array = main.book_offers[6].duplicate()
		main._open_pause()
		await create_timer(0.1).timeout
		if wait < 1.0:
			main.pause_menu.levels_pressed.emit()
			await create_timer(0.3).timeout
			if not main.picker.visible or main.swapping or main.busy:
				_fail("leaving while the little frog eats (%.1f s) failed" % wait)
		else:
			main.pause_menu.restart_pressed.emit()
		main._start_level(6)
		await create_timer(2.5).timeout
		if main.busy or main.swapping or main.puzzle.is_empty() or not main.theme_label.visible \
				or main.theme_label.scale != Vector2.ONE or main.theme_cards.get_child_count() != 0 or main.book_offers[6] != offer:
			_fail("something was left over from the little frog (%.1f s)" % wait)
	# Finishing the book (cheat) while it is eating.
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	await create_timer(0.8).timeout
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	await create_timer(2.5).timeout
	if not main.complete_panel.visible or main.swapping or main.theme_cards.get_child_count() != 0:
		_fail("the little frog spoiled the end of a book")
	main.owned_upgrades = {}
	main.level_records = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	print("little frog ok")


## The hourglass: one countdown for the whole book. In time = double, too late = as always; perfect still means no help.
func _check_hourglass(main: Node) -> void:
	main.owned_upgrades = {}
	main.level_records = {}
	main._start_level(1)
	await process_frame
	if main.sand_timer.visible or main.in_time():
		_fail("there is sand without the hourglass")
	main.owned_upgrades = {"hourglass": 1}
	main._start_level(1)
	await create_timer(0.5).timeout
	if not main.sand_timer.visible or main.sand_timer.total != 105.0 or main.sand_timer.left > 104.8 or main.sand_timer.left < 103.5:
		_fail("book 1 should give 105 s: %.1f of %.1f" % [main.sand_timer.left, main.sand_timer.total])
	# No sand runs in the spell book, while paused or while stirring.
	var before: float = main.sand_timer.left
	main._open_shop()
	before = main.sand_timer.left
	await create_timer(0.4).timeout
	if main.sand_timer.left != before:
		_fail("the sand runs while the spell book is open")
	main.shop_panel.close_book()
	main._open_pause()
	before = main.sand_timer.left
	await create_timer(0.4).timeout
	if main.sand_timer.left != before:
		_fail("the sand runs while the game is paused")
	main.pause_menu.close()
	# In time: 1 + 1 points. A last moment before the stir counts, however long the stirring takes.
	_solve(main, main.puzzle.word, false)
	main.sand_timer.left = 0.4
	await main._stir()
	if main.plain_points != 1.0 or main.time_points != 1.0 or not main.word_results[0].fast:
		_fail("a word in time should give 1 + 1: %.2f, %s" % [main.plain_points, main.word_results])
	if main.sand_timer.left > 0.4 or main.sand_timer.total != 105.0:
		_fail("the hourglass was turned over for the next word: %.1f" % main.sand_timer.left)
	# In time with help: the whole point for time.
	main.sand_timer.left = 50.0
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	main._drink_vision()
	_solve(main, main.puzzle.word, false)
	await main._stir()
	if absf(main.plain_points - 1.5) > 0.001 or main.time_points != 2.0:
		_fail("a helped word in time should give 0.5 + 1: %.2f + %.2f" % [main.plain_points, main.time_points])
	# Too late: nothing for time, and the hourglass stays empty for the rest of the book.
	main.sand_timer.left = 0.1
	await create_timer(0.4).timeout
	_solve(main, main.puzzle.word, false)
	await main._stir()
	if main.plain_points != 2.5 or main.time_points != 2.0 or main.word_results[2].fast:
		_fail("a word too late should give 1 + 0: %.2f + %.2f" % [main.plain_points, main.time_points])
	if main.sand_timer.left > 0.0 or main.in_time():
		_fail("a failed hourglass got new sand for the next word")
	while not main.complete_panel.visible:
		_solve(main, main.puzzle.word, false)
		await main._stir()
	var rec: Dictionary = main.level_records[1]
	if absf(rec.best - 11.5) > 0.001 or rec.plain != 9.5 or rec.time != 2.0 or rec.conquered:
		_fail("that run should be 9.5 + 2, not mastered: %s" % rec)
	main._start_level(1)
	await process_frame
	if main.sand_timer.left < 100.0 or not main.in_time():
		_fail("the hourglass is still empty in the next run")
	# The best of each counts, from different runs: first 10 by guessing without the hourglass...
	main.level_records = {}
	main.owned_upgrades = {}
	main._start_level(1)
	await process_frame
	await _play_level(main)
	if main.level_records[1].best != 10.0:
		_fail("a perfect run without the hourglass should be 10: %s" % main.level_records[1])
	# ...then a run full of help, but all in time: 10 + 10.
	main.owned_upgrades = {"hourglass": 1}
	main._start_level(1)
	await process_frame
	while not main.complete_panel.visible:
		main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
		main._drink_vision()
		main._drink_wisdom()
		_solve(main, main.puzzle.word, false)
		await main._stir()
	if main.plain_points != 0.0 or main.level_records[1].best != 20.0 or not main.level_records[1].conquered:
		_fail("0 + 10 in time after a perfect 10 should make 20: %s" % main.level_records[1])
	if not main.complete_panel.message_label.text.contains("Best: 10 + 10") or not main.complete_panel.message_label.text.contains("0 + 10 in time"):
		_fail("the end screen says: %s" % main.complete_panel.message_label.text)
	# The big moment: the hourglass pours its 10 stars, then the end screen follows; a click skips it.
	var finale: BookFinale = main.complete_panel.finale
	if not finale.visible or finale.time != 10.0 or finale.fast != 10 or finale.length() != BookFinale.LAST or finale.plain != 0.0:
		_fail("the finale shows %.1f stars, %d levels in time" % [finale.time, finale.fast])
	var badge: LevelComplete.Badge = main.complete_panel.badge
	if not badge.visible or badge.time != 10.0 or badge.lost:
		_fail("the badge of the hourglass: +%.1f, lost: %s" % [badge.time, badge.lost])
	await create_timer(BookFinale.SLAM + 0.3).timeout
	if not finale.visible or finale.arrived() != 10.0 or finale._star.best != 10.0:
		_fail("the finale counts to %.1f" % finale._star.best)
	await create_timer(BookFinale.LAST - BookFinale.SLAM).timeout
	if finale.visible:
		_fail("the finale does not end")
	await create_timer(1.4).timeout
	if main.complete_panel.star.best != 20.0:
		_fail("the star of the end screen says %.1f" % main.complete_panel.star.best)
	main._show_level_complete()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	finale._gui_input(press)
	if not finale.visible:
		_fail("a click right away skips the finale by accident")
	await create_timer(0.6).timeout
	finale._gui_input(press)
	if finale.visible or not main.complete_panel.visible:
		_fail("a click does not skip the finale")
	# Running out is shown big three times, then only by the small hourglass. The word can still be brewed.
	main.sand_fails = 0
	for time_out in range(1, 6):
		main._start_level(1)
		await process_frame
		main.sand_timer.left = 0.05
		await create_timer(0.3).timeout
		if main.sand_fails != time_out or main.sand_out.visible != (time_out <= 3) or (main.sand_timer.modulate.a < 0.5) != (time_out <= 3):
			_fail("the sand ran out for time %d: shown %s" % [main.sand_fails, main.sand_out.visible])
		if main.busy or main.sand_out.mouse_filter != Control.MOUSE_FILTER_IGNORE or not main.sand_lost:
			_fail("the empty hourglass gets in the way")
		if time_out == 1:
			await create_timer(SandOut.GO + SandOut.BACK).timeout
			if main.sand_out.visible or main.sand_timer.modulate.a != 1.0:
				_fail("the empty hourglass does not go back")
		if time_out == 2:
			main._show_screen(main.Screen.LEVELS)
			if main.sand_out.visible or main.sand_timer.modulate.a != 1.0:
				_fail("the empty hourglass is still there on another screen")
			continue
		main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
		if not main.complete_panel.visible or main.sand_out.visible or not badge.lost or badge.time != 0.0 or finale.length() != BookFinale.ALONE:
			_fail("the end screen after running out: badge %s" % badge.lost)
	main.level_records = {1: {"best": 20.0, "plain": 10.0, "time": 10.0, "conquered": true}}
	# A bad run afterwards takes nothing away.
	main._start_level(1)
	await process_frame
	main.sand_timer.left = 0.0
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	if main.level_records[1].best != 20.0:
		_fail("a run without time took something away: %s" % main.level_records[1])
	# Old records: above 10 is time.
	var old := {"best": 13.0, "conquered": false}
	main._split_best(old, 1)
	if old.plain != 10.0 or old.time != 3.0:
		_fail("an old record was split into %s" % old)
	main.level_records = {}
	# A perfect run, all in time.
	main._start_level(1)
	await process_frame
	await _play_level(main)
	if absf(main.level_records[1].best - 20.0) > 0.001 or not main.level_records[1].conquered:
		_fail("a perfect fast run should be 20 and mastered: %s" % main.level_records[1])
	# Slow sand: needs the hourglass, 15% more time per rank, 5 ranks.
	main.level_records = {}
	for n in range(1, 11):
		main.level_records[n] = {"best": 10.0, "conquered": true}
	main.score = 100000
	main.owned_upgrades = {}
	if main.skill_buy("more_sand"):
		_fail("Slow sand could be learned before the hourglass")
	main.skill_buy("hourglass")
	for i in 7:
		main.skill_buy("more_sand")
	main._start_level(1)
	if main.rank_of("more_sand") != 5 or absf(main.sand_timer.total - 105.0 * 2.25) > 0.01:
		_fail("Slow sand rank %d gives %.1f s" % [main.rank_of("more_sand"), main.sand_timer.total])
	main.score = 0
	main.owned_upgrades = {"hourglass": 1}
	_check_golden_sand(main)
	main.owned_upgrades = {"hourglass": 1}
	# The hourglass: what is gone above lies below, at every moment.
	var glass: SandTimer = main.sand_timer
	for share in [0.0, 0.1, 0.5, 0.9, 1.0]:
		var up := glass._level(share, true)
		var down := glass._level(share, false)
		if up < -0.001 or up > 1.001 or down < -0.001 or down > 1.001 or absf(up - glass._level(1.0 - share, false)) > 0.02:
			_fail("the sand does not add up at %.1f: %.2f above, %.2f below" % [share, up, down])
	# Harder books get more sand: (6 s + 4.5 s per missing letter + 3 s when hidden) for each of the 10 words.
	for pair in [[2, 135.0], [4, 150.0], [6, 180.0], [16, 240.0], [19, 270.0], [20, 285.0], [29, 315.0]]:
		main._start_level(pair[0])
		if main.sand_timer.total != pair[1]:
			_fail("book %d gives %.0f s, expected %.0f" % [pair[0], main.sand_timer.total, pair[1]])
	main.owned_upgrades = {}
	main.level_records = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	print("hourglass ok")


## Golden sand: up to 5 stars more for a level, by how quick it was against its share of the sand.
func _check_golden_sand(main: Node) -> void:
	main.level_records = {1: {"best": 59.0, "conquered": true}}
	main.score = 100000
	main.owned_upgrades = {"hourglass": 1}
	var prices: Array = []
	for i in 5:
		prices.append(main._upgrade_price("more_sand"))
		main.owned_upgrades["more_sand"] = i + 1
	if prices != [120, 180, 270, 410, 610]:
		_fail("Slow sand costs %s" % [prices])
	if main.skill_buy("golden_sand"):
		_fail("Golden sand for too few stars")
	main.level_records[1].best = 60.0
	main.owned_upgrades = {}
	if main.skill_buy("golden_sand"):
		_fail("Golden sand without the hourglass")
	main.owned_upgrades = {"hourglass": 1}
	main._start_level(1)
	main._run_sand(0.0)
	if main.sand_timer.bonus() != 0:
		_fail("a star bonus without Golden sand")
	if not main.skill_buy("golden_sand") or main.score != 99400:
		_fail("Golden sand costs %d" % (100000 - main.score))
	main._run_sand(0.0)
	var glass: SandTimer = main.sand_timer
	var last := 5
	for n in [1, 29]:
		main._start_level(n)
		last = 5
		for tenth in range(0, int(glass.pace_total * 10.0) + 1):
			glass.pace_used = tenth * 0.1
			if tenth <= 20 and glass.bonus() != 5:
				_fail("%.1f s of %.1f used: %d stars" % [tenth * 0.1, glass.pace_total, glass.bonus()])
			if glass.bonus() > last or glass.bonus() < last - 1:
				_fail("the star bonus jumps from %d to %d" % [last, glass.bonus()])
			last = glass.bonus()
		if last != 0:
			_fail("a word that took its whole share gives %d stars" % last)
		glass.pace_used = 0.0
		glass.left = 0.0
		if glass.bonus() != 0:
			_fail("an empty hourglass gives %d stars" % glass.bonus())
	# Brewed: 1 + 1 + the bonus, also in the list at the end.
	main._start_level(1)
	main.word_results = []
	_solve(main, main.puzzle.word, false)
	for wanted in [5, 3, 0]:
		var before: float = main.time_points
		glass.left = glass.total
		glass.pace_used = 2.0 + (glass.pace_total - 2.0) * (1.0 - wanted / 5.0) + 0.1
		if glass.bonus() != wanted:
			_fail("%.1f s used: %d stars, expected %d" % [glass.pace_used, glass.bonus(), wanted])
		main._brew_success()
		if main.time_points != before + 1.0 + wanted or main.word_results[-1].time != 1.0 + wanted:
			_fail("a level should give 1 + %d for time: %s" % [wanted, main.word_results[-1]])
	glass.left = 0.0
	main._brew_success()
	if main.word_results[-1].time != 0.0:
		_fail("too late, but %s" % main.word_results[-1])
	var row: Control = main.complete_panel._word_row(main.word_results[0])
	if not row.get_children().any(func(c: Node) -> bool: return c is Label and c.text == "time +6"):
		_fail("the end screen does not show the 6 stars for time")
	row.free()
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	main.score = 0
	main.level_records = {}
	print("golden sand ok")


## Books 20-29: a random theme for every word, no frog before them; the others keep one theme.
func _check_mixed(main: Node) -> void:
	main.owned_upgrades = {"frog": 1}
	for n in range(1, 30):
		if GameData.LEVELS[n - 1].get("mixed", false) != (n > 19):
			_fail("book %d should %sbe mixed" % [n, "" if n > 20 else "not "])
	for n in [20, 24, 29]:
		main._open_book(n)
		await process_frame
		if main.frog.visible or not main.hud.visible or main.level != n or main.puzzle.is_empty():
			_fail("book %d did not start at once" % n)
		var themes := {}
		var words := {}
		for i in 10:
			var t: String = main.session_themes[i]
			themes[t] = true
			words[main.session_words[i][0]] = true
			if not (main.session_words[i] in GameData.THEMES[t]):
				_fail("book %d: %s is not from %s" % [n, main.session_words[i][0], t])
			if i > 0 and main.session_themes[i - 1] == t:
				_fail("book %d: theme %s twice in a row" % [n, t])
			if GameData.length_distance(String(main.session_words[i][0]).length(), GameData.LEVELS[n - 1]) > 0:
				_fail("book %d: %s has the wrong length" % [n, main.session_words[i][0]])
		if themes.size() < 5 or words.size() != 10:
			_fail("book %d: %d themes and %d different words" % [n, themes.size(), words.size()])
		for i in 3:
			if main.theme != main.session_themes[i] or not main.theme_label.text.contains(main.theme):
				_fail("word %d of book %d shows %s instead of %s" % [i + 1, n, main.theme_label.text, main.session_themes[i]])
			main._next_word()
			await process_frame
	# The little frog changes only this word.
	var before_words: Array = main.session_words.duplicate()
	var at: int = main.word_number
	var old_theme: String = main.theme
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	await create_timer(4.0).timeout
	for i in 10:
		if (main.session_words[i] == before_words[i]) == (i == at):
			_fail("the little frog in a mixed book: word %d %s" % [i + 1, "did not change" if i == at else "changed"])
	if main.theme == old_theme or main.theme != main.session_themes[at] or main.book_offers.has(29):
		_fail("the little frog in a mixed book: theme %s after %s" % [main.theme, old_theme])
	# Books 1-19 still have one theme, picked with the frog.
	main._open_book(19)
	await process_frame
	if not main.frog.visible:
		_fail("book 19 should begin with the frog")
	main._show_screen(main.Screen.LEVELS)
	main.theme = "Animals"
	main._start_level(19)
	for t in main.session_themes:
		if t != "Animals":
			_fail("book 19 mixes themes")
	main.owned_upgrades = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main.picker.show_page(0)
	print("mixed books ok")


## Mystery books (page 2): easy to hard again, a new secret theme for every word, no frog, the themes told at the end.
func _check_mystery(main: Node) -> void:
	if GameData.book_count() != 49 or GameData.MYSTERY_LIKE.size() < 20:
		_fail("there should be at least 20 mystery books")
	var last := 0
	for n in range(30, GameData.book_count() + 1):
		var like: int = GameData.MYSTERY_LIKE[n - 30]
		if like < last or not GameData.book(n).mystery or not GameData.book(n).mixed or GameData.book(n).min_len != GameData.LEVELS[like - 1].min_len:
			_fail("mystery book %d: %s" % [n - 29, GameData.book(n)])
		last = like
	if GameData.MYSTERY_LIKE[0] != 1 or GameData.MYSTERY_LIKE[-1] != GameData.LEVELS.size() or GameData.book(1).has("mystery"):
		_fail("the mystery books should go from book 1 to book 29 again")
	# The same staircase as the normal books: never easier, and each number of missing letters starts with the gaps shown
	# (at least twice from 2 letters on) before they are hidden.
	for n in range(31, GameData.book_count() + 1):
		var a: Dictionary = GameData.book(n - 1)
		var b: Dictionary = GameData.book(n)
		var a_missing: int = GameData.missing_span(a).y
		var b_missing: int = GameData.missing_span(b).y
		if b_missing < a_missing or b.min_len < a.min_len or b.decoys < a.decoys - 1:
			_fail("mystery book %d is easier than the one before" % (n - 29))
		if b_missing > a_missing and not b.gaps_visible:
			_fail("mystery book %d: %d letters start with the gaps hidden" % [n - 29, b_missing])
		if b_missing == a_missing and b.gaps_visible and not a.gaps_visible:
			_fail("mystery book %d shows the gaps again" % (n - 29))
	for missing in range(2, 6):
		var shown := 0
		for n in range(30, GameData.book_count() + 1):
			if GameData.missing_span(GameData.book(n)).y == missing and GameData.book(n).gaps_visible:
				shown += 1
		if shown < 2:
			_fail("mystery books: %d letters with the gaps shown only %d times" % [missing, shown])
	if GameData.book_title(30) != "Mystery recipes 1" or GameData.book_title(3) != "Brew recipes 3":
		_fail("book titles: %s, %s" % [GameData.book_title(30), GameData.book_title(3)])
	main.owned_upgrades = {"frog": 1}
	main._open_book(32)
	await process_frame
	if main.frog.visible or not main.hud.visible or main.level != 32 or main.puzzle.is_empty():
		_fail("a mystery book did not start at once")
	if main.level_label.text != "Mystery recipes 3" or main.pocket_frog.visible or main.book_offers.has(32):
		_fail("mystery book 3: %s, little frog %s" % [main.level_label.text, main.pocket_frog.visible])
	var themes := {}
	for i in 10:
		var t: String = main.session_themes[i]
		themes[t] = true
		if not (main.session_words[i] in GameData.THEMES[t]):
			_fail("mystery: %s is not from %s" % [main.session_words[i][0], t])
		if i > 0 and main.session_themes[i - 1] == t:
			_fail("mystery: theme %s twice in a row" % t)
	if themes.size() < 3:
		_fail("a mystery book should have a new theme for every word: %s" % [themes.keys()])
	# Brewed to the end: every word's secret is told beside it.
	while not main.complete_panel.visible:
		if main.theme_label.text.contains(main.theme) or not main.theme_label.text.contains("Secret"):
			_fail("the theme sign gives the secret away: %s" % main.theme_label.text)
		_solve(main, main.puzzle.word, false)
		await main._stir()
	if not main.complete_panel.title_label.text.begins_with("Mystery recipes 3") or not main.complete_panel.message_label.text.contains("secret"):
		_fail("the end of a mystery book: %s / %s" % [main.complete_panel.title_label.text, main.complete_panel.message_label.text])
	for i in 10:
		if main.word_results[i].theme != main.session_themes[i]:
			_fail("word %d does not tell its secret theme" % (i + 1))
	var row: Control = main.complete_panel._word_row(main.word_results[0])
	if not row.get_children().any(func(c: Node) -> bool: return c is Label and c.text.contains(main.session_themes[0])):
		_fail("the end screen does not show the secret theme")
	row.free()
	if not main.level_records.has(32):
		_fail("a brewed mystery book lost its score")
	main._show_screen(main.Screen.LEVELS)
	main.level_records.erase(32)
	main.owned_upgrades = {}
	main.picker.show_page(0)
	print("mystery books ok")


## A new game: FROG first, then the frog (free, nothing else), then one free meal.
func _check_first_mission(main: Node) -> void:
	var all: Dictionary = main.spelled
	for start in ["play", "book"]:
		main.frog_uses = {}
		main.spelled = {}
		main.owned_upgrades = {}
		main.level_records = {}
		main.score = 0
		main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
		main.tutorial = main.Tutorial.SPELL
		main._show_screen(main.Screen.TITLE)
		if start == "play":
			main._play()
		else:
			main._open_book(7)
		await create_timer(0.2).timeout
		if main.screen != main.Screen.PLAY or main.level != 1 or main.puzzle.word != "FROG" or main.theme != "Animals":
			_fail("a new game starts with %s in book %d" % [main.puzzle.get("word", "?"), main.level])
		if main.puzzle.missing.size() != 1 or not main.puzzle.gaps_visible or main.session_words.size() != 10 or main.session_themes.size() != 10:
			_fail("the first mission is not the easiest: %s" % main.puzzle)
		if not main.tutorial_note.visible or not main.tutorial_note._label.text.contains("spell FROG"):
			_fail("the first mission has no message")
		if main.skill_info("frog").can_buy or main.skill_buy("frog"):
			_fail("the frog can be learned before FROG was spelled")
		main._start_level(1)  # starting over keeps it
		await process_frame
		if main.puzzle.word != "FROG":
			_fail("starting over lost the first mission")
		_solve(main, "FROG", false)
		await main._stir()
		await create_timer(0.2).timeout
		if main.tutorial != main.Tutorial.LEARN or main.word_number != 1 or not main._must_learn():
			_fail("spelling FROG did not lead to the shelves")
		if not main.tutorial_note.visible or not main.tutorial_note._label.text.contains("unlock the frog") or main.stir_tip.visible:
			_fail("no message to unlock the frog")
		if main._engraving_text() != "OPEN THE SHELVES":
			_fail("the cauldron says %s" % main._engraving_text())
		# Nothing can be done before, not even with lots of knowledge and stars.
		main._drink_wisdom()
		main._drink_vision()
		if main.wisdom_level + main.vision_level != 0:
			_fail("potions can be drunk before the frog is learned")
		main.score = 100000
		for n in range(1, 30):
			main.level_records[n] = {"best": 10.0, "conquered": true}
		main.spelled = all.duplicate()
		main._open_shop()
		await create_timer(0.1).timeout
		if main.tutorial_note.visible or main.shop_panel.game.book_points_at() != "frog" or not main.book_tip().contains("free"):
			_fail("the book does not point at the frog")
		for n in main.SKILL_TREE:
			if n.id == "frog":
				continue
			var info: Dictionary = main.skill_info(n.id)
			if info.can_buy or info.afford > 0.0 or info.has("need_stars") or main.skill_buy(n.id):
				_fail("%s can be learned before the frog" % n.id)
		main.score = 0
		main.level_records = {}
		var frog_info: Dictionary = main.skill_info("frog")
		if not frog_info.can_buy or frog_info.afford != 1.0 or frog_info.status_text != "free" or not frog_info.hint.contains("free"):
			_fail("the frog is not free: %s" % frog_info)
		# Holding the mouse on it, like a player.
		main.shop_panel.hold_id = "frog"
		main.shop_panel.hold_t = 0.0
		await create_timer(main.shop_panel.HOLD_TIME + 0.3).timeout
		if main.rank_of("frog") != 1 or main.score != 0 or main.tutorial != main.Tutorial.USE:
			_fail("holding the frog did not learn it for free")
		if not main.book_tip().contains("now you can use it"):
			_fail("the book does not say the frog can be used")
		main.shop_panel.close_book()
		await create_timer(0.2).timeout
		if not main.tutorial_note.visible or not main.tutorial_note._label.text.contains("now you can use it") or not main.pocket_frog.visible:
			_fail("no message that the frog can be used")
		if not main.stir_tip.visible or main._must_learn():
			_fail("the game still waits after the frog was learned")
		var word: String = main.puzzle.word
		main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
		if start == "play":
			# The first meal is free, the next one is not.
			main.frog_uses = {}  # the limit has its own check
			main._feed_pocket_frog()
			await create_timer(4.0).timeout
			if main.puzzle.word == word or main.tutorial != main.Tutorial.DONE or main.tutorial_note.visible or main.potions[PotionArt.WISDOM] != 0:
				_fail("the first meal of the frog went wrong")
			if main._can_reroll():
				_fail("the second meal is free too")
		else:
			# Brewing on instead: the message goes, the free meal stays.
			_solve(main, word, false)
			await main._stir()
			await create_timer(0.2).timeout
			if main.tutorial_note.visible or main.tutorial != main.Tutorial.USE or not main._can_reroll():
				_fail("after brewing on: note %s, step %d" % [main.tutorial_note.visible, main.tutorial])
			main.use_note_seen = false
	main.tutorial = main.Tutorial.DONE
	main.spelled = all
	main.owned_upgrades = {}
	main.level_records = {}
	main.book_offers = {}
	main.score = 0
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._update_potion_ui()
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	print("first mission ok")


## Two themes at first; the others are bought for 60 knowledge each, without stars.
func _check_theme_shop(main: Node) -> void:
	var start: Array = main.START_THEMES
	main.themes_owned = start.duplicate()
	main.owned_upgrades = {}
	main.level_records = {}
	main.theme_order = []
	for u in main.UPGRADES:  # every pet's name can be spelled with the first themes (some upgrades need other themes)
		if u.has("spell") and u.id in ["wisdom", "vision", "frog", "familiar", "cat", "raven", "mouse", "chameleon", "raccoon"]:
			var found := false
			for t in start:
				for e in GameData.THEMES[t]:
					found = found or e[0] == u.spell
			if not found:
				_fail("%s is in none of the first themes" % u.spell)
	# Only the themes you have turn up, never the same one twice in a row, whatever was seen.
	for tired in [false, true]:
		main.dealer = WordDealer.new()
		if tired:
			for e in GameData.THEMES["Animals"] + GameData.THEMES["Witchcraft & magic"]:
				main.dealer.mark_seen("Animals", e[0])
				main.dealer.mark_seen("Witchcraft & magic", e[0])
		var last := ""
		var times := {}
		for i in 120:
			var one: Array = main._roll_themes(1 + i % 29, 1, [])
			if one.size() != 1 or not (one[0] in start) or one[0] == last:
				_fail("with two themes %s came after %s" % [one, last])
			last = one[0]
			times[last] = times.get(last, 0) + 1
		for t in start:
			if times.get(t, 0) < 25:
				_fail("%s came only %d times of 120" % [t, times.get(t, 0)])
	main.dealer = WordDealer.new()
	for n in [1, 8, 19, 20, 29]:
		main._open_book(n)
		await process_frame
		if main.book_offers.has(n) and main.book_offers[n].any(func(t: String) -> bool: return not (t in start)):
			_fail("book %d offers %s" % [n, main.book_offers[n]])
		for t in main.session_themes if n >= 20 else []:
			if not (t in start):
				_fail("book %d uses %s, which was not bought" % [n, t])
	# The buffet and the frog with few themes: no double cards, always another theme in play.
	main.owned_upgrades = {"frog": 1, "frog_choice": 2}
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main.book_offers = {}
	main._open_book(5)
	await create_timer(3.0).timeout
	var offer: Array = main.book_offers[5].duplicate()
	offer.sort()
	if offer != start or main.frog.cards.size() != 2:
		_fail("with two themes the buffet offers %s" % [main.book_offers[5]])
	if main._can_reroll():
		_fail("the frog can be fed although it has no other theme")
	main.frog.cards[0].pressed.emit()
	await process_frame
	var old_theme: String = main.theme
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	await create_timer(4.0).timeout
	if main.theme == old_theme or main.book_offers[5] != [main.theme]:
		_fail("with two themes the little frog offers %s instead of %s" % [main.book_offers[5], old_theme])
	main._show_screen(main.Screen.LEVELS)
	# The page in the spell book.
	main.score = 140
	main._open_shop()
	await process_frame
	var book: SpellBook = main.shop_panel
	if book.nodes().size() != main.SKILL_TREE.size() + 1 + GameData.THEMES.size():
		_fail("the tree has %d nodes" % book.nodes().size())
	for n in book.nodes():
		# Everything is on the page, nothing overlaps, and the mouse finds it.
		var c: Vector2 = book.node_center(n.id)
		if not Rect2(Vector2.ZERO, book.canvas.size).grow(-SpellBook.NODE_R).has_point(c) or book.node_at(book.node_global_pos(n.id)) != n.id:
			_fail("%s is not where it should be" % n.id)
		for other in book.nodes():
			if other.id != n.id and c.distance_to(book.node_center(other.id)) < 2.0 * SpellBook.NODE_R:
				_fail("%s lies over %s" % [n.id, other.id])
		if n.has("side") and (n.parent != "themes" or absf(c.x + n.side * 150.0 - book.canvas.size.x * 0.5) > book.canvas.size.x * 0.5):
			_fail("the name of %s runs off the page" % n.id)
	for n in main.SKILL_TREE:  # the animals above the cauldron, the rest below it
		var pet: bool = n.id in ["frog", "familiar", "cat", "mouse", "raven", "chameleon", "raccoon"]
		if n.parent == "root" and pet and n.pos.y > 10.0 or n.parent == "root" and not pet and n.pos.y < 90.0:
			_fail("%s is on the wrong side of the cauldron" % n.id)
		if n.parent not in ["", "root"] and n.id != "raven":
			for other in main.SKILL_TREE:
				if other.id == n.parent and other.pos.length() >= n.pos.length():
					_fail("%s does not lead away from the cauldron" % n.id)
	if main._tree_nodes.filter(func(n: Dictionary) -> bool: return n.id == "theme:Time & calendar")[0].pos.y != main._tree_nodes.filter(func(n: Dictionary) -> bool: return n.id == "theme:At home")[0].pos.y:
		_fail("Time & calendar is not in row 3")
	if main.skill_info("sage").has("special") or not main.skill_info("cat").has("special") or not main.skill_info("hourglass").has("special"):
		_fail("the wrong spells have a special unlock")
	var start_node: Dictionary = main.skill_info("themes")
	if start_node.status_text != "2 / 11" or not start_node.understood or start_node.can_buy or main.skill_buy("themes"):
		_fail("the starting node of the themes: %s" % start_node)
	for t in GameData.THEMES:
		var info: Dictionary = main.skill_info("theme:" + t)
		if info.understood != (t in start) or info.can_buy != (not (t in start) and t != "Time & calendar") or info.label != t:
			_fail("%s: %s" % [t, info])
	if main.skill_buy("theme:Animals") or main.score != 140:
		_fail("a theme you have can be bought again")
	book.hold_id = "theme:At home"
	book.hold_t = 0.0
	await create_timer(book.HOLD_TIME + 0.3).timeout
	if not ("At home" in main.themes_owned) or main.score != 80 or not main.skill_info("theme:At home").understood:
		_fail("holding a theme did not buy it: %d knowledge, %s" % [main.score, main.themes_owned])
	if not main.skill_buy("theme:Universe") or main.score != 20:
		_fail("the second theme could not be bought")
	if main.skill_buy("theme:Ocean & sea") or main.score != 20 or absf(main.skill_info("theme:Ocean & sea").afford - 1.0 / 3.0) > 0.01:
		_fail("a theme was sold for too little knowledge")
	main.score = 199
	if main.skill_buy("theme:Time & calendar") or not main.skill_info("theme:Time & calendar").hint.contains("200"):
		_fail("Time & calendar costs: %s" % main.skill_info("theme:Time & calendar").hint)
	main.score = 200
	if not main.skill_buy("theme:Time & calendar") or main.score != 0 or not ("Time & calendar" in main.themes_owned):
		_fail("Time & calendar can't be bought for 200")
	if main._renamed(["Animals", "Space & sky"]) != ["Animals", "Universe"]:
		_fail("a theme from an old save has no new name")
	main._cheat_click(book.node_global_pos("themes"), true)
	if main.themes_owned.size() != GameData.THEMES.size():
		_fail("ctrl+click on the themes did not give all of them")
	main._cheat_click(book.node_global_pos("themes"), false)
	main.themes_owned = start + ["At home", "Universe"]
	book.close_book()
	var seen := {}
	for i in 20:
		seen[main._roll_themes(1, 1, [])[0]] = true
	if not seen.has("At home") or not seen.has("Universe") or seen.size() != 4:
		_fail("after buying two themes these come up: %s" % [seen.keys()])
	main.tutorial = main.Tutorial.LEARN
	main.score = 1000
	if main.skill_info("theme:Ocean & sea").can_buy or main.skill_buy("theme:Ocean & sea"):
		_fail("a theme can be bought before the frog")
	main.tutorial = main.Tutorial.DONE
	main.themes_owned = GameData.THEMES.keys()
	main.owned_upgrades = {}
	main.theme_order = []
	main.book_offers = {}
	main.score = 0
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	print("theme shop ok")


## What is newly unlocked flies into the button of the spell book, once.
func _check_unlocks(main: Node) -> void:
	var all: Dictionary = main.spelled
	main.owned_upgrades = {}
	main.level_records = {}
	main.spelled = {"orchard": true}  # the discount only waits for its stars
	main._start_level(1)
	await create_timer(0.1).timeout
	main.unlock_queue = []
	main.unlock_wait = 0.0
	for f in main.unlock_layer.get_children():
		f.queue_free()
	await create_timer(0.5).timeout
	if main.unlock_layer.get_child_count() != 0 or not main.unlock_queue.is_empty():
		_fail("something is announced although nothing was unlocked")
	# 20 stars open the discount.
	main.level_records = {1: {"best": 20.0, "conquered": true}}
	await create_timer(0.2).timeout
	var flights: Array = main.unlock_layer.get_children()
	if flights.size() != 1 or flights[0].text != "Potion discount unlocked!" or flights[0].icon != "💰" or flights[0].target != main.shop_button:
		_fail("20 stars announce %s" % [flights.map(func(f: Node) -> String: return f.text)])
	await create_timer(3.2).timeout
	if main.unlock_layer.get_child_count() != 0 or not main.unlock_queue.is_empty():
		_fail("the discount is still flying, or is announced again")
	if main.shop_button.modulate != Color.WHITE or main.shop_button.scale != Vector2.ONE:
		_fail("the Shelves button did not come to rest")
	# A pet's name, with and without enough stars.
	for stars in [5.0, 12.0]:
		main.spelled = {}
		main.level_records = {1: {"best": stars, "conquered": true}}
		main._start_level(1)
		await create_timer(0.2).timeout
		main.unlock_queue = []
		for f in main.unlock_layer.get_children():
			f.queue_free()
		main.session_words[0] = ["owl", "a bird", "🦉"]
		main._start_word()
		main.unlock_wait = 0.0
		_solve(main, "OWL", false)
		main._stir()
		await create_timer(2.0).timeout
		var texts: Array = main.unlock_layer.get_children().map(func(f: Node) -> String: return f.text)
		var want := "You spelled OWL!" if stars < 10.0 else "Owl familiar unlocked!"
		if texts != [want]:
			_fail("spelling OWL with %.0f stars announces %s" % [stars, texts])
		await create_timer(3.0).timeout
	# At the end of a book it waits for the next screen with a spell book button.
	main.spelled = {"orchard": true}
	main.level_records = {}
	main._start_level(1)
	await create_timer(0.2).timeout
	main.unlock_queue = []
	main.unlock_wait = 0.0
	for f in main.unlock_layer.get_children():
		f.queue_free()
	main.level_records = {2: {"best": 10.0, "conquered": true}}
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	await create_timer(0.3).timeout
	if main.unlock_layer.get_child_count() != 0 or main.unlock_queue.size() != 1:
		_fail("at the end of a book %d things fly and %d wait" % [main.unlock_layer.get_child_count(), main.unlock_queue.size()])
	main.complete_panel.levels_pressed.emit()
	await create_timer(0.3).timeout
	flights = main.unlock_layer.get_children()
	if flights.size() != 1 or flights[0].target != main.picker.book_button:
		_fail("nothing flies to the Spell book button of the books")
	main._show_screen(main.Screen.TITLE)  # leaving meanwhile is harmless
	await create_timer(0.2).timeout
	if main.unlock_layer.get_child_count() != 0:
		_fail("an unlocked spell flies on the title screen")
	# What opens in the spell book itself is not announced.
	main._start_level(1)
	main.level_records = {1: {"best": 20.0, "conquered": true}, 2: {"best": 20.0, "conquered": true}}
	await create_timer(0.2).timeout
	main.unlock_queue = []
	main._open_shop()
	main.score = 1000
	main.spelled["hourglass"] = true
	main.spelled["slow"] = true
	await create_timer(0.2).timeout
	main.skill_buy("hourglass")
	await create_timer(0.2).timeout
	main.shop_panel.close_book()
	if not main.unlock_queue.is_empty() or not main.open_spells.has("more_sand"):
		_fail("Slow sand was announced although you bought the hourglass in the book")
	await create_timer(2.0).timeout
	main.spelled = all
	main.owned_upgrades = {}
	main.level_records = {}
	main.score = 0
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	print("unlocks ok")


## Wisdom and Vision: spelled in Witchcraft & magic, learned for free, then they can be drunk.
func _check_potion_spells(main: Node) -> void:
	var all: Dictionary = main.spelled
	main.potions_known = {PotionArt.WISDOM: false, PotionArt.VISION: false}
	main.spelled = {}
	main.owned_upgrades = {}
	main.theme = "Witchcraft & magic"
	main.level_records = {1: {"best": 20.0, "conquered": true}, 2: {"best": 20.0, "conquered": true}}
	for n in GameData.LEVELS.size():
		# Both words come up in the first fitting books of their theme.
		if GameData.length_distance(6, GameData.LEVELS[n]) == 0:
			main._start_level(n + 1)
			var names: Array = main.session_words.map(func(e: Array) -> String: return e[0])
			if not ("wisdom" in names) or not ("vision" in names):
				_fail("book %d of Witchcraft & magic asks for %s" % [n + 1, names])
	for kind in [PotionArt.WISDOM, PotionArt.VISION]:
		main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
		main.score = 1000
		main._start_level(4)
		await process_frame
		var drink: Callable = main._drink_wisdom if kind == PotionArt.WISDOM else main._drink_vision
		var button: Button = main.potion_buttons[kind]
		var shelf: String = kind + "_shelf"
		var better := "sage" if kind == PotionArt.WISDOM else "sight"
		drink.call()
		if main.potions[kind] != 9 or main.word_score() != 1.0 or not button.disabled or not button.text.contains("locked") \
				or not button.tooltip_text.contains("Witchcraft & magic"):
			_fail("%s can be drunk before it is learned: %s" % [kind, button.text])
		if main.skill_buy(kind) or main.skill_buy(shelf) or main.skill_info(shelf).can_buy or main.skill_buy(better) \
				or main.skill_info(kind).get("unspelled", "") != kind.to_upper():
			_fail("%s, its shelf or %s can be learned before it was spelled" % [kind, better])
		for e in GameData.THEMES["Witchcraft & magic"]:
			if e[0] == kind:
				main.session_words[0] = e
		main._start_word()
		_solve(main, kind.to_upper(), false)
		main._stir()
		await create_timer(3.6).timeout
		if not main.spelled.has(kind) or not button.text.contains("learn it") or not button.disabled:
			_fail("spelling %s: the button says %s" % [kind, button.text])
		var info: Dictionary = main.skill_info(kind)
		if not info.can_buy or info.status_text != "free" or main.skill_buy(shelf):
			_fail("%s is not free after spelling it: %s" % [kind, info])
		if not main.skill_buy(kind) or main.score < 1000 or main.skill_buy(kind):
			_fail("%s was not learned once, for free" % kind)
		if not main.skill_info(shelf).can_buy or not main.skill_buy(shelf) or main.skill_buy("sight"):
			_fail("the shelf of %s can't be learned, or Clear sight without KETTLE" % kind)
		main.spelled["kettle"] = true
		if not main.skill_buy(better):
			_fail("%s can't be learned with %s" % [better, kind])
		main.spelled.erase("kettle")
		main.shelf_slots[kind] -= 1
		main.owned_upgrades = {}
		main.potions[kind] = 9
		main._update_potion_ui()
		if button.disabled or button.text.contains("locked") or not button.tooltip_text.contains("Drink"):
			_fail("%s can't be drunk after it was learned: %s" % [kind, button.text])
		drink.call()
		if main.potions[kind] != 9 - main._potion_cost() or main.word_score() != 0.5:
			_fail("drinking %s after learning it: %d left" % [kind, main.potions[kind]])
	main.spelled = all
	main.unlock_queue = []
	main.owned_upgrades = {}
	main.level_records = {}
	main.score = 0
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._update_potion_ui()
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	print("potion spells ok")


## The frog can be fed once per book, twice or three times with Second helping; only finishing the book fills it up again.
func _check_frog_limit(main: Node) -> void:
	main.level_records = {1: {"best": 20.0, "conquered": true}, 2: {"best": 20.0, "conquered": true}}
	main.score = 10000
	for rank in [0, 1, 2]:
		main.owned_upgrades = {"frog": 1}
		for i in rank + (1 if rank == 2 else 0):
			main.skill_buy("frog_more")
		if main.rank_of("frog_more") != rank:
			_fail("Second helping has rank %d instead of %d" % [main.rank_of("frog_more"), rank])
		main.frog_uses = {}
		main.theme = "Animals"
		main._start_level(6)
		await process_frame
		for i in rank + 1:
			main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
			main._update_potion_ui()
			if main.frog_left() != rank + 1 - i or main.pocket_frog.left != main.frog_left() or not main.pocket_frog.affordable:
				_fail("rank %d, meal %d: %d left" % [rank, i + 1, main.frog_left()])
			main._feed_pocket_frog()
			await create_timer(4.0).timeout
			if main.potions[PotionArt.WISDOM] != 7:
				_fail("rank %d: meal %d did not happen" % [rank, i + 1])
		main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
		main._update_potion_ui()
		var word: String = main.puzzle.word
		main._feed_pocket_frog()
		if main.potions[PotionArt.WISDOM] != 9 or main.busy or main.puzzle.word != word or main.pocket_frog.left != 0 or main.pocket_frog.affordable:
			_fail("rank %d: the frog ate more than %d times" % [rank, rank + 1])
		# Starting over or coming back changes nothing, on the theme screen too; another book has its own meals.
		main._start_level(6)
		if main.frog_left() != 0:
			_fail("starting over filled the frog's plate")
		main._show_screen(main.Screen.LEVELS)
		main._open_book(6)
		await create_timer(3.0).timeout
		main._reroll()
		if main.potions[PotionArt.WISDOM] != 9 or not main.frog.reroll_button.disabled or not main.frog.reroll_button.text.contains("full"):
			_fail("the frog on the theme screen can be fed without limit: %s" % main.frog.reroll_button.text)
		main._show_screen(main.Screen.LEVELS)
		main._open_book(7)
		await create_timer(3.0).timeout
		if main.frog_left() != rank + 1 or not main.frog.reroll_button.text.contains("(%d left)" % (rank + 1)):
			_fail("another book does not have its own meals: %s" % main.frog.reroll_button.text)
		main._reroll()
		await create_timer(4.0).timeout
		if main.frog_left() != rank:
			_fail("feeding the frog on the theme screen does not count")
		main._start_level(6)
		await process_frame
		main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
		if main.frog_left() != rank + 1:
			_fail("finishing the book did not fill the frog's plate")
		main._show_screen(main.Screen.LEVELS)
	main.frog_uses = {}
	main.owned_upgrades = {}
	main.level_records = {}
	main.book_offers = {}
	main.unlock_queue = []
	main.score = 0
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._update_potion_ui()
	main.picker.show_page(0)
	print("frog limit ok")


## OWL and CAT are in every book of the theme Animals until their pets are learned.
func _check_always_words(main: Node) -> void:
	var all: Dictionary = main.spelled
	main.always_words = {"Animals": ["owl", "cat"], "Witchcraft & magic": ["wisdom", "vision"], "Time & calendar": ["hourglass", "slow"],
		"Universe": ["moon"], "Body & feelings": ["eye"]}
	main._special_texts = {}
	for sp in [{}, all]:  # spelled or not makes no difference, only learning does
		main.spelled = sp.duplicate()
		for owned in [[], ["familiar"], ["familiar", "cat"]]:
			main.owned_upgrades = {}
			for id in owned:
				main.owned_upgrades[id] = 1
			for n in range(1, 20):
				main.theme = "Animals"
				main._start_level(n)
				var names: Array = main.session_words.map(func(e: Array) -> String: return e[0])
				var want_owl: bool = not ("familiar" in owned)
				var want_cat: bool = not ("cat" in owned)
				var fits: bool = GameData.length_distance(3, GameData.LEVELS[n - 1]) == 0
				if names.count("owl") > 1 or names.count("cat") > 1 or names.size() != 10:
					_fail("book %d of Animals has %s" % [n, names])
				if (want_owl and not ("owl" in names)) or (want_cat and not ("cat" in names)):
					_fail("book %d of Animals lacks owl or cat with %s learned: %s" % [n, owned, names])
				if not fits and ((not want_owl and "owl" in names) or (not want_cat and "cat" in names)):
					_fail("book %d of Animals still has owl or cat with %s learned: %s" % [n, owned, names])
				for w in main._names_to_spell():  # they push out no other name
					for e in GameData.THEMES["Animals"]:
						if e[0] == w and GameData.length_distance(w.length(), GameData.LEVELS[n - 1]) == 0 and not (w in names):
							_fail("book %d of Animals lost the name %s" % [n, w])
	# Short words make fair puzzles in hard books too.
	main.owned_upgrades = {}
	for n in [2, 10, 13, 19]:
		main.theme = "Animals"
		for w in ["owl", "cat"]:
			for again in 10:
				main._start_level(n)
				for e in GameData.THEMES["Animals"]:
					if e[0] == w:
						main.session_words[0] = e
				main._start_word()
				if main.puzzle.missing.size() != 1 or main.puzzle.tiles.size() < 2:
					_fail("book %d: %s misses %s of %s" % [n, w, main.puzzle.missing, main.puzzle.tiles])
				_solve(main, w.to_upper(), false)
				if main._spelling() != w.to_upper():
					_fail("book %d: %s can't be spelled" % [n, w])
	# Other themes don't have them; with the little frog they come, but not twice.
	main.theme = "Witchcraft & magic"
	main._start_level(10)
	for e in main.session_words:
		if e[0] in ["owl", "cat"]:
			_fail("%s turned up in Witchcraft & magic" % e[0])
	main.level = 10
	main.word_number = 2
	main.session_words[0] = GameData.THEMES["Animals"].filter(func(e: Array) -> bool: return e[0] == "owl")[0]
	main._swap_theme("Animals")
	var now: Array = main.session_words.map(func(e: Array) -> String: return e[0])
	if now.size() != 10 or now.count("owl") != 1 or now.count("cat") != 1 or now.find("cat") < 2:
		_fail("after swapping to Animals: %s" % [now])
	main._start_level(25)  # a random theme for every word
	for i in 10:
		if main.session_themes[i] == "Animals" and main.session_themes.find("Animals") == i and not (main.session_words[i][0] in ["owl", "cat"]):
			_fail("the first Animals word of a mixed book is %s" % main.session_words[i][0])
	# WISDOM and VISION the same in their theme, until each potion is learned.
	for known in [[false, false], [true, false], [false, true], [true, true]]:
		main.potions_known = {PotionArt.WISDOM: known[0], PotionArt.VISION: known[1]}
		for n in range(1, 20):
			main.theme = "Witchcraft & magic"
			main._start_level(n)
			var names: Array = main.session_words.map(func(e: Array) -> String: return e[0])
			var fits: bool = GameData.length_distance(6, GameData.LEVELS[n - 1]) == 0
			for pair in [["wisdom", known[0]], ["vision", known[1]]]:
				if names.count(pair[0]) > 1 or (not pair[1] and not (pair[0] in names)) or (pair[1] and not fits and pair[0] in names):
					_fail("book %d of Witchcraft & magic with %s learned: %s" % [n, known, names])
	main.potions_known = {PotionArt.WISDOM: false, PotionArt.VISION: false}
	for n in [1, 8, 19]:
		for w in ["wisdom", "vision"]:
			for again in 10:
				main._start_level(n)
				for e in GameData.THEMES["Witchcraft & magic"]:
					if e[0] == w:
						main.session_words[0] = e
				main._start_word()
				_solve(main, w.to_upper(), false)
				if main._spelling() != w.to_upper():
					_fail("book %d: %s can't be spelled" % [n, w])
	# HOURGLASS the same in Time & calendar, and it can only be learned after spelling it there.
	main.level_records = {1: {"best": 20.0, "conquered": true}, 2: {"best": 20.0, "conquered": true}}
	for n in range(1, 20):
		main.owned_upgrades = {}
		main.spelled = {}
		main.score = 1000
		if main.skill_buy("hourglass") or not main.skill_info("hourglass").hint.contains("HOURGLASS"):
			_fail("the hourglass can be learned without spelling it")
		main.theme = "Time & calendar"
		main._start_level(n)
		if main.session_words.filter(func(e: Array) -> bool: return e[0] == "hourglass").size() != 1:
			_fail("book %d of Time & calendar lacks the hourglass" % n)
		for e in GameData.THEMES["Time & calendar"]:
			if e[0] == "hourglass":
				main.session_words[0] = e
		main._start_word()
		_solve(main, "HOURGLASS", false)
		if main._spelling() != "HOURGLASS":
			_fail("book %d: hourglass can't be spelled" % n)
		if n in [1, 19]:
			main._stir()
			await create_timer(1.6).timeout
			if not main.spelled.has("hourglass") or not main.skill_buy("hourglass"):
				_fail("book %d: the hourglass can't be learned after spelling it" % n)
			main.theme = "Time & calendar"
			main._start_level(1)
			for e in main.session_words:
				if e[0] == "hourglass":
					_fail("the hourglass is still in every book after it was learned")
	main.themes_owned = main.START_THEMES.duplicate()
	main.spelled = {}
	if not main._special_text("hourglass").contains("Time & calendar (any book). You need that theme first."):
		_fail("the special unlock of the hourglass says: %s" % main._special_text("hourglass"))
	main.themes_owned = GameData.THEMES.keys()
	if main._special_text("hourglass").contains("need"):
		_fail("the hourglass still asks for a theme you have")
	# SLOW, MOON and EYE the same in their themes, but only until they are spelled.
	main.owned_upgrades = {}
	for pair in [["slow", "Time & calendar"], ["moon", "Universe"], ["eye", "Body & feelings"]]:
		var w: String = pair[0]
		for n in range(1, 20):
			main.spelled = {}
			main.theme = pair[1]
			main._start_level(n)
			if main.session_words.filter(func(e: Array) -> bool: return e[0] == w).size() != 1 or main.session_words.size() != 10:
				_fail("book %d of %s lacks %s" % [n, pair[1], w])
			for e in GameData.THEMES[pair[1]]:
				if e[0] == w:
					main.session_words[0] = e
			main._start_word()
			_solve(main, w.to_upper(), false)
			if main._spelling() != w.to_upper():
				_fail("book %d: %s can't be spelled" % [n, w])
			if n == 19:
				main._stir()
				await create_timer(1.6).timeout
				if not main.spelled.has(w):
					_fail("%s was not remembered" % w)
			main.spelled = {w: true}
			if main._always_in(pair[1]).any(func(e: Array) -> bool: return e[0] == w):
				_fail("%s is still in every book after it was spelled" % w)
		main.spelled = {}
		if not main._special_text(w).contains("(any book)"):
			_fail("the special unlock of %s says: %s" % [w, main._special_text(w)])
	main.level_records = {}
	main.score = 0
	main.owned_upgrades = {}
	main.spelled = {}
	if not main._special_text("wisdom").contains("any book"):
		_fail("the special unlock of Wisdom says: %s" % main._special_text("wisdom"))
	main.potions_known = {PotionArt.WISDOM: true, PotionArt.VISION: true}
	if not main._special_text("owl").contains("any book") or not main._special_text("mouse").contains("books 2-7"):
		_fail("the special unlocks say: %s / %s" % [main._special_text("owl"), main._special_text("mouse")])
	main.always_words = {}
	main._special_texts = {}
	main.spelled = all
	main.owned_upgrades = {}
	main.unlock_queue = []
	main.book_offers = {}
	main._show_screen(main.Screen.LEVELS)
	main.picker.show_page(0)
	print("owl and cat ok")


## The potions are icons that look and work like the pets: lit when they can be drunk, filling up with every drink.
func _check_potion_icons(main: Node) -> void:
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main._start_level(6)  # 2 missing letters
	await process_frame
	for kind in [PotionArt.WISDOM, PotionArt.VISION]:
		var icon: PotionIcon = main.potion_buttons[kind]
		if icon.disabled or icon.locked or icon.done != 0 or icon.steps != 2 or icon.costs.colors.size() != main._potion_cost():
			_fail("%s: %d/%d, cost %d, locked %s" % [kind, icon.done, icon.steps, icon.costs.colors.size(), icon.locked])
		icon.pressed.emit()
		if icon.done != 1 or main.potions[kind] != 9 - main._potion_cost():
			_fail("clicking the %s icon did not drink one" % kind)
		icon.pressed.emit()
		if icon.done != 2 or icon.costs.colors.size() != 0 or not icon.note.begins_with("all") or icon.disabled != (kind == PotionArt.VISION):
			_fail("after all %s: %d/%d %s" % [kind, icon.done, icon.steps, icon.note])
		var shelf: Control = main.shelves[kind]
		if absf(icon.get_global_rect().get_center().x - shelf.get_global_rect().get_center().x) > 2.0 or icon.get_global_rect().intersects(shelf.get_global_rect()):
			_fail("the potions of %s are not under its icon" % kind)
		if icon._has_point(Vector2(1, 1)) and icon.size.x > 100.0 + 2.0 * icon._radius():
			_fail("the corner of the %s icon can be clicked" % kind)
	main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
	main._start_level(6)
	if not main.potion_buttons[PotionArt.WISDOM].disabled or not main.potion_buttons[PotionArt.VISION].disabled:
		_fail("a potion you don't have can be drunk")
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main._update_potion_ui()
	main._show_screen(main.Screen.LEVELS)
	print("potion icons ok")


## The raccoon takes wrong letters off the table, one at a time, never a needed one.
func _check_raccoon(main: Node) -> void:
	main.owned_upgrades = {"raccoon": 1}
	for lvl in [1, 8, 15, 19, 29]:
		main._start_level(lvl)
		await process_frame
		var word: String = main.puzzle.word
		var decoys: int = main.puzzle.tiles.size() - main.puzzle.missing.size()
		# A wrong letter you put in the word is safe from it.
		var placed: LetterTile = main._wrong_on_table()[0]
		main._begin_drag(placed, placed.position)
		placed.position = main._target_of(main.row[main.puzzle.missing[0] if main.puzzle.gaps_visible else 0])
		main._drop()
		var stolen := 0
		while main._pet_help("raccoon") and stolen < 20:
			stolen += 1
		if stolen != decoys - 1 or not placed.in_word or not (placed in main.tiles):
			_fail("book %d: the raccoon stole %d of %d wrong letters" % [lvl, stolen, decoys])
		main._begin_drag(placed, placed.position)
		placed.position = Vector2(640, 655)
		main._drop()
		main._pet_help("raccoon")
		await create_timer(1.6).timeout
		if main.tiles.size() != main.puzzle.missing.size() or main.word_score() != 1.0:
			_fail("book %d: %d letters left for %d missing" % [lvl, main.tiles.size(), main.puzzle.missing.size()])
		_solve(main, word, false)
		if main._spelling() != word or main._can_help("raccoon"):
			_fail("book %d: %s can't be spelled after the raccoon" % [lvl, word])
	for rank in [0, 10]:
		main.owned_upgrades["raccoon_speed"] = rank
		if main.pet_interval("raccoon") != 20.0 - rank:
			_fail("Sneaky paws rank %d: %.1f s" % [rank, main.pet_interval("raccoon")])
	# Leaving while it runs, and the frog while it runs, are harmless.
	main.owned_upgrades = {"raccoon": 1, "frog": 1}
	main.potions = {PotionArt.WISDOM: 9, PotionArt.VISION: 9}
	main._start_level(15)
	await process_frame
	main._pet_help("raccoon")
	await create_timer(0.3).timeout
	main.frog_uses = {}  # the limit has its own check
	main._feed_pocket_frog()
	await create_timer(4.0).timeout
	if main.busy or main.tiles.size() != main.puzzle.tiles.size():
		_fail("the frog and the raccoon got in each other's way")
	main._pet_help("raccoon")
	main._show_screen(main.Screen.LEVELS)
	await create_timer(1.5).timeout
	main.owned_upgrades = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	main.picker.show_page(0)
	print("raccoon ok")


## The chameleon judges the next letter you let go of, when it is charged.
func _check_chameleon(main: Node) -> void:
	main.owned_upgrades = {"chameleon": 1}
	main.pets_paused = {}
	for rank in 9:
		main.owned_upgrades["chameleon_speed"] = rank
		if main.pet_interval("chameleon") != 10.0 - rank:
			_fail("Quick colors rank %d: %.1f s" % [rank, main.pet_interval("chameleon")])
	main.owned_upgrades = {"chameleon": 1}
	# Shown gaps: every letter in every slot.
	main._start_level(8)
	await process_frame
	for t in main.tiles.duplicate():
		for idx in main.puzzle.missing:
			var slot: GapSlot = null
			for item in main.row:
				if item is GapSlot and item.index == idx:
					slot = item
			main.pet_time["chameleon"] = 10.0
			main._begin_drag(t, t.position)
			t.position = main._target_of(slot)
			main._drop()
			var want: int = 1 if main.puzzle.word[idx] == t.letter else -1
			if t.verdict != want or main.pet_time["chameleon"] > 0.5:
				_fail("%s in slot %d of %s: verdict %d" % [t.letter, idx, main.puzzle.word, t.verdict])
			main._begin_drag(t, t.position)
			if t.verdict != 0:
				_fail("a letter that was picked up keeps its verdict")
			main.dragged.position = Vector2(640, 655)
			main._drop()
	# Not charged, or asleep: no verdict. A letter that misses the word does not use it up.
	main.pet_time["chameleon"] = 5.0
	var tile: LetterTile = main.tiles[0]
	main._begin_drag(tile, tile.position)
	tile.position = main._target_of(main.row[main.puzzle.missing[0]])
	main._drop()
	if tile.verdict != 0:
		_fail("a chameleon that is not charged gave a verdict")
	main.pet_time["chameleon"] = 10.0
	main._toggle_pet("chameleon")
	main._begin_drag(tile, tile.position)
	tile.position = main._target_of(main.row[main.puzzle.missing[0]])
	main._drop()
	if tile.verdict != 0 or main.pet_time["chameleon"] < 10.0:
		_fail("a sleeping chameleon gave a verdict")
	main._toggle_pet("chameleon")
	main._begin_drag(tile, tile.position)
	tile.position = Vector2(640, 655)
	main._drop()
	if main.pet_time["chameleon"] < 10.0:
		_fail("putting a letter back on the table used up the chameleon")
	if main.word_score() != 1.0:
		_fail("the chameleon costs score")
	# Hidden gaps, TO__UE: N then G.
	for case in [["N", 2, 1], ["G", 2, 1], ["X", 2, -1], ["N", 1, -1], ["G", 3, -1]]:
		_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
		main.owned_upgrades = {"chameleon": 1}
		_put(main, case[0], case[1], case[2])
	_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
	main.owned_upgrades = {"chameleon": 1}
	_put(main, "G", 2, 1)
	_put(main, "N", 2, 1)   # before the G: right
	_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
	main.owned_upgrades = {"chameleon": 1}
	_put(main, "G", 2, 1)
	_put(main, "N", 3, -1)  # after the G: wrong
	# With both spaces open its exact place counts.
	for case in [["N", 0, 1], ["N", 1, -1], ["G", 0, -1], ["G", 1, 1]]:
		_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
		main.owned_upgrades = {"chameleon": 1, "cat": 1}
		main._cat_split(2)
		main._cat_split(2)
		main.pet_time["chameleon"] = 10.0
		_drop_at(main, case[0], main.claws.spots[case[1]])
		for t in main.tiles:
			if t.letter == case[0] and t.verdict != case[2]:
				_fail("TO__UE: %s in space %d: verdict %d" % [case[0], case[1], t.verdict])
	main.owned_upgrades = {}
	print("chameleon ok")


## Drops a letter between row[at - 1] and row[at] and checks the chameleon's verdict.
func _put(main: Node, letter: String, at: int, want: int) -> void:
	main.pet_time["chameleon"] = 10.0
	_drop_at(main, letter, Vector2((main._target_of(main.row[at - 1]).x + main._target_of(main.row[at]).x) * 0.5, main.WORD_CENTER.y))
	for t in main.tiles:
		if t.letter == letter and t.in_word and t.verdict != want:
			_fail("%s: %s put at %d gets verdict %d, expected %d" % [main._spelling(), letter, at, t.verdict, want])


## Pets can only be learned once their name was spelled, and their names come up first.
func _check_names(main: Node) -> void:
	var all: Dictionary = main.spelled
	var places := {}
	for t in GameData.THEMES:
		for e in GameData.THEMES[t]:
			places[e[0]] = t
	main.spelled = {}
	for n in range(1, 30):
		main.level_records[n] = {"best": 10.0, "conquered": true}
	for u in main.UPGRADES:
		if not u.has("spell"):
			continue
		if not places.has(u.spell):
			_fail("%s is not a word in the game" % u.spell)
			continue
		main.score = 100000
		main.owned_upgrades = {}
		main.potions_known = {PotionArt.WISDOM: false, PotionArt.VISION: false}
		if u.has("needs"):
			main._set_rank(u.needs, 1)
		if main.skill_info(u.id).get("unspelled", "") != String(u.spell).to_upper():
			_fail("%s does not show the letters of %s" % ["%s (spelled %s, owned %s)" % [u.id, main.spelled, main.owned_upgrades], u.spell])
		# It says in plain words what is special: the word, its theme and the books it can come up in.
		var special: String = main.skill_info(u.id).special
		if not special.contains(String(u.spell).to_upper()) or not special.contains(places[u.spell]) or main.skill_info(u.id).spell_theme != places[u.spell]:
			_fail("%s says it is unlocked by: %s" % [u.id, special])
		var fitting: Array = []
		for part in special.get_slice("(book", 1).trim_prefix("s").trim_suffix(").").strip_edges().split(" and "):
			for n in range(int(part.get_slice("-", 0)), int(part.get_slice("-", part.get_slice_count("-") - 1)) + 1):
				fitting.append(n)
		for n in range(1, 30):
			if (GameData.length_distance(String(u.spell).length(), GameData.LEVELS[n - 1]) == 0) != (n in fitting):
				_fail("%s names the wrong books: %s" % [u.id, special])
				break
		if main.skill_buy(u.id) or not main.skill_info(u.id).hint.contains(String(u.spell).to_upper()):
			_fail("%s could be learned without spelling %s: %s" % [u.id, u.spell, main.skill_info(u.id).hint])
		# The name is in the first fitting book of its theme.
		for n in range(1, 30):
			if GameData.length_distance(String(u.spell).length(), GameData.LEVELS[n - 1]) == 0:
				main.theme = places[u.spell]
				for again in 5:
					main._start_level(n)
					var found := false
					for e in main.session_words:
						found = found or e[0] == u.spell
					if not found or main.session_words.size() != 10:
						_fail("book %d with theme %s does not ask for %s" % [n, main.theme, u.spell])
				# Spelling it opens the way.
				for e in main.session_words:
					if e[0] == u.spell:
						main.session_words[0] = e
				main._start_word()
				_solve(main, main.puzzle.word, false)
				main._stir()
				await create_timer(1.6).timeout
				break
		if not main.spelled.has(u.spell) or not (u.name in main.new_names):
			_fail("brewing %s was not remembered" % u.spell)
		var said: String = main.skill_info(u.id).special
		if not said.contains("you spelled %s" % String(u.spell).to_upper()):
			_fail("%s says after spelling it: %s" % [u.id, said])
		if main.skill_info(u.id).has("unspelled"):
			_fail("%s still shows letters after %s was spelled" % [u.id, u.spell])
		main.score = 100000
		if not main.skill_buy(u.id):
			_fail("%s can't be learned after spelling %s: %s" % [u.id, u.spell, main.skill_info(u.id).hint])
	if not main._names_to_spell().is_empty():
		_fail("names still to spell: %s" % [main._names_to_spell()])
	main.spelled = all
	main.potions_known = {PotionArt.WISDOM: true, PotionArt.VISION: true}
	main.owned_upgrades = {}
	main.level_records = {}
	main.score = 0
	main._show_screen(main.Screen.LEVELS)
	print("pet names ok")


## The mouse brings potions on its own, only while brewing and only when there is room.
func _check_mouse(main: Node) -> void:
	main.owned_upgrades = {}
	main.shelf_slots = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
	main._start_level(4)
	await process_frame
	main.mouse_time = 29.9
	await create_timer(0.4).timeout
	if main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION] != 0:
		_fail("a mouse that was not learned brought a potion")
	main.owned_upgrades = {"mouse": 1}
	main.mouse_time = 29.8
	await create_timer(0.5).timeout
	if main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION] != 1 or main.mouse_time > 1.0:
		_fail("the mouse did not bring one potion after 30 s: %s" % main.potions)
	# Faster per rank: 30, 25, 20, 15, 10, 5.
	for rank in 6:
		main.owned_upgrades = {"mouse": 1, "mouse_speed": rank}
		if main.mouse_interval() != 30.0 - 5.0 * rank:
			_fail("Cheese rank %d: a potion every %.1f s" % [rank, main.mouse_interval()])
	# Not while the spell book is open or the game is paused.
	main._open_shop()
	var before: float = main.mouse_time
	await create_timer(0.3).timeout
	if main.mouse_time != before:
		_fail("the mouse works while the spell book is open")
	main.shop_panel.close_book()
	main._open_pause()
	before = main.mouse_time
	await create_timer(0.3).timeout
	if main.mouse_time != before:
		_fail("the mouse works while the game is paused")
	main.pause_menu.close()
	# One shelf full: the other kind. Both full: knowledge.
	for i in 4:
		main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 1}
		main.mouse_time = 4.9
		await create_timer(0.3).timeout
		if main.potions[PotionArt.WISDOM] != 3 or main.potions[PotionArt.VISION] != 2:
			_fail("with a full Wisdom shelf the mouse brought %s" % main.potions)
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	var score_before: int = main.score
	main.mouse_time = 4.9
	await create_timer(0.5).timeout
	if main.score != score_before + main.POINTS_PER_POTION or main.potions != {PotionArt.WISDOM: 3, PotionArt.VISION: 3} or main.mouse_time > 1.0:
		_fail("with full shelves the mouse's potion should become knowledge: +%d, %s" % [main.score - score_before, main.potions])
	await create_timer(1.2).timeout
	if main.score_incoming != 0:
		_fail("the mouse's knowledge never landed")
	# Cheese needs the mouse.
	for n in range(1, 11):
		main.level_records[n] = {"best": 10.0, "conquered": true}
	main.score = 100000
	main.owned_upgrades = {}
	if main.skill_buy("mouse_speed"):
		_fail("Cheese could be learned without the mouse")
	# Nothing else up to 80 stars costs more than about a book's worth of knowledge to begin with.
	for u in main.UPGRADES:
		if int(u.base) > 220 and u.id != "golden_sand":  # which is meant to be expensive
			_fail("%s starts at %d knowledge" % [u.name, u.base])
	# The first animals come early: their stars within the first book or two, the first one with the starting knowledge.
	for pair in [["familiar", 10, 100], ["cat", 20, 100], ["mouse", 30, 200]]:
		var pet: Dictionary = main._upgrade_info(pair[0])
		if int(pet.stars) > pair[1] or int(pet.base) > pair[2]:
			_fail("%s costs %d stars and %d knowledge" % [pet.name, pet.stars, pet.base])
	# No animal needs another one, so each can be learned as the very first; only the raven needs the cat.
	for id in ["familiar", "cat", "mouse", "chameleon", "raccoon", "frog"]:
		main.owned_upgrades = {}
		main.score = 100000
		if main._upgrade_info(id).has("needs") or not main.skill_buy(id):
			_fail("%s can't be learned first: %s" % [id, main.skill_info(id).hint])
		for n in main.SKILL_TREE:
			if n.id == id and n.parent != "root":
				_fail("%s hangs on %s in the spell book" % [id, n.parent])
	main.owned_upgrades = {}
	if main.skill_buy("raven") or not main.skill_info("raven").hint.contains("Cat familiar"):
		_fail("the raven can be learned without the cat: %s" % main.skill_info("raven").hint)
	if not main.skill_buy("cat") or not main.skill_buy("raven"):
		_fail("the raven can't be learned after the cat")
	main.owned_upgrades = {"mouse": 1}
	if not main.skill_buy("mouse_speed"):
		_fail("Cheese could not be learned after the mouse")
	main.score = 0
	main.level_records = {}
	main.owned_upgrades = {}
	main.mouse_time = 0.0
	await create_timer(1.2).timeout
	main.incoming = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	print("mouse ok")


## The raven points at where letters belong, red for vowels, black for consonants.
func _check_raven(main: Node) -> void:
	for pair in [["A", true], ["e", true], ["U", true], ["B", false], ["y", false], ["Z", false]]:
		if LetterTile.is_vowel(pair[0]) != pair[1]:
			_fail("%s is taken for a %s" % [pair[0], "consonant" if pair[1] else "vowel"])
	main.owned_upgrades = {"raven": 1}
	for lvl in [1, 4, 8, 10, 15, 19, 29]:
		main._start_level(lvl)
		await process_frame
		var missing: Array = main.puzzle.missing
		if not main.puzzle.gaps_visible:
			# Hidden gaps: nothing to point at before the cat has opened the spaces.
			if main._pet_help("raven") or not main.raven_spots.is_empty():
				_fail("book %d: the raven points at a space that can't be seen" % lvl)
			var first_gap: int = main._cat_gaps()[0]
			while not main._cat_gaps().is_empty() and main._cat_gaps()[0] == first_gap:
				main._cat_split(first_gap)
			for i in main._raven_free():
				if main._gap_of(i) != first_gap:
					_fail("book %d: the raven may point at a gap the cat did not open" % lvl)
			if main._raven_free().is_empty():
				_fail("book %d: the raven can't use the space the cat opened" % lvl)
			while not main._cat_gaps().is_empty():
				main._cat_split(main._cat_gaps()[0])
		main._pet_help("raven")
		main._pet_help("raven")  # one at a time: another letter, or nothing if there is only one
		await create_timer(1.1).timeout
		var want: int = mini(2, missing.size())
		if main.raven_marks.marks.size() != want:
			_fail("book %d: %d raven marks, expected %d" % [lvl, main.raven_marks.marks.size(), want])
		if main.word_score() != 1.0:
			_fail("the raven costs score")
		for i in main.raven_spots:
			if not (i in missing):
				_fail("the raven points at %d of %s, which is not missing" % [i, main.puzzle.word])
		for m in main.raven_marks.marks:
			if m.at.x < 250 or m.at.x > 1030 or m.at.y > main.WORD_CENTER.y - 20:
				_fail("book %d: a raven mark is at %s" % [lvl, m.at])
		# The marks stay, whatever you put there, and don't move out of their gap.
		_solve(main, main.puzzle.word, false)
		await process_frame
		await process_frame
		if main.raven_marks.marks.size() != want:
			_fail("a raven mark went away when the letter was placed")
		for i in main.raven_spots:
			var over: Node2D = main.row[i]
			if absf(main._raven_spot(i, false).x - main._target_of(over).x) > 1.0:
				_fail("book %d: the raven points beside letter %d of the finished %s" % [lvl, i, main.puzzle.word])
	# The pointers stay right above their moving bubble.
	main._start_level(8)
	await create_timer(0.8).timeout
	main.owned_upgrades = {"raven": 1}
	for i in 3:
		main._pet_help("raven")
	await create_timer(1.2).timeout
	for k in 10:
		await create_timer(0.13).timeout
		var n := 0
		for i in main.raven_spots:
			var above: Vector2 = main._raven_spot(i) - main.raven_marks.marks[n].at
			if absf(above.x) > 3.0 or above.y < 30.0 or above.y > 52.0:
				_fail("a raven pointer is %s from its bubble" % above)
			n += 1
	# TO__UE: two in one gap, in the right order, also with the cat's spaces.
	_set_puzzle(main, "TONGUE", [2, 3], ["N", "G", "X"])
	main.owned_upgrades = {"raven": 1, "cat": 1}
	if main._raven_spot(2, false).x >= main._raven_spot(3, false).x or main._raven_spot(2, false).x <= main._target_of(main.row[1]).x or main._raven_spot(3, false).x >= main._target_of(main.row[2]).x:
		_fail("TO__UE: the raven's two spots are out of order")
	main._cat_split(2)
	main._cat_split(2)
	if absf(main._raven_spot(2, false).x - main.claws.spots[0].x) > 1.0 or absf(main._raven_spot(3, false).x - main.claws.spots[1].x) > 1.0:
		_fail("TO__UE: the raven does not point at the cat's spaces")
	_set_puzzle(main, "OTTER", [0, 2], ["O", "T", "X"])
	main.owned_upgrades = {"raven": 1}
	main._cat_split(0)
	main._cat_split(1)
	main._pet_help("raven")
	main._pet_help("raven")
	await create_timer(1.0).timeout
	var reds := 0
	for m in main.raven_marks.marks:
		reds += 1 if m.vowel else 0
	if reds != 1 or main.raven_marks.marks.size() != 2:
		_fail("_T_ER: one red and one black mark expected, %d red of %d" % [reds, main.raven_marks.marks.size()])
	# Leaving while it flies is harmless; a new word has no marks.
	main._start_level(15)
	await process_frame
	main._pet_help("raven")
	main._show_screen(main.Screen.LEVELS)
	await create_timer(1.2).timeout
	main._start_level(19)
	await process_frame
	if not main.raven_spots.is_empty() or not main.raven_marks.marks.is_empty():
		_fail("an old raven mark is in a new word")
	main.owned_upgrades = {}
	print("raven ok")


## Vision: one picture for every missing letter, one per potion, and then no more for this word.
func _check_vision(main: Node) -> void:
	# Wisdom: one buy per missing letter; with one letter the first buy tells everything.
	main.owned_upgrades = {}
	for lvl in [1, 2, 4, 10, 19, 29]:
		main._start_level(lvl)
		await process_frame
		var buys: int = mini(main.puzzle.missing.size(), String(main.puzzle.meaning).split(" ", false).size())
		if main._wisdom_steps() != buys:
			_fail("book %d: %d Wisdom buys instead of %d" % [lvl, main._wisdom_steps(), buys])
		for i in buys:
			if i > 0 and main._meaning_snippet() == main.puzzle.meaning:
				_fail("book %d: the meaning of %s was complete after %d of %d buys" % [lvl, main.puzzle.word, i, buys])
			main.potions[PotionArt.WISDOM] = 10
			main._drink_wisdom()
		if main._meaning_snippet() != main.puzzle.meaning:
			_fail("book %d: %d Wisdom buys do not tell the meaning of %s" % [lvl, buys, main.puzzle.word])
		main.potions[PotionArt.WISDOM] = 10
		main._drink_wisdom()
		if main.potions[PotionArt.WISDOM] != 10:
			_fail("book %d: Wisdom could be bought more than %d times" % [lvl, buys])
	main.owned_upgrades = {}
	for lvl in [1, 4, 10, 19, 29]:
		main._start_level(lvl)
		await process_frame
		var n: int = main.puzzle.missing.size()
		var all: int = main.puzzle.pictures.size()
		if main._vision_count() != all or main._vision_steps() != n or all < n:
			_fail("book %d: %s has %d pictures and %d buys for %d letters" % [lvl, main.puzzle.word, all, main._vision_steps(), n])
		for i in n:
			if i > 0 and main._pictures_after(i) <= main._pictures_after(i - 1) or main._pictures_after(i) >= all:
				_fail("book %d: Vision buy %d of %d shows nothing new, or all too soon" % [lvl, i, n])
			main.potions[PotionArt.VISION] = 10
			main._drink_vision()
			await create_timer(0.1).timeout
		await create_timer(2.0).timeout
		if main.picture_alphas.min() < 0.99 or main.picture_alphas.size() != all:
			_fail("book %d: after %d potions the pictures are %s" % [lvl, n, main.picture_alphas])
		main.potions[PotionArt.VISION] = 10
		main._drink_vision()
		if main.potions[PotionArt.VISION] != 10 or main.vision_level != n or not main.potion_buttons[PotionArt.VISION].disabled:
			_fail("book %d: Vision works more than %d times" % [lvl, n])
	# Four missing letters: a quarter of the pictures at a time.
	main._start_level(19)
	await process_frame
	main.potions[PotionArt.VISION] = 10
	main._drink_vision()
	await create_timer(1.6).timeout
	var first: int = ceili(main._vision_count() / 4.0)
	if main.picture_alphas[first - 1] < 0.99 or main.picture_alphas[first] > 0.0:
		_fail("the first of 4 potions should show %d pictures: %s" % [first, main.picture_alphas])
	# A new word starts hidden again; a brewed one shows them all.
	_solve(main, main.puzzle.word, false)
	main._stir()
	await create_timer(2.6).timeout
	if main.picture_alphas.min() < 0.99:
		_fail("a brewed word does not show all its pictures")
	await create_timer(1.5).timeout
	if main.word_number != 1 or main.picture_alphas.max() > 0.0 or main.vision_level != 0:
		_fail("the next word still shows pictures: %s" % [main.picture_alphas])
	# Clear sight: two potions fewer, so more at a time.
	main.owned_upgrades = {"sight": 2}
	main._start_level(19)
	await process_frame
	main.potions[PotionArt.VISION] = 10
	main._drink_vision()
	await create_timer(1.6).timeout
	var half: int = ceili(main._vision_count() / 2.0)
	if main._vision_steps() != 2 or main.picture_alphas[half - 1] < 0.99 or main.picture_alphas[half] > 0.0:
		_fail("Clear sight 2: the first of two potions should show %d pictures: %s" % [half, main.picture_alphas])
	main.owned_upgrades = {}
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	# Hallucination: a free Vision at the start of some words.
	main.owned_upgrades = {}
	main.potions = {PotionArt.WISDOM: 1, PotionArt.VISION: 1}
	var had := [0, 0]
	for rank in [0, 5]:
		main.owned_upgrades = {"hallucination": rank}
		for i in 120:
			main._start_level(11)
			if main.vision_level > 0:
				had[0 if rank == 0 else 1] += 1
				if main.vision_level != 1 or main.word_score() != 1.0 or main.potions[PotionArt.VISION] != 1:
					_fail("a hallucination should be one free Vision: %d, %.2f, %s" % [main.vision_level, main.word_score(), main.potions])
	if had[0] != 0 or had[1] < 36 or had[1] > 84:
		_fail("hallucinations in %d of 120 words without it, %d with 50%%" % had)
	main.owned_upgrades = {}
	main._start_level(11)
	main._hallucinate()
	await create_timer(1.9).timeout
	if main.picture_alphas[0] < 0.99 or main.picture_alphas[-1] > 0.0:
		_fail("a hallucination does not show the first pictures only: %s" % [main.picture_alphas])
	main.potions[PotionArt.VISION] = 10
	main._drink_vision()
	if main.vision_level != 2 or absf(main.word_score() - 0.5) > 0.001:
		_fail("a Vision bought after a hallucination: %d, %.2f" % [main.vision_level, main.word_score()])
	main.potions = {PotionArt.WISDOM: 2, PotionArt.VISION: 2}
	# Every word has enough different pictures.
	for e in GameData.all_words():
		var word := String(e[0])
		var most := 1
		for settings in GameData.LEVELS:
			if GameData.length_distance(word.length(), settings) == 0:
				most = maxi(most, mini(settings.missing_max, GameData.most_missing(word.length())))
		var pics := GameData.pictures(e)
		var different := {}
		for p in pics:
			different[p] = true
			if p.begins_with("@") and MenuKit.drawing(p) == null:
				_fail("%s has no drawing %s" % [word, p])
			elif p.begins_with("@") and MenuKit.drawing(p) != MenuKit.drawing(p):
				_fail("drawing %s is not kept loaded" % p)
		if pics.size() < most or different.size() != pics.size():
			_fail("%s has %d pictures (%d different), needs %d" % [word, pics.size(), different.size(), most])
	print("vision: one picture per missing letter ok")


## A word is worth 1, shared between all helpers; every helper is really counted when used.
func _check_helpers(main: Node) -> void:
	main.owned_upgrades = {"familiar": 1, "cat": 1}
	main.potions = {PotionArt.WISDOM: 10, PotionArt.VISION: 10}
	main._start_level(7)
	await process_frame
	var help := {
		"wisdom": main._drink_wisdom, "vision": main._drink_vision,
	}
	if help.size() != main.HELPERS.size():
		_fail("this test covers %d helpers, the game has %d" % [help.size(), main.HELPERS.size()])
	# The pets are free.
	main._pet_help("familiar")
	main._cat_split(main._cat_gaps()[0])
	if main.word_score() != 1.0 or _revealed(main) != 1 or main.cat_splits.is_empty():
		_fail("using the owl and the cat should cost nothing: %.2f" % main.word_score())
	var used := 0
	for id in main.HELPERS:
		help[id].call()
		used += 1
		if not main.helpers_used.has(id) or absf(main.word_score() - (1.0 - 0.5 * used)) > 0.0001:
			_fail("after %d helpers (%s) the word gives %.2f" % [used, id, main.word_score()])
	if main.word_score() != 0.0:
		_fail("a word solved with every helper should give 0, not %f" % main.word_score())
	# All helpers on the first word: 9 of 10. The next word starts fresh.
	_solve(main, main.puzzle.word, false)
	await main._stir()
	if main.plain_points != 0.0 or main.word_score() != 1.0:
		_fail("helpers carried over to the next word: %.2f, %.2f" % [main.plain_points, main.word_score()])
	# Tenths that don't add up exactly in binary still reach whole numbers.
	main.level_records = {1: {"best": 9.8, "conquered": false}, 2: {"best": 10.2 - 0.0000001, "conquered": false}}
	if main.total_stars() != 20.0 or main._upgrade_lock_reason("discount") != "":
		_fail("20 stars are %f and do not unlock Potion discount" % main.total_stars())
	main.level_records = {}
	for pair in [[10.0, "10"], [9.6, "9.6"], [0.0, "0"], [0.25, "0.25"], [95.5, "95.5"], [100.0, "100"]]:
		if MenuKit.points_text(pair[0]) != pair[1]:
			_fail("%f is shown as %s" % [pair[0], MenuKit.points_text(pair[0])])
	# A book may have more levels: its perfect score grows along.
	if GameData.total_words() != 290:
		_fail("all books together should give 290, not %d" % GameData.total_words())
	var bigger: Dictionary = GameData.LEVELS[0].duplicate()
	bigger["words"] = 15
	if main.dealer.pick(main.theme, bigger).size() != 15:
		_fail("a book with 15 levels did not get 15 words")
	main.owned_upgrades = {}
	print("helpers share 1 point: ", main.HELPERS)


## Holding a spell you can't pay for deciphers only the share of the price you have.
func _check_partial_reveal(main: Node, book: SpellBook) -> void:
	main.owned_upgrades = {}
	for part in [0.0, 0.25, 0.5, 0.9, 1.0]:
		main.score = roundi(main._upgrade_price("sage") * part)
		var had: int = main.score
		_press_spell(book, "sage", true)
		await create_timer(SpellBook.HOLD_TIME + 0.3).timeout
		var reveal := book.reveal_of("sage", main.skill_info("sage"))
		if absf(reveal - part) > 0.01:
			_fail("with %d%% of the price, %d%% of the spell is readable" % [part * 100, reveal * 100])
		if part < 1.0 and (main.rank_of("sage") != 0 or main.score != had):
			_fail("a spell was bought with only %d%% of its price" % (part * 100))
		if part == 1.0 and main.rank_of("sage") != 1:
			_fail("a spell was not bought with exactly its price")
		_press_spell(book, "sage", false)
	# Letting go hides it again; a learned spell stays readable while you can't pay the next rank.
	main.owned_upgrades = {}
	main.score = 60
	_press_spell(book, "sage", true)
	await create_timer(0.3).timeout
	_press_spell(book, "sage", false)
	if book.reveal_of("sage", main.skill_info("sage")) != 0.0:
		_fail("letting go did not hide the spell's text again")
	main.owned_upgrades = {"sage": 1}
	_press_spell(book, "sage", true)
	await create_timer(0.3).timeout
	if book.reveal_of("sage", main.skill_info("sage")) != 1.0:
		_fail("a learned spell became unreadable when held without enough points")
	_press_spell(book, "sage", false)
	# Not enough stars: points don't help.
	var records: Dictionary = main.level_records
	main.level_records = {}
	main.owned_upgrades = {}
	main.score = 100000
	_press_spell(book, "sage", true)
	await create_timer(0.3).timeout
	if book.hold_id != "" or book.reveal_of("sage", main.skill_info("sage")) != 0.0:
		_fail("a spell locked by stars could be deciphered")
	_press_spell(book, "sage", false)
	main.level_records = records
	# Held on: one rank after the other, at the same pace, until it is full.
	main.owned_upgrades = {}
	main.score = 100000
	_press_spell(book, "sage", true)
	await create_timer(SpellBook.HOLD_TIME + 0.3).timeout
	if main.rank_of("sage") != 1:
		_fail("holding did not learn the first rank")
	await create_timer(SpellBook.HOLD_TIME).timeout
	if main.rank_of("sage") != 2 or book.hold_id != "":
		_fail("holding on did not learn the next rank: rank %d" % main.rank_of("sage"))
	_press_spell(book, "sage", false)
	# Unlocked shows at once, also without the knowledge to learn it.
	main.owned_upgrades = {}
	main.score = 0
	if not main.skill_info("sage").open or main.skill_info("sage").can_buy:
		_fail("an unlocked spell does not show as open without knowledge: %s" % main.skill_info("sage"))
	main.score = 100000  # as before these checks
	print("partial reveal ok")


func _press_spell(book: SpellBook, id: String, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = book.node_center(id)
	book._canvas_input(e)


func _expect_level(main: Node, lvl: int, points: float) -> void:
	var rec: Dictionary = main.level_records.get(lvl, {})
	if rec.is_empty() or rec.conquered or rec.best != points:
		_fail("level %d: expected %.1f points, not conquered; got %s" % [lvl, points, rec])
	else:
		print("book %d: %s / 10" % [lvl, MenuKit.points_text(rec.best)])


## Brews all 10 words of the current level; drinks the given potions on the first word.
func _play_level(main: Node, drinks: Array = []) -> void:
	for w in GameData.WORDS_PER_LEVEL:
		if w == 0:
			for d in drinks:
				if d == "vision":
					main._drink_vision()
				else:
					main._drink_wisdom()
		var word: String = main.puzzle.word
		_solve(main, word, false)
		await main._stir()


func _revealed(main: Node) -> int:
	var n := 0
	for t in main.tiles:
		n += 1 if t.revealed else 0
	return n


## Places tiles straight into the word, the same way a drop does.
func _solve(main: Node, word: String, wrong: bool) -> void:
	for t in main.tiles:
		if t.in_word:
			main._take_out_of_word(t)
			t.in_word = false
	var free_tiles: Array = main.tiles.duplicate()
	var missing: Array = main.puzzle.missing
	var needed: Array = []
	for idx in missing:
		needed.append(word[idx])
	for n in missing.size():
		var idx: int = missing[n]
		var letter: String = word[idx]
		var pick: LetterTile = null
		for t in free_tiles:
			var ok: bool = t.letter == letter
			if wrong and n == 0:
				ok = not (t.letter in needed)  # a pure decoy
			if ok:
				pick = t
				break
		free_tiles.erase(pick)
		pick.in_word = true
		if main.puzzle.gaps_visible:
			for item in main.row:
				if item is GapSlot and item.index == idx:
					item.tile = pick
		else:
			main.row.insert(idx, pick)
	main._layout_row(false)
