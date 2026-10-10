extends Node

const INK: Color = Color("#45574d")
const MUTED: Color = Color("#687668")
const PAPER: Color = Color("#f8f5e9")
var body_font: Font = preload("res://fonts/Body_NotoSansSC.tres")
var title_font: Font = preload("res://fonts/Title_NotoSansSC.tres")
var game_theme: Theme

func _ready() -> void:
	# 公开版统一使用 Noto Sans SC；标题 600 字重，正文 400 字重。
	game_theme = Theme.new()
	game_theme.default_font = body_font
	game_theme.default_font_size = 26
	game_theme.set_color("font_color", "Label", INK)
	game_theme.set_color("font_color", "Button", INK)
	game_theme.set_font("font", "TooltipLabel", body_font)
	game_theme.set_font_size("font_size", "TooltipLabel", 23)
	game_theme.set_color("font_color", "TooltipLabel", INK)
	game_theme.set_stylebox("panel", "TooltipPanel", paper_style(18,true))
	get_tree().root.theme = game_theme

func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func art(id: String, parent: Node, rect: Rect2, crop: bool = true) -> TextureRect:
	var node = TextureRect.new()
	node.texture = AssetLibrary.texture(id, crop)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.set_meta("asset_id",id)
	if id.begins_with("CHR_"):
		node.add_to_group("character_art")
	parent.add_child(node)
	place(node, rect)
	return node

func prop(id: String, parent: Node, at: Vector2, width: float) -> TextureRect:
	var image = art(id, parent, Rect2(at, Vector2(width, width * AssetLibrary.ratio(id))))
	image.add_to_group("illustration_art")
	if id.begins_with("PLT_"):
		var foliage := ShaderMaterial.new()
		foliage.shader = preload("res://shaders/foliage_sway.gdshader")
		image.material = foliage
		image.add_to_group("ambient_foliage")
	return image

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
	var caption = label(text, node, Rect2(24, 6, rect.size.x - 48, rect.size.y - 12), 26, false, PAPER)
	caption.add_theme_color_override("font_shadow_color", Color(0.23, 0.27, 0.20, 0.55))
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.add_theme_constant_override("shadow_offset_x", 0)
	node.set_meta("caption", caption)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node

func icon_button(id: String, title: String, parent: Node, at: Vector2, callback: Callable, width: float = 84.0) -> Button:
	var node: Button = preload("res://scripts/ui/paper_icon_button.gd").new()
	node.flat = true
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.tooltip_text = title
	parent.add_child(node)
	place(node, Rect2(at, Vector2(width, width + 44)))
	art("UI_014", node, Rect2(0, 0, width, width))
	art(id, node, Rect2(width * 0.18, width * 0.16, width * 0.64, width * 0.64))
	var caption_plate = flat_card(node, Rect2(-9, width + 4, width + 18, 36), Color(0.98, 0.97, 0.92, 0.94))
	caption_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(title, node, Rect2(-7, width + 5, width + 14, 34), 20)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node

func paper_style(margin: float = 12.0, small: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = AssetLibrary.texture("UI_456" if small else "UI_455")
	style.texture_margin_left = 15 if small else 40
	style.texture_margin_right = 15 if small else 40
	style.texture_margin_top = 12 if small else 36
	style.texture_margin_bottom = 12 if small else 36
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.5
	style.content_margin_bottom = margin * 0.5
	return style

func flat_card(parent: Node, rect: Rect2, _color: Color = Color("#eeeee0")) -> Panel:
	var panel = Panel.new()
	panel.add_to_group("paper_frames")
	panel.add_theme_stylebox_override("panel", paper_style(12.0, rect.size.y < 80))
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
	art("UI_006",parent,Rect2(600,34,820,65))
	art("ICO_457",parent,Rect2(624,49,30,30))
	var money = label("",parent,Rect2(661,47,166,38),22)
	art("ICO_108",parent,Rect2(861,48,32,32))
	var day_label = label("",parent,Rect2(899,47,108,38),22)
	art("ICO_201",parent,Rect2(1031,48,32,32))
	var profession_label = label("",parent,Rect2(1069,47,160,38),22)
	var experience_label = label("",parent,Rect2(1237,47,147,38),21)
	for x in [841,1016]:
		var line := ColorRect.new()
		line.color = Color(0.72,0.64,0.39,0.28)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
		place(line,Rect2(x,50,1,31))
	var update = func() -> void:
		set_text(money,str(GameState.copper)+" 铜钱")
		set_text(day_label,"第 "+str(GameState.day)+" 日")
		set_text(profession_label,str(GameState.RULES.professions[GameState.profession].name))
		set_text(experience_label,"经验 "+str(GameState.experience))
	update.call()
	GameState.changed.connect(update)
	parent.tree_exiting.connect(func(): if GameState.changed.is_connected(update): GameState.changed.disconnect(update),CONNECT_ONE_SHOT)
	var todo: Control = preload("res://scripts/components/daily_todo_sidebar.gd").new()
	parent.add_child(todo)
	for editor in get_tree().get_nodes_in_group("furniture_editors"):
		if parent.is_ancestor_of(editor): editor.mode_changed.connect(func(_enabled: bool):todo.refresh())
	icon_button("ICO_402", "存读档", parent, Vector2(1442, 24), func(): SceneRouter.modal("saves", {"mode": "save"}), 84)
	icon_button("ICO_106", "制茶手记", parent, Vector2(1548, 24), func(): SceneRouter.modal("journal"), 84)
	icon_button("ICO_107", "设置", parent, Vector2(1654, 24), func(): SceneRouter.modal("settings"), 84)
	icon_button("ICO_404", "主页", parent, Vector2(1760, 24), func(): SceneRouter.go("home"), 84)
	button("返回主页" if village else "返回茶村", parent, Rect2(53, 955, 265, 59), func(): SceneRouter.go("home" if village else "village"), false)

func toolbar(parent: Control, entries: Array) -> void:
	var spacing: float = 148.0 if entries.size()>=6 else 164.0
	var width: float = 1020.0 if entries.size()>=6 else 900.0
	var left: float = (1920.0-width)*0.5
	art("UI_005",parent,Rect2(left,924,width,116))
	var start: float = 960.0-((entries.size()-1)*spacing+88.0)*0.5
	for i in range(entries.size()):
		var entry: Array = entries[i]
		icon_button(entry[0],entry[1],parent,Vector2(start+i*spacing,907),entry[2],88)


# 所有物件以实际落地点定位；仿射校准保持垂直支脚不倾斜。
func ground_prop(id: String, parent: Node, point: Vector2, width: float, calibration: Transform2D = Transform2D.IDENTITY) -> TextureRect:
	var support = Node2D.new()
	support.name = id + "_Support"
	parent.add_child(support)
	support.transform = calibration
	support.position = point
	support.set_meta("asset_id", id)
	support.set_meta("ground_point", point)
	support.add_to_group("grounded_art")
	var height: float = width * AssetLibrary.ratio(id)
	var anchor: Vector2 = SceneLayout.anchor(id)
	var node = art(id, support, Rect2(-width*anchor.x,-height*anchor.y,width,height))
	node.name = id + "_Image"
	node.set_meta("asset_id", id)
	return node


func background_depth(background: TextureRect, room: String, registered_rect: Rect2 = Rect2(0,0,1920,1080)) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/background_depth.gdshader")
	mat.set_shader_parameter("scene_texture",background.texture)
	mat.set_shader_parameter("distance_mask",load("res://assets/13_Figma原图拆分/depth_"+room+".png"))
	mat.set_shader_parameter("scene_region",Vector4(registered_rect.position.x/1920.0,registered_rect.position.y/1080.0,registered_rect.size.x/1920.0,registered_rect.size.y/1080.0))
	mat.set_shader_parameter("near_fade",0.0 if room == "loading" else (0.22 if room == "home" else 0.075))
	mat.set_shader_parameter("mist_strength",0.10 if room == "loading" else (0.23 if room == "home" else (0.50 if room in ["village","garden"] else 0.53)))
	background.material = mat
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.set_meta("depth_room",room)
