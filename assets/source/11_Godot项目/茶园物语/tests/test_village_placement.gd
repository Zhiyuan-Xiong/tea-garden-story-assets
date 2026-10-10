extends Node
var game: Control
var village: Control
var editor: Node2D
var passed := 0
var failures: Array[String] = []
var report: Dictionary = {}

func check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else:
		failures.append(text)
		push_error(text)

func settle(frames: int = 8) -> void:
	for i in range(frames): await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	check(get_viewport().get_texture().get_image().save_png("res://docs/茶村自由布置/"+name+".png")==OK,"Capture "+name)

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	Input.parse_input_event(event)
	await settle(2)

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	await settle(2)

func click(point: Vector2) -> void:
	await move_mouse(point)
	await mouse(point,true)
	await mouse(point,false)

func right_click(point: Vector2) -> void:
	await move_mouse(point)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		Input.parse_input_event(event)
		await settle(2)

func key(code: Key, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
	await settle(2)
	event.pressed = false
	Input.parse_input_event(event)

func overlap_point(a: TextureRect, b: TextureRect) -> Vector2:
	var rect := a.get_global_rect().intersection(b.get_global_rect())
	var aa := a.texture.get_image()
	var bb := b.texture.get_image()
	for y in range(int(rect.position.y)+1,int(rect.end.y)-1,2):
		for x in range(int(rect.position.x)+1,int(rect.end.x)-1,2):
			var point := Vector2(x,y)
			var av: Vector2 = (point-a.global_position)/a.size
			var bv: Vector2 = (point-b.global_position)/b.size
			if aa.get_pixel(int(av.x*aa.get_width()),int(av.y*aa.get_height())).a>.95 and bb.get_pixel(int(bv.x*bb.get_width()),int(bv.y*bb.get_height())).a>.95: return point
	return Vector2.ZERO

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://village_placement_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	SceneRouter.go("village",false)
	await settle(15)
	village = game.area_root.get_child(0)
	editor = village.village_editor
	game.toast_time = 0
	game.toast.get_parent().hide()
	check(editor.items.size()==19 and editor.palette.size()==10,"19 independently placed defaults and ten palette choices")
	check(not editor.enabled and not editor.panel.visible,"Arrangement is opt-in")
	check(not editor.world.y_sort_enabled,"Explicit manual order replaces automatic Y sorting")
	for id in editor.order:
		var item: Dictionary = editor.items[id]
		check(item.image.z_index==0 and item.support.z_index==0,"World order never raises an object above HUD")
		check(is_equal_approx(item.image.get_global_rect().end.y,item.support.position.y),"Each sprite base uses the ground anchor")
		if item.asset.begins_with("DEC_"):
			check(item.image.material==null,"Static scenery adds no runtime shader")
	check(editor.items.BLD_111.support.position==Vector2(1374,560),"Workshop preserves its default floor position")
	check(editor.items.BLD_112.support.position==Vector2(1628,752),"Shop preserves its default floor position")
	for id in ["DEC_461","DEC_462","DEC_463","DEC_464","DEC_465","DEC_466"]:
		var image: Image = AssetLibrary.texture(id,false).get_image()
		check(image.has_mipmaps(),"Prepared mipmaps for "+id)
		check(image.get_pixel(0,0).a<.02,"Transparent outer canvas for "+id)
	await capture("茶村默认")
	# Enter using the actual visible in-game control.
	await click(editor.toggle.get_global_rect().get_center())
	check(editor.enabled and editor.panel.visible,"Real arrangement toggle opens the palette")
	for badge in village.entrance_badges.values(): check(not badge.visible,"Entrance UI is hidden during placement")
	await settle(10)
	check(village.ambient.baked_player.paused,"Prepared background motion pauses during precision placement")
	await capture("布置素材库")
	# Palette click plus floor click places a new independent transparent item.
	var tile: Button = editor.pages[0].get_node("Palette_DEC_461")
	await click(tile.get_global_rect().get_center())
	check(editor.pending_asset=="DEC_461","Palette choice arms floor placement")
	await click(Vector2(1110,613))
	var placed: String = editor.selected
	check(not placed.is_empty() and editor.items.size()==20,"Floor click adds exactly one sprite")
	check(editor.pending_asset.is_empty() and editor.active_page==1,"After placement, show the selected item controls")
	var point: Vector2 = editor.items[placed].support.position
	check(point==editor.grounded_point(Vector2(1110,613)),"Pointer placement snaps to the closest floor")
	# Real mouse drag uses the object's base, retains pointer offset and commits one undo entry.
	editor.snap_to_ground = false
	editor.set_item_position(placed,Vector2(990,590))
	var art: TextureRect = editor.items[placed].image
	var center := art.get_global_rect().get_center()
	var before: Vector2 = editor.items[placed].support.position
	await move_mouse(center)
	await mouse(center,true)
	check(editor.dragging,"Real opaque sprite press begins a drag")
	await move_mouse(center+Vector2(23,17))
	await mouse(center+Vector2(23,17),false)
	check(editor.items[placed].support.position.is_equal_approx(before+Vector2(23,17)),"Real drag preserves the ground anchor and grab offset")
	check(not editor.dragging and editor.last_save_ok,"Release commits the drag and saves")
	# Native coordinate inputs, widths, flips, opacity and key nudges.
	editor.select_item(placed)
	editor.x_spin.value = 1021
	editor.y_spin.value = 600
	check(editor.items[placed].support.position==Vector2(1021,600),"Native numeric inputs set exact ground coordinates")
	editor.width_spin.value = 167
	editor.opacity_spin.value = 73
	editor.mirror_check.button_pressed = true
	check(editor.items[placed].image.size.x==167 and is_equal_approx(editor.items[placed].image.modulate.a,.73) and editor.items[placed].image.flip_h,"Native size, transparency and flip controls work")
	get_viewport().gui_release_focus()
	await key(KEY_RIGHT)
	check(editor.items[placed].support.position==Vector2(1022,600),"Arrow key makes a one-pixel adjustment")
	editor.lock_check.button_pressed = true
	check(not editor.move_item(placed,Vector2(1010,605)) and editor.items[placed].support.position==Vector2(1022,600),"Locked objects cannot move")
	editor.lock_check.button_pressed = false
	await capture("精准调整")
	var steps: OptionButton = editor.pages[1].get_node("NudgeStep")
	await click(steps.get_global_rect().get_center())
	check(steps.get_popup().visible,"Actual step selector opens the option menu")
	check(steps.get_theme_stylebox("normal") is StyleBoxTexture and steps.get_popup().get_theme_stylebox("panel") is StyleBoxTexture,"Closed selector and expanded menu both use light paper")
	await settle()
	check(steps.get_popup().get_texture().get_image().save_png("res://docs/茶村自由布置/亮色步长菜单.png")==OK,"Capture actual light step popup")
	steps.get_popup().hide()
	await settle()
	check(not steps.get_popup().visible and editor.enabled,"Closing the dropdown keeps arrangement active")
	# Resize by actual visible bounding handles. The base never shifts.
	get_viewport().gui_release_focus()
	editor.select_item(placed)
	var resize_foot: Vector2 = editor.items[placed].support.position
	var initial_size: Vector2 = editor.items[placed].image.size
	var corner: Vector2 = editor._handles().ne
	await move_mouse(corner)
	await mouse(corner,true)
	check(editor.resizing and not editor.dragging,"Corner control begins resize rather than moving the sprite")
	await move_mouse(corner+Vector2(20,-10))
	await mouse(corner+Vector2(20,-10),false)
	var corner_size: Vector2 = editor.items[placed].image.size
	check(corner_size.x>initial_size.x and is_equal_approx(corner_size.y/corner_size.x,initial_size.y/initial_size.x),"Corner drag enlarges proportionally")
	check(editor.items[placed].support.position==resize_foot,"Corner resize keeps the exact floor anchor")
	editor.undo()
	check(editor.items[placed].image.size.is_equal_approx(initial_size),"One undo restores the complete corner resize")
	var edge: Vector2 = editor._handles().e
	await move_mouse(edge)
	await mouse(edge,true)
	await move_mouse(edge+Vector2(16,0))
	await mouse(edge+Vector2(16,0),false)
	check(is_equal_approx(editor.items[placed].image.size.x,initial_size.x+32) and is_equal_approx(editor.items[placed].image.size.y,initial_size.y),"Side handle changes width independently of height")
	check(editor.items[placed].support.position==resize_foot,"Independent aspect adjustment also stays grounded")
	var top: Vector2 = editor._handles().n
	await mouse(top,true)
	await move_mouse(top-Vector2(0,12))
	await mouse(top-Vector2(0,12),false)
	check(is_equal_approx(editor.items[placed].image.size.y,initial_size.y+12),"Top edge adjusts height independently")
	editor.keep_proportions = false
	editor.height_spin.value = 89
	check(is_equal_approx(editor.items[placed].image.size.y,89),"Numeric height is available for exact aspect adjustments")
	await capture("定界框缩放")
	await right_click(editor.items[placed].image.get_global_rect().get_center())
	check(editor.context.visible and editor.selected==placed,"Real right click opens the selected sprite context menu")
	check(editor.context.get_node("DeleteItem").icon!=null,"Context deletion shows an independent trash icon")
	await capture("右键删除菜单")
	await click(editor.context.get_node("DeleteItem").get_global_rect().get_center())
	check(not editor.items.has(placed) and not editor.context.visible,"Actual delete-icon click removes the sprite and closes the menu")
	editor.undo()
	check(editor.items.has(placed) and is_equal_approx(editor.items[placed].image.size.y,89),"Undo restores a deleted sprite with its adjusted proportions")
	editor.select_item(placed)
	editor.set_width(placed,167)
	editor.keep_proportions = true
	# Copy, deletion and undo/redo retain complete placement properties.
	var duplicate: String = editor.duplicate_selected()
	check(editor.items[duplicate].image.size.x==167 and editor.items[duplicate].image.flip_h and is_equal_approx(editor.items[duplicate].image.modulate.a,.73),"Duplicated plant keeps size, flip and transparency")
	editor.delete_selected()
	check(not editor.items.has(duplicate),"Removal deletes the independent item")
	editor.undo()
	check(editor.items.has(duplicate),"Undo restores the removed plant")
	editor.redo()
	check(not editor.items.has(duplicate),"Redo removes the plant again")
	# Alpha-aware hit testing and real front/back composition against a house.
	editor.set_item_position(placed,Vector2(1374,560))
	editor.select_item(placed)
	editor._set_opacity(100)
	editor._set_mirror(false)
	editor.set_width(placed,180)
	editor.set_layer(placed,0)
	var overlap := overlap_point(editor.items[placed].image,editor.items.BLD_111.image)
	check(overlap!=Vector2.ZERO,"There is a known opaque plant/house overlap")
	check(editor._hit(overlap)=="BLD_111","Rear plant hit testing reaches the house in front")
	editor.select_item("")
	await capture("植物在房屋后")
	var rear_image := get_viewport().get_texture().get_image()
	editor.set_layer(placed,editor.order.size()-1)
	check(editor._hit(overlap)==placed,"Front plant hit testing selects the visible foreground plant")
	await capture("植物在房屋前")
	var front_image := get_viewport().get_texture().get_image()
	var changed := 0
	for y in range(510,560):
		for x in range(1285,1465):
			var a := rear_image.get_pixel(x,y)
			var b := front_image.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.12: changed += 1
	check(changed>200,"GPU raster changes when a plant moves across the building layer")
	editor.select_item(placed)
	editor._set_page(2)
	await capture("前后层级")
	# Layer list selects a fully covered object independently of world hit testing.
	editor.set_layer(placed,0)
	var index: int = editor.list_ids.find(placed)
	editor.layer_list.item_selected.emit(index)
	check(editor.selected==placed,"Layer list selects objects hidden behind a building")
	editor.layer_spin.value = editor.order.size()
	check(editor.order.back()==placed,"Native numeric layer control places the object at the front")
	# Moving/resizing a building also moves its destination hit area.
	editor.select_item("BLD_111")
	editor.set_item_position("BLD_111",Vector2(1357,574))
	editor.set_width("BLD_111",398)
	check(editor.links.BLD_111.hit.get_global_rect().is_equal_approx(editor.items.BLD_111.image.get_global_rect()),"Building click bounds follow exact position and size")
	var house_count: int = editor.items.size()
	check(editor.duplicate_selected().is_empty(),"Buildings retain one navigation target each")
	editor.delete_selected()
	check(editor.items.size()==house_count-1 and not editor.links.BLD_111.hit.visible,"Deleting a house also removes its destination hit area")
	editor.undo()
	check(editor.items.size()==house_count and editor.items.has("BLD_111"),"Undo restores a deleted house")
	# Geometry containment, save validation and clean fold/unfold.
	editor.snap_to_ground = true
	check(editor.grounded_point(Vector2(1500,130))!=Vector2(1500,130),"Ground snapping excludes sky positions")
	editor.snap_to_ground = false
	check(editor.grounded_point(Vector2(1500,130))==Vector2(1500,130),"Ground snapping can be disabled for deliberate overlays")
	await click(editor.fold.get_global_rect().get_center())
	check(not editor.panel.visible,"Panel folds for an unobstructed scene")
	await click(editor.fold.get_global_rect().get_center())
	check(editor.panel.visible,"Panel unfolds again")
	var saved: Dictionary = editor.capture_state()
	check(editor._valid_state(saved) and editor.save_layout(),"Complete layout validates and saves atomically")
	var invalid := saved.duplicate(true)
	invalid.items.append(invalid.items[0].duplicate(true))
	check(not editor._valid_state(invalid),"Duplicate object IDs are rejected")
	editor.reset_layout()
	check(editor.items.size()==19,"Restore default layout is available")
	editor.undo()
	check(editor.capture_state()==saved,"Restoring defaults is undoable")
	# Scene re-entry restores new plants, widths, positions and the exact manual order.
	editor.set_enabled(false)
	await settle(10)
	check(not village.ambient.baked_player.paused,"Completing arrangement resumes prepared motion")
	for badge in village.entrance_badges.values():
		check(badge.visible,"Destination banners return after arrangement")
		for id in ["BLD_111","BLD_112"]: check(not badge.get_global_rect().intersects(editor.items[id].image.get_global_rect()),"Banner avoids the moved building silhouette")
	await capture("布置完成示例")
	SceneRouter.go("home",false)
	await settle()
	SceneRouter.go("village",false)
	await settle(12)
	village = game.area_root.get_child(0)
	editor = village.village_editor
	check(editor.capture_state()==saved,"Re-entering restores the full layout without loss")
	check(editor.links.BLD_111.hit.get_global_rect().is_equal_approx(editor.items.BLD_111.image.get_global_rect()),"Restored house destination retains its new bounds")
	var hit_point: Vector2 = editor.links.BLD_111.hit.get_global_rect().get_center()
	var layout_path: String = editor.save_path()
	await click(hit_point)
	await get_tree().create_timer(.8).timeout
	check(SceneRouter.current=="workshop","Real moved-house click still enters the workshop")
	# Invalid on-disk layout falls back to the original valid defaults.
	var file := FileAccess.open(layout_path,FileAccess.WRITE)
	file.store_string('{"version":0,"items":[]}')
	file.close()
	SceneRouter.go("village",false)
	await settle(12)
	village = game.area_root.get_child(0)
	editor = village.village_editor
	check(editor.items.size()==19,"Invalid saved layout safely falls back to defaults")
	# Fit all native text inside every editor page and ensure widgets never clip the bottom.
	editor.set_enabled(true)
	for page in range(3):
		editor._set_page(page)
		await settle()
		for label in get_tree().get_nodes_in_group("game_text"):
			if not label.is_visible_in_tree() or not editor.panel.is_ancestor_of(label): continue
			var font: Font = label.get_theme_font("font")
			var measured: Vector2 = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,maxf(label.size.x-8,1),label.get_theme_font_size("font_size"))
			check(measured.y<=label.size.y+1,"Native editor text fits: "+label.text)
			check(not label.text.contains("\\n"),"No escaped newlines in editor text")
			check(editor.panel.get_global_rect().encloses(label.get_global_rect()),"Editor text stays inside its panel: "+label.text)
	report = {"passed":passed,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"palette_count":editor.palette.size(),"layer_raster_changed_pixels":changed,"isolated_test_saves":SaveSystem.base_path,"png_originals_preserved":true}
	var out := FileAccess.open("res://docs/茶村自由布置/实际运行检查.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"\t"))
	print("VILLAGE_PLACEMENT_VERIFICATION: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
