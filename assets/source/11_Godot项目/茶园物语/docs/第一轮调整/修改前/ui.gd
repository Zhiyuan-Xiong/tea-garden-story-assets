extends Node

const INK: Color = Color("#45574d")
const MUTED: Color = Color("#687668")
const PAPER: Color = Color("#f8f5e9")
var body_font: Font = preload("res://fonts/User_Body.ttf")
var title_font: Font = preload("res://fonts/Title_TangXianBinSong.otf")
var game_theme: Theme

func _ready() -> void:
	# 标题优先使用用户指定字体；未收录的字才回退至用户指定的正文字体。
	title_font.fallbacks = [body_font]
	game_theme = Theme.new()
	game_theme.default_font = body_font
	game_theme.default_font_size = 26
	game_theme.set_color("font_color", "Label", INK)
	game_theme.set_color("font_color", "Button", INK)

func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func art(id: String, parent: Node, rect: Rect2, crop: bool = true) -> TextureRect:
	var node = TextureRect.new()
	node.texture = AssetLibrary.texture(id, crop)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, rect)
	return node

func prop(id: String, parent: Node, at: Vector2, width: float) -> TextureRect:
	return art(id, parent, Rect2(at, Vector2(width, width * AssetLibrary.ratio(id))))

func label(text: String, parent: Node, rect: Rect2, font_size: int = 26, heading: bool = false, color: Color = INK) -> Label:
	var node = Label.new()
	parent.add_child(node)
	node.theme = game_theme
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.clip_text = true
	node.clip_contents = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", title_font if heading else body_font)
	node.add_theme_color_override("font_color", color)
	node.set_meta("box", rect)
	node.set_meta("requested_size", font_size)
	node.add_to_group("game_text")
	place(node, rect)
	node.custom_maximum_size = rect.size
	set_text(node, text)
	return node

func set_text(node: Label, text: String) -> void:
	node.text = text
	var rect: Rect2 = node.get_meta("box")
	var desired: int = node.get_meta("requested_size", 26)
	var font: Font = node.get_theme_font("font")
	var fitted: int = desired
	while fitted > 16:
		var measure: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, maxf(rect.size.x - 8.0, 1.0), fitted)
		if measure.y <= rect.size.y - 6.0 and measure.x <= rect.size.x:
			break
		fitted -= 1
	node.add_theme_font_size_override("font_size", fitted)
	node.size = rect.size

func button(text: String, parent: Node, rect: Rect2, callback: Callable, green: bool = true) -> TextureButton:
	var node = TextureButton.new()
	var ids: Array = ["UI_040", "UI_041", "UI_042", "UI_043"] if green else ["UI_010", "UI_011", "UI_012", "UI_013"]
	node.texture_normal = AssetLibrary.texture(ids[0])
	node.texture_hover = AssetLibrary.texture(ids[1])
	node.texture_pressed = AssetLibrary.texture(ids[2])
	node.texture_disabled = AssetLibrary.texture(ids[3])
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_SCALE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	place(node, rect)
	var caption = label(text, node, Rect2(24, 6, rect.size.x - 48, rect.size.y - 12), 26)
	node.set_meta("caption", caption)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node

func icon_button(id: String, title: String, parent: Node, at: Vector2, callback: Callable, width: float = 74.0) -> Button:
	var node = Button.new()
	node.flat = true
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.tooltip_text = title
	parent.add_child(node)
	place(node, Rect2(at, Vector2(width, width + 40)))
	art("UI_014", node, Rect2(0, 0, width, width))
	art(id, node, Rect2(width * 0.23, width * 0.20, width * 0.54, width * 0.54))
	label(title, node, Rect2(-20, width + 2, width + 40, 33), 20)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node

func flat_card(parent: Node, rect: Rect2, color: Color = Color("#eeeee0")) -> Panel:
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#adb5a0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	place(panel, rect)
	return panel

func meter(parent: Node, rect: Rect2, value: float, color: Color = Color("#8fa682")) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty = StyleBoxFlat.new()
	empty.bg_color = Color("#dcded0")
	empty.set_corner_radius_all(8)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", empty)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	place(bar, rect)
	return bar

func chrome(parent: Control, title: String, village: bool = false) -> void:
	art("UI_002", parent, Rect2(45, 35, 330, 71))
	label(title, parent, Rect2(85, 45, 250, 51), 32, true, PAPER)
	art("UI_006", parent, Rect2(600, 34, 615, 65))
	art("PRP_308", parent, Rect2(627, 50, 32, 32))
	art("ICO_108", parent, Rect2(826, 49, 32, 32))
	art("PRP_103", parent, Rect2(1030, 51, 37, 29))
	var money = label("", parent, Rect2(665, 47, 135, 38), 24)
	var day_label = label("", parent, Rect2(860, 47, 143, 38), 24)
	var fresh_label = label("", parent, Rect2(1070, 47, 129, 38), 24)
	var goal = label("", parent, Rect2(54, 121, 690, 48), 22)
	var update = func() -> void:
		set_text(money, str(GameState.copper) + " 铜钱")
		set_text(day_label, "第 " + str(GameState.day) + " 日")
		set_text(fresh_label, "鲜叶 " + str(GameState.fresh))
		set_text(goal, GameState.objective() if GameState.settings.show_hints else "")
	update.call()
	GameState.changed.connect(update)
	parent.tree_exiting.connect(func(): if GameState.changed.is_connected(update): GameState.changed.disconnect(update), CONNECT_ONE_SHOT)
	icon_button("ICO_402", "存读档", parent, Vector2(1465, 30), func(): SceneRouter.modal("saves", {"mode": "save"}), 68)
	icon_button("ICO_106", "制茶手记", parent, Vector2(1562, 30), func(): SceneRouter.modal("journal"), 68)
	icon_button("ICO_107", "设置", parent, Vector2(1659, 30), func(): SceneRouter.modal("settings"), 68)
	icon_button("ICO_404", "主页", parent, Vector2(1756, 30), func(): SceneRouter.go("home"), 68)
	button("返回主页" if village else "返回茶村", parent, Rect2(53, 955, 265, 59), func(): SceneRouter.go("home" if village else "village"), false)

func toolbar(parent: Control, entries: Array) -> void:
	art("UI_005", parent, Rect2(527, 927, 870, 96))
	var start: float = 527 + (870 - ((entries.size() - 1) * 158 + 72)) * 0.5
	for i in range(entries.size()):
		var entry: Array = entries[i]
		icon_button(entry[0], entry[1], parent, Vector2(start + i * 158, 917), entry[2], 72)
