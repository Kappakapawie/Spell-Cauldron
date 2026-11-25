class_name MenuKit
extends RefCounted

## Small helpers shared by the game HUD and all menu screens.

const INK := Color("4a2c17")
const CREAM := Color("fff3d6")
const GOLD := Color("ffd45c")


static func label(text: String, font_size: int, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_size: Vector2, on_press: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_size.x, maxf(min_size.y, ScreenLayout.pick(0, 60)))  # fingers need room
	b.focus_mode = Control.FOCUS_NONE
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A score as short text: 10, 9.6, 0.25.
static func points_text(v: float) -> String:
	var t := "%.2f" % v
	return t.rstrip("0").rstrip(".")


## Drawings that were shown before. They must stay loaded: a texture that is only drawn, and not kept
## anywhere, is gone before the picture reaches the screen.
static var _drawings := {}


## The drawing for a picture like "@mole", or null for an emoji.
static func drawing(picture: String) -> Texture2D:
	if not picture.begins_with("@"):
		return null
	if not _drawings.has(picture):
		_drawings[picture] = load("res://art/pictures/%s.svg" % picture.substr(1)) as Texture2D
	return _drawings[picture]


## A small picture (emoji or drawing) for a list.
static func picture(pic: String, font_size: int, emoji_font: Font) -> Control:
	var art := drawing(pic)
	if art:
		var r := TextureRect.new()
		r.texture = art
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2.ONE * font_size * 1.4
		return r
	var l := label(pic, font_size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if emoji_font:
		l.add_theme_font_override("font", emoji_font)
	return l
