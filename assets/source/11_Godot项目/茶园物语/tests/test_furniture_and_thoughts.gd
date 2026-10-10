extends Node
var game: Control
var passed: int = 0
var failures: Array[String] = []
var floors: Array[Dictionary] = []
var captures: Array[String] = []
func _ready() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for index in range(5): await get_tree().process_frame
func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_tree().root.push_input(event)
func click_caption(text: String) -> void:
	for label in get_tree().get_nodes_in_group("game_text"):
		if label.text==text and label.is_visible_in_tree() and label.get_parent() is BaseButton:
			click_at(label.get_parent().get_global_rect().get_center())
			return
	check(false,"Missing visible action "+text)
func free_point(editor: Node2D, id: String) -> Vector2:
	var current: Vector2 = editor.items[id].support.position
	var best: Vector2 = current
	var distance: float = INF
	for x in range(1,28):
		for y in range(1,42):
			var point: Vector2 = editor.floor_point(Vector2(float(x)/28,float(y)/42))
			var difference: float = point.distance_to(current)
			if difference>24 and difference<distance and editor.can_place(id,point):
				distance = difference
				best = point
	return best
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/第二轮调整/实际画面/"+name+".png"
	get_viewport().get_texture().get_image().save_png(path)
	captures.append(path)
func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://floor_and_thought_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	for index in range(3):
		GameState.plant(index)
		GameState.plots[index].age = 24
	GameState.fresh = 3
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	for room in ["workshop","teashop"]:
		SceneRouter.go(room,false)
		await settle()
		var area: Control = game.area_root.get_child(0)
		var editor: Node2D = area.furniture_editor
		check(editor.items.size()==(12 if room=="workshop" else 8),room+" all floor furniture registered")
		var uv := Vector2(.173,.729)
		check(editor.floor_uv(editor.floor_point(uv)).distance_to(uv)<.0001,room+" projected floor coordinates roundtrip")
		for id in editor.items:
			var point: Vector2 = editor.items[id].support.position
			var within: bool = editor.within_floor(id,point)
			floors.append({"room":room,"id":id,"anchor":[point.x,point.y],"all_contacts_inside_floor":within,"default_footprint_clear":editor.can_place(id,point)})
			check(within,room+" "+id+" default contact points remain on the floor")
		click_caption("布置家具")
		await settle()
		check(editor.enabled,room+" actual layout toggle works")
		await capture(room+"_floor_edit")
		if room=="workshop":
			GameState.start_batch()
			game.modals.open("processing")
			await settle()
			check(not GameState.paused,"crafting modal keeps its own timer running")
			var background_press := InputEventMouseButton.new()
			background_press.position = editor.items["FGW_09"].image.get_global_rect().get_center()
			background_press.button_index = MOUSE_BUTTON_LEFT
			background_press.pressed = true
			get_tree().root.push_input(background_press)
			check(editor.selected.is_empty(),"crafting modal blocks furniture input even without pausing the game")
			game.modals.close()
			check(game.modals.get_child_count()==0,"closed crafting panel immediately releases its listeners")
			game.modals.close()
			GameState.batch = {}
			GameState.changed.emit()
			await settle()
		var id: String = "FGW_09" if room=="workshop" else "FGT_08"
		var image: TextureRect = editor.items[id].image
		var initial: Vector2 = editor.items[id].support.position
		var image_size: Vector2 = image.size
		var target: Vector2 = free_point(editor,id)
		check(target.distance_to(initial)>24,room+" free placement is available")
		var grab: Vector2 = image.get_global_rect().position+image.size*Vector2(.5,.70)
		check(editor._hit(grab)==id,room+" selection uses visible opaque sprite instead of rectangular empty margin")
		var press := InputEventMouseButton.new()
		press.position = grab
		press.global_position = grab
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		get_tree().root.push_input(press)
		check(editor.selected==id,room+" actual pointer press selects furniture")
		var motion := InputEventMouseMotion.new()
		motion.position = grab+(target-initial)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(motion)
		var release := InputEventMouseButton.new()
		release.position = motion.position
		release.global_position = release.position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		get_tree().root.push_input(release)
		check(editor.items[id].support.position.distance_to(editor.snapped_point(target))<.001 and editor.selected.is_empty(),room+" actual pointer motion and release move and save furniture")
		var moved: Vector2 = editor.items[id].support.position
		var snapped_uv: Vector2 = editor.floor_uv(moved)*editor.DIVISIONS
		check(snapped_uv.distance_to(snapped_uv.round())<.001,room+" ground anchor lies exactly on floor grid")
		check(image.size.is_equal_approx(image_size) and is_zero_approx(image.rotation),room+" dragging preserves scale and camera perspective")
		var invalid: Vector2 = editor.floor_point(Vector2(-1,-1))
		check(not editor.move_item(id,invalid) and editor.items[id].support.position.is_equal_approx(moved),room+" off-floor drop rejected without changing valid placement")
		var other: String = "FGW_03" if room=="workshop" else "FGT_01"
		check(not editor.can_place(id,editor.items[other].support.position),room+" occupied furniture footprint rejected")
		check(editor.save_layout(),room+" layout persists to isolated file")
		editor.set_enabled(false)
		SceneRouter.go("village",false)
		await settle()
		SceneRouter.go(room,false)
		await settle()
		area = game.area_root.get_child(0)
		editor = area.furniture_editor
		check(editor.items[id].support.position.distance_to(moved)<.001,room+" reopening room restores layout")
		editor.reset_layout()
		check(editor.items[id].support.position.distance_to(initial)<.001,room+" reset restores authored floor placement")
		area.thoughts.next_thought = .01
		area.thoughts._process(.02)
		check(area.thoughts.bubble.visible,room+" ambient role thought appears automatically")
		var role: String = "WorkshopMaker" if room=="workshop" else "TeashopGuest"
		area.thoughts.bubble.visible = false
		for speaker in area.thoughts.speakers:
			if speaker.role == role:
				click_at(speaker.hit.get_global_rect().get_center())
		await settle()
		check(area.thoughts.current_speaker==role and area.thoughts.bubble.visible,room+" actual character click shows the matching role thought")
		check(area.thoughts.bubble.visible,room+" native character thought appears")
		check(not area.thoughts.caption.text.is_empty(),room+" character role has inner speech")
		var bubble_rect: Rect2 = area.thoughts.bubble.get_global_rect()
		for speaker in area.thoughts.speakers:
			check(not bubble_rect.intersects(speaker.image.get_global_rect()),room+" thought avoids character "+speaker.role)
		for label in get_tree().get_nodes_in_group("game_text"):
			if label==area.thoughts.caption or not label.is_visible_in_tree() or not area.is_ancestor_of(label): continue
			check(not bubble_rect.intersects(label.get_global_rect()),room+" thought avoids UI text "+label.text)
		await capture(room+"_character_thought")
		GameState.paused = true
		await settle()
		check(not area.thoughts.bubble.visible,room+" modal pause hides ambient thought")
		GameState.paused = false
		if room=="teashop":
			for guest in range(3):
				GameState.customer_index = guest
				GameState.changed.emit()
				await settle()
				check(area.guest_image.get_parent().position.distance_to(Vector2(1434,716))<.001,"customer switch preserves ground point "+str(guest))
				area.thoughts.show_thought("TeashopGuest")
				check(area.thoughts.caption.text==area.thoughts.text_for("TeashopGuest",area.thoughts.speakers[1].count-1),"customer inner speech matches current role "+str(guest))
	SceneRouter.go("garden",false)
	await settle()
	var garden: Control = game.area_root.get_child(0)
	garden.thoughts.show_thought("GardenPicker")
	await settle()
	check(garden.thoughts.bubble.visible,"garden picker thought appears")
	await capture("garden_character_thought")
	var report := {"passed":passed,"failed":failures,"furniture_floor_contacts":floors,"captures":captures,"test_save_directory":ProjectSettings.globalize_path(SaveSystem.base_path)}
	var file := FileAccess.open("res://docs/第二轮调整/家具吸附与人物气泡验证.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("FLOOR_THOUGHT_VERIFICATION: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
