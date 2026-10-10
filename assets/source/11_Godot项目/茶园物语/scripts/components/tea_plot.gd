extends Control
@export var plot_index: int = 0
var status: Label
var growth: ProgressBar
var soil_layer: Node2D
var plant_layer: Control
var click_area: Button
var previous_state: String = ""
var planting_layout: Dictionary
const PLANT_SCALE: float = 1.30

func _ready() -> void:
	planting_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/garden_planting_layout.json")).terraces[plot_index]
	soil_layer = Node2D.new()
	soil_layer.name = "CultivatedSoil"
	add_child(soil_layer)
	_make_soil()
	plant_layer = Control.new()
	plant_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plant_layer)
	click_area = Button.new()
	click_area.flat = true
	click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(click_area)
	UiKit.place(click_area, Rect2(Vector2.ZERO, size))
	click_area.pressed.connect(_clicked)
	status = UiKit.label("", self, Rect2(size.x * 0.5 - 146, -39 + float(planting_layout.status_offset), 292, 51), 23)
	growth = UiKit.meter(self, Rect2(size.x * 0.5 - 100, 13 + float(planting_layout.growth_offset), 200, 10), 0)
	GameState.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var state: String = GameState.plot_state(plot_index)
	var plot: Dictionary = GameState.plots[plot_index]
	var names: Dictionary = {"empty": "空茶田 · 点击种植", "seedling": "幼苗 · 生长中", "growing": "茶树 · 嫩芽生长中", "ready": "茶芽成熟 · 点击采摘", "harvested": "已采摘 · 茶树再生"}
	var remaining: int = ceili(GameState.GROW_SECONDS - float(plot.age))
	UiKit.set_text(status, str(plot_index + 1) + "号茶田  " + names[state] + (" · " + str(remaining) + "秒" if state in ["seedling", "growing", "harvested"] else ""))
	growth.visible = plot.planted
	growth.value = float(plot.age) / GameState.GROW_SECONDS
	if state == previous_state:
		return
	previous_state = state
	for child in plant_layer.get_children():
		child.queue_free()
	if state == "empty":
		UiKit.art("ICO_101", plant_layer, Rect2(_plant_point(int(planting_layout.cue_slot))-Vector2(26,52),Vector2(52,52)))
	else:
		var id: String = {"seedling": "PLT_102", "growing": "PLT_103", "ready": "PLT_101", "harvested": "PLT_104"}[state]
		var regrowing: bool = bool(plot.harvested) and state == "growing"
		if regrowing: id = "PLT_104"
		var original_width: float = size.x * 0.22
		var mature_width: float = original_width * PLANT_SCALE
		var mature_height: float = mature_width * AssetLibrary.ratio("PLT_101")
		var width: float = mature_width
		if state == "seedling":
			width = minf(mature_width * 0.43, mature_height * 0.52 / AssetLibrary.ratio(id))
		elif state == "growing" and not regrowing:
			width = minf(mature_width * 0.77, mature_height * 0.80 / AssetLibrary.ratio(id))
		# All growth stages share exactly the same centre as their soil slot.
		for i in _draw_order():
			var foot := _plant_point(i)
			var image := UiKit.ground_prop(id, plant_layer, foot, width * float(planting_layout.slots[i].scale))
			image.name = "TeaPlant_" + str(i + 1)
			image.add_to_group("tea_growth_art")
			image.add_to_group("ambient_foliage")
			image.set_meta("growth_state",state)
			image.set_meta("plot_index",plot_index)
			image.set_meta("slot",i)
			var foliage := ShaderMaterial.new()
			foliage.shader = preload("res://shaders/foliage_sway.gdshader")
			image.material = foliage
		if state == "ready":
			UiKit.prop("UI_024", plant_layer, _plant_point(int(planting_layout.cue_slot)) - Vector2(20,mature_height * 0.72), 40)

func _plant_point(slot: int) -> Vector2:
	var point: Array = planting_layout.slots[slot].point
	var origin: Array = planting_layout.origin
	return Vector2(float(point[0])-float(origin[0]),float(point[1])-float(origin[1]))

func _draw_order() -> Array[int]:
	var slots: Array[int] = []
	for i in range(planting_layout.slots.size()): slots.append(i)
	slots.sort_custom(func(a: int,b: int) -> bool: return _plant_point(a).y < _plant_point(b).y)
	return slots

func _make_soil() -> void:
	for slot in range(planting_layout.slots.size()):
		var placement: Dictionary = planting_layout.slots[slot]
		var width: float = size.x * 0.25 * float(placement.scale)
		var height: float = width * 0.36
		var support := Node2D.new()
		support.name = "SoilSlot_"+str(slot+1)
		soil_layer.add_child(support)
		# Ground projection and upright tea share one persistent planting centre.
		support.transform = Transform2D(Vector2(1,float(placement.slope)),Vector2(float(placement.shear),float(placement.depth)),_plant_point(slot))
		support.set_meta("planting_point",_plant_point(slot))
		var soil := UiKit.art("TER_181",support,Rect2(-width*0.5,-height*0.5,width,height))
		soil.name = "PlantingSoil_"+str(slot+1)
		soil.add_to_group("planting_soil_art")
		soil.set_meta("plot_index",plot_index)
		soil.set_meta("slot",slot)

func _clicked() -> void:
	match GameState.plot_state(plot_index):
		"empty": SceneRouter.modal("plant", {"plot": plot_index})
		"ready": GameState.harvest(plot_index)
		_: SceneRouter.modal("info", {"title": "茶树正在生长", "text": "采摘后会保留茶树，并继续长出新芽。\n可使用肥料缩短本轮成长时间；成熟嫩芽不会枯萎。"})
