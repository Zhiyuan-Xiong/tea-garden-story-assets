extends Control
@export_enum("home", "village", "garden", "workshop", "teashop") var area: String = "home"
var entrance_labels: Dictionary = {}
var guest_image: TextureRect
var guest_label: Label
var room_items: Node2D
var order_button: TextureButton

func _ready() -> void:
	theme = UiKit.game_theme
	match area:
		"home": _home()
		"village": _village()
		"garden": _garden()
		"workshop": _workshop()
		"teashop": _teashop()

func _home() -> void:
	UiKit.art("LOG_301", self, Rect2(740, 555, 440, 320))
	UiKit.button("新的旅程", self, Rect2(780, 920, 360, 82), _new_game)
	var latest: int = SaveSystem.latest_slot()
	var resume = UiKit.button("继续旅程", self, Rect2(1190, 935, 225, 60), func(): _continue(latest), false)
	resume.disabled = latest < 0
	UiKit.icon_button("ICO_403", "读取存档", self, Vector2(1630, 45), func(): SceneRouter.modal("saves", {"mode": "load"}))
	UiKit.icon_button("ICO_107", "设置", self, Vector2(1760, 45), func(): SceneRouter.modal("settings"))
	UiKit.label("种一株茶，制一批茶，待一位客", self, Rect2(704, 860, 512, 45), 25)
	UiKit.label("茶园物语 · 国风制茶轻经营", self, Rect2(710, 1023, 500, 32), 18)

func _new_game() -> void:
	if GameState.started or SaveSystem.latest_slot() >= 0:
		SceneRouter.modal("confirm", {"title": "启程前", "text": "开启新的旅程会替换自动存档。\n两份手动存档将保留，可先读取或保存旧进度。", "action": "new"})
	else:
		GameState.reset()
		SceneRouter.go("village")

func _continue(slot: int) -> void:
	if slot >= 0 and SaveSystem.load_slot(slot):
		SceneRouter.go(GameState.last_scene)
	else:
		GameState.notice.emit("暂无可读取的存档。")

func _entrance(title: String, detail: String, rect: Rect2, target: String) -> void:
	var card = UiKit.flat_card(self, rect, Color(0.97, 0.96, 0.90, 0.94))
	UiKit.label(title, card, Rect2(10, 3, rect.size.x - 20, 38), 29, true)
	entrance_labels[target] = UiKit.label(detail, card, Rect2(8, 43, rect.size.x - 16, 35), 20)
	var button = Button.new()
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_child(button)
	UiKit.place(button, Rect2(Vector2.ZERO, rect.size))
	button.pressed.connect(func(): SceneRouter.go(target))

func _village() -> void:
	for row in [[Vector2(215,265),Vector2(360,260),Vector2(506,262)],[Vector2(239,409),Vector2(392,405),Vector2(545,408)],[Vector2(359,548),Vector2(513,543),Vector2(668,546)]]:
		for point in row:
			UiKit.prop("PLT_101",self,point,112)
	var workshop_image = UiKit.ground_prop("BLD_111",self,Vector2(1374,560),330)
	_building_click(workshop_image,"workshop")
	var shop_image = UiKit.ground_prop("BLD_112",self,Vector2(1628,752),352)
	_building_click(shop_image,"teashop")
	UiKit.ground_prop("CHR_002",self,Vector2(1341,662),44)
	_entrance("云雾茶园","种植、照料与采摘",Rect2(287,175,295,87),"garden")
	_entrance("制茶工坊","从鲜叶到一炉新茶",Rect2(1225,318,290,87),"workshop")
	_entrance("临水茶铺","以新茶招待来客",Rect2(1481,489,290,87),"teashop")
	GameState.changed.connect(_update_destinations)
	_update_destinations()
	UiKit.chrome(self,"茶村",true)
	UiKit.button("看看背包",self,Rect2(795,952,330,65),func():SceneRouter.modal("inventory"),false)
	if not GameState.milestones.has("welcome"):
		call_deferred("_welcome")

func _welcome() -> void:
	SceneRouter.modal("welcome")

func _garden() -> void:
	var packed: PackedScene = preload("res://scenes/components/tea_plot.tscn")
	var boxes: Array[Rect2] = [Rect2(180, 196, 600, 175), Rect2(300, 357, 770, 210), Rect2(430, 579, 915, 245)]
	for index in range(3):
		var plot: Control = packed.instantiate()
		plot.plot_index = index
		plot.position = boxes[index].position
		plot.size = boxes[index].size
		add_child(plot)
	UiKit.prop("CHR_102", self, Vector2(1094, 458), 61)
	UiKit.prop("CHR_003", self, Vector2(1222, 706), 83)
	UiKit.prop("PRP_101", self, Vector2(1300, 802), 66)
	UiKit.chrome(self, "云雾茶园")
	UiKit.toolbar(self, [
		["ICO_101", "种子", func(): SceneRouter.modal("seeds")],
		["ICO_102", "背包", func(): SceneRouter.modal("inventory")],
		["ICO_103", "茶篓", func(): SceneRouter.modal("basket")],
		["ICO_104", "化肥", func(): SceneRouter.modal("fertilizer")],
		["ICO_105", "采摘说明", func(): SceneRouter.modal("manual")]
	])

func _make_room_items() -> void:
	room_items = Node2D.new()
	room_items.name = "FloorItems"
	room_items.y_sort_enabled = true
	add_child(room_items)

func _room_prop(id: String, uv: Vector2, width: float) -> TextureRect:
	var node = UiKit.ground_prop(id,room_items,SceneLayout.floor_point(area,uv),width,SceneLayout.calibration(id,area,uv))
	node.get_parent().set_meta("floor_room",area)
	node.get_parent().set_meta("floor_uv",uv)
	return node

func _surface_prop(id: String, surface: TextureRect, relative_point: Vector2, width: float) -> TextureRect:
	var center: Vector2 = relative_point * surface.size
	var height: float = width * AssetLibrary.ratio(id)
	var node = UiKit.art(id,surface,Rect2(center.x-width*0.5,center.y-height,width,height))
	node.set_meta("surface_asset",surface.get_meta("asset_id"))
	node.add_to_group("surface_art")
	return node

func _workshop() -> void:
	_make_room_items()
	_room_prop("PRP_433",Vector2(0.57,0.10),148)
	_room_prop("CHR_102",Vector2(0.14,0.62),64)
	var bench = _room_prop("PRP_431",Vector2(0.37,0.52),380)
	_surface_prop("PRP_435",bench,Vector2(0.48,0.35),126)
	_room_prop("CHR_004",Vector2(0.53,0.51),74)
	_room_prop("PRP_434",Vector2(0.24,0.66),69)
	_room_prop("PRP_432",Vector2(0.70,0.38),215)
	UiKit.chrome(self,"制茶工坊")
	var actions = UiKit.flat_card(self,Rect2(60,253,330,192),Color(0.98,0.97,0.93,0.97))
	UiKit.label("从鲜叶到新茶",actions,Rect2(20,13,290,43),30,true)
	UiKit.label("选好鲜叶，依次摊放、杀青、\n揉捻和干燥。",actions,Rect2(18,60,294,55),22)
	UiKit.button("开始 / 继续制茶",actions,Rect2(23,126,284,55),func():SceneRouter.modal("processing" if not GameState.batch.is_empty() else "recipe"))
	UiKit.toolbar(self,[
		["ICO_201","制茶器具",func():SceneRouter.modal("tools")],
		["PRP_103","配方",func():SceneRouter.modal("recipe")],
		["ICO_102","背包",func():SceneRouter.modal("inventory")],
		["ICO_106","工艺记录",func():SceneRouter.modal("journal")]
	])

func _teashop() -> void:
	_make_room_items()
	_room_prop("PRP_422",Vector2(0.55,0.09),174)
	_room_prop("CHR_005",Vector2(0.13,0.32),66)
	_room_prop("PRP_421",Vector2(0.14,0.47),320)
	_room_prop("PRP_424",Vector2(0.16,0.69),65)
	var left_table = _room_prop("PRP_423",Vector2(0.26,0.70),212)
	_surface_prop("PRP_301",left_table,Vector2(0.50,0.35),39)
	_surface_prop("PRP_302",left_table,Vector2(0.67,0.45),22)
	_room_prop("PRP_425",Vector2(0.40,0.72),65)
	_room_prop("PRP_424",Vector2(0.55,0.57),68)
	var right_table = _room_prop("PRP_423",Vector2(0.65,0.59),225)
	_surface_prop("PRP_301",right_table,Vector2(0.50,0.35),43)
	_surface_prop("PRP_302",right_table,Vector2(0.68,0.45),23)
	_room_prop("PRP_425",Vector2(0.78,0.61),68)
	guest_image = _room_prop("CHR_202",Vector2(0.73,0.40),66)
	var order_card = UiKit.flat_card(self,Rect2(60,257,334,227),Color(0.98,0.97,0.93,0.97))
	order_card.name = "GuestOrderCard"
	UiKit.label("今日茶客",order_card,Rect2(20,13,294,45),30,true)
	guest_label = UiKit.label("",order_card,Rect2(20,66,294,78),24)
	order_button = UiKit.button("招待茶客",order_card,Rect2(26,158,282,55),func():SceneRouter.modal("order"))
	GameState.changed.connect(_refresh_guest)
	_refresh_guest()
	UiKit.chrome(self,"临水茶铺")
	UiKit.toolbar(self,[
		["ICO_301","茶铺管理",func():SceneRouter.modal("shop")],
		["PRP_209","成品茶",func():SceneRouter.modal("inventory")],
		["ICO_108","结束一天",func():SceneRouter.modal("confirm",{"title":"结束这一天","text":"推进至下一日，保留茶树和制茶进度。\n日数是故事记录，茶树仍按游戏运行时间成长。","action":"end_day"})],
		["ICO_106","制茶手记",func():SceneRouter.modal("journal")]
	])

func _refresh_guest() -> void:
	var ids: Array[String] = ["CHR_202","CHR_204","CHR_206"]
	var names: Array[String] = ["常来的村民","路过的旅人","认真品茶的熟客"]
	var id: String = ids[GameState.customer_index]
	guest_image.texture = AssetLibrary.texture(id)
	guest_image.size = Vector2(180.0/AssetLibrary.ratio(id),180)
	guest_image.position = Vector2(-guest_image.size.x*0.5,-180)
	UiKit.set_text(guest_label,names[GameState.customer_index]+"\n想喝一份云雾春芽")

func _building_click(image: TextureRect, target: String) -> void:
	var button = Button.new()
	button.flat = true
	button.tooltip_text = "制茶工坊" if target == "workshop" else "临水茶铺"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	UiKit.place(button, image.get_global_rect())
	button.pressed.connect(func(): SceneRouter.go(target))
	button.mouse_entered.connect(func(): image.modulate = Color(1.07, 1.07, 1.07, 1))
	button.mouse_exited.connect(func(): image.modulate = Color.WHITE)

func _update_destinations() -> void:
	var ready: int = 0
	for i in range(GameState.plots.size()):
		if GameState.plot_state(i) == "ready":
			ready += 1
	UiKit.set_text(entrance_labels.garden, str(ready) + "块茶田可采摘" if ready > 0 else "种植、照料与采摘")
	var workshop_status: String = "从鲜叶到一炉新茶"
	if not GameState.batch.is_empty():
		workshop_status = "新茶已完成 · 可以领取" if int(GameState.batch.stage) == 4 else "有一批茶正在制作"
	elif GameState.fresh >= 3:
		workshop_status = "鲜叶已备齐 · 可以制茶"
	UiKit.set_text(entrance_labels.workshop, workshop_status)
	UiKit.set_text(entrance_labels.teashop, "有茶客正在等候 · 已接待" + str(GameState.served) + "位")
