extends Node2D
signal mode_changed(enabled: bool)
var room: String
var world: Node2D
var corners: PackedVector2Array
var items: Dictionary = {}
var badges: Dictionary = {}
var saved_positions: Dictionary = {}
var enabled: bool = false
var selected: String = ""
var pointer_offset := Vector2.ZERO
var drag_start := Vector2.ZERO
var last_valid: bool = true
var grid: Node2D
const INSET: float = 0.025
const DIVISIONS := Vector2(28,42)
const BADGE_ITEMS := {"FGU_W1":"FGW_01","FGU_W2":"FGW_02","FGU_W3":"FGW_03","FGU_W4":"FGW_04","FGU_W5":"FGW_05","FGU_T1":"FGT_03","FGU_T2":"FGT_01","FGU_T3":"FGT_02"}

func setup(owner_room: String, layer: Node2D) -> void:
	room = owner_room
	world = layer
	var file := FileAccess.open("res://data/furniture_floor_layout.json",FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	for point in data.rooms[room].corners:
		corners.append(Vector2(float(point[0]),float(point[1])))
	grid = Node2D.new()
	grid.name = "FurnitureFloorGrid"
	world.add_child(grid)
	grid.visible = false
	for axis in range(2):
		var count: int = int(DIVISIONS[axis])
		for index in range(count+1):
			var fraction: float = float(index)/float(count)
			var line := Line2D.new()
			line.width = 1
			line.default_color = Color(0.40,0.49,0.38,0.13)
			line.points = PackedVector2Array([floor_point(Vector2(fraction,INSET)) if axis == 0 else floor_point(Vector2(INSET,fraction)),floor_point(Vector2(fraction,1-INSET)) if axis == 0 else floor_point(Vector2(1-INSET,fraction))])
			grid.add_child(line)
	_read_saved()
	add_to_group("furniture_editors")

func floor_point(uv: Vector2) -> Vector2:
	return corners[0] + uv.x*(corners[1]-corners[0]) + uv.y*(corners[3]-corners[0]) + uv.x*uv.y*(corners[2]-corners[1]-corners[3]+corners[0])

func floor_uv(point: Vector2) -> Vector2:
	var uv := Vector2(0.5,0.5)
	var cross: Vector2 = corners[2]-corners[1]-corners[3]+corners[0]
	for iteration in range(8):
		var residual: Vector2 = floor_point(uv)-point
		var du: Vector2 = corners[1]-corners[0]+uv.y*cross
		var dv: Vector2 = corners[3]-corners[0]+uv.x*cross
		var determinant: float = du.cross(dv)
		if absf(determinant)<0.001: break
		uv -= Vector2(residual.cross(dv),du.cross(residual))/determinant
	return uv

func snapped_point(point: Vector2) -> Vector2:
	var uv: Vector2 = floor_uv(point)
	uv = (uv*DIVISIONS).round()/DIVISIONS
	return floor_point(Vector2(clampf(uv.x,INSET,1-INSET),clampf(uv.y,INSET,1-INSET)))

func register_item(image: TextureRect, part: Dictionary) -> void:
	if not part.has("groundContacts"): return
	var contact_points := PackedVector2Array()
	var anchor := Vector2.ZERO
	for point in part.groundContacts:
		var local := Vector2(float(point[0]),float(point[1]))*image.size
		contact_points.append(local)
		anchor += local
	anchor /= float(contact_points.size())
	var initial: Vector2 = image.position+anchor
	var support := Node2D.new()
	support.name = part.id+"_FloorAnchor"
	world.add_child(support)
	support.position = initial
	image.reparent(support,false)
	image.position = -anchor
	var shadow := preload("res://scripts/components/ground_contact_shadow.gd").new()
	shadow.contacts = PackedVector2Array()
	shadow.radius = 8.0 if part.id in ["FGW_09","FGW_11","FGT_06","FGT_08"] else 4.5
	for point in contact_points: shadow.contacts.append(point-anchor)
	support.add_child(shadow)
	support.move_child(shadow,0)
	var offsets := PackedVector2Array()
	for point in contact_points: offsets.append(point-anchor)
	if offsets.size()<3:
		offsets = PackedVector2Array([Vector2(-8,-3),Vector2(8,-3),Vector2(8,3),Vector2(-8,3)])
	items[part.id] = {"image":image,"support":support,"anchor":anchor,"default":initial,"offsets":offsets,"alpha":image.texture.get_image(),"label":part.label}
	image.set_meta("floor_anchor",initial)
	image.add_to_group("draggable_furniture")
	if saved_positions.has(part.id):
		var point: Vector2 = saved_positions[part.id]
		if within_floor(part.id,point): _place(part.id,point)

func footprint(id: String, point: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for offset in items[id].offsets: polygon.append(point+offset)
	return Geometry2D.convex_hull(polygon)

func within_floor(id: String, point: Vector2) -> bool:
	for vertex in footprint(id,point):
		var uv: Vector2 = floor_uv(vertex)
		if uv.x<INSET or uv.y<INSET or uv.x>1-INSET or uv.y>1-INSET: return false
	return true

func _polygon_area(polygon: PackedVector2Array) -> float:
	var area_sum: float = 0
	for index in range(polygon.size()): area_sum += polygon[index].cross(polygon[(index+1)%polygon.size()])
	return absf(area_sum)*0.5

func can_place(id: String, point: Vector2) -> bool:
	if not within_floor(id,point): return false
	var polygon: PackedVector2Array = footprint(id,point)
	for character in get_tree().get_nodes_in_group("grounded_art"):
		if character.get_meta("room","") == room and str(character.get_meta("asset_id","")).begins_with("CHR_"):
			if Geometry2D.is_point_in_polygon(character.position,polygon): return false
	for other in items:
		if other == id: continue
		for overlap in Geometry2D.intersect_polygons(polygon,footprint(other,items[other].support.position)):
			if _polygon_area(overlap)>24: return false
	return true

func _place(id: String, point: Vector2) -> void:
	items[id].support.position = point
	items[id].image.set_meta("floor_anchor",point)
	if items[id].image.material is ShaderMaterial:
		var rect: Rect2 = items[id].image.get_global_rect()
		items[id].image.material.set_shader_parameter("scene_region",Vector4(rect.position.x/1920,rect.position.y/1080,rect.size.x/1920,rect.size.y/1080))
	if badges.has(id):
		var delta: Vector2 = point-items[id].default
		badges[id].tag.position = badges[id].tag_origin+delta
		badges[id].hit.position = badges[id].hit_origin+delta
	queue_redraw()

func move_item(id: String, point: Vector2) -> bool:
	if not items.has(id): return false
	var target: Vector2 = snapped_point(point)
	if not can_place(id,target): return false
	_place(id,target)
	return true

func bind_badge(badge_id: String, tag: Control, hit: Button) -> void:
	var id: String = BADGE_ITEMS.get(badge_id,"")
	if not items.has(id): return
	badges[id] = {"tag":tag,"hit":hit,"tag_origin":tag.position,"hit_origin":hit.position}
	_place(id,items[id].support.position)

func set_enabled(value: bool) -> void:
	if not value and not selected.is_empty():
		_place(selected,drag_start)
		selected = ""
	enabled = value
	grid.visible = value
	for record in badges.values(): record.hit.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	mode_changed.emit(value)
	queue_redraw()

func _hit(point: Vector2) -> String:
	var found: String = ""
	var depth: float = -100000
	for id in items:
		var record: Dictionary = items[id]
		var rect: Rect2 = record.image.get_global_rect()
		if not rect.has_point(point): continue
		var local: Vector2 = (point-rect.position)/rect.size*Vector2(record.alpha.get_size())
		var pixel := Vector2i(local)
		if record.alpha.get_pixelv(pixel).a<0.10: continue
		if record.support.position.y >= depth:
			depth = record.support.position.y
			found = id
	return found

func _over_ui(point: Vector2) -> bool:
	for button in get_tree().get_nodes_in_group("furniture_editor_ui"):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point): return true
	for node in get_tree().get_nodes_in_group("character_clicks"):
		if node.get_global_rect().has_point(point): return true
	return point.y<180 or point.y>900 or point.x<345

func _input(event: InputEvent) -> void:
	var modal: Node = get_tree().root.find_child("Modals",true,false)
	if not enabled or GameState.paused or (modal != null and modal.visible): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not selected.is_empty():
			_place(selected,drag_start)
			selected = ""
		else: set_enabled(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = make_input_local(event).position
		if event.pressed:
			if _over_ui(point): return
			selected = _hit(point)
			if selected.is_empty(): return
			drag_start = items[selected].support.position
			pointer_offset = drag_start-point
			last_valid = true
		else:
			if selected.is_empty(): return
			save_layout()
			selected = ""
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventMouseMotion and not selected.is_empty():
		last_valid = move_item(selected,make_input_local(event).position+pointer_offset)
		get_viewport().set_input_as_handled()
		queue_redraw()

func _draw() -> void:
	if not enabled or selected.is_empty(): return
	var point: Vector2 = items[selected].support.position
	var color := Color(0.40,0.54,0.36,0.85) if last_valid else Color(0.65,0.47,0.28,0.85)
	draw_arc(point,13,0,TAU,32,color,2,true)
	draw_line(point+Vector2(-18,0),point+Vector2(18,0),color,1,true)
	draw_line(point+Vector2(0,-8),point+Vector2(0,8),color,1,true)

func save_path() -> String:
	return SaveSystem.base_path.path_join("furniture_layout_v1.cfg")

func _read_saved() -> void:
	var config := ConfigFile.new()
	if config.load(save_path()) != OK: return
	for key in config.get_section_keys(room) if config.has_section(room) else PackedStringArray():
		var value: Variant = config.get_value(room,key)
		if value is Vector2 and is_finite(value.x) and is_finite(value.y): saved_positions[key] = value

func save_layout() -> bool:
	var directory: String = ProjectSettings.globalize_path(SaveSystem.base_path)
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return false
	var config := ConfigFile.new()
	config.load(save_path())
	for id in items: config.set_value(room,id,items[id].support.position)
	return config.save(save_path()) == OK

func reset_layout() -> void:
	selected = ""
	for id in items: _place(id,items[id].default)
	save_layout()
