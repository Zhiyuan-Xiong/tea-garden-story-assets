extends Node
var game: Control
var passed: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var reveal_values: Array[float] = []

func _ready() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for index in range(3): await get_tree().process_frame
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"PNG capture "+path)
	captures.append(path)

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://ambient_motion_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	GameState.settings.reduced_motion = false
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	var home: Control = game.area_root.get_child(0)
	var motion: Node = home.ambient
	var logo: TextureRect = home.get_node("HomeTitleLogo")
	check(motion.player.has_animation("breeze"),"native keyframe animation is installed")
	check(motion.player.get_animation("breeze").loop_mode==Animation.LOOP_LINEAR,"breeze keyframes loop")
	check(motion.player.get_animation("breeze").length==8.0,"eight second gentle breeze period")
	var phase_before: float = motion.phase
	await get_tree().create_timer(.15).timeout
	check(motion.phase>phase_before,"live AnimationPlayer advances the actual breeze phase")
	for seconds in [0.0,0.6,1.2,2.6]:
		motion.set_preview_time(seconds,false)
		reveal_values.append(logo.modulate.a)
		await capture("res://docs/动效调整/标题渐显/reveal_"+str(reveal_values.size()-1)+".png")
	check(is_zero_approx(reveal_values[0]) and is_equal_approx(reveal_values[3],1.0),"title starts transparent and ends fully readable")
	check(reveal_values[1]>0 and reveal_values[1]<reveal_values[2] and reveal_values[2]<1,"title appears progressively without abrupt full opacity")
	check(home.get_node("HomeTagline").modulate.a==1,"subtitle is readable after reveal")
	check(logo.position==Vector2(740,555) and logo.size==Vector2(440,320),"title reveal preserves layout and proportions")
	motion.set_preview_time(0,true)
	var initial_cloud: Vector2 = motion.cloud.position
	# Keep value snapshots independent of the controller's reused uniform buffer.
	var initial_offsets: PackedVector2Array = motion.background.material.get_shader_parameter("plant_offsets").duplicate()
	motion.set_preview_time(2,true)
	var moved_offsets: PackedVector2Array = motion.background.material.get_shader_parameter("plant_offsets").duplicate()
	check(motion.cloud.position.distance_to(initial_cloud)>2,"logo cloud has gentle independent motion")
	check(initial_offsets[0].distance_to(moved_offsets[0])>.0005,"plant crown changes at a different keyframe")
	check(logo.position==Vector2(740,555),"cloud motion leaves title lettering still")
	motion.set_preview_time(8,true)
	var closure_offsets: PackedVector2Array = motion.background.material.get_shader_parameter("plant_offsets").duplicate()
	check(motion.cloud.position.distance_to(initial_cloud)<.0001 and closure_offsets==initial_offsets,"end of loop returns to the same cloud and plant state")
	# Export the user's background keyframes directly from the original painted scene.
	var hidden: Array[CanvasItem] = []
	for child in home.get_children():
		if child is CanvasItem and child!=motion.background and child.visible:
			hidden.append(child)
			child.visible = false
	for index in range(13):
		motion.set_preview_time(8.0*index/12.0,true)
		await capture("res://docs/动效调整/背景关键帧/home/frame_%02d.png"%index)
	for child in hidden: child.visible = true
	motion.set_preview_time(2.0,true)
	await capture("res://docs/动效调整/home_motion.png")
	GameState.settings.reduced_motion = true
	motion.set_preview_time(2,true)
	check(motion.cloud.position==motion.cloud_origin,"reduced motion keeps cloud fixed")
	for offset in motion.background.material.get_shader_parameter("plant_offsets"):
		check(offset==Vector2.ZERO,"reduced motion disables plant deformation")
	check(logo.modulate.a==1,"reduced motion keeps title readable")
	GameState.settings.reduced_motion = false
	motion.preview_mode = false
	game.modals.open("settings")
	motion._process(.1)
	check(not motion.player.is_playing(),"settings modal pauses ambient loop")
	game.modals.close()
	motion._process(.1)
	check(motion.player.is_playing(),"closing modal resumes ambient loop")
	game.loading_layer.visible = true
	game._set_progress(.65)
	game.loading_motion.restart_reveal()
	game.loading_motion.set_preview_time(0,false)
	check(game.loading_layer.get_node("LoadingTitle").modulate.a==0,"loading text starts its own reveal")
	game.loading_motion.set_preview_time(.5,false)
	check(game.loading_layer.get_node("LoadingTitle").modulate.a==1 and game.loading_percent.text=="65%","loading text becomes readable and progress still works")
	await capture("res://docs/动效调整/loading_motion.png")
	game.loading_layer.visible = false
	for room in ["village","garden","workshop","teashop"]:
		if room=="garden":
			for plot in range(3):
				GameState.plant(plot)
				GameState.plots[plot].age = 24
		SceneRouter.go(room,false)
		await settle()
		var area: Control = game.area_root.get_child(0)
		check(is_instance_valid(area.ambient),room+" owns its own ambient controller")
		var property_rects: Dictionary = {}
		for image in get_tree().get_nodes_in_group("figma_registered_art"):
			property_rects[image.get_instance_id()] = image.get_global_rect()
		area.ambient.set_preview_time(2,true)
		for image in get_tree().get_nodes_in_group("figma_registered_art"):
			check(image.get_global_rect()==property_rects[image.get_instance_id()],room+" furniture remains exactly on its floor placement")
		if room in ["village","garden"]:
			var count: int = 0
			for tree in get_tree().get_nodes_in_group("ambient_foliage"):
				if area.is_ancestor_of(tree):
					count+=1
					check(absf(tree.material.get_shader_parameter("sway_pixels"))<=2.2,room+" tea foliage movement is bounded")
			check(count==9,room+" all nine tea trees get foliage motion")
		game.get_node("ToastPanel").visible = false
		await capture("res://docs/动效调整/"+room+"_motion.png")
	var report: Dictionary = {"passed":passed,"failed":failures,"title_alpha_keyframes":reveal_values,"loop_seconds":8,"background_keyframes":12,"loop_closure_frame":12,"captures":captures,"renderer":RenderingServer.get_video_adapter_name(),"settings_save_directory":ProjectSettings.globalize_path(SaveSystem.base_path)}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/动效调整"))
	var file := FileAccess.open("res://docs/动效调整/动效交互检查.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("AMBIENT_MOTION_VERIFICATION: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
