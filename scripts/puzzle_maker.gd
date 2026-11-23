class_name PuzzleMaker
extends RefCounted

## Turns a word + level settings into a puzzle:
## which letters are missing, and which letters lie on the table.

## Decoys are drawn from this pool, so common letters show up more often.
const LETTER_POOL := "EEEEEEAAAAIIIIOOOONNNNRRRRTTTTLLLSSSSUUDDDGGBBCCMMPPFFHHVWWYYKJXQZ"

static var _dictionary: Array[String] = []


## entry = [word, meaning]. Returns:
## {word, meaning, missing: Array[int] (sorted), tiles: Array[String], gaps_visible}
static func make(entry: Array, settings: Dictionary) -> Dictionary:
	var word: String = String(entry[0]).to_upper()
	var n := word.length()
	var gaps_visible: bool = settings.gaps_visible
	var k := clampi(randi_range(settings.missing_min, settings.missing_max), 1, n - 1)

	# Pick which letters to take out. Re-roll if the correct letters alone
	# could also spell some other real word.
	var missing: Array = []
	for _attempt in 20:
		var order: Array = range(n)
		order.shuffle()
		missing = order.slice(0, k)
		missing.sort()
		if not _allows_other_word(word, missing, _letters_at(word, missing), gaps_visible):
			break

	var tiles: Array = _letters_at(word, missing)
	var wanted: int = settings.decoys
	var added := 0
	var tries := 0
	while added < wanted and tries < 400:
		tries += 1
		var c := LETTER_POOL[randi() % LETTER_POOL.length()]
		if c in tiles:
			continue  # keep decoys different from each other and from the right letters
		tiles.append(c)
		if _allows_other_word(word, missing, tiles, gaps_visible):
			tiles.pop_back()
		else:
			added += 1
	tiles.shuffle()

	return {
		"word": word,
		"meaning": entry[1],
		"picture": GameData.PICTURES.get(String(entry[0]).to_lower(), ""),
		"missing": missing,
		"tiles": tiles,
		"gaps_visible": gaps_visible,
	}


static func _letters_at(word: String, indices: Array) -> Array:
	var out: Array = []
	for i in indices:
		out.append(word[i])
	return out


## Could the player build a real word other than `word` with these tiles?
static func _allows_other_word(word: String, missing: Array, tiles: Array, gaps_visible: bool) -> bool:
	var fixed := ""
	for i in word.length():
		if not (i in missing):
			fixed += word[i]

	for w in dictionary():
		if w == word:
			continue
		if gaps_visible:
			# Same length, same letters in the fixed spots, gaps filled from the tiles.
			if w.length() != word.length():
				continue
			var ok := true
			var need: Array = []
			for i in word.length():
				if i in missing:
					need.append(w[i])
				elif w[i] != word[i]:
					ok = false
					break
			if ok and _is_submultiset(need, tiles):
				return true
		else:
			# Hidden gaps: letters can be slotted in anywhere between the fixed ones.
			if w.length() <= fixed.length() or w.length() > fixed.length() + tiles.size():
				continue
			if not _is_subsequence(fixed, w):
				continue
			var rest: Array = []
			for ch in w:
				rest.append(ch)
			for ch in fixed:
				rest.erase(ch)
			if _is_submultiset(rest, tiles):
				return true
	return false


static func _is_subsequence(needle: String, hay: String) -> bool:
	var j := 0
	for ch in hay:
		if j < needle.length() and needle[j] == ch:
			j += 1
	return j == needle.length()


static func _is_submultiset(need: Array, pool: Array) -> bool:
	var left := pool.duplicate()
	for ch in need:
		var idx := left.find(ch)
		if idx < 0:
			return false
		left.remove_at(idx)
	return true


static func dictionary() -> Array[String]:
	if _dictionary.is_empty():
		var seen := {}
		for e in GameData.WORDS:
			seen[String(e[0]).to_upper()] = true
		var raw := GameData.CHECK_WORDS.replace("\n", " ").replace("\t", " ")
		for w in raw.split(" ", false):
			seen[w.to_upper()] = true
		for key in seen.keys():
			_dictionary.append(key)
	return _dictionary
