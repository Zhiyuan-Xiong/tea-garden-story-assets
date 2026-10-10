extends Node
var game: Control
var passed := 0
var failures: Array[String] = []
var geometry: Array[Dictionary] = []

func _ready() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failures.append(message)
		push_error(message)

func settle(frames: int = 8) -> void:
	for i in range(frames): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/茶村配景与入口调整/"+name+".png")==OK, "Capture "+name)

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://village_scenery_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	SceneRouter.go("village",false)
	await settle(15)
	var village: Control = game.area_root.get_child(0)
	var motion: Node = village.ambient
	check(motion.background.material==null and motion.baked_player.is_playing(), "Prepared video remains the only animated background")
	var buildings: Array[TextureRect] = [village.get_node("BLD_111_Support/BLD_111_Image"),village.get_node("BLD_112_Support/BLD_112_Image")]
	var feet: Array[Vector2] = [Vector2(1374,560),Vector2(1628,752)]
	var old_widths: Array[float] = [330.0,352.0]
	for i in range(2):
		var building := buildings[i]
		check(building.get_parent().position.is_equal_approx(feet[i]), "Building preserves its original grounded position")
		check(building.size.x/old_widths[i]>1.08 and building.size.x/old_widths[i]<1.16, "Building enlargement stays modest")
		check(is_equal_approx(building.get_global_rect().end.y,feet[i].y), "Building base contacts the terrace")
		geometry.append({"asset":building.get_meta("asset_id"),"rect":[building.global_position.x,building.global_position.y,building.size.x,building.size.y],"foot":[feet[i].x,feet[i].y]})
	var scenery: Array[Node] = get_tree().get_nodes_in_group("village_scenery")
	check(scenery.size()==8,"Two rear trees and six connected foreground planting groups")
	var rear := 0
	var front := 0
	for item in scenery:
		check(item.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Scenery never intercepts destination clicks")
		check(item.material==null and not item.is_in_group("ambient_foliage"),"New scenery adds no realtime foliage calculations")
		check(AssetLibrary.texture(item.get_meta("asset_id"),false).get_image().has_mipmaps(),"Scenery uses prepared mipmaps to avoid noisy minification")
		if item.get_meta("scenery_layer")=="back":
			rear += 1
			check(item.get_parent().get_index()<buildings[0].get_parent().get_index(),"Rear trees draw behind both buildings")
			check(item.modulate.a<.9,"Rear trees stay paler than the buildings")
		else:
			front += 1
			check(item.get_parent().get_index()>buildings[1].get_parent().get_index(),"Low planting draws in front of the bases")
			check(item.size.y<buildings[0].size.y*.36,"Enlarged base planting remains low relative to the building")
			check(item.size.x>=118,"Leaf groups are large enough to avoid tiny scattered grass")
	check(rear==2 and front==6,"Both scenery layers are present")
	var pine: TextureRect = village.get_node("DEC_451_Support/DEC_451_Image")
	var tree: TextureRect = village.get_node("DEC_452_Support/DEC_452_Image")
	check(pine.get_parent().position.x<buildings[0].get_global_rect().position.x-25,"Workshop tree root anchor clears the foundation")
	check(tree.get_parent().position.x>buildings[1].get_global_rect().end.x+25,"Shop tree root anchor clears the foundation")
	for badge in get_tree().get_nodes_in_group("village_entrances"):
		var title: Label = badge.get_node("EntranceTitle")
		check(title.text.replace("\n","")==badge.title and title.text.count("\n")==3,"Four native Chinese title characters are stacked correctly")
		check(not title.text.contains("\\n"),"No literal escaped newline leaks into a title")
		check(is_equal_approx(badge.size.y/badge.size.x,720.0/256.0),"Pennant keeps the source ratio and circular medallion")
		check(title.get_line_count()==4,"Vertical title has exactly four lines")
		check(title.get_theme_font("font").get_multiline_string_size(title.text,HORIZONTAL_ALIGNMENT_CENTER,title.size.x-8,title.get_theme_font_size("font_size")).y<title.size.y-5,"Native title fits inside the banner")
		for building in buildings:
			check(not badge.get_global_rect().intersects(building.get_global_rect()),"Entrance banner clears the building silhouette")
		check(badge.get_theme_stylebox("focus") is StyleBoxEmpty,"No rectangular focus frame appears over the pennant")
		for child in badge.get_children(): check(not child is Panel,"Old rectangular entry card is removed")
		geometry.append({"destination":badge.get_meta("destination"),"title":badge.title,"rect":[badge.position.x,badge.position.y,badge.size.x,badge.size.y]})
	check(get_tree().get_nodes_in_group("village_entrances").size()==3,"Exactly three new entry banners with no duplicate originals")
	GameState.fresh = 3
	GameState.served = 12
	GameState.plant(0)
	GameState.plots[0].age = 24
	GameState.changed.emit()
	check(village.entrance_badges.garden.detail.contains("1块茶田可采摘"),"Garden tooltip reflects harvest availability")
	check(village.entrance_badges.workshop.detail.contains("可以制茶"),"Workshop tooltip reflects the available fresh leaves")
	check(village.entrance_badges.teashop.detail.contains("12位"),"Shop tooltip reflects served guests")
	GameState.batch = {"stage":4}
	GameState.changed.emit()
	check(village.entrance_badges.workshop.detail.contains("可以领取"),"Workshop completed-batch status remains available")
	GameState.reset()
	GameState.unlock("welcome")
	GameState.changed.emit()
	game.toast_time = 0
	game.toast.get_parent().hide()
	await settle()
	await capture("village")
	var tooltip: Control = village.entrance_badges.teashop._make_custom_tooltip(village.entrance_badges.teashop.tooltip_text)
	game.add_child(tooltip)
	tooltip.position = Vector2(1485,815)
	await settle()
	await capture("village_status_tooltip")
	tooltip.queue_free()
	await settle()
	# Use engine input at the banner to exercise hit testing and the real callback.
	for room in ["garden","workshop","teashop"]:
		var current: Control = game.area_root.get_child(0)
		var badge: Button = current.entrance_badges[room]
		var at: Vector2 = badge.get_global_rect().get_center()
		var hover := InputEventMouseMotion.new()
		hover.position = at
		Input.parse_input_event(hover)
		await settle(2)
		var press := InputEventMouseButton.new()
		press.position = at
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		Input.parse_input_event(press)
		await settle(2)
		var release := InputEventMouseButton.new()
		release.position = at
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		await get_tree().create_timer(.8).timeout
		await settle()
		check(SceneRouter.current==room,"Real banner click navigates to "+room)
		SceneRouter.go("village",false)
		await settle()
	var report := {"passed":passed,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"geometry":geometry,"native_text":true,"new_realtime_foliage_shaders":0}
	var file := FileAccess.open("res://docs/茶村配景与入口调整/实际渲染与交互检查.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("VILLAGE_SCENERY_VERIFICATION: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
