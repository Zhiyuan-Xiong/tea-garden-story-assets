extends Node
var failures: Array = []
var checks: int = 0
var folder: String = "res://docs/细节调整_待办与茶田状态/"
var scene: Control
var observed_kind: String = ""

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);push_error(message)

func _ready() -> void:
	SaveSystem.base_path = "user://detail_visual_tests_only"
	SaveSystem.settings_path = SaveSystem.base_path+"/settings.cfg"
	GameState.set_process(false)
	GameState.reset()
	GameState.in_menu = false
	GameState.milestones["welcome"] = true
	SceneRouter.modal_requested.connect(func(kind: String,_data: Dictionary):observed_kind=kind)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	call_deferred("run")

func screenshot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+name+".png")

func load_area(area: String) -> void:
	if is_instance_valid(scene):
		remove_child(scene);scene.queue_free()
		await get_tree().process_frame
	scene = load("res://scenes/areas/"+area+".tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	if scene.thoughts:scene.thoughts.set_process(false);scene.thoughts.bubble.hide()
	if scene.ambient:scene.ambient.player.pause();scene.ambient.set_process(false)

func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position=point;move.global_position=point
	get_viewport().push_input(move)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		get_viewport().push_input(event)
	await get_tree().process_frame

func text_fits(owner: Node) -> void:
	for label in get_tree().get_nodes_in_group("game_text"):
		if not owner.is_ancestor_of(label) or not label.is_visible_in_tree():continue
		var font: Font = label.get_theme_font("font")
		var measure: Vector2 = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,maxf(label.size.x-8,1),label.get_theme_font_size("font_size"))
		check(measure.y<=label.size.y and measure.x<=label.size.x,"text fits: "+label.text)

func run() -> void:
	await load_area("garden")
	var reference: Control = scene.get_node("ReferenceGarden")
	var todo: Control = scene.get_node("DailyTodoSidebar")
	check(not todo.finish.disabled == GameState.guide_complete(),"end day matches guide")
	check(todo.rows.size()==4,"four live daily tasks")
	check(todo.get_global_rect().end.x<279,"sidebar clears every exact Figma field")
	GameState.day=5
	for i in range(14):
		GameState.plots[i]={"planted":true,"age":20.0,"harvested":true,"fertilized":false,"material":"basic"}
	GameState.changed.emit()
	await get_tree().process_frame
	for i in range(14):
		var badge: Button = reference.visuals[i].status
		check(badge.visible and badge.caption.text=="35秒成熟","countdown visible "+str(i))
		for art in get_tree().get_nodes_in_group("tea_growth_art"):
			if not scene.is_ancestor_of(art):continue
			check(not badge.get_global_rect().intersects(art.get_global_rect()),"status avoids tea canopy "+str(i))
	GameState.plots[0].age=21.0;GameState.changed.emit()
	check(reference.visuals[0].status.caption.text=="34秒成熟","countdown updates without rebuilding tree")
	text_fits(todo)
	await screenshot("01_茶园成长倒计时")
	for i in range(14):GameState.plots[i].age=55.0
	GameState.changed.emit()
	await get_tree().process_frame
	for i in range(14):check(reference.visuals[i].status.caption.text=="可采摘","mature label "+str(i))
	var fresh: int = GameState.fresh
	await click(reference.visuals[0].status.get_global_rect().get_center())
	check(GameState.fresh==fresh+1 and GameState.plots[0].age==0,"mature badge actually harvests")
	check(reference.visuals[0].status.caption.text=="55秒成熟","harvest badge resets to regrowth time")
	for i in range(4):GameState.daily.counts[i]=int(GameState.daily_rule().targets[i]);GameState.daily.claimed[i]=true
	GameState.tasting_guests=3;GameState.changed.emit()
	check(not todo.finish.disabled,"end day enabled when guide done")
	for i in range(4):check(is_equal_approx(todo.rows[i].progress.value,1.0),"completed progress "+str(i))
	await screenshot("02_茶园可采摘与完成待办")
	observed_kind=""
	await click(todo.finish.get_global_rect().get_center())
	check(observed_kind=="end_day","sidebar end day opens summary")
	await click(todo.get_node("FoldTodo").get_global_rect().get_center())
	check(todo.folded and todo.size.y==58 and not todo.content.visible,"sidebar folds without stale hits")
	await screenshot("03_待办收起")
	await click(todo.get_node("FoldTodo").get_global_rect().get_center())
	check(not todo.folded and todo.content.visible,"sidebar unfolds")
	for speaker in scene.thoughts.speakers:
		check(not todo.get_global_rect().intersects(speaker.image.get_global_rect()),"people clear sidebar")
		scene.thoughts.show_thought(speaker.role)
		check(scene.thoughts.bubble.visible,"thought remains available "+speaker.role)
		scene.thoughts.bubble.hide()
	GameState.day=2;GameState.daily=GameState.new_daily();GameState.changed.emit()
	for row in todo.rows:check(is_zero_approx(row.progress.value),"new day task count refreshed")
	await screenshot("04_新一天待办")
	await load_area("village")
	var editor: Node2D = scene.village_editor
	check(editor.items.size()==28,"18 grouped tea trees plus 10 existing scenery and houses")
	var tea_count: int = 0
	for id in editor.items:
		if editor.items[id].kind!="tea":continue
		tea_count+=1
		var foot: Vector2 = editor.items[id].support.position
		check(editor.grounded_point(foot)==foot,"village tea rooted on terrace "+id)
	check(tea_count==18,"grouped village count")
	var original: Dictionary=editor.capture_state()
	var former: Dictionary=original.duplicate(true)
	former.items=[]
	for entry in editor.defaults.previous_tea_layout:former.items.append(entry.duplicate(true))
	for entry in original.items:
		if not str(entry.uid).begins_with("tea_"):former.items.append(entry.duplicate(true))
	var upgraded: Dictionary=editor._upgrade_default_tea(former)
	check(upgraded.items.size()==original.items.size(),"untouched old native grouping upgraded")
	former.items[0].position[0]+=10
	check(editor._upgrade_default_tea(former)==former,"custom moved tea arrangement preserved")
	former.items[0].position[0]-=10;former.items[0].width+=10
	check(editor._upgrade_default_tea(former)==former,"custom resized tea arrangement preserved")
	former.items[0].width-=10
	var first: Dictionary=former.items.pop_front()
	former.items.insert(10,first)
	check(editor._upgrade_default_tea(former)==former,"custom tea layer arrangement preserved")
	text_fits(scene.get_node("DailyTodoSidebar"))
	await screenshot("05_茶村组团茶树")
	editor.set_enabled(true)
	check(not scene.get_node("DailyTodoSidebar").visible,"sidebar yields space to village editor")
	await screenshot("06_自由布置面板")
	editor.set_enabled(false)
	for area in ["workshop","teashop"]:
		await load_area(area)
		todo=scene.get_node("DailyTodoSidebar")
		check(todo.visible and todo.position.x==20,"consistent sidebar in "+area)
		text_fits(todo)
		var context: Panel=scene.get_node("WorkshopActionCard" if area=="workshop" else "GuestOrderCard")
		text_fits(context)
		check(not todo.get_global_rect().intersects(context.get_global_rect()),"context clears todo "+area)
		var toggle: TextureButton=scene.get_node("FurnitureLayoutToggle")
		check(not context.get_global_rect().intersects(toggle.get_global_rect()),"editor toggle clears actions "+area)
		await screenshot("07_"+area+"_左侧待办")
		scene.furniture_editor.set_enabled(true)
		check(not todo.visible and not context.visible,"editor clears left task and action cards "+area)
		scene.furniture_editor.set_enabled(false)
		check(todo.visible and context.visible,"editor restores task cards "+area)
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file:=FileAccess.open(folder+"检查报告.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("DETAIL_TEST "+JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
