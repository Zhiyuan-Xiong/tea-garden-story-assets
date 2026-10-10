extends Control
var slots: Array = []
var visuals: Array[Dictionary] = []
var reference_only: bool = false
var plants: Node2D
var markers: Control
var masks: Control
var hit_layer: Control
var status_layer: Control
var _states: Array = []
const ROOT: String = "res://assets/19_云雾茶园Figma还原/"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size=Vector2(1920,1080)
	slots = JSON.parse_string(FileAccess.get_file_as_string("res://data/garden_reference_layout.json")).slots
	masks = Control.new()
	masks.name="LockedTerraceMasks"
	masks.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(masks)
	for tier in range(5):
		var shade := Polygon2D.new()
		shade.name="LockedLayer_"+str(tier+1)
		var points: Array=[]
		for slot in slots:
			if int(slot.tier)==tier:points.append(Vector2(float(slot.ellipse[0])+float(slot.ellipse[2])*0.5,float(slot.ellipse[1])+15))
		var polygon := PackedVector2Array()
		for i in range(40):
			var angle: float=TAU*i/40.0
			polygon.append(Vector2((points[0].x+points[-1].x)*0.5,points.reduce(func(total,point):return total+point.y,0.0)/points.size())+Vector2(cos(angle)*((points[-1].x-points[0].x)*0.5+100),sin(angle)*41))
		shade.polygon=polygon
		shade.color=Color(0.98,0.97,0.93,0.36)
		masks.add_child(shade)
	for i in range(14):
		var rect:=_rect(slots[i].ellipse)
		var ellipse:=_art(ROOT+"planting_ellipse_"+str(int(rect.size.x))+".svg",self,rect)
		ellipse.name="FigmaEllipse_"+str(i+1)
		ellipse.add_to_group("reference_garden_soil")
		ellipse.set_meta("plot_index",i)
		ellipse.set_meta("planting_point",rect.get_center())
	markers=Control.new()
	markers.mouse_filter=Control.MOUSE_FILTER_IGNORE
	markers.name="PlantingPennants"
	add_child(markers)
	plants=Node2D.new()
	plants.name="CenteredTeaTrees"
	plants.y_sort_enabled=true
	add_child(plants)
	hit_layer=Control.new()
	hit_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hit_layer.name="PlantingHits"
	add_child(hit_layer)
	for i in range(14):
		var badge:=_art(ROOT+"planting_marker.png",markers,_rect(slots[i].marker))
		badge.name="FigmaPennant_"+str(i+1)
		var lock: Control=Control.new()
		markers.add_child(lock)
		lock.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UiKit.place(lock,_rect(slots[i].marker))
		UiKit.art("UI_451",lock,Rect2(0,0,40,98),false)
		UiKit.art("ICO_451",lock,Rect2(10,6,20,20))
		UiKit.label("第"+str(int(slots[i].tier)+1)+"日\n开放",lock,Rect2(4,40,32,38),11,true)
		lock.name="LockedPennant_"+str(i+1)
		var marker_hit:=_hit(i,_rect(slots[i].marker),false)
		visuals.append({"badge":badge,"lock":lock,"plant":null,"marker_hit":marker_hit})
		_states.append("")
	# All soil hit areas are placed after all pennants; the centre of a rear soil
	# can never be stolen by a lower terrace's overlapping pennant rectangle.
	for i in range(14):
		var soil_hit:=_hit(i,_rect(slots[i].ellipse).grow(3),true)
		visuals[i].soil_hit=soil_hit
	status_layer = Control.new()
	status_layer.name = "TeaGrowthStatus"
	status_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_layer)
	for i in range(14):
		var status: Button = preload("res://scripts/components/plant_status_badge.gd").new()
		status.name = "GrowthStatus_"+str(i+1)
		status_layer.add_child(status)
		var foot: Vector2 = _rect(slots[i].ellipse).get_center()
		var canopy_height: float = float(slots[i].ellipse[2])*1.30*AssetLibrary.ratio("PLT_101")
		var top: float = foot.y-canopy_height-35 if int(slots[i].tier)==4 else foot.y+4
		UiKit.place(status,Rect2(foot.x-61,top,122,29))
		status.pressed.connect(clicked.bind(i))
		visuals[i].status = status
	GameState.changed.connect(refresh)
	refresh()

func _rect(box: Array) -> Rect2:
	return Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))

func _art(path: String, parent: Node, box: Rect2) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=load(path)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_SCALE
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	UiKit.place(image,box)
	return image

func _hit(index: int, rect: Rect2, ellipse: bool) -> Button:
	var button: Button=preload("res://scripts/components/garden_slot_hit.gd").new()
	button.ellipse=ellipse
	button.flat=true
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.name=("SoilHit_" if ellipse else "PennantHit_")+str(index+1)
	button.set_meta("plot_index",index)
	hit_layer.add_child(button)
	UiKit.place(button,rect)
	button.pressed.connect(func():clicked(index))
	return button

func clicked(index: int) -> void:
	var state: String=GameState.plot_state(index)
	match state:
		"locked": SceneRouter.modal("info",{"title":"梯田尚未开放","text":"第"+str(GameState.tier_of(index)+1)+"日自动开放这一层。\n开放时赠送对应数量的基础种植材料。\n无需职业等级或开垦费用。"})
		"empty": SceneRouter.modal("plant",{"plot":index})
		"ready": GameState.harvest(index)
		_: SceneRouter.modal("info",{"title":"茶树正在生长","text":"距离成熟还有 "+str(ceili(GameState.grow_duration(index)-float(GameState.plots[index].age)))+"秒。\n切换场景仍然成长，成熟后不会枯萎。\n可到化肥面板缩短本轮剩余时间。"})

func refresh() -> void:
	if not is_inside_tree():return
	for tier in range(5):masks.get_child(tier).visible=not reference_only and tier>=GameState.opened_terraces()
	for i in range(14):
		var state: String="empty" if reference_only else GameState.plot_state(i)
		var visual: Dictionary=visuals[i]
		visual.badge.visible=state=="empty"
		visual.lock.visible=state=="locked"
		visual.marker_hit.visible=state in ["empty","locked"]
		visual.soil_hit.tooltip_text="第"+str(GameState.tier_of(i)+1)+"层 · "+str(i+1)+"号 · "+({"locked":"第"+str(GameState.tier_of(i)+1)+"日开放","empty":"可种植","seedling":"幼苗","growing":"生长中","ready":"点击采摘","harvested":"再次生长"}[state])
		visual.status.update_status(i,state)
		if _states[i]==state:continue
		_states[i]=state
		if is_instance_valid(visual.plant):plants.remove_child(visual.plant);visual.plant.queue_free();visual.plant=null
		if state in ["empty","locked"]:continue
		var id: String={"seedling":"PLT_102","growing":"PLT_103","ready":"PLT_101","harvested":"PLT_104"}[state]
		var regrowing: bool=state=="growing" and GameState.plots[i].harvested
		if regrowing:id="PLT_104"
		var width: float=float(slots[i].ellipse[2])*1.30
		if state=="seedling":width*=0.42
		elif state=="growing" and not regrowing:width*=0.77
		var foot:=_rect(slots[i].ellipse).get_center()
		var image:=UiKit.ground_prop(id,plants,foot,width)
		visual.plant=image.get_parent()
		image.name="CenteredTea_"+str(i+1)
		image.add_to_group("tea_growth_art")
		image.set_meta("plot_index",i)
		image.set_meta("growth_state",state)
		image.set_meta("planting_point",foot)

func _exit_tree() -> void:
	if GameState.changed.is_connected(refresh):GameState.changed.disconnect(refresh)
