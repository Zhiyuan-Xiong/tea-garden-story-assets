extends Node
var checks: int=0
var failures: Array=[]
var garden: Control
var modal: Control
var folder: String="res://docs/云雾茶园Figma还原/"
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _ready() -> void:
	SaveSystem.base_path="user://experience_render_tests_only"
	SaveSystem.settings_path="user://experience_render_tests_only/settings.cfg"
	GameState.set_process(false)
	GameState.reset()
	GameState.in_menu=false
	call_deferred("run")
func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+name+".png")
func run() -> void:
	garden=load("res://scenes/areas/garden.tscn").instantiate()
	add_child(garden)
	await get_tree().process_frame
	var reference: Control=garden.get_node("ReferenceGarden")
	check(reference.slots.size()==14,"14 exact reference slots")
	for i in range(14):
		var ellipse: TextureRect=get_tree().get_nodes_in_group("reference_garden_soil")[i]
		check(ellipse.get_rect()==reference._rect(reference.slots[i].ellipse),"exact Figma ellipse geometry")
		check(reference.visuals[i].badge.get_rect()==reference._rect(reference.slots[i].marker),"exact Figma pennant geometry")
		var point: Vector2=ellipse.get_rect().get_center()
		var winner: int=-1
		for hit in reference.hit_layer.get_children():
			if hit.visible and hit._has_point(point-hit.position):winner=int(hit.get_meta("plot_index"))
		check(winner==i,"soil centre click wins over overlapping pennants "+str(i))
	for child in garden.get_children():
		if child is CanvasItem:child.visible=child.name in ["Background","ReferenceGarden"]
	reference.reference_only=true
	reference.refresh()
	await snap("00_Figma坐标还原")
	for child in garden.get_children():
		if child is CanvasItem:child.visible=true
	if garden.thoughts:garden.thoughts.set_process(false);garden.thoughts.bubble.visible=false
	reference.reference_only=false
	for n in range(1,6):
		GameState.day=n
		GameState.changed.emit()
		await snap("0"+str(n)+"_第"+str(n)+"日梯田开放")
	GameState.day=5
	for i in range(14):
		GameState.plots[i]={"planted":true,"age":55.0,"harvested":true,"fertilized":false,"material":"basic"}
	GameState.changed.emit()
	for state in ["seedling","growing","ready","harvested"]:
		for i in range(14):
			GameState.plots[i].harvested=state in ["ready","harvested"]
			GameState.plots[i].age={"seedling":0.0,"growing":5.0,"ready":55.0,"harvested":0.0}[state]
		GameState.changed.emit()
		for image in get_tree().get_nodes_in_group("tea_growth_art"):
			if not image.is_inside_tree():continue
			var point: Vector2=reference._rect(reference.slots[int(image.get_meta("plot_index"))].ellipse).get_center()
			check(image.get_parent().position==point,"all growth stages centred")
		await snap("06_生长阶段_"+state)
	for i in range(14):GameState.plots[i].harvested=true;GameState.plots[i].age=30.0
	GameState.changed.emit()
	for image in get_tree().get_nodes_in_group("tea_growth_art"):
		if not image.is_inside_tree():continue
		var index: int=int(image.get_meta("plot_index"))
		check(image.get_meta("asset_id")=="PLT_104" and is_equal_approx(image.size.x,float(reference.slots[index].ellipse[2])*1.30),"regrowing tree retains mature trunk and canopy scale")
	await snap("06_生长阶段_regrowing")
	# Verify the engine's real GUI picking, not only rectangular geometry.
	GameState.reset();GameState.day=5;GameState.changed.emit()
	await get_tree().process_frame
	var picked: Array=[-1]
	var observe=func(kind: String,payload: Dictionary):
		if kind=="plant":picked[0]=int(payload.plot)
	SceneRouter.modal_requested.connect(observe)
	for i in range(14):
		picked[0]=-1
		var point: Vector2=reference._rect(reference.slots[i].ellipse).get_center()
		var motion:=InputEventMouseMotion.new()
		motion.position=point;motion.global_position=point
		get_viewport().push_input(motion)
		var down:=InputEventMouseButton.new()
		down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
		get_viewport().push_input(down)
		var up:=InputEventMouseButton.new()
		up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point;up.global_position=point
		get_viewport().push_input(up)
		await get_tree().process_frame
		check(picked[0]==i,"engine mouse click targets correct plot "+str(i))
	SceneRouter.modal_requested.disconnect(observe)
	GameState.experience=650
	GameState.crafted_batches=12
	GameState.completed_tasks=12
	GameState.recipe_mastery.spring=3
	GameState.teas[1]=8
	GameState.fresh=12
	GameState.update_progress()
	modal=Control.new()
	modal.name="Modals"
	modal.set_script(load("res://scripts/ui/modal_manager.gd"))
	add_child(modal)
	UiKit.place(modal,Rect2(0,0,1920,1080))
	for mode in ["tasks","growth","recipe","order","shop","end_day","seeds","inventory","fertilizer","plant","basket","manual","journal","settings"]:
		modal.open(mode,{"plot":0})
		check(GameState.paused==(mode in ["settings","end_day"]),"production pause semantics "+mode)
		await snap("UI_"+mode)
		check(modal.get_child_count()>3,"modal content exists "+mode)
		for label in get_tree().get_nodes_in_group("game_text"):
			if not modal.is_ancestor_of(label) or not label.is_visible_in_tree():continue
			check(label.get_global_rect().end.x<=1545.0 and label.get_global_rect().end.y<=975.0,"modal text inside frame")
	# Real native clicks through the first recipe lesson, avoiding freed callbacks.
	GameState.reset();GameState.fresh=1
	modal.open("recipe")
	await get_tree().process_frame
	var lesson: TextureButton
	for button in modal.find_children("*","TextureButton",true,false):
		if button.get_meta("caption",null) and button.get_meta("caption").text=="查看首次教学":lesson=button
	check(is_instance_valid(lesson),"first recipe tutorial native button")
	lesson.pressed.emit()
	await get_tree().process_frame
	check(modal.current_kind=="confirm","first recipe lesson opened")
	for button in modal.find_children("*","TextureButton",true,false):
		if button.get_meta("caption",null) and button.get_meta("caption").text=="确认":button.pressed.emit();break
	await get_tree().process_frame
	check(modal.current_kind=="processing" and not GameState.batch.is_empty(),"first recipe confirmation starts processing")
	await snap("UI_processing")
	modal.close()
	GameState.batch={}
	GameState.day=5;GameState.tasting_guests=3;GameState.update_progress()
	modal.open("summary")
	await snap("UI_summary")
	modal.close()
	remove_child(modal);modal.queue_free()
	remove_child(garden);garden.queue_free()
	await get_tree().process_frame
	GameState.reset()
	var main: Control=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.set_process(false)
	GameState.experience=180;GameState.crafted_batches=1;GameState.completed_tasks=4
	GameState.update_progress()
	main._route("workshop",false)
	await get_tree().process_frame
	main._process(0.01)
	check(main.modals.current_kind=="info" and main.modals.current_data.recipe=="dew","unlocked recipe opens automatic short lesson")
	check(GameState.pending_recipe_lessons.is_empty() and GameState.recipe_taught.has("dew"),"lesson queued once and persisted")
	await snap("UI_auto_recipe_lesson")
	for button in main.modals.find_children("*","TextureButton",true,false):
		if button.get_meta("caption",null) and button.get_meta("caption").text=="去制作新茶":button.pressed.emit();break
	await get_tree().process_frame
	check(main.modals.get_node("ExperiencePanel_recipe").selected_recipe=="dew","lesson opens matching recipe")
	main.modals.close()
	GameState.decorations=["清雅茶桌","五日新茶纪念雅座"]
	main._route("teashop",false)
	await get_tree().process_frame
	var shop: Control=main.area_root.get_child(0)
	for id in ["OWN_TEA_TABLE","OWN_FIVE_DAY_SEAT"]:
		check(shop.furniture_editor.items.has(id),"owned decor added "+id)
		if shop.furniture_editor.items.has(id):check(shop.furniture_editor.can_place(id,shop.furniture_editor.items[id].support.position),"owned decor grounded and unobstructed "+id)
	await snap("07_茶铺经营奖励陈设")
	main._route("garden",false)
	await get_tree().process_frame
	check(main.area_root.get_child(0).get_node("Background").texture.resource_path.contains("19_云雾茶园"),"actual routed garden retains original Figma background")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file:=FileAccess.open(folder+"界面与坐标测试报告.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RENDER_TEST ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
