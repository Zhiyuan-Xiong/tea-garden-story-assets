extends Control
@export_enum("home", "village", "garden", "workshop", "teashop") var area: String = "home"
var entrance_labels: Dictionary = {}
var guest_image: TextureRect
var guest_label: Label
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
	for row in [[Vector2(215, 265), Vector2(360, 260), Vector2(506, 262)], [Vector2(239, 409), Vector2(392, 405), Vector2(545, 408)], [Vector2(359, 548), Vector2(513, 543), Vector2(668, 546)]]:
		for point in row:
			UiKit.prop("PLT_101", self, point, 112)
	var workshop_image = UiKit.prop("BLD_101", self, Vector2(1198, 295), 344)
	_building_click(workshop_image, "workshop")
	var shop_image = UiKit.prop("BLD_102", self, Vector2(1430, 500), 375)
	_building_click(shop_image, "teashop")
	UiKit.prop("CHR_002", self, Vector2(1320, 545), 46)
	_entrance("云雾茶园", "种植、照料与采摘", Rect2(287, 175, 295, 87), "garden")
	_entrance("制茶工坊", "从鲜叶到一炉新茶", Rect2(1220, 225, 290, 87), "workshop")
	_entrance("临水茶铺", "以新茶招待来客", Rect2(1480, 440, 290, 87), "teashop")
	GameState.changed.connect(_update_destinations)
	_update_destinations()
	UiKit.chrome(self, "茶村", true)
	UiKit.button("看看背包", self, Rect2(795, 952, 330, 65), func(): SceneRouter.modal("inventory"), false)
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

func _workshop() -> void:
	UiKit.prop("PRP_207", self, Vector2(1340, 430), 170)
	UiKit.prop("PRP_209", self, Vector2(1490, 676), 59)
	UiKit.prop("PRP_205", self, Vector2(617, 510), 390)
	UiKit.art("PRP_206", self, Rect2(706, 548, 193, 70))
	UiKit.prop("CHR_004", self, Vector2(998, 487), 90)
	UiKit.prop("PRP_204", self, Vector2(1129, 665), 202)
	UiKit.art("PRP_203", self, Rect2(1115, 632, 226, 113))
	UiKit.art("FX_202", self, Rect2(1230, 742, 34, 42))
	UiKit.art("PRP_201", self, Rect2(795, 801, 223, 111))
	UiKit.art("PRP_202", self, Rect2(817, 817, 179, 76))
	UiKit.prop("PRP_210", self, Vector2(509, 645), 98)
	UiKit.prop("CHR_102", self, Vector2(434, 467), 69)
	UiKit.chrome(self, "制茶工坊")
	UiKit.button("开始 / 继续制茶", self, Rect2(1150, 550, 300, 72), func(): SceneRouter.modal("processing" if not GameState.batch.is_empty() else "recipe"))
	UiKit.toolbar(self, [
		["ICO_201", "制茶器具", func(): SceneRouter.modal("tools")],
		["PRP_103", "配方", func(): SceneRouter.modal("recipe")],
		["ICO_102", "背包", func(): SceneRouter.modal("inventory")],
		["ICO_106", "工艺记录", func(): SceneRouter.modal("journal")]
	])

func _teashop() -> void:
	UiKit.prop("PRP_307", self, Vector2(1150, 407), 183)
	UiKit.prop("PRP_209", self, Vector2(1218, 548), 43)
	UiKit.prop("PRP_306", self, Vector2(605, 494), 405)
	UiKit.art("PRP_309", self, Rect2(786, 539, 76, 54))
	UiKit.prop("CHR_005", self, Vector2(1030, 516), 82)
	UiKit.prop("PRP_304", self, Vector2(1130, 595), 245)
	UiKit.prop("PRP_305", self, Vector2(1390, 620), 88)
	UiKit.art("PRP_301", self, Rect2(1211, 631, 63, 40))
	UiKit.art("PRP_302", self, Rect2(1300, 666, 32, 28))
	UiKit.art("PRP_303", self, Rect2(1306, 669, 23, 10))
	UiKit.prop("PRP_304", self, Vector2(562, 640), 216)
	UiKit.prop("PRP_305", self, Vector2(811, 650), 88)
	guest_image = UiKit.prop("CHR_202", self, Vector2(1460, 480), 79)
	guest_label = UiKit.label("", self, Rect2(1400, 355, 355, 65), 24)
	order_button = UiKit.button("招待茶客", self, Rect2(1430, 424, 300, 63), func(): SceneRouter.modal("order"))
	GameState.changed.connect(_refresh_guest)
	_refresh_guest()
	UiKit.chrome(self, "临水茶铺")
	UiKit.toolbar(self, [
		["ICO_301", "茶铺管理", func(): SceneRouter.modal("shop")],
		["PRP_209", "成品茶", func(): SceneRouter.modal("inventory")],
		["ICO_108", "结束一天", func(): SceneRouter.modal("confirm", {"title": "结束这一天", "text": "推进至下一日，保留茶树和制茶进度。\n日数是故事记录，茶树仍按游戏运行时间成长。", "action": "end_day"})],
		["ICO_106", "制茶手记", func(): SceneRouter.modal("journal")]
	])

func _refresh_guest() -> void:
	var ids: Array[String] = ["CHR_202", "CHR_204", "CHR_206"]
	var names: Array[String] = ["常来的村民", "路过的旅人", "认真品茶的熟客"]
	guest_image.texture = AssetLibrary.texture(ids[GameState.customer_index])
	guest_image.size.y = guest_image.size.x * AssetLibrary.ratio(ids[GameState.customer_index])
	UiKit.set_text(guest_label, names[GameState.customer_index] + "\n想喝一份云雾春芽")

func _building_click(image: TextureRect, target: String) -> void:
	var button = Button.new()
	button.flat = true
	button.tooltip_text = "制茶工坊" if target == "workshop" else "临水茶铺"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(button)
	UiKit.place(button, image.get_rect())
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
