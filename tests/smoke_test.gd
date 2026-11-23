extends SceneTree

## Headless check: run with
##   godot --headless --path . --script res://tests/smoke_test.gd
## Generates puzzles on every level and solves one word per level through the real game scene.

var failures := 0


func _initialize() -> void:
	_check_puzzles()
	_check_gameplay.call_deferred()


func _fail(msg: String) -> void:
	failures += 1
	printerr("FAIL: ", msg)


func _check_puzzles() -> void:
	for lvl in GameData.LEVELS.size():
		var settings: Dictionary = GameData.LEVELS[lvl]
		var count := 0
		for e in GameData.WORDS:
			var l := String(e[0]).length()
			if l >= settings.min_len and l <= settings.max_len:
				count += 1
		if count < GameData.WORDS_PER_LEVEL:
			_fail("level %d only has %d words" % [lvl + 1, count])
		for i in 40:
			var entry: Array = GameData.WORDS[randi() % GameData.WORDS.size()]
			var p := PuzzleMaker.make(entry, settings)
			var word: String = p.word
			var tiles: Array = p.tiles.duplicate()
			for idx in p.missing:
				var at := tiles.find(word[idx])
				if at < 0:
					_fail("level %d word %s: missing letter %s not on table" % [lvl + 1, word, word[idx]])
				else:
					tiles.remove_at(at)
	print("puzzle check done")


func _check_gameplay() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.persist = false  # never touch the player's real save
	root.add_child(main)
	await process_frame
	for lvl in [1, 4, 5, 10]:
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
		# Below the cap, rewards go to the shelves instead.
		main.potions = {PotionArt.WISDOM: 0, PotionArt.VISION: 0}
		main._award_potions()
		if main.potions[PotionArt.WISDOM] + main.potions[PotionArt.VISION] != main._potion_reward():
			_fail("level %d: rewards below the cap did not reach the shelves" % lvl)
		if main.word_number != 1:
			_fail("level %d: correct answer did not advance (word %s)" % [lvl, word])
		else:
			print("level %d ok: %s" % [lvl, word])
	# Wisdom snippets: partial first, full meaning after all steps.
	main._start_level(7)
	await process_frame
	main.potions = {PotionArt.WISDOM: 10, PotionArt.VISION: 10}
	main._drink_wisdom()
	var first: String = main._meaning_snippet()
	if not first.contains("…"):
		_fail("first Wisdom potion revealed everything: %s" % first)
	for i in main._reveal_steps():
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
	if rec.is_empty() or not rec.conquered or rec.best != 100:
		_fail("perfect level 1 run was not recorded as 100 and conquered: %s" % rec)
	else:
		print("level 1 conquered with ", rec.best, " points")

	# One Vision potion on one word: that word gives 5 -> 95, not conquered.
	main._start_level(2)
	await process_frame
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	await _play_level(main, ["vision"])
	_expect_level(main, 2, 95)

	# Vision + Wisdom on one word: that word gives 0 -> 90.
	main._start_level(3)
	await process_frame
	main.potions = {PotionArt.WISDOM: 3, PotionArt.VISION: 3}
	await _play_level(main, ["vision", "wisdom"])
	_expect_level(main, 3, 90)

	# Shelves menu: buying a slot spends score and adds room.
	main.score = 100
	var price: int = main._slot_price(PotionArt.WISDOM)
	main._buy_slot(PotionArt.WISDOM)
	if main.shelf_slots[PotionArt.WISDOM] != main.START_SLOTS + 1 or main.score != 100 - price:
		_fail("buying a slot: slots %d, score %d" % [main.shelf_slots[PotionArt.WISDOM], main.score])
	else:
		print("bought a Wisdom slot for ", price, " points")

	# Owl familiar: solves whole words on easy (visible gaps) and hard (hidden gaps) levels.
	main.owned_upgrades["familiar"] = true
	main.familiar_on = true
	for lvl in [1, 4, 6, 10]:
		for attempt in 3:
			main._start_level(lvl)
			await process_frame
			var word: String = main.puzzle.word
			var guard := 0
			while main._familiar_next_index() >= 0 and guard < 10:
				main._familiar_place()
				guard += 1
			if main._spelling() != word:
				_fail("owl on level %d spelled %s, expected %s" % [lvl, main._spelling(), word])
				break
			var pts_before: int = main.level_points
			await main._stir()
			if main.level_points - pts_before != 5:
				_fail("owl-helped word on level %d gave %d points, expected 5" % [lvl, main.level_points - pts_before])
	print("owl familiar solved words on levels 1, 4, 6, 10")
	main.owned_upgrades.erase("familiar")

	# Discount and Lucky cauldron.
	main._start_level(10)
	await process_frame
	var full_cost: int = main._potion_cost()
	var reward: int = main._potion_reward()
	main.owned_upgrades["discount"] = true
	main.owned_upgrades["lucky"] = true
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
	var star_col: Control = main.level_stars[4].get_parent()
	main._cheat_click(star_col.get_global_rect().get_center(), true)
	if not main.level_records.get(5, {}).get("conquered", false):
		_fail("ctrl+click on level 5 star did not conquer it")
	main._cheat_click(star_col.get_global_rect().get_center(), false)
	if main.level_records.has(5):
		_fail("alt+click on level 5 star did not clear it")
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
	var up_row: Control = main.upgrade_rows["familiar"].row
	main._cheat_click(up_row.get_global_rect().get_center(), true)
	var hdr: Control = main.upgrade_rows["_header"].label
	main._cheat_click(hdr.get_global_rect().get_center(), true)
	if not main.owned_upgrades.has("familiar") or main.total_stars() != 1000:
		_fail("ctrl+click in Shelves menu: owl %s, stars %d" % [main.owned_upgrades.has("familiar"), main.total_stars()])
	main._cheat_click(hdr.get_global_rect().get_center(), false)
	main._cheat_click(up_row.get_global_rect().get_center(), false)
	if main.owned_upgrades.has("familiar") or main.total_stars() != 0:
		_fail("alt+click in Shelves menu did not reset")
	main.shop_panel.visible = false
	main._cheat_click(main.progress_label.get_global_rect().get_center(), true)
	if not main.complete_panel.visible or main.level_records.get(1, {}).get("best", 0) != 100:
		_fail("ctrl+click on word counter did not finish the level with 100")
	print("ctrl/alt shortcuts ok")

	print("RESULT: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)


func _expect_level(main: Node, lvl: int, points: int) -> void:
	var rec: Dictionary = main.level_records.get(lvl, {})
	if rec.is_empty() or rec.conquered or rec.best != points:
		_fail("level %d: expected %d points, not conquered; got %s" % [lvl, points, rec])
	else:
		print("level %d: %d / 100" % [lvl, rec.best])


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
