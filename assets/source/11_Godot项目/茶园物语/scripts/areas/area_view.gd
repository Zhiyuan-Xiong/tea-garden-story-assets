extends Control
@export_enum("home", "village", "garden", "workshop", "teashop") var area: String = "home"
var entrance_badges: Dictionary = {}
var guest_image: TextureRect
var guest_label: Label
var room_items: Node2D
var order_button: TextureButton
var furniture_editor: Node2D
var village_editor: Node2D
var thoughts: Node2D
var ambient: Node

func _ready() -> void:
	theme = UiKit.game_theme
	if area != "garden": UiKit.background_depth($Background,area)
	match area:
		"home": _home()
		"village": _village()
		"garden": _garden()
		"workshop": _workshop()
		"teashop": _teashop()
	if area in ["garden","workshop","teashop"]:
		thoughts = preload("res://scripts/components/character_thoughts.gd").new()
		add_child(thoughts)
		thoughts.setup(area,self)
	if area == "garden": return
	ambient = preload("res://scripts/components/ambient_motion.gd").new()
	add_child(ambient)
	ambient.setup($Background,self,area)
	if area=="home":
		ambient.bind_cloud($LogoCloud)
		ambient.add_reveal($LogoCloud,0.0,1.4)
		ambient.add_reveal($HomeTitleLogo,0.15,1.8)
		ambient.add_reveal($HomeTagline,0.65,1.6)
		ambient.add_reveal($HomeFooter,0.85,1.6)

func _home() -> void:
	var logo_cloud := UiKit.art("UI_454", self, Rect2(657, 520, 606, 360))
	logo_cloud.name = "LogoCloud"
	var logo := UiKit.art("LOG_301", self, Rect2(740, 555, 440, 320))
	logo.name = "HomeTitleLogo"
	UiKit.button("新的旅程", self, Rect2(780, 920, 360, 82), _new_game)
	var latest: int = SaveSystem.latest_slot()
	var resume = UiKit.button("继续旅程", self, Rect2(1190, 935, 225, 60), func(): _continue(latest), false)
	resume.disabled = latest < 0
	UiKit.icon_button("ICO_403", "读取存档", self, Vector2(1630, 45), func(): SceneRouter.modal("saves", {"mode": "load"}))
	UiKit.icon_button("ICO_107", "设置", self, Vector2(1760, 45), func(): SceneRouter.modal("settings"))
	var tagline := UiKit.label("种一株茶，制一批茶，待一位客", self, Rect2(704, 860, 512, 45), 25)
	tagline.name = "HomeTagline"
	var footer := UiKit.label("茶园物语 · 国风制茶轻经营", self, Rect2(710, 1023, 500, 32), 18)
	footer.name = "HomeFooter"

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

func _entrance(title: String, detail: String, at: Vector2, target: String, icon_id: String) -> void:
	var badge := preload("res://scripts/ui/village_entrance.gd").new()
	badge.name = "VillageEntrance_" + target
	add_child(badge)
	UiKit.place(badge, Rect2(at, Vector2(86, 241.875)))
	badge.setup(title, detail, icon_id)
	badge.set_meta("destination", target)
	entrance_badges[target] = badge
	badge.pressed.connect(func(): SceneRouter.go(target))

func _village() -> void:
	room_items = Node2D.new()
	room_items.name = "VillageItems"
	add_child(room_items)
	village_editor = preload("res://scripts/components/village_layout_editor.gd").new()
	village_editor.name = "VillageLayoutEditor"
	add_child(village_editor)
	village_editor.setup(self,room_items)
	_entrance("云雾茶园","种植、照料与采摘",Vector2(747,185),"garden","ICO_451")
	_entrance("制茶工坊","从鲜叶到一炉新茶",Vector2(1331,164),"workshop","ICO_454")
	_entrance("临水茶铺","以新茶招待来客",Vector2(1671,313),"teashop","ICO_456")
	village_editor.bind_house("BLD_111",entrance_badges.workshop,"workshop")
	village_editor.bind_house("BLD_112",entrance_badges.teashop,"teashop")
	village_editor.set_enabled(false)
	GameState.changed.connect(_update_destinations)
	_update_destinations()
	UiKit.chrome(self,"茶村",true)
	UiKit.button("看看背包",self,Rect2(795,952,330,65),func():SceneRouter.modal("inventory"),false)
	if not GameState.milestones.has("welcome"):
		call_deferred("_welcome")

func _welcome() -> void:
	SceneRouter.modal("welcome")

func _garden() -> void:
	var garden: Control = preload("res://scripts/components/reference_garden.gd").new()
	garden.name = "ReferenceGarden"
	add_child(garden)
	_scene_people("front")
	UiKit.chrome(self,"云雾茶园")
	var memorial:=UiKit.button("满山茶香",self,Rect2(1550,959,255,58),func():SceneRouter.modal("growth"),false)
	var show_memorial=func():memorial.visible=GameState.decorations.has("满山茶香题签")
	show_memorial.call()
	GameState.changed.connect(show_memorial)
	tree_exiting.connect(func():if GameState.changed.is_connected(show_memorial):GameState.changed.disconnect(show_memorial),CONNECT_ONE_SHOT)
	UiKit.toolbar(self,[
		["ICO_101","种子",func():SceneRouter.modal("seeds")],
		["ICO_102","背包",func():SceneRouter.modal("inventory")],
		["ICO_103","茶篓",func():SceneRouter.modal("basket")],
		["ICO_104","化肥",func():SceneRouter.modal("fertilizer")],
		["ICO_105","采摘说明",func():SceneRouter.modal("manual")],
		["ICO_106","每日任务",func():SceneRouter.modal("tasks")]
	])


func _scene_people(layer: String) -> void:
	var file := FileAccess.open("res://data/scene_people_layout.json",FileAccess.READ)
	var layout: Dictionary = JSON.parse_string(file.get_as_text())
	for entry in layout.people + layout.props:
		if entry.room != area or entry.get("layer","front") != layer:
			continue
		var foot := Vector2(float(entry.foot[0]),float(entry.foot[1]))
		var image := UiKit.ground_prop(entry.id,room_items if is_instance_valid(room_items) else self,foot,float(entry.width))
		image.name = entry.name
		image.add_to_group("illustration_art")
		image.get_parent().set_meta("layout_name",entry.name)
		image.get_parent().set_meta("room",area)
		image.get_parent().set_meta("layer",layer)
		var shadow := preload("res://scripts/components/ground_contact_shadow.gd").new()
		shadow.radius = 6.5
		shadow.contacts = PackedVector2Array([Vector2(-float(entry.width)*.12,-4),Vector2(float(entry.width)*.12,-1)])
		image.get_parent().add_child(shadow)
		image.get_parent().move_child(shadow,0)
		if entry.get("dynamicCustomer",false):
			guest_image = image

func _setup_furniture_editor() -> void:
	var y: float = 807
	var toggle := UiKit.button("布置家具",self,Rect2(30,y,216,46),func():
		if not GameState.paused: furniture_editor.set_enabled(not furniture_editor.enabled))
	toggle.name = "FurnitureLayoutToggle"
	toggle.add_to_group("furniture_editor_ui")
	var options := UiKit.flat_card(self,Rect2(20,y+56,236,85))
	options.add_to_group("furniture_editor_ui")
	UiKit.label("拖动家具，松手后保存",options,Rect2(8,4,220,28),18)
	var reset := UiKit.button("恢复默认摆放",options,Rect2(12,38,212,40),func(): furniture_editor.reset_layout(),false)
	reset.add_to_group("furniture_editor_ui")
	options.visible = false
	furniture_editor.mode_changed.connect(func(enabled: bool):
		UiKit.set_text(toggle.get_meta("caption"),"完成布置" if enabled else "布置家具")
		options.visible = enabled)

func _figma_parts() -> void:
	room_items = Node2D.new()
	room_items.name = "GroundedRoomFurniture"
	room_items.y_sort_enabled = true
	add_child(room_items)
	furniture_editor = preload("res://scripts/components/furniture_layout_editor.gd").new()
	add_child(furniture_editor)
	furniture_editor.setup(area,room_items)
	var file = FileAccess.open("res://data/figma_scene_parts.json",FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	_scene_people("behind_counter")
	for part in data.parts:
		if part.room != area or part.get("kind","") == "editable_badge":
			continue
		var box: Array = part.viewportRect
		var rect := Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
		var image := UiKit.art(part.id,room_items,rect,false)
		image.name = part.id
		image.set_meta("source_rect",rect)
		image.set_meta("source_id",part.id)
		image.add_to_group("figma_registered_art")
		UiKit.background_depth(image,area,rect)
		furniture_editor.register_item(image,part)
	_scene_people("front")
	for part in data.parts:
		if part.room != area or part.get("kind","") != "editable_badge":
			continue
		var box: Array = part.viewportRect
		var rect := Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
		var tag := Control.new()
		tag.name = part.id + "_Tag"
		tag.add_to_group("world_badge_visuals")
		add_child(tag)
		var tag_rect := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 39.0,0),Vector2(78,219))
		UiKit.place(tag,tag_rect)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.art(part.plateId,tag,Rect2(Vector2.ZERO,tag_rect.size),false)
		var icon_rect := Rect2(4,3,70,70)
		var icon := UiKit.art(part.iconId,tag,icon_rect,false)
		icon.name = part.id + "_Icon"
		var caption: String = "\n".join(Array(part.label.split("")))
		var caption_label := UiKit.label(caption,tag,Rect2(17,87,44,91),23,true)
		caption_label.name = part.id + "_GodotText"
		var hit: Button = preload("res://scripts/ui/paper_icon_button.gd").new()
		hit.name = part.id + "_Click"
		hit.flat = true
		hit.tooltip_text = "查看" + part.label + "详解" if area == "workshop" else part.label
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(hit)
		UiKit.place(hit,tag_rect)
		hit.set_meta("badge_id",part.id)
		hit.add_to_group("scene_icon_clicks")
		if area == "workshop":
			var step: String = {"FGU_W1":"spread","FGU_W2":"drying","FGU_W3":"fixation","FGU_W4":"rolling","FGU_W5":"sorting"}[part.id]
			hit.set_meta("guide_step",step)
			hit.pressed.connect(func(): SceneRouter.modal("craft_guide",{"step":step}))
		else:
			var destination: String = {"FGU_T1":"shop","FGU_T2":"order","FGU_T3":"inventory"}[part.id]
			hit.pressed.connect(func(): SceneRouter.modal(destination))
		furniture_editor.bind_badge(part.id,tag,hit)
	_setup_furniture_editor()

func _workshop() -> void:
	_figma_parts()
	UiKit.chrome(self,"制茶工坊")
	var actions = UiKit.flat_card(self,Rect2(20,616,236,176))
	actions.name = "WorkshopActionCard"
	UiKit.label("从鲜叶到新茶",actions,Rect2(12,9,212,37),24,true)
	UiKit.label("摊放、杀青
揉捻、干燥",actions,Rect2(14,49,208,53),20)
	UiKit.button("开始 / 继续制茶",actions,Rect2(12,120,212,45),func():SceneRouter.modal("processing" if not GameState.batch.is_empty() else "recipe"))
	furniture_editor.mode_changed.connect(func(enabled: bool):actions.visible=not enabled)
	UiKit.toolbar(self,[
		["ICO_201","制茶器具",func():SceneRouter.modal("tools")],
		["ICO_401","配方",func():SceneRouter.modal("recipe")],
		["ICO_102","背包",func():SceneRouter.modal("inventory")],
		["ICO_106","工艺记录",func():SceneRouter.modal("journal")]
	])

func _teashop() -> void:
	_figma_parts()
	_update_owned_decor()
	GameState.action_completed.connect(_update_owned_decor)
	furniture_editor.mode_changed.connect(func(_enabled: bool):_update_owned_decor())
	UiKit.chrome(self,"临水茶铺")
	var master:=UiKit.button("制茶大师",self,Rect2(1540,174,250,51),func():SceneRouter.modal("growth"),false)
	var show_master=func():master.visible=GameState.decorations.has("制茶大师题签")
	show_master.call()
	GameState.changed.connect(show_master)
	tree_exiting.connect(func():if GameState.changed.is_connected(show_master):GameState.changed.disconnect(show_master),CONNECT_ONE_SHOT)
	var order_card = UiKit.flat_card(self,Rect2(20,616,236,176))
	order_card.name = "GuestOrderCard"
	UiKit.label("今日茶客",order_card,Rect2(12,8,212,34),24,true)
	guest_label = UiKit.label("",order_card,Rect2(12,44,212,63),20)
	order_button = UiKit.button("招待茶客",order_card,Rect2(12,120,212,45),func():SceneRouter.modal("order"))
	furniture_editor.mode_changed.connect(func(enabled: bool):order_card.visible=not enabled)
	GameState.changed.connect(_refresh_guest)
	_refresh_guest()
	UiKit.toolbar(self,[
		["ICO_301","茶铺管理",func():SceneRouter.modal("shop")],
		["ICO_456","成品茶",func():SceneRouter.modal("inventory")],
		["ICO_108","结束一天",func():SceneRouter.modal("end_day")],
		["ICO_106","制茶手记",func():SceneRouter.modal("journal")]
	])

func _refresh_guest() -> void:
	var names: Array[String] = ["常来的村民","路过的旅人","认真品茶的熟客"]
	UiKit.set_text(guest_label,names[GameState.customer_index]+"\n"+GameState.recipe_data(str(GameState.current_order.recipe)).name+"×"+str(GameState.current_order.quantity))
	if is_instance_valid(guest_image):
		var id: String = ["CHR_202","CHR_204","CHR_206"][GameState.customer_index]
		guest_image.texture = AssetLibrary.texture(id)
		guest_image.set_meta("asset_id",id)
		var width: float = guest_image.size.x
		var height: float = width * AssetLibrary.ratio(id)
		UiKit.place(guest_image,Rect2(-width*0.5,-height,width,height))

func _building_click(image: TextureRect, target: String) -> void:
	var button: Button = preload("res://scripts/ui/paper_icon_button.gd").new()
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
	entrance_badges.garden.update_detail(str(ready) + "块茶田可采摘" if ready > 0 else "种植、照料与采摘")
	var workshop_status: String = "从鲜叶到一炉新茶"
	if not GameState.batch.is_empty():
		workshop_status = "新茶已完成 · 可以领取" if int(GameState.batch.stage) == 4 else "有一批茶正在制作"
	elif GameState.fresh >= 1:
		workshop_status = "鲜叶已备齐 · 可以制茶"
	entrance_badges.workshop.update_detail(workshop_status)
	entrance_badges.teashop.update_detail("有茶客正在等候 · 已接待" + str(GameState.served) + "位")

func _update_owned_decor(_action: String = "") -> void:
	if area!="teashop" or not is_instance_valid(furniture_editor):return
	var parts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/figma_scene_parts.json"))
	var source: Dictionary={}
	for part in parts.parts:
		if part.id=="FGT_03":source=part.duplicate(true);break
	for decor in [["清雅茶桌","OWN_TEA_TABLE"],["五日新茶纪念雅座","OWN_FIVE_DAY_SEAT"]]:
		if not GameState.decorations.has(decor[0]) or furniture_editor.items.has(decor[1]):continue
		var width: float=210.0
		var image:=UiKit.art("FGT_03",room_items,Rect2(0,0,width,width*258.0/404.0),false)
		image.name=decor[1]
		image.tooltip_text=decor[0]
		var part: Dictionary=source.duplicate(true)
		part.id=decor[1]
		part.label=decor[0]
		furniture_editor.register_item(image,part)
		var saved: bool=furniture_editor.saved_positions.has(decor[1]) and furniture_editor.can_place(decor[1],furniture_editor.items[decor[1]].support.position)
		var placed: bool=saved
		if not saved:
			for y in range(3,17):
				for x in range(3,17):
					var point: Vector2=furniture_editor.floor_point(Vector2(float(x)/20.0,float(y)/20.0))
					if furniture_editor.can_place(decor[1],point):
						furniture_editor._place(decor[1],point)
						placed=true
						break
				if placed:break
		if not placed:
			var support: Node2D=furniture_editor.items[decor[1]].support
			furniture_editor.items.erase(decor[1])
			room_items.remove_child(support)
			support.queue_free()
			GameState.notice.emit("陈设已收入背包；茶铺暂时没有空位，可布置家具后再摆放。")
