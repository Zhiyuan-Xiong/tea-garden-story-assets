extends Node
var game: Control
var passed := 0
var failures: Array[String] = []
var measurements: Array = []
var floor_points: Dictionary = {}
var soil_instances: Dictionary = {}

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failures.append(message)
		push_error(message)

func settle(frames: int = 6) -> void:
	for i in range(frames): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	var screenshot: Image = get_viewport().get_texture().get_image()
	check(screenshot.save_png("res://docs/茶树生长阶段重绘/"+name+".png")==OK,"Capture "+name)
	if name.begins_with("0"):
		check(screenshot.save_png("res://docs/茶田土壤区块/"+name+".png")==OK,"Soil view "+name)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await settle(2)
	for down in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		Input.parse_input_event(mouse)
		await settle(2)

func inspect_soil() -> void:
	var tiles: Array[Node] = get_tree().get_nodes_in_group("planting_soil_art")
	check(tiles.size()==13,"Thirteen persistent soil beds in a 4/4/5 arrangement")
	for soil in tiles:
		var plot: Control = soil.get_parent().get_parent().get_parent()
		var slot: int = int(soil.get_meta("slot"))
		var key: String = str(soil.get_meta("plot_index"))+str(slot)
		var centre: Vector2 = soil.get_global_transform()*(soil.size*0.5)
		if not soil_instances.has(key):soil_instances[key] = soil.get_instance_id()
		check(soil_instances[key]==soil.get_instance_id(),"Soil retained during stage changes "+key)
		check(soil.material==null and not soil.is_processing(),"Static soil adds no animation work "+key)
		check(is_equal_approx(soil.size.y/soil.size.x,0.36),"Circular planting spot has calibrated oval ground depth "+key)
		check(soil.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Soil permits planting clicks "+key)
		check(plot.soil_layer.get_index()<plot.plant_layer.get_index(),"Soil stays underneath tea "+key)
		check(centre.is_equal_approx(soil.get_parent().global_position),"Projected soil centre is its planting anchor "+key)
		var placement: Dictionary = plot.planting_layout.slots[slot]
		check(centre.distance_to(Vector2(placement.point[0],placement.point[1]))<0.01,"Soil uses its calibrated ground centre "+key)
		check(plot.soil_layer.get_child_count()==[4,4,5][int(soil.get_meta("plot_index"))],"Correct planting density on terrace "+key)
		check(soil.texture.get_image().get_pixel(soil.texture.get_width()/2,soil.texture.get_height()/2).a>.9,"Centre lies inside visible soil "+key)

func inspect_plants(stage: String, id: String) -> void:
	inspect_soil()
	var plants: Array[Node] = get_tree().get_nodes_in_group("tea_growth_art")
	check(plants.size()==13,"Thirteen tea bushes for "+stage)
	for plant in plants:
		var key: String = str(plant.get_meta("plot_index"))+plant.name
		var foot: Vector2 = plant.get_parent().global_position
		var plot: Control = plant.get_parent().get_parent().get_parent()
		var slot: int = int(plant.get_meta("slot"))
		var placement: Dictionary = plot.planting_layout.slots[slot]
		var expected_foot := Vector2(placement.point[0],placement.point[1])
		check(foot.distance_to(expected_foot)<0.01,"Plant remains at calibrated terrace floor point "+stage+key)
		var soil: TextureRect = plot.soil_layer.get_child(slot).get_child(0)
		check(foot.distance_to(soil.get_global_transform()*(soil.size*0.5))<0.01,"Tea root precisely centred on projected soil "+stage+key)
		check(plant.get_global_rect().position.y>plot.growth.get_global_rect().end.y,"Tea canopy clears growth UI "+stage+key)
		if stage in ["ready","harvested","regrowing","second_ready"]:
			check(is_equal_approx(plant.size.x,plot.size.x*0.22*1.30*float(placement.scale)),"Mature bush keeps 30 percent enlargement with depth scaling "+stage+key)
		if plant.get_parent().get_index()>0:
			var behind: Node2D = plot.plant_layer.get_child(plant.get_parent().get_index()-1)
			check(behind.global_position.y<=foot.y,"Rear bushes draw before front bushes "+stage+key)
		if not floor_points.has(key): floor_points[key] = foot
		check(foot.is_equal_approx(floor_points[key]),"Fixed floor point "+stage+key)
		check(is_equal_approx(plant.get_global_rect().end.y,foot.y),"Sprite rooted on floor "+stage+key)
		check(plant.get_meta("asset_id")==id,"Stage asset "+stage+key)
		check(is_equal_approx(plant.size.y/plant.size.x,AssetLibrary.ratio(id)),"Native undistorted ratio "+stage+key)
		measurements.append({"stage":stage,"plot":plant.get_meta("plot_index"),"slot":slot,"width":plant.size.x,"height":plant.size.y,"foot":[foot.x,foot.y]})

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://tea_growth_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	for id in ["PLT_101","PLT_102","PLT_103","PLT_104"]:
		var raw: Image = AssetLibrary.texture(id,false).get_image()
		check(raw.has_mipmaps(),"Prepared mipmaps "+id)
		check(raw.get_pixel(0,0).a==0,"True exterior alpha "+id)
		check(AssetLibrary.catalog[id].revision=="v003","New revision "+id)
	var raw_soil: Image = AssetLibrary.texture("TER_181",false).get_image()
	check(raw_soil.has_mipmaps(),"Soil mipmaps prepared")
	check(raw_soil.get_pixel(0,0).a==0,"Soil exterior is genuinely transparent")
	check(AssetLibrary.catalog.TER_181.revision=="v002","Reference-style oval soil replaces the long strip")
	SceneRouter.go("village",false)
	await settle(15)
	var editor: Node2D = game.area_root.get_child(0).village_editor
	await capture("茶村新茶树")
	var native: Dictionary = editor.capture_state()
	var legacy: Dictionary = native.duplicate(true)
	var tea_uids: Array[String] = []
	for entry in legacy.items:
		if entry.asset=="PLT_101":
			tea_uids.append(entry.uid)
			entry.erase("asset_revision")
			entry.height = entry.width*(807.0/1214.0)
	var custom: Dictionary = legacy.items.filter(func(e): return e.uid==tea_uids[1])[0]
	custom.height = 105.0
	custom.opacity = 0.75
	custom.mirror = true
	custom.locked = true
	editor._restore_state(legacy)
	var migrated: Dictionary = editor.capture_state()
	for i in range(legacy.items.size()):
		var before: Dictionary = legacy.items[i]
		var after: Dictionary = migrated.items[i]
		for field in ["uid","asset","position","width","opacity","mirror","locked","scenery_layer"]:
			check(before[field]==after[field],"Migration preserves "+str(field)+str(i))
		if before.asset=="PLT_101" and before.uid!=tea_uids[1]:
			check(is_equal_approx(after.height,after.width*AssetLibrary.ratio("PLT_101")),"Old native ratio adopts new painting")
	check(editor.items[tea_uids[1]].image.size.y==105.0,"Manual stretched tea ratio retained")
	editor._restore_state(migrated)
	check(editor.capture_state()==migrated,"Revision prevents repeated migration on restore")
	editor._restore_state(native)
	SceneRouter.go("garden",false)
	await settle(15)
	GameState.in_menu = false
	inspect_soil()
	await capture("00_空茶田")
	for soil in get_tree().get_nodes_in_group("planting_soil_art"):
		await click(soil.get_global_transform()*(soil.size*0.5))
		check(game.modals.current_kind=="plant" and int(game.modals.current_data.plot)==int(soil.get_meta("plot_index")),"Every oval centre selects its own terrace")
		game.modals.close()
		await settle(2)
	for i in range(3):
		var target: TextureRect
		for soil in get_tree().get_nodes_in_group("planting_soil_art"):
			if int(soil.get_meta("plot_index"))==i and int(soil.get_meta("slot"))==2:target=soil
		await click(target.get_global_transform()*(target.size*0.5))
		check(game.modals.visible and game.modals.current_kind=="plant" and int(game.modals.current_data.plot)==i,"Click projected soil opens correct planting dialog "+str(i))
		await click(Vector2(960,866))
		check(GameState.plots[i].planted and not game.modals.visible,"Confirm planting through actual UI "+str(i))
	check(GameState.seeds==0,"Existing seed cost remains one per terrace")
	game.toast_time = 0
	game.toast.get_parent().hide()
	await settle()
	inspect_plants("seedling","PLT_102")
	await capture("01_幼苗")
	var first: Node = get_tree().get_nodes_in_group("tea_growth_art")[0]
	var initial_height: float = first.size.y
	var instance: int = first.get_instance_id()
	GameState.advance_time(1)
	GameState.changed.emit()
	await settle()
	check(get_tree().get_nodes_in_group("tea_growth_art")[0].get_instance_id()==instance,"Same-stage timer refresh does not recreate textures")
	GameState.advance_time(9)
	GameState.changed.emit()
	await settle()
	inspect_plants("growing","PLT_103")
	var middle_height: float = get_tree().get_nodes_in_group("tea_growth_art")[0].size.y
	check(middle_height>initial_height,"Growing bush is taller than seedling")
	await capture("02_生长中")
	GameState.advance_time(14)
	GameState.changed.emit()
	await settle()
	inspect_plants("ready","PLT_101")
	check(get_tree().get_nodes_in_group("tea_growth_art")[0].size.y>middle_height,"Mature bush is taller than growing bush")
	await capture("03_成熟待采")
	for i in range(3): check(GameState.harvest(i),"Harvest ready plot "+str(i))
	check(GameState.fresh==3 and GameState.total_harvested==3,"Harvest yield remains correct")
	await settle()
	inspect_plants("harvested","PLT_104")
	await capture("04_采摘后")
	GameState.advance_time(12)
	GameState.changed.emit()
	await settle()
	inspect_plants("regrowing","PLT_104")
	GameState.advance_time(12)
	GameState.changed.emit()
	await settle()
	inspect_plants("second_ready","PLT_101")
	check(GameState.harvest(0),"Second harvest completes normally")
	GameState.plots[1].harvested = false
	GameState.plots[1].age = 12.0
	GameState.plots[2].harvested = false
	GameState.plots[2].age = 0.0
	GameState.changed.emit()
	game.toast.get_parent().hide()
	await capture("05_混合生长阶段")
	var report: Dictionary = {"passed":passed,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"plant_scale":1.30,"fixed_ground_anchors":true,"soil_slots":13,"per_terrace":[4,4,5],"soil_centred_planting":true,"soil_perspective":true,"saved_layout_migration":true,"original_rgba_preserved":true,"measurements":measurements,"isolated_test_saves":SaveSystem.base_path}
	var out := FileAccess.open("res://docs/茶树生长阶段重绘/实际运行检查.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	var soil_report := FileAccess.open("res://docs/茶田土壤区块/实际运行检查.json",FileAccess.WRITE)
	soil_report.store_string(JSON.stringify(report,"\t"))
	print("TEA_GROWTH_VERIFICATION: ",JSON.stringify({"passed":passed,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
