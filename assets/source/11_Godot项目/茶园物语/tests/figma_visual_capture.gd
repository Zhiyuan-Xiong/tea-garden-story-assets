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
	SaveSystem.base_path = "user://figma_visual_verification_"+str(Time.get_ticks_usec())
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
	var tea = game.loading_layer.get_node("FigmaLoadingTea")
	if not is_equal_approx(tea.size.x,550) or not tea.position.is_equal_approx(Vector2(655,390)):
		issues.append("载入茶具比例没有匹配Figma")
	game.loading_layer.visible = false
	for area in ["village","workshop","teashop","garden"]:
		SceneRouter.go(area,false)
		await _settle()
		_audit_registration(area)
		await _capture(area)
	SceneRouter.go("workshop",false)
	await _settle()
	for step in ["spread","fixation","rolling","drying","sorting"]:
		game.modals.open("craft_guide",{"step":step})
		await _settle()
		await _capture("guide_"+step)
	game.modals.close()
	for kind in ["welcome","plant","seeds","inventory","basket","fertilizer","manual","recipe","tools","order","shop","journal","settings","saves","confirm","info"]:
		game.modals.open(kind,{"plot":1,"mode":"save","title":"操作确认","text":"操作前展示材料数量与结果。所有文字在框内居中。"})
		await _settle()
		await _capture("panel_"+kind)
	game.modals.close()
	GameState.fresh = 3
	GameState.start_batch()
	for stage in range(5):
		GameState.batch.stage = stage
		GameState.batch.count = 0
		GameState.batch.elapsed = 7.0 if stage == 3 else 0.0
		GameState.batch.quality = 1
		game.modals.open("processing")
		await _settle()
		await _capture("processing_"+str(stage))
	game.modals.close()
	var tooltip_button = preload("res://scripts/ui/paper_icon_button.gd").new()
	var tooltip = tooltip_button._make_custom_tooltip("查看揉捻详解")
	tooltip_button.free()
	game.add_child(tooltip)
	tooltip.position = Vector2(1130,460)
	await _settle()
	await _capture("tooltip")
	tooltip.queue_free()
	var file = FileAccess.open("res://docs/第二轮调整/实际渲染核对.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"resolution":[1920,1080],"captures":captured,"source_registration":geometry,"issues":issues},"\t"))
	file.close()
	print("FIGMA_VISUAL_CAPTURE: ",RenderingServer.get_video_adapter_name()," issues=",issues.size())
	get_tree().quit(0 if issues.is_empty() else 1)
func _settle() -> void:
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
func _capture(area: String) -> void:
	for motion in get_tree().get_nodes_in_group("ambient_motion_controllers"):
		motion.set_preview_time(0.0,true)
	await RenderingServer.frame_post_draw
	var path = "res://docs/第二轮调整/实际画面/"+area+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var img = get_viewport().get_texture().get_image()
	if img.save_png(path) != OK:
		issues.append("无法保存实际渲染 "+area)
	captured.append(path)
func _audit_registration(area: String) -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("figma_registered_art"):
		count += 1
		var target: Rect2 = node.get_meta("source_rect")
		var actual: Rect2 = node.get_global_rect()
		var texture_size: Vector2 = node.texture.get_size()
		var scales: Vector2 = actual.size/texture_size
		var ok = actual.position.is_equal_approx(target.position) and actual.size.is_equal_approx(target.size) and absf(node.rotation)<0.00001 and node.scale.is_equal_approx(Vector2.ONE) and absf(scales.x-scales.y)<0.0001
		if not ok:
			issues.append(area+" "+node.name+" 没有保持原坐标等比缩放")
		geometry.append({"room":area,"source_id":node.get_meta("source_id"),"rect":[actual.position.x,actual.position.y,actual.size.x,actual.size.y],"scale":[scales.x,scales.y],"matches_source_registration":ok})
	if area in ["workshop","teashop"] and count != (15 if area=="workshop" else 8):
		issues.append(area+" 分件数量错误")
	for text in get_tree().get_nodes_in_group("game_text"):
		if text.get_parent() is TextureButton and text.get_theme_color("font_color") != UiKit.PAPER:
			issues.append("深色按钮缺少亮色文字："+text.text)
