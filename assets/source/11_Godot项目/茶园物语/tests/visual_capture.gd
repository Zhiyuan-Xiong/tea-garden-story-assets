extends Node
var game: Control
var issues: Array[String] = []
var geometry: Array[Dictionary] = []
var captured: Array[String] = []
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://visual_verification_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	for i in range(3):
		GameState.plant(i)
		GameState.plots[i].age = 24
	GameState.fresh = 3
	GameState.teas = [2,2,2]
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _settle()
	await _capture("home")
	game.loading_layer.visible = true
	game._set_progress(0.65)
	await _settle()
	await _capture("loading")
	game.loading_layer.visible = false
	for area in ["village","workshop","teashop","garden"]:
		SceneRouter.go(area,false)
		await _settle()
		_audit_geometry(area)
		await _capture(area)
	var file = FileAccess.open("res://docs/第一轮调整/实际渲染核对.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"resolution":[1920,1080],"captures":captured,"geometry":geometry,"issues":issues}, "\t"))
	file.close()
	print("VISUAL_CAPTURE: ",RenderingServer.get_video_adapter_name()," issues=",issues.size())
	get_tree().quit(0 if issues.is_empty() else 1)
func _settle() -> void:
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
func _capture(area: String) -> void:
	var path: String = "res://docs/第一轮调整/实际画面/"+area+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		issues.append("无法保存实际渲染 "+area)
	captured.append(path)
func _audit_geometry(area: String) -> void:
	for support in get_tree().get_nodes_in_group("grounded_art"):
		if not support.has_meta("floor_room"):
			continue
		var id: String = support.get_meta("asset_id")
		var uv: Vector2 = support.get_meta("floor_uv")
		var point: Vector2 = support.get_meta("ground_point")
		if not SceneLayout.inside_floor(area,point):
			issues.append(area+" "+id+" 脚点超出地板")
		var item: Dictionary = {"room":area,"id":id,"uv":[uv.x,uv.y],"ground":[point.x,point.y],"inside_floor":SceneLayout.inside_floor(area,point)}
		if SceneLayout.ASSET_AXES.has(id):
			var source: Vector2 = SceneLayout.ASSET_AXES[id]
			var target: Vector2 = SceneLayout.floor_axes(area,uv)
			var measured: Vector2 = Vector2(rad_to_deg((support.transform.basis_xform(Vector2(1,tan(deg_to_rad(source.x))))).angle()),rad_to_deg((support.transform.basis_xform(Vector2(1,tan(deg_to_rad(source.y))))).angle()))
			item["source_axes"] = [source.x,source.y]
			item["floor_axes"] = [target.x,target.y]
			item["projected_axes"] = [measured.x,measured.y]
			item["upright_x"] = support.transform.y.x
			if (measured-target).length() > 0.05 or absf(support.transform.y.x) > 0.001:
				issues.append(area+" "+id+" 透视校准错误")
		if SceneLayout.FOOTPRINTS.has(id):
			var texture: TextureRect = support.get_child(0)
			var feet: Array = []
			for relative in SceneLayout.FOOTPRINTS[id]:
				var actual: Vector2 = texture.get_global_transform() * (relative * texture.size)
				feet.append([actual.x,actual.y])
				if not SceneLayout.inside_floor(area,actual):
					issues.append(area+" "+id+" 支脚超出地板："+str(actual))
			item["feet"] = feet
		geometry.append(item)
	for text in get_tree().get_nodes_in_group("game_text"):
		if text.get_parent() is TextureButton and text.get_theme_color("font_color") != UiKit.PAPER:
			issues.append("深色按钮缺少亮色文字："+text.text)

