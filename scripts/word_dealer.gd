class_name WordDealer
extends RefCounted

## Chooses the words for a recipe book so that they repeat as little as possible:
## words the player has not seen yet come first, then the ones seen longest ago.
## What was seen is kept in the save file, so it also counts after a restart.

var _seen := {}      ## theme -> {word: when it was last shown (a rising number)}
var _clock := 0


## The player has been shown this word.
func mark_seen(theme: String, word: String) -> void:
	_clock += 1
	if not _seen.has(theme):
		_seen[theme] = {}
	_seen[theme][word.to_lower()] = _clock


## Can this theme fill a book with words that were not seen yet?
func has_enough(theme: String, settings: Dictionary) -> bool:
	var seen: Dictionary = _seen.get(theme, {})
	var count := 0
	for e in GameData.THEMES[theme]:
		if not seen.has(e[0]) and GameData.length_distance(String(e[0]).length(), settings) == 0:
			count += 1
	return count >= GameData.words_in(settings)


## The entries for one book, in random order:
##   0. words in `first` that fit (pet names still to be spelled),
##   1. words not seen yet,
##   2. words seen longest ago,
##   3. only if the theme has too few words of the right length: the nearest lengths.
func pick(theme: String, settings: Dictionary, first: Array = []) -> Array:
	var want := GameData.words_in(settings)
	var fresh: Array = []   # unseen, right length
	var stale: Array = []   # seen, right length
	var others: Array = []  # wrong length
	var seen: Dictionary = _seen.get(theme, {})
	for e in GameData.THEMES[theme]:
		if GameData.length_distance(String(e[0]).length(), settings) > 0:
			others.append(e)
		elif seen.has(e[0]):
			stale.append(e)
		else:
			fresh.append(e)
	var out: Array = []
	var urgent := (fresh + stale).filter(func(e: Array) -> bool: return e[0] in first)
	_fill(out, urgent, want)
	fresh = fresh.filter(func(e: Array) -> bool: return not (e in urgent))
	stale = stale.filter(func(e: Array) -> bool: return not (e in urgent))
	fresh.shuffle()
	_fill(out, fresh, want)
	# The longest-ago half, mixed, so a book that is played again and again keeps changing.
	stale.sort_custom(func(a: Array, b: Array) -> bool: return seen[a[0]] < seen[b[0]])
	var need := want - out.size()
	var old := stale.slice(0, maxi(need, stale.size() / 2))
	old.shuffle()
	_fill(out, old, want)
	others.shuffle()
	others.sort_custom(func(a: Array, b: Array) -> bool:
		return GameData.length_distance(String(a[0]).length(), settings) < GameData.length_distance(String(b[0]).length(), settings))
	_fill(out, others, want)
	var i := 0
	while out.size() < want:  # a theme smaller than the book: go round again
		out.append(out[i])
		i += 1
	out.shuffle()
	return out


func _fill(out: Array, from: Array, want: int) -> void:
	for e in from:
		if out.size() >= want:
			return
		out.append(e)


## For the save file: theme -> words, seen longest ago first.
func to_save() -> Dictionary:
	var out := {}
	for theme in _seen:
		var words: Array = _seen[theme].keys()
		words.sort_custom(func(a: String, b: String) -> bool: return _seen[theme][a] < _seen[theme][b])
		out[theme] = words
	return out


func from_save(saved: Dictionary) -> void:
	for theme in saved:
		if GameData.THEMES.has(theme):
			for word in saved[theme]:
				mark_seen(theme, word)
