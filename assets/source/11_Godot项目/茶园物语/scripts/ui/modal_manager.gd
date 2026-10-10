extends Control
const Orders = preload("res://scripts/core/orders.gd")
var current_kind: String = ""
var current_data: Dictionary = {}
var guide_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/craft_guides.json"))
var selected_slot: int = 1
const AREA_NAMES: Dictionary = {"village": "茶村", "garden": "云雾茶园", "workshop": "制茶工坊", "teashop": "临水茶铺"}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	SceneRouter.modal_requested.connect(open)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if not visible and current_kind.is_empty():
		return
	if current_kind == "settings":
		SaveSystem.save_settings()
	visible = false
	current_kind = ""
	_clear()
	GameState.paused = false
	GameState.changed.emit()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func open(kind: String, data: Dictionary = {}) -> void:
	_clear()
	current_kind = kind
	current_data = data
	visible = true
	GameState.paused = kind in ["settings", "saves", "end_day", "summary"]
	var veil = ColorRect.new()
	veil.color = Color(0.21, 0.28, 0.24, 0.39)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	UiKit.place(veil, Rect2(0, 0, 1920, 1080))
	UiKit.art("UI_030", self, Rect2(375, 125, 1170, 850))
	var titles: Dictionary = {"welcome": "初到茶村", "plant": "种下第一株茶树", "seeds": "种子库", "inventory": "背包", "basket": "茶篓", "fertilizer": "照料茶田", "manual": "采摘说明书", "recipe": "新茶配方", "tasks": "每日任务", "growth": "成长与成就", "end_day": "结束一天", "summary": "五日新茶", "processing": "制茶工坊", "tools": "制茶器具", "craft_guide": guide_catalog.guides.get(data.get("step","spread"),guide_catalog.guides.spread).title, "order": "临水待客", "shop": "茶铺管理", "journal": "制茶手记", "settings": "设置", "saves": "游戏存档", "confirm": data.get("title", "请确认"), "info": data.get("title", "茶村小记")}
	UiKit.label(titles.get(kind, "茶村小记"), self, Rect2(690, 163, 540, 66), 38, true)
	UiKit.button("关闭", self, Rect2(1385,174,111,56), close, false)
	if kind in ["tasks","growth","recipe","order","shop","end_day","summary","seeds","inventory","plant","fertilizer"]:
		var panel: Control = preload("res://scripts/components/experience_panel.gd").new()
		panel.name = "ExperiencePanel_"+kind
		add_child(panel)
		panel.setup(self,kind,data)
		return
	match kind:
		"welcome": _welcome()
		"basket": _basket()
		"manual": _manual()
		"processing": _processing()
		"tools": _tools()
		"craft_guide": _craft_guide(str(data.get("step","spread")))
		"journal": _journal()
		"settings": _settings()
		"saves": _saves(data)
		"confirm": _confirm(data)
		"info": _info(data)

func _body(text: String, rect: Rect2 = Rect2(580, 280, 760, 240), font_size: int = 28) -> Label:
	return UiKit.label(text, self, rect, font_size)

func _welcome() -> void:
	UiKit.prop("CHR_101", self, Vector2(455, 310), 215)
	_body("欢迎来到茶村。\n\n先到云雾茶园，种下三株茶树；\n采得1份鲜叶，就能去工坊做第一炉新茶。\n再把自己的茶端给来客，慢慢恢复茶村的生活。", Rect2(705, 290, 705, 335), 28)
	_body("鼠标点击操作 · 一般面板可按 Esc 关闭\n茶树跨场景继续成长；按Esc打开设置可暂停", Rect2(690, 651, 725, 90), 23)
	UiKit.button("去看看茶园", self, Rect2(777, 830, 366, 75), func(): GameState.unlock("welcome"); close(); GameState.complete_action("welcome"); SceneRouter.go("garden"))

func _item(id: String, title: String, amount: String, rect: Rect2) -> void:
	var card = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	UiKit.place(card, rect)
	UiKit.flat_card(card, Rect2(Vector2.ZERO, rect.size)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fitted_width: float = minf(112.0,108.0/AssetLibrary.ratio(id))
	UiKit.prop(id, card, Vector2((rect.size.x-fitted_width)*0.5,20), fitted_width)
	UiKit.label(title, card, Rect2(10, 143, rect.size.x - 20, 45), 25)
	UiKit.label(amount, card, Rect2(10, 196, rect.size.x - 20, 43), 25)

func _basket() -> void:
	UiKit.prop("PRP_101", self, Vector2(750, 275), 420)
	_body("当前鲜叶： " + str(GameState.fresh) + " 份\n累计采摘： " + str(GameState.total_harvested) + " 份\n1份鲜叶可制成1份云岫春芽", Rect2(605, 637, 710, 175), 31)
	_body("采摘后茶树继续生长；这里与背包共用库存", Rect2(590, 842, 740, 46), 23)

func _manual() -> void:
	UiKit.prop("PRP_105", self, Vector2(462, 310), 228)
	_body("空茶田：选择种子，再确认种植。\n\n幼苗与生长中：嫩芽尚未长足，等待或使用肥料。\n\n嫩芽成熟：点击茶田，获得1份鲜叶。\n\n采摘后：茶树保留，继续长出下一轮新芽。", Rect2(720, 280, 660, 443), 28)
	_body("首轮8秒、普通55秒的成长是游戏参数。\n真实茶树生长和采摘周期需结合品种、环境与季节判断。", Rect2(510, 792, 900, 102), 23)

func _processing() -> void:
	var station: Control = preload("res://scenes/components/processing_station.tscn").instantiate()
	station.position = Vector2(435, 260)
	add_child(station)
	station.finished.connect(close)

func _tools() -> void:
	var entries: Array = [["FGW_01","摊青长桌","spread"],["FGW_03","杀青炉","fixation"],["FGW_04","揉捻台","rolling"],["FGW_02","竹制晾架","drying"],["FGW_05","筛分筒","sorting"]]
	for i in range(entries.size()):
		var entry: Array = entries[i]
		var rect := Rect2(474+i*196,320,185,256)
		_item(entry[0],entry[1],"点击查看工序详解",rect)
		var hit := Button.new()
		hit.flat = true
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(hit)
		UiKit.place(hit,rect)
		var step: String = entry[2]
		hit.pressed.connect(func():open("craft_guide",{"step":step}))
	_body("器具与工序相互配合。\n点击任意器具，查看工序目的、步骤和观察要点。",Rect2(550,658,820,120),26)
	UiKit.button("进入制茶",self,Rect2(800,838,320,68),func():open("recipe"))

func _craft_guide(step: String) -> void:
	var selected: String = step if guide_catalog.guides.has(step) else "spread"
	current_data["step"] = selected
	var guide: Dictionary = guide_catalog.guides[selected]
	for i in range(guide_catalog.order.size()):
		var id: String = guide_catalog.order[i]
		var tab := UiKit.button(guide_catalog.guides[id].short,self,Rect2(485+i*194,251,177,54),func():open("craft_guide",{"step":id}),id==selected)
		tab.name = "GuideTab_"+id
	var art_card := UiKit.flat_card(self,Rect2(483,331,255,159),Color(0.95,0.94,0.88,0.94))
	var source_ratio: float = AssetLibrary.ratio(guide.asset)
	var artwork_width: float = minf(220.0,128.0/source_ratio)
	UiKit.prop(guide.asset,art_card,Vector2((255.0-artwork_width)*0.5,14),artwork_width)
	UiKit.label("工序目的",self,Rect2(778,326,630,41),27,true)
	_body(guide.purpose,Rect2(774,376,630,95),25)
	_body("操作步骤",Rect2(650,490,620,45),27)
	for i in range(3):
		var item: Array = guide.steps[i]
		var card := UiKit.flat_card(self,Rect2(485+i*323,543,303,164),Color(0.97,0.96,0.91,0.96))
		UiKit.label(str(i+1)+" · "+str(item[0]),card,Rect2(12,9,279,44),25,true)
		UiKit.label(str(item[1]),card,Rect2(17,61,269,87),22)
	_body(guide.observe,Rect2(501,718,918,67),22)
	_body(guide.game,Rect2(501,792,918,65),21)
	UiKit.button("体验制茶",self,Rect2(548,879,294,59),func():open("processing" if not GameState.batch.is_empty() else "recipe"))
	var source: Dictionary = guide_catalog.sources[int(guide.source)]
	UiKit.button("查看工艺资料",self,Rect2(1078,879,294,59),func():OS.shell_open(source.url),false)
	_body("云岫春芽为虚构茶品，流程按游戏体验压缩",Rect2(845,882,229,53),17)

func _journal() -> void:
	var records: Array = [
		["茶树与鲜叶", "harvested", "PRP_103", "采摘后保留茶树，下一轮嫩芽继续生长。\n游戏使用统一鲜叶资源，实际原料需结合茶树品种与采摘要求。"],
		["制茶器具", "spread", "PRP_201", "竹筛用于摊放，铁锅承载火候操作。\n不同茶品与地区的器具和工序各有特点。"],
		["制茶工艺", "crafted", "PRP_203", "摊放、杀青、揉捻、干燥是本作压缩的体验路线。\n云岫春芽为虚构茶名，操作时长与品质等级用于游戏。"],
		["茶与日常生活", "served", "PRP_301", "制茶、饮茶和待客连在一起。\n一盏茶让客人歇脚，也让茶村里的日常有了回应。"]
	]
	for i in range(4):
		var record: Array = records[i]
		var unlocked: bool = GameState.milestones.has(record[1])
		var card = UiKit.flat_card(self, Rect2(475 + i % 2 * 490, 281 + i / 2 * 242, 470, 226))
		UiKit.art(record[2], card, Rect2(20, 58, 100, 100))
		UiKit.label(record[0] + (" · 已体验" if unlocked else " · 待解锁"), card, Rect2(122, 11, 330, 48), 26, true)
		UiKit.label(record[3] if unlocked else "完成相应的采摘、制茶或待客体验后，记录会收入手记。", card, Rect2(132, 66, 316, 138), 22)
	_body("资料入口：UNESCO《中国传统制茶技艺及其相关习俗》\n文化资料与游戏参数分别记录；后续按具体茶品核实细节", Rect2(500, 800, 920, 72), 21)
	UiKit.button("查看资料来源", self, Rect2(549, 886, 344, 56), func(): OS.shell_open("https://ich.unesco.org/en/RL/traditional-tea-processing-techniques-and-associated-social-practices-in-china-01884"), false)

	UiKit.button("成长与成就",self,Rect2(1027,886,344,56),func():open("growth"))
	if GameState.claimed_achievements.has("five_day"):
		UiKit.button("五日新茶手记",self,Rect2(778,758,364,47),func():open("info",{"title":"五日新茶","text":"第五日，茶村的三位朋友如约而来。\n村民记得第一篓嫩芽，旅人带走一缕清香，熟客看见你的手艺渐渐稳妥。\n\n五层梯田已开放，茶园的日常仍在继续。\n五日新茶纪念雅座可在茶铺中自由摆放。"}),false)

func _settings() -> void:
	_body("声音与氛围", Rect2(600, 260, 720, 50), 30)
	_body("背景音乐", Rect2(530, 333, 190, 48), 26)
	var slider := HSlider.new()
	slider.name = "MusicVolume"
	slider.theme = UiKit.game_theme
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = float(GameState.settings.music_volume) * 100.0
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.tooltip_text = "调节背景音乐音量，0% 为静音"
	add_child(slider)
	UiKit.place(slider, Rect2(745, 335, 475, 40))
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("e3dfcc")
	rail.border_color = Color("b6a46c")
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(5)
	rail.content_margin_top = 5.0
	rail.content_margin_bottom = 5.0
	slider.add_theme_stylebox_override("slider", rail)
	var fill: StyleBoxFlat = rail.duplicate()
	fill.bg_color = Color("94a782")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: Texture2D = load("res://assets/20_背景音乐/volume_knob.svg")
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon_name, knob)
	var amount := UiKit.label(str(roundi(slider.value)) + "%", self, Rect2(1240, 331, 110, 48), 25)
	amount.name = "MusicVolumeAmount"
	slider.value_changed.connect(func(value: float):
		GameState.settings.music_volume = value / 100.0
		amount.text = str(roundi(value)) + "%"
		GameState.changed.emit()
	)
	_setting_check("静音背景音乐", "music_muted", Vector2(650, 399))
	_body("文字与动效", Rect2(600, 491, 720, 48), 28)
	_setting_check("显示当前目标提示", "show_hints", Vector2(650, 544))
	_setting_check("减少动画", "reduced_motion", Vector2(650, 628))
	var credits := RichTextLabel.new()
	credits.name = "MusicCredits"
	credits.theme = UiKit.game_theme
	credits.bbcode_enabled = true
	credits.scroll_active = false
	credits.add_theme_font_size_override("normal_font_size", 18)
	credits.add_theme_color_override("default_color", UiKit.INK)
	credits.text = '[center]音乐：[url=https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1900005]River Flute — Kevin MacLeod (incompetech.com)[/url]\n[url=https://creativecommons.org/licenses/by/4.0/]Creative Commons: By Attribution 4.0[/url] · 已调整循环衔接与响度\n音乐跨场景连续播放；设置菜单暂停生产计时。[/center]'
	credits.meta_clicked.connect(func(link: Variant): OS.shell_open(str(link)))
	add_child(credits)
	UiKit.place(credits, Rect2(495, 718, 930, 94))
	UiKit.button("保存设置", self, Rect2(790, 836, 340, 73), close)


func _setting_check(title: String, key: String, at: Vector2) -> void:
	var check = CheckButton.new()
	check.theme = UiKit.game_theme
	check.button_pressed = bool(GameState.settings[key])
	check.text = ""
	add_child(check)
	UiKit.place(check, Rect2(at, Vector2(620, 68)))
	UiKit.label(title, check, Rect2(75, 7, 470, 54), 28)
	check.toggled.connect(func(value: bool): GameState.settings[key] = value; GameState.changed.emit())

func _saves(data: Dictionary) -> void:
	var mode: String = data.get("mode", "save")
	selected_slot = int(data.get("selected", 1 if mode == "save" else maxi(SaveSystem.latest_slot(), 0)))
	var save_tab = UiKit.button("保存游戏", self, Rect2(673, 246, 268, 58), func(): open("saves", {"mode": "save", "selected": 1}))
	save_tab.disabled = not GameState.started
	UiKit.button("读取存档", self, Rect2(979, 246, 268, 58), func(): open("saves", {"mode": "load", "selected": maxi(SaveSystem.latest_slot(), 0)}), mode == "load")
	for slot in range(3):
		var y: float = 332 + slot * 155
		var card = Control.new()
		add_child(card)
		UiKit.place(card, Rect2(480, y, 960, 143))
		UiKit.art("UI_044", card, Rect2(0, 0, 960, 143))
		if slot == selected_slot:
			UiKit.art("UI_045", card, Rect2(0, 0, 960, 143))
		var saved: Dictionary = SaveSystem.read_slot(slot)
		var title: String = "自动存档" if slot == 0 else "手动存档 " + str(slot)
		var detail: String = "空存档"
		if not saved.is_empty():
			var state: Dictionary = saved.state
			detail = AREA_NAMES.get(state.last_scene, "茶村") + "  ·  第" + str(int(state.day)) + "日\n" + str(saved.saved_at).replace("T", " ") + "\n铜钱 " + str(int(state.copper)) + " · 鲜叶 " + str(int(state.fresh))
			UiKit.art({"village": "BG_303", "garden": "BG_304", "workshop": "BG_305", "teashop": "BG_306"}[state.last_scene], card, Rect2(28, 22, 173, 99), false)
		else:
			UiKit.art("ICO_402", card, Rect2(87, 36, 62, 62))
		UiKit.art("UI_046", card, Rect2(23, 18, 182, 107))
		UiKit.label(title + (" · 已选中" if slot == selected_slot else ""), card, Rect2(220, 17, 293, 49), 26, true)
		UiKit.label(detail, card, Rect2(520, 10, 408, 124), 22)
		var click = Button.new()
		click.flat = true
		click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_child(click)
		UiKit.place(click, Rect2(Vector2.ZERO, card.size))
		click.pressed.connect(func(): open("saves", {"mode": mode, "selected": slot}))
	var selected: Dictionary = SaveSystem.read_slot(selected_slot)
	var action = UiKit.button("保存到此槽位" if mode == "save" else "读取此存档", self, Rect2(1060, 852, 355, 72), func(): _save_load(mode))
	action.disabled = (mode == "save" and (not GameState.started or selected_slot == 0)) or (mode == "load" and selected.is_empty())
	_body("自动存档由游戏维护\n手动保存请选择槽位1或2", Rect2(496, 843, 500, 84), 22)

func _save_load(mode: String) -> void:
	var slot: int = selected_slot
	var old: Dictionary = SaveSystem.read_slot(slot)
	if mode == "save":
		if not old.is_empty():
			open("confirm", {"title": "覆盖这份存档？", "text": "手动存档 " + str(slot) + " · " + AREA_NAMES.get(old.state.last_scene, "茶村") + " · 第" + str(int(old.state.day)) + "日\n\n确认后，旧记录会被当前进度替换。", "callback": func(): _write_manual(slot)})
		else:
			_write_manual(slot)
	else:
		open("confirm", {"title": "读取这份存档？", "text": "读取后回到记录的场景和经营进度。\n当前尚未保存的变化将被这份记录替换。", "callback": func(): _load(slot)})

func _write_manual(slot: int) -> void:
	if SaveSystem.write_slot(slot):
		GameState.notice.emit("手动存档已保存。")
		open("saves", {"mode": "save", "selected": slot})
	else:
		GameState.notice.emit(SaveSystem.last_error)

func _load(slot: int) -> void:
	if SaveSystem.load_slot(slot):
		close()
		SceneRouter.go(GameState.last_scene)
	else:
		GameState.notice.emit(SaveSystem.last_error)

func _confirm(data: Dictionary) -> void:
	_body(data.get("text", ""), Rect2(560, 338, 800, 299), 30)
	UiKit.button("取消", self, Rect2(640, 797, 290, 76), close, false)
	UiKit.button("确认", self, Rect2(990, 797, 290, 76), func(): _execute(data))

func _execute(data: Dictionary) -> void:
	close()
	if data.has("callback") and data.callback is Callable:
		data.callback.call()
		return
	match data.get("action", ""):
		"new":
			GameState.reset()
			SceneRouter.go("village")
		"end_day": GameState.end_day()
		"start_recipe":
			if GameState.start_batch(str(data.get("recipe","spring")),int(data.get("quantity",1))):open("processing")

func _info(data: Dictionary) -> void:
	_body(data.get("text", ""), Rect2(555, 324, 810, 380), 30)
	UiKit.button("去制作新茶" if data.has("recipe") else "知道了",self,Rect2(800,829,320,74),func():
		close()
		if data.has("recipe"):SceneRouter.modal("recipe",{"recipe":str(data.recipe)}))
