extends Node2D
signal mode_changed(value: bool)

const GROUNDS: Array = [
	[Vector2(126,322),Vector2(202,272),Vector2(520,269),Vector2(665,300),Vector2(727,337),Vector2(675,361),Vector2(430,380),Vector2(215,367)],
	[Vector2(160,448),Vector2(246,403),Vector2(615,392),Vector2(777,414),Vector2(864,449),Vector2(844,477),Vector2(596,521),Vector2(288,504)],
	[Vector2(230,605),Vector2(340,550),Vector2(739,518),Vector2(932,546),Vector2(1028,588),Vector2(1003,632),Vector2(740,677),Vector2(429,674)],
	[Vector2(1120,541),Vector2(1217,514),Vector2(1457,498),Vector2(1577,520),Vector2(1611,550),Vector2(1544,576),Vector2(1320,596),Vector2(1168,577)],
	[Vector2(1418,744),Vector2(1480,714),Vector2(1782,697),Vector2(1907,737),Vector2(1902,768),Vector2(1836,791),Vector2(1591,809),Vector2(1440,777)]
]
var room := "village"
var enabled := false
var world: Node2D
var view: Control
var items: Dictionary = {}
var order: Array[String] = []
var alpha_cache: Dictionary = {}
var links: Dictionary = {}
var selected := ""
var dragging := false
var resizing := false
var resize_handle := ""
var resize_pointer := Vector2.ZERO
var resize_size := Vector2.ZERO
var resize_state: Dictionary = {}
var keep_proportions := true
var drag_offset := Vector2.ZERO
var drag_state: Dictionary = {}
var pending_asset := ""
var counter := 0
var snap_to_ground := true
var nudge_step := 1.0
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var defaults: Dictionary
var palette: Array
var ghost: TextureRect
var ghost_foot := Vector2.ZERO
var panel: Panel
var pages: Array[Control] = []
var active_page := 0
var toggle: TextureButton
var fold: TextureButton
var selection_label: Label
var status_label: Label
var x_spin: SpinBox
var y_spin: SpinBox
var width_spin: SpinBox
var height_spin: SpinBox
var opacity_spin: SpinBox
var layer_spin: SpinBox
var mirror_check: CheckBox
var lock_check: CheckBox
var snap_check: CheckBox
var ratio_check: CheckBox
var context: Panel
var layer_list: ItemList
var list_ids: Array[String] = []
var updating_ui := false
var last_save_ok := true

func setup(owner_view: Control, layer: Node2D) -> void:
	view = owner_view
	world = layer
	world.y_sort_enabled = false
	var file := FileAccess.open("res://data/village_placement_defaults.json",FileAccess.READ)
	defaults = JSON.parse_string(file.get_as_text())
	palette = defaults.palette
	_restore_state(defaults)
	_read_saved()
	_make_ui()
	ghost = TextureRect.new()
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate.a = 0.55
	ghost.hide()
	add_child(ghost)
	add_to_group("furniture_editors")
	add_to_group("village_layout_editors")
	set_enabled(false)

func _create_item(data: Dictionary) -> void:
	var id: String = data.uid
	var asset: String = data.asset
	var foot := Vector2(float(data.position[0]),float(data.position[1]))
	var width: float = float(data.width)
	var image := UiKit.ground_prop(asset,world,foot,width)
	if data.has("height"):
		var height: float = float(data.height)
		var asset_info: Dictionary = AssetLibrary.catalog[asset]
		# Previously saved native tea proportions adopt the new drawing. Deliberate
		# non-uniform user resizing is preserved, as are every saved position/layer.
		if asset=="PLT_101" and data.get("asset_revision","")!=asset_info.get("revision","") and asset_info.has("previous_ratio"):
			if absf(height/width-float(asset_info.previous_ratio))<0.001:
				height = width*AssetLibrary.ratio(asset)
		image.size.y = height
		image.position.y = -height
	var support: Node2D = image.get_parent()
	support.name = id + "_Support"
	image.name = id + "_Image"
	image.flip_h = bool(data.get("mirror",false))
	image.modulate.a = float(data.get("opacity",1.0))
	image.set_meta("placement_id",id)
	image.add_to_group("village_placeable_art")
	if asset.begins_with("DEC_"):
		image.add_to_group("village_scenery")
		image.set_meta("scenery_layer",data.get("scenery_layer","front"))
	if asset=="PLT_101":
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/foliage_sway.gdshader")
		image.material = mat
		image.add_to_group("ambient_foliage")
	if not alpha_cache.has(asset): alpha_cache[asset] = image.texture.get_image()
	items[id] = {"asset":asset,"label":data.label,"kind":data.get("kind","plant"),"image":image,"support":support,"locked":bool(data.get("locked",false)),"scenery_layer":data.get("scenery_layer","front")}
	order.append(id)
	_sync_link(id)

func capture_state() -> Dictionary:
	var entries: Array[Dictionary] = []
	for id in order:
		var record: Dictionary = items[id]
		var point: Vector2 = record.support.position
		entries.append({"uid":id,"asset":record.asset,"label":record.label,"kind":record.kind,"position":[point.x,point.y],"width":record.image.size.x,"height":record.image.size.y,"asset_revision":AssetLibrary.catalog[record.asset].get("revision",""),"opacity":record.image.modulate.a,"mirror":record.image.flip_h,"locked":record.locked,"scenery_layer":record.scenery_layer})
	return {"version":1,"counter":counter,"snap_to_ground":snap_to_ground,"keep_proportions":keep_proportions,"items":entries}

func _restore_state(state: Dictionary) -> void:
	for child in world.get_children(): child.free()
	items.clear()
	order.clear()
	counter = int(state.get("counter",0))
	snap_to_ground = bool(state.get("snap_to_ground",true))
	keep_proportions = bool(state.get("keep_proportions",true))
	for entry in state.items: _create_item(entry)
	if not items.has(selected): selected = ""
	_sync_all_links()
	_refresh_ui()
	queue_redraw()

func _checkpoint() -> void:
	undo_stack.append(capture_state())
	if undo_stack.size()>50: undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty() or dragging or resizing: return
	redo_stack.append(capture_state())
	_restore_state(undo_stack.pop_back())
	save_layout()

func redo() -> void:
	if redo_stack.is_empty() or dragging or resizing: return
	undo_stack.append(capture_state())
	_restore_state(redo_stack.pop_back())
	save_layout()

func select_item(id: String) -> void:
	selected = id if items.has(id) else ""
	_refresh_ui()
	queue_redraw()

func _constrain(id: String, point: Vector2) -> Vector2:
	var image: TextureRect = items[id].image
	var width: float = image.size.x
	var height: float = image.size.y
	return Vector2(clampf(point.x,width*.5+3,1917-width*.5),clampf(point.y,173+height,932))

func grounded_point(point: Vector2) -> Vector2:
	if not snap_to_ground: return point
	var best := point
	var distance := INF
	for data in GROUNDS:
		var polygon := PackedVector2Array(data)
		if Geometry2D.is_point_in_polygon(point,polygon): return point.round()
		for i in range(polygon.size()):
			var candidate := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
			var squared: float = candidate.distance_squared_to(point)
			if squared<distance:
				distance = squared
				best = candidate
	return best.round()

func _place(id: String, point: Vector2) -> void:
	var final := _constrain(id,point)
	items[id].support.position = final
	items[id].support.set_meta("ground_point",final)
	_sync_link(id)
	_refresh_ui()
	queue_redraw()

func move_item(id: String, point: Vector2, use_ground: bool = true) -> bool:
	if not items.has(id) or items[id].locked: return false
	_place(id,grounded_point(point) if use_ground else point)
	return true

func set_item_position(id: String, point: Vector2) -> void:
	if not items.has(id) or items[id].locked: return
	_checkpoint()
	# Coordinates specify the exact ground anchor; snapping is for pointer placement.
	move_item(id,point,false)
	save_layout()

func set_width(id: String, width: float) -> void:
	if not items.has(id) or items[id].locked: return
	_checkpoint()
	var image: TextureRect = items[id].image
	var height: float = image.size.y*width/image.size.x if keep_proportions else image.size.y
	_apply_dimensions(id,Vector2(width,height),keep_proportions)
	save_layout()

func set_height(id: String, height: float) -> void:
	if not items.has(id) or items[id].locked: return
	_checkpoint()
	var image: TextureRect = items[id].image
	var width: float = image.size.x*height/image.size.y if keep_proportions else image.size.x
	_apply_dimensions(id,Vector2(width,height),keep_proportions)
	save_layout()

func _apply_dimensions(id: String, requested: Vector2, proportional: bool = false) -> void:
	var foot: Vector2 = items[id].support.position
	var limit := Vector2(minf(1100,2*minf(foot.x-3,1917-foot.x)),minf(750,foot.y-173))
	var size := requested.max(Vector2(1,1))
	if proportional:
		var factor: float = clampf(1,maxf(30/size.x,15/size.y),minf(limit.x/size.x,limit.y/size.y))
		size *= factor
	else: size = size.clamp(Vector2(30,15),limit)
	var image: TextureRect = items[id].image
	image.size = size
	image.position = Vector2(-size.x*.5,-size.y)
	_sync_link(id)
	_refresh_ui()
	queue_redraw()

func _handles() -> Dictionary:
	if not items.has(selected): return {}
	var rect: Rect2 = items[selected].image.get_global_rect()
	return {"nw":rect.position,"n":Vector2(rect.get_center().x,rect.position.y),"ne":Vector2(rect.end.x,rect.position.y),"w":Vector2(rect.position.x,rect.get_center().y),"e":Vector2(rect.end.x,rect.get_center().y)}

func _handle_at(point: Vector2) -> String:
	if not items.has(selected) or items[selected].locked: return ""
	var handles := _handles()
	for name in handles:
		if point.distance_squared_to(handles[name])<=100: return name
	return ""

func _resize_to(point: Vector2, shift: bool = false) -> void:
	var delta := point-resize_pointer
	var size := resize_size
	if resize_handle.contains("w"): size.x += -delta.x*2
	if resize_handle.contains("e"): size.x += delta.x*2
	if resize_handle.contains("n"): size.y -= delta.y
	var corner: bool = resize_handle in ["nw","ne"]
	var proportional: bool = corner and (keep_proportions!=shift)
	if proportional:
		var change := Vector2(size.x/resize_size.x-1,size.y/resize_size.y-1)
		var factor: float = maxf(.05,1+(change.x if absf(change.x)>absf(change.y) else change.y))
		size = resize_size*factor
	_apply_dimensions(selected,size,proportional)

func set_layer(id: String, index: int) -> void:
	if not items.has(id) or items[id].locked: return
	index = clampi(index,0,order.size()-1)
	if order.find(id)==index: return
	_checkpoint()
	order.erase(id)
	order.insert(index,id)
	world.move_child(items[id].support,index)
	_refresh_ui()
	queue_redraw()
	save_layout()

func shift_layer(delta: int) -> void:
	if items.has(selected): set_layer(selected,order.find(selected)+delta)

func add_asset(asset: String, point: Vector2) -> String:
	if items.size()>=200 or not AssetLibrary.catalog.has(asset) or asset.begins_with("BLD_"): return ""
	_checkpoint()
	counter += 1
	var uid := "added_"+str(counter)
	while items.has(uid):
		counter += 1
		uid = "added_"+str(counter)
	var width := 140.0
	for choice in palette:
		if choice.asset==asset: width = float(choice.width)
	_create_item({"uid":uid,"asset":asset,"label":AssetLibrary.catalog[asset].label,"kind":"plant","position":[point.x,point.y],"width":width})
	move_item(uid,point)
	selected = uid
	_refresh_ui()
	save_layout()
	return uid

func duplicate_selected() -> String:
	if not items.has(selected) or items[selected].kind=="house": return ""
	var original: Dictionary = items[selected]
	var original_image: TextureRect = original.image
	var width: float = original_image.size.x
	var mirrored: bool = original_image.flip_h
	var opacity: float = original_image.modulate.a
	var height: float = original_image.size.y
	var uid := add_asset(original.asset,original.support.position+Vector2(22,14))
	if uid.is_empty(): return ""
	var image: TextureRect = items[uid].image
	image.size = Vector2(width,height)
	image.position = Vector2(-width*.5,-image.size.y)
	image.flip_h = mirrored
	image.modulate.a = opacity
	_refresh_ui()
	save_layout()
	return uid

func delete_selected() -> void:
	if not items.has(selected) or items[selected].locked: return
	_checkpoint()
	var deleted: String = selected
	items[selected].support.free()
	items.erase(selected)
	order.erase(selected)
	selected = ""
	_sync_link(deleted)
	if is_instance_valid(context): context.hide()
	_refresh_ui()
	queue_redraw()
	save_layout()

func _set_mirror(value: bool) -> void:
	if updating_ui or not items.has(selected) or items[selected].locked: return
	_checkpoint()
	items[selected].image.flip_h = value
	save_layout()

func _set_opacity(value: float) -> void:
	if updating_ui or not items.has(selected) or items[selected].locked: return
	_checkpoint()
	items[selected].image.modulate.a = value/100.0
	save_layout()

func _set_locked(value: bool) -> void:
	if updating_ui or not items.has(selected): return
	_checkpoint()
	items[selected].locked = value
	_refresh_ui()
	save_layout()

func bind_house(id: String, badge: Button, destination: String) -> void:
	var hit: Button = preload("res://scripts/ui/paper_icon_button.gd").new()
	hit.flat = true
	hit.tooltip_text = badge.title
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.add_child(hit)
	hit.pressed.connect(func(): SceneRouter.go(destination))
	var origin := Vector2.ZERO
	var original_height := 0.0
	for entry in defaults.items:
		if entry.uid==id:
			origin = Vector2(entry.position[0],entry.position[1])
			original_height = float(entry.width)*AssetLibrary.ratio(entry.asset)
	links[id] = {"badge":badge,"hit":hit,"origin":origin,"badge_origin":badge.position,"original_height":original_height}
	_sync_link(id)

func _sync_link(id: String) -> void:
	if not links.has(id): return
	var record: Dictionary = links[id]
	if not items.has(id):
		record.hit.hide()
		record.badge.hide()
		return
	record.hit.visible = not enabled
	record.badge.visible = not enabled
	var image: TextureRect = items[id].image
	UiKit.place(record.hit,image.get_global_rect())
	var delta: Vector2 = items[id].support.position-record.origin
	record.badge.position = record.badge_origin+delta+Vector2(0,record.original_height-image.size.y)

func _sync_all_links() -> void:
	for id in links: _sync_link(id)

func _arrange_badges() -> void:
	var occupied: Array[Rect2] = []
	if view.entrance_badges.has("garden"): occupied.append(view.entrance_badges.garden.get_global_rect())
	for id in links:
		if not items.has(id): continue
		var badge: Button = links[id].badge
		var building_rect: Rect2 = items[id].image.get_global_rect()
		var choices: Array[Vector2] = [badge.position,Vector2(building_rect.get_center().x-43,building_rect.position.y-254),Vector2(building_rect.position.x-102,building_rect.get_center().y-121),Vector2(building_rect.end.x+16,building_rect.get_center().y-121)]
		var best := Vector2.ZERO
		var best_score := INF
		for point in choices:
			point = Vector2(clampf(point.x,355,1828),clampf(point.y,180,685))
			var box := Rect2(point,badge.size)
			var score := 0.0
			for other in links:
				if not items.has(other): continue
				var overlap: Rect2 = box.intersection(items[other].image.get_global_rect())
				score += overlap.get_area()
			for rect in occupied: score += box.intersection(rect).get_area()
			if score<best_score:
				best_score = score
				best = point
		badge.position = best
		occupied.append(badge.get_global_rect())

func set_enabled(value: bool) -> void:
	if dragging: _restore_state(drag_state)
	if resizing: _restore_state(resize_state)
	dragging = false
	resizing = false
	pending_asset = ""
	enabled = value
	if is_instance_valid(panel): panel.visible = value
	if is_instance_valid(fold): fold.visible = value
	if is_instance_valid(ghost): ghost.hide()
	if is_instance_valid(context): context.hide()
	for record in links.values(): record.hit.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	for badge in view.entrance_badges.values(): badge.visible = not value
	_sync_all_links()
	if not value: _arrange_badges()
	if is_instance_valid(toggle): UiKit.set_text(toggle.get_meta("caption"),"完成布置" if value else "布置茶村")
	mode_changed.emit(value)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()

func _hit(point: Vector2) -> String:
	for index in range(order.size()-1,-1,-1):
		var id: String = order[index]
		var record: Dictionary = items[id]
		var image: TextureRect = record.image
		var rect: Rect2 = image.get_global_rect()
		if not rect.has_point(point) or image.modulate.a<0.05: continue
		var alpha: Image = alpha_cache[record.asset]
		var fraction: Vector2 = (point-rect.position)/rect.size
		if image.flip_h: fraction.x = 1-fraction.x
		var pixel := Vector2i(clampi(int(fraction.x*alpha.get_width()),0,alpha.get_width()-1),clampi(int(fraction.y*alpha.get_height()),0,alpha.get_height()-1))
		if alpha.get_pixelv(pixel).a>=.1: return id
	return ""

func _over_ui(point: Vector2) -> bool:
	return point.y<175 or point.y>935 or (panel.visible and panel.get_global_rect().has_point(point)) or (context.visible and context.get_global_rect().has_point(point))

func _text_has_focus() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit

func _input(event: InputEvent) -> void:
	if not enabled or GameState.paused: return
	var modal: Control = get_tree().root.find_child("Modals",true,false)
	if is_instance_valid(modal) and modal.visible: return
	if event is InputEventKey and event.pressed and not _text_has_focus():
		if event.keycode==KEY_ESCAPE:
			if resizing:
				_restore_state(resize_state)
				resizing = false
			elif context.visible: context.hide()
			elif dragging:
				_restore_state(drag_state)
				dragging = false
			elif not pending_asset.is_empty():
				pending_asset = ""
				ghost.hide()
			else: set_enabled(false)
		elif event.ctrl_pressed and event.keycode==KEY_Z: redo() if event.shift_pressed else undo()
		elif event.ctrl_pressed and event.keycode==KEY_Y: redo()
		elif event.ctrl_pressed and event.keycode==KEY_D: duplicate_selected()
		elif event.keycode==KEY_DELETE: delete_selected()
		elif event.keycode==KEY_BRACKETLEFT: shift_layer(-1)
		elif event.keycode==KEY_BRACKETRIGHT: shift_layer(1)
		elif event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var direction: Vector2 = {KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}[event.keycode]
			_nudge(direction*(10 if event.shift_pressed else nudge_step))
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		var point: Vector2 = make_input_local(event).position
		if _over_ui(point) or dragging or resizing: return
		pending_asset = ""
		ghost.hide()
		var id := _hit(point)
		if id.is_empty() and items.has(selected) and items[selected].image.get_global_rect().has_point(point): id = selected
		if not id.is_empty():
			select_item(id)
			_show_context(point)
		else: context.hide()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var point: Vector2 = make_input_local(event).position
		if event.pressed:
			if context.visible and not context.get_global_rect().has_point(point): context.hide()
			if _over_ui(point): return
			get_viewport().gui_release_focus()
			var handle := _handle_at(point)
			if not handle.is_empty():
				resizing = true
				resize_handle = handle
				resize_pointer = point
				resize_size = items[selected].image.size
				resize_state = capture_state()
				get_viewport().set_input_as_handled()
				return
			if not pending_asset.is_empty():
				add_asset(pending_asset,point)
				pending_asset = ""
				ghost.hide()
				_set_page(1)
			else:
				select_item(_hit(point))
				if selected.is_empty(): return
				_set_page(1)
				if not items[selected].locked:
					dragging = true
					drag_state = capture_state()
					drag_offset = items[selected].support.position-point
		else:
			if resizing:
				resizing = false
				if capture_state()!=resize_state:
					undo_stack.append(resize_state)
					if undo_stack.size()>50: undo_stack.pop_front()
					redo_stack.clear()
					save_layout()
				get_viewport().set_input_as_handled()
				return
			if not dragging: return
			dragging = false
			if capture_state()!=drag_state:
				undo_stack.append(drag_state)
				if undo_stack.size()>50: undo_stack.pop_front()
				redo_stack.clear()
				save_layout()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var point: Vector2 = make_input_local(event).position
		if resizing:
			_resize_to(point,event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif dragging:
			move_item(selected,point+drag_offset)
			get_viewport().set_input_as_handled()
		elif not pending_asset.is_empty():
			ghost.visible = not _over_ui(point)
			ghost_foot = grounded_point(point)
			ghost.position = ghost_foot-Vector2(ghost.size.x*.5,ghost.size.y)
			queue_redraw()
		else:
			var handle := "" if _over_ui(point) else _handle_at(point)
			var shape: Input.CursorShape = Input.CURSOR_ARROW
			if handle in ["w","e"]: shape = Input.CURSOR_HSIZE
			elif handle=="n": shape = Input.CURSOR_VSIZE
			elif handle=="nw": shape = Input.CURSOR_FDIAGSIZE
			elif handle=="ne": shape = Input.CURSOR_BDIAGSIZE
			Input.set_default_cursor_shape(shape)

func _draw() -> void:
	if not enabled: return
	if snap_to_ground:
		for polygon in GROUNDS:
			var closed := PackedVector2Array(polygon)
			closed.append(closed[0])
			draw_polyline(closed,Color(.55,.62,.46,.30),1.3,true)
	if items.has(selected):
		var rect: Rect2 = items[selected].image.get_global_rect()
		draw_rect(rect,Color(.64,.55,.31,.70),false,1.4)
		if not items[selected].locked:
			for point in _handles().values():
				draw_rect(Rect2(point-Vector2(5,5),Vector2(10,10)),UiKit.PAPER)
				draw_rect(Rect2(point-Vector2(5,5),Vector2(10,10)),Color(.64,.55,.31),false,1.4)
		var foot: Vector2 = items[selected].support.position
		draw_arc(foot,10,0,TAU,24,Color(.64,.55,.31,.85),1.5,true)
		draw_line(foot-Vector2(15,0),foot+Vector2(15,0),Color(.64,.55,.31,.85),1.2,true)
	if is_instance_valid(ghost) and ghost.visible: draw_arc(ghost_foot,9,0,TAU,24,Color(.46,.61,.40,.8),1.5,true)

func save_path() -> String: return SaveSystem.base_path.path_join("village_layout_v1.json")

func _valid_state(state: Variant) -> bool:
	if not state is Dictionary or state.get("version")!=1 or not state.get("items") is Array or state.items.size()>200: return false
	if not state.get("counter",0) is int and not state.get("counter",0) is float: return false
	if not is_finite(float(state.get("counter",0))) or float(state.get("counter",0))<0 or float(state.get("counter",0))>1000000000: return false
	if not state.get("snap_to_ground",true) is bool: return false
	if not state.get("keep_proportions",true) is bool: return false
	var seen: Dictionary = {}
	var houses: Dictionary = {}
	for entry in state.items:
		if not entry is Dictionary or not entry.has_all(["uid","asset","label","position","width"]): return false
		if not entry.uid is String or not entry.label is String or not entry.asset is String or not AssetLibrary.catalog.has(entry.asset) or seen.has(entry.uid): return false
		if not entry.asset.begins_with("DEC_") and entry.asset not in ["PLT_101","BLD_111","BLD_112"]: return false
		if not entry.position is Array or entry.position.size()!=2: return false
		for number in entry.position:
			if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number))>5000: return false
		if not (entry.width is float or entry.width is int) or not is_finite(float(entry.width)) or float(entry.width)<30 or float(entry.width)>1100: return false
		var width: float = float(entry.width)
		var actual_height: Variant = entry.get("height",width*AssetLibrary.ratio(entry.asset))
		if not (actual_height is float or actual_height is int) or not is_finite(float(actual_height)) or float(actual_height)<1: return false
		var height: float = float(actual_height)
		if height>750 or float(entry.position[0])<width*.5+2 or float(entry.position[0])>1918-width*.5 or float(entry.position[1])<172+height or float(entry.position[1])>933: return false
		var opacity: Variant = entry.get("opacity",1.0)
		if not (opacity is float or opacity is int) or not is_finite(float(opacity)) or float(opacity)<0 or float(opacity)>1: return false
		if not entry.get("locked",false) is bool or not entry.get("mirror",false) is bool: return false
		seen[entry.uid] = true
		if entry.asset.begins_with("BLD_"):
			if houses.has(entry.asset) or entry.uid!=entry.asset or entry.get("kind")!="house": return false
			houses[entry.asset] = true
	return true

func _read_saved() -> void:
	if not FileAccess.file_exists(save_path()): return
	var file := FileAccess.open(save_path(),FileAccess.READ)
	if file==null: return
	var state: Variant = JSON.parse_string(file.get_as_text())
	if _valid_state(state):
		_restore_state(_upgrade_default_tea(state))

func _upgrade_default_tea(state: Dictionary) -> Dictionary:
	# Only the untouched former nine-tree arrangement receives the new grouping.
	# A user who moved, resized, removed, mirrored or reordered a tea tree keeps it.
	var former: Array = defaults.get("previous_tea_layout",[])
	if former.is_empty(): return state
	var actual: Array = []
	for entry in state.items:
		if str(entry.get("uid","")).begins_with("tea_"): actual.append(entry)
	if actual.size()!=former.size(): return state
	for i in range(former.size()):
		var a: Dictionary = actual[i]
		var b: Dictionary = former[i]
		if state.items[i].uid!=a.uid: return state
		if a.uid!=b.uid or a.asset!=b.asset or absf(float(a.width)-float(b.width))>0.01: return state
		if Vector2(a.position[0],a.position[1]).distance_to(Vector2(b.position[0],b.position[1]))>0.1: return state
		if a.get("mirror",false) or a.get("locked",false) or absf(float(a.get("opacity",1.0))-1.0)>0.01: return state
		if a.has("height"):
			var ratio: float = float(a.height)/float(a.width)
			if absf(ratio-AssetLibrary.ratio(a.asset))>0.001 and absf(ratio-float(AssetLibrary.catalog[a.asset].get("previous_ratio",0)))>0.001: return state
	var upgraded: Dictionary = state.duplicate(true)
	var fresh: Array = []
	for entry in defaults.items:
		if entry.kind=="tea": fresh.append(entry.duplicate(true))
	for entry in upgraded.items:
		if not str(entry.uid).begins_with("tea_"): fresh.append(entry)
	upgraded.items = fresh
	return upgraded

func save_layout() -> bool:
	var directory := ProjectSettings.globalize_path(SaveSystem.base_path)
	last_save_ok = DirAccess.make_dir_recursive_absolute(directory)==OK
	if last_save_ok:
		var temporary := save_path()+".tmp"
		var file := FileAccess.open(temporary,FileAccess.WRITE)
		if file!=null:
			file.store_string(JSON.stringify(capture_state()))
			file.flush()
			file.close()
			last_save_ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path()))==OK
		else: last_save_ok = false
	if is_instance_valid(status_label): UiKit.set_text(status_label,"摆放已保存" if last_save_ok else "保存失败，请检查磁盘空间")
	return last_save_ok

func reset_layout() -> void:
	_checkpoint()
	selected = ""
	_restore_state(defaults)
	save_layout()

func _ui_button(text: String, parent: Node, rect: Rect2, callback: Callable) -> TextureButton:
	var button := UiKit.button(text,parent,rect,callback)
	var caption: Label = button.get_meta("caption")
	var box := Rect2(9,4,rect.size.x-18,rect.size.y-8)
	caption.set_meta("box",box)
	caption.position = box.position
	caption.custom_maximum_size = box.size
	caption.set_meta("requested_size",18)
	UiKit.set_text(caption,text)
	return button

func _spin(text: String, parent: Node, y: float, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
	UiKit.label(text,parent,Rect2(4,y,83,36),19)
	var spin := SpinBox.new()
	UiKit.place(spin,Rect2(91,y,198,36))
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.add_theme_font_override("font",UiKit.body_font)
	spin.add_theme_font_size_override("font_size",20)
	parent.add_child(spin)
	var line := spin.get_line_edit()
	line.add_theme_font_override("font",UiKit.body_font)
	line.add_theme_font_size_override("font_size",20)
	line.add_theme_color_override("font_color",UiKit.INK)
	line.add_theme_stylebox_override("normal",UiKit.paper_style(8,true))
	line.add_theme_stylebox_override("focus",UiKit.paper_style(8,true))
	spin.value_changed.connect(callback)
	return spin

func _check(text: String, parent: Node, rect: Rect2, callback: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.add_theme_font_override("font",UiKit.body_font)
	box.add_theme_font_size_override("font_size",19)
	box.add_theme_color_override("font_color",UiKit.INK)
	box.add_theme_color_override("font_pressed_color",UiKit.INK)
	box.add_theme_color_override("font_hover_color",UiKit.INK)
	box.add_theme_color_override("font_hover_pressed_color",UiKit.INK)
	UiKit.place(box,rect)
	parent.add_child(box)
	box.toggled.connect(callback)
	return box

func _make_ui() -> void:
	panel = UiKit.flat_card(view,Rect2(32,184,318,744))
	panel.name = "VillagePlacementPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.label("茶村布置",panel,Rect2(12,10,294,38),28,true)
	for i in range(3):
		_ui_button(["素材","调整","层级"][i],panel,Rect2(12+i*100,57,94,44),_set_page.bind(i))
		var page := Control.new()
		UiKit.place(page,Rect2(12,112,294,532))
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(page)
		pages.append(page)
	# Art is independent of text. Every new entry uses a single transparent sprite.
	UiKit.label("选择植物，再点击地面放置",pages[0],Rect2(0,0,294,38),19)
	for i in range(palette.size()):
		var choice: Dictionary = palette[i]
		var tile := Button.new()
		tile.name = "Palette_"+choice.asset
		tile.flat = true
		tile.tooltip_text = choice.label
		UiKit.place(tile,Rect2((i%3)*98,43+(i/3)*95,92,88))
		pages[0].add_child(tile)
		var card := UiKit.flat_card(tile,Rect2(0,0,92,88))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ratio: float = AssetLibrary.ratio(choice.asset)
		var width: float = minf(76,54/ratio)
		UiKit.art(choice.asset,tile,Rect2((92-width)*.5,7,width,width*ratio))
		UiKit.label(choice.label,tile,Rect2(1,63,90,22),16)
		tile.pressed.connect(choose_asset.bind(choice.asset))
	_ui_button("选择 / 恢复制茶工坊",pages[0],Rect2(3,443,288,40),_select_house.bind("BLD_111"))
	_ui_button("选择 / 恢复临水茶铺",pages[0],Rect2(3,487,288,40),_select_house.bind("BLD_112"))
	var form := pages[1]
	x_spin = _spin("落地点 X",form,0,0,1920,1,func(value): if not updating_ui: set_item_position(selected,Vector2(value,y_spin.value)))
	y_spin = _spin("落地点 Y",form,40,0,1080,1,func(value): if not updating_ui: set_item_position(selected,Vector2(x_spin.value,value)))
	width_spin = _spin("宽度",form,80,30,1100,1,func(value): if not updating_ui: set_width(selected,value))
	height_spin = _spin("高度",form,120,15,750,1,func(value): if not updating_ui: set_height(selected,value))
	opacity_spin = _spin("不透明度",form,160,0,100,1,_set_opacity)
	opacity_spin.suffix = "%"
	layer_spin = _spin("层级",form,200,1,200,1,func(value): if not updating_ui: set_layer(selected,int(value)-1))
	mirror_check = _check("水平翻转",form,Rect2(0,239,150,36),_set_mirror)
	lock_check = _check("锁定对象",form,Rect2(151,239,142,36),_set_locked)
	ratio_check = _check("等比缩放",form,Rect2(0,275,148,36),func(value):
		if not updating_ui:
			keep_proportions = value
			save_layout())
	snap_check = _check("地面吸附",form,Rect2(150,275,144,36),func(value):
		if not updating_ui:
			snap_to_ground = value
			queue_redraw()
			save_layout())
	snap_check.tooltip_text = "拖动时以底部落地点吸附地面；坐标输入可精准定位"
	UiKit.label("微调步长",form,Rect2(0,313,90,30),19)
	var steps := OptionButton.new()
	steps.name = "NudgeStep"
	UiKit.place(steps,Rect2(94,313,196,30))
	steps.add_theme_font_override("font",UiKit.body_font)
	steps.add_theme_font_size_override("font_size",19)
	steps.add_theme_color_override("font_color",UiKit.INK)
	steps.add_theme_color_override("font_hover_color",UiKit.INK)
	steps.add_theme_color_override("font_pressed_color",UiKit.INK)
	steps.add_theme_color_override("font_hover_pressed_color",UiKit.INK)
	steps.add_theme_color_override("font_focus_color",UiKit.INK)
	steps.add_theme_color_override("font_disabled_color",UiKit.MUTED)
	steps.add_theme_stylebox_override("normal",UiKit.paper_style(8,true))
	steps.add_theme_stylebox_override("hover",UiKit.paper_style(8,true))
	steps.add_theme_stylebox_override("pressed",UiKit.paper_style(8,true))
	steps.add_theme_stylebox_override("disabled",UiKit.paper_style(8,true))
	steps.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	for number in [1,5,10]: steps.add_item(str(number)+" 像素")
	form.add_child(steps)
	var popup := steps.get_popup()
	popup.add_theme_font_override("font",UiKit.body_font)
	popup.add_theme_font_size_override("font_size",19)
	popup.add_theme_color_override("font_color",UiKit.INK)
	popup.add_theme_color_override("font_hover_color",UiKit.INK)
	popup.add_theme_color_override("font_disabled_color",UiKit.MUTED)
	popup.add_theme_stylebox_override("panel",UiKit.paper_style(12,true))
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color("#dfe7d3")
	highlight.set_corner_radius_all(5)
	popup.add_theme_stylebox_override("hover",highlight)
	steps.item_selected.connect(func(index): nudge_step = [1.0,5.0,10.0][index])
	for i in range(4):
		var direction: Vector2 = [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.RIGHT][i]
		_ui_button(["左","上","下","右"][i],form,Rect2(i*74,353,70,36),func(): _nudge(direction*nudge_step))
	_ui_button("后移一层",form,Rect2(0,397,144,39),shift_layer.bind(-1))
	_ui_button("前移一层",form,Rect2(150,397,144,39),shift_layer.bind(1))
	_ui_button("移到最后",form,Rect2(0,441,144,39),func(): set_layer(selected,0))
	_ui_button("移到最前",form,Rect2(150,441,144,39),func(): set_layer(selected,order.size()-1))
	_ui_button("复制植物",form,Rect2(0,490,144,39),duplicate_selected)
	_ui_button("移除素材",form,Rect2(150,490,144,39),delete_selected)
	UiKit.label("上方先显示；可选被遮住的对象",pages[2],Rect2(0,0,294,35),18)
	layer_list = ItemList.new()
	UiKit.place(layer_list,Rect2(0,41,294,345))
	layer_list.add_theme_font_override("font",UiKit.body_font)
	layer_list.add_theme_font_size_override("font_size",18)
	layer_list.add_theme_color_override("font_color",UiKit.INK)
	layer_list.add_theme_stylebox_override("panel",UiKit.paper_style(8,true))
	layer_list.fixed_column_width = 278
	pages[2].add_child(layer_list)
	layer_list.item_selected.connect(func(index): if not updating_ui: select_item(list_ids[index]))
	_ui_button("后移一层",pages[2],Rect2(0,397,144,39),shift_layer.bind(-1))
	_ui_button("前移一层",pages[2],Rect2(150,397,144,39),shift_layer.bind(1))
	_ui_button("移到最后",pages[2],Rect2(0,441,144,39),func(): set_layer(selected,0))
	_ui_button("移到最前",pages[2],Rect2(150,441,144,39),func(): set_layer(selected,order.size()-1))
	_ui_button("调整所选对象",pages[2],Rect2(0,490,294,39),_set_page.bind(1))
	selection_label = UiKit.label("尚未选择对象",panel,Rect2(12,650,294,29),18)
	_ui_button("撤销",panel,Rect2(12,686,92,36),undo)
	_ui_button("重做",panel,Rect2(112,686,92,36),redo)
	_ui_button("恢复默认",panel,Rect2(212,686,94,36),reset_layout)
	status_label = UiKit.label("位置和层级自动保存",panel,Rect2(12,722,294,20),16)
	context = UiKit.flat_card(view,Rect2(0,0,212,106))
	context.name = "PlacementContext"
	context.z_index = 40
	context.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.label("素材操作",context,Rect2(10,8,192,30),20,true)
	var remove := Button.new()
	remove.name = "DeleteItem"
	remove.text = "删除素材"
	remove.icon = preload("res://assets/editor_ui/editor_delete.svg")
	remove.expand_icon = true
	remove.add_theme_constant_override("icon_max_width",26)
	remove.add_theme_font_override("font",UiKit.body_font)
	remove.add_theme_font_size_override("font_size",20)
	remove.add_theme_color_override("font_color",Color("#8b6353"))
	remove.add_theme_color_override("font_hover_color",Color("#8b6353"))
	remove.add_theme_color_override("font_pressed_color",Color("#8b6353"))
	for style in ["normal","hover","pressed","disabled"]: remove.add_theme_stylebox_override(style,UiKit.paper_style(8,true))
	context.add_child(remove)
	UiKit.place(remove,Rect2(14,46,184,46))
	remove.pressed.connect(delete_selected)
	context.hide()
	toggle = UiKit.button("布置茶村",view,Rect2(362,952,350,65),func(): set_enabled(not enabled))
	toggle.name = "VillagePlacementToggle"
	fold = _ui_button("收起面板",view,Rect2(1150,955,230,56),func():
		panel.visible = not panel.visible
		UiKit.set_text(fold.get_meta("caption"),"收起面板" if panel.visible else "展开面板"))
	_set_page(0)
	_refresh_ui()

func _set_page(index: int) -> void:
	active_page = index
	for i in range(pages.size()): pages[i].visible = i==index
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(panel): return
	updating_ui = true
	var valid := items.has(selected)
	var locked: bool = items[selected].locked if valid else true
	for spin in [x_spin,y_spin,width_spin,height_spin,opacity_spin,layer_spin]: spin.get_line_edit().editable = valid and not locked
	mirror_check.disabled = not valid or locked
	lock_check.disabled = not valid
	snap_check.set_pressed_no_signal(snap_to_ground)
	ratio_check.set_pressed_no_signal(keep_proportions)
	if valid:
		var record: Dictionary = items[selected]
		var point: Vector2 = record.support.position
		x_spin.set_value_no_signal(point.x)
		y_spin.set_value_no_signal(point.y)
		width_spin.set_value_no_signal(record.image.size.x)
		height_spin.set_value_no_signal(record.image.size.y)
		opacity_spin.set_value_no_signal(record.image.modulate.a*100)
		layer_spin.max_value = order.size()
		layer_spin.set_value_no_signal(order.find(selected)+1)
		mirror_check.set_pressed_no_signal(record.image.flip_h)
		lock_check.set_pressed_no_signal(locked)
		UiKit.set_text(selection_label,record.label+" · 第"+str(order.find(selected)+1)+"层"+(" · 锁定" if locked else ""))
	else: UiKit.set_text(selection_label,"尚未选择对象")
	# Rebuilding the list is only needed when selection/order changes, never every idle frame.
	var current_ids: Array[String] = order.duplicate()
	current_ids.reverse()
	if current_ids!=list_ids or layer_list.item_count!=order.size():
		list_ids = current_ids
		layer_list.clear()
		for id in list_ids: layer_list.add_item(str(order.find(id)+1)+"  "+items[id].label)
	for i in range(list_ids.size()):
		var id: String = list_ids[i]
		layer_list.set_item_text(i,str(order.find(id)+1)+"  "+items[id].label+(" [锁]" if items[id].locked else ""))
	layer_list.deselect_all()
	if valid: layer_list.select(list_ids.find(selected))
	updating_ui = false

func choose_asset(asset: String) -> void:
	pending_asset = asset
	selected = ""
	ghost.texture = AssetLibrary.texture(asset)
	var width := 140.0
	for choice in palette:
		if choice.asset==asset: width = float(choice.width)
	ghost.size = Vector2(width,width*AssetLibrary.ratio(asset))
	UiKit.set_text(status_label,"点击地面放置；Esc 取消")
	_refresh_ui()
	queue_redraw()

func _nudge(delta: Vector2) -> void:
	if items.has(selected): set_item_position(selected,items[selected].support.position+delta)

func _show_context(point: Vector2) -> void:
	if not items.has(selected): return
	context.position = Vector2(clampf(point.x+12,355,1708),clampf(point.y+12,180,825))
	context.get_node("DeleteItem").disabled = items[selected].locked
	context.get_node("DeleteItem").tooltip_text = "解除锁定后可删除" if items[selected].locked else "删除所选素材，可撤销"
	context.show()

func _select_house(id: String) -> void:
	if not items.has(id):
		_checkpoint()
		for entry in defaults.items:
			if entry.uid==id: _create_item(entry)
		save_layout()
	select_item(id)
	_set_page(1)
