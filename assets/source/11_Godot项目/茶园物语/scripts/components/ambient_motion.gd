extends Node
const CONFIG: Dictionary = preload("res://scripts/components/ambient_motion_config.gd").ROOMS
const CYCLE_SECONDS: float = 8.0
var phase: float = 0.0
var background: TextureRect
var view: Control
var room: String
var player: AnimationPlayer
var cloud: TextureRect
var cloud_origin := Vector2.ZERO
var reveals: Array[Dictionary] = []
var reveal_elapsed: float = 0.0
var reveals_complete: bool = false
var plants: Array = []
var clouds: Array = []
var preview_mode: bool = false
var baked_player: VideoStreamPlayer
var render_material: ShaderMaterial
var render_texture: Texture2D
var still_texture: Texture2D
var cache_dirty: bool = true
var modal: Control
var loading_view: Control
var editors: Array[Node] = []
var foliage: Array[Dictionary] = []
var plant_offsets := PackedVector2Array()
var cloud_offsets := PackedVector2Array()

func setup(image: TextureRect, owner_view: Control, owner_room: String) -> void:
	background = image
	view = owner_view
	room = owner_room
	name = "AmbientMotion"
	add_to_group("ambient_motion_controllers")
	var settings: Dictionary = CONFIG.get(room,{})
	plants = settings.get("plants",[])
	clouds = settings.get("clouds",[])
	var protected_rects: Array = settings.get("static",[])
	var static_zones := PackedVector4Array()
	for index in range(4):
		var value: Array = protected_rects[index] if index<protected_rects.size() else [0,0,0,0]
		static_zones.append(Vector4(value[0]/1920.0,value[1]/1080.0,value[2]/1920.0,value[3]/1080.0))
	var plant_zones := PackedVector4Array()
	var cloud_zones := PackedVector4Array()
	for index in range(8):
		var value: Array = plants[index] if index<plants.size() else [0,0,1,1,0,0]
		plant_zones.append(Vector4(value[0]/1920.0,value[1]/1080.0,value[2]/1920.0,value[3]/1080.0))
	for index in range(6):
		var value: Array = clouds[index] if index<clouds.size() else [0,0,1,1,0,0,0]
		cloud_zones.append(Vector4(value[0]/1920.0,value[1]/1080.0,value[2]/1920.0,value[3]/1080.0))
	render_material = background.material
	render_texture = background.texture
	render_material.set_shader_parameter("static_count",protected_rects.size())
	render_material.set_shader_parameter("static_zones",static_zones)
	render_material.set_shader_parameter("plant_count",plants.size())
	render_material.set_shader_parameter("cloud_count",clouds.size())
	render_material.set_shader_parameter("plant_zones",plant_zones)
	render_material.set_shader_parameter("cloud_zones",cloud_zones)
	plant_offsets.resize(8)
	cloud_offsets.resize(6)
	player = AnimationPlayer.new()
	player.name = "BreezeKeyframes"
	add_child(player)
	var animation := Animation.new()
	animation.length = CYCLE_SECONDS
	animation.loop_mode = Animation.LOOP_LINEAR
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track,NodePath(".:phase"))
	animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
	for index in range(5):
		animation.track_insert_key(track,CYCLE_SECONDS*index/4.0,TAU*index/4.0)
	var library := AnimationLibrary.new()
	library.add_animation("breeze",animation)
	player.add_animation_library("",library)
	get_tree().tree_changed.connect(_invalidate_cache)
	player.play("breeze")
	apply_phase()
	_setup_baked_video()

func _setup_baked_video() -> void:
	if get_tree().has_meta("baking_ambient_video"): return
	var base: String = "res://assets/14_预渲染动效/"+room
	if not ResourceLoader.exists(base+"_loop.ogv") or not ResourceLoader.exists(base+"_still.png"): return
	var stream: VideoStream = load(base+"_loop.ogv")
	if stream==null: return
	still_texture = load(base+"_still.png")
	if still_texture==null: return
	baked_player = VideoStreamPlayer.new()
	baked_player.name = "BakedBackgroundLoop"
	baked_player.expand = true
	baked_player.loop = true
	baked_player.volume_db = -80
	baked_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baked_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	baked_player.stream = stream
	background.get_parent().add_child(baked_player)
	background.get_parent().move_child(baked_player,background.get_index()+1)
	baked_player.position = background.position
	baked_player.size = background.size
	baked_player.play()
	baked_player.paused = true
	baked_player.visible = false
	background.material = null
	background.texture = still_texture
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _invalidate_cache() -> void: cache_dirty = true

func _refresh_cache() -> void:
	if not cache_dirty: return
	cache_dirty = false
	modal = get_tree().root.find_child("Modals",true,false) as Control
	loading_view = get_tree().root.find_child("Loading",true,false) as Control
	editors.clear()
	for editor in get_tree().get_nodes_in_group("furniture_editors"):
		if editor.room==room: editors.append(editor)
	foliage.clear()
	for image in get_tree().get_nodes_in_group("ambient_foliage"):
		if view.is_ancestor_of(image) and not image.is_queued_for_deletion():
			foliage.append({"image":image,"material":image.material,"phase":fposmod(image.position.x*.017+image.position.y*.011,TAU),"amplitude":minf(2.2,image.size.x*.015)})

func add_reveal(node: CanvasItem, delay: float, duration: float) -> void:
	reveals.append({"node":node,"delay":delay,"duration":duration})
	reveals_complete = false
	node.modulate.a = 1.0 if GameState.settings.reduced_motion else 0.0

func bind_cloud(image: TextureRect) -> void:
	cloud = image
	cloud_origin = cloud.position
	cloud.name = "LogoCloud"
	cloud.add_to_group("animated_logo_clouds")

func restart_reveal() -> void:
	reveal_elapsed = 0.0
	reveals_complete = false
	for entry in reveals:
		entry.node.modulate.a = 1.0 if GameState.settings.reduced_motion else 0.0

func _blocked() -> bool:
	_refresh_cache()
	if is_instance_valid(modal) and modal.visible: return true
	for editor in editors:
		if is_instance_valid(editor) and editor.enabled: return true
	return false

func _process(delta: float) -> void:
	if preview_mode or not is_instance_valid(background): return
	_refresh_cache()
	var active: bool = background.is_visible_in_tree()
	if room!="loading" and is_instance_valid(loading_view) and loading_view.visible: active = false
	if not active:
		player.pause()
		if is_instance_valid(baked_player): baked_player.paused = true
		return
	var blocked: bool = _blocked()
	if not blocked and not reveals_complete:
		reveal_elapsed += delta
		update_reveal()
	var reduced: bool = GameState.settings.reduced_motion
	if reduced:
		player.pause()
		phase = 0.0
		if is_instance_valid(baked_player):
			baked_player.paused = true
			baked_player.visible = false
		apply_phase()
	elif blocked:
		player.pause()
		if is_instance_valid(baked_player): baked_player.paused = true
	else:
		if not player.is_playing(): player.play("breeze")
		if is_instance_valid(baked_player):
			baked_player.visible = true
			baked_player.paused = false
			phase = fposmod(baked_player.stream_position,CYCLE_SECONDS)/CYCLE_SECONDS*TAU
		apply_phase()

func update_reveal() -> void:
	reveals_complete = true
	for entry in reveals:
		if not is_instance_valid(entry.node): continue
		var value: float = clampf((reveal_elapsed-entry.delay)/entry.duration,0.0,1.0)
		entry.node.modulate.a = 1.0 if GameState.settings.reduced_motion else smoothstep(0.0,1.0,value)
		if value<1.0 and not GameState.settings.reduced_motion: reveals_complete = false

func apply_phase() -> void:
	_refresh_cache()
	var reduced: bool = GameState.settings.reduced_motion
	# Full background deformation only runs in deterministic captures/fallback.
	# Normal gameplay decodes one prepared video; no background shader updates.
	if not is_instance_valid(baked_player) or preview_mode:
		plant_offsets.fill(Vector2.ZERO)
		cloud_offsets.fill(Vector2.ZERO)
		for index in range(plants.size()):
			var value: Array = plants[index]
			var sway: float = 0.0 if reduced else sin(phase+float(value[5]))*float(value[4])
			plant_offsets[index] = Vector2(sway/1920.0,sway*.10/1080.0)
		for index in range(clouds.size()):
			var value: Array = clouds[index]
			var wave: float = 0.0 if reduced else sin(phase+float(value[6]))
			cloud_offsets[index] = Vector2(wave*float(value[4])/1920.0,wave*float(value[5])/1080.0)
		render_material.set_shader_parameter("plant_offsets",plant_offsets)
		render_material.set_shader_parameter("cloud_offsets",cloud_offsets)
	for entry in foliage:
		if not is_instance_valid(entry.image) or entry.image.is_queued_for_deletion():
			cache_dirty = true
			continue
		var sway: float = 0.0 if reduced else sin(phase+entry.phase)*entry.amplitude
		entry.material.set_shader_parameter("sway_pixels",sway)
	if is_instance_valid(cloud):
		cloud.position = cloud_origin if reduced else cloud_origin+Vector2(sin(phase)*5.5,sin(phase+0.5)*2.0)

func set_preview_time(seconds: float, revealed: bool = true) -> void:
	preview_mode = true
	player.pause()
	if is_instance_valid(baked_player):
		baked_player.paused = true
		baked_player.visible = false
		background.texture = render_texture
		background.material = render_material
	phase = fposmod(seconds,CYCLE_SECONDS)/CYCLE_SECONDS*TAU
	reveal_elapsed = 10.0 if revealed else maxf(0.0,seconds)
	update_reveal()
	apply_phase()

func resume_motion() -> void:
	preview_mode = false
	if is_instance_valid(baked_player):
		background.texture = still_texture
		background.material = null
	player.play("breeze")
