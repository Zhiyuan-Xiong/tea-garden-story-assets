extends Control
var area_root: Control
var loading_layer: Control
var loading_fill: Control
var loading_leaf: TextureRect
var loading_percent: Label
var modals: Control
var toast: Label
var toast_time: float = 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	theme = UiKit.game_theme
	area_root = Control.new()
	area_root.name = "CurrentArea"
	add_child(area_root)
	UiKit.place(area_root, Rect2(0, 0, 1920, 1080))
	_make_loading()
	modals = Control.new()
	modals.set_script(preload("res://scripts/ui/modal_manager.gd"))
	modals.name = "Modals"
	add_child(modals)
	UiKit.place(modals, Rect2(0, 0, 1920, 1080))
	var toast_panel = UiKit.flat_card(self, Rect2(555, 182, 810, 69), Color(0.97, 0.97, 0.89, 0.97))
	toast_panel.name = "ToastPanel"
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = UiKit.label("", toast_panel, Rect2(20, 5, 770, 59), 24)
	toast_panel.visible = false
	SceneRouter.requested.connect(_route)
	GameState.notice.connect(_notice)
	GameState.action_completed.connect(_autosave)
	_route("home", false)

func _make_loading() -> void:
	loading_layer = Control.new()
	loading_layer.name = "Loading"
	loading_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loading_layer)
	UiKit.place(loading_layer, Rect2(0, 0, 1920, 1080))
	UiKit.art("BG_312", loading_layer, Rect2(0, 0, 1920, 1080), false)
	# 用户图三的茶器组合为一个整体，内部不再分别缩放、移动。
	UiKit.prop("PRP_411", loading_layer, Vector2(430, 152), 1060)
	UiKit.art("UI_038", loading_layer, Rect2(565, 824, 790, 30))
	var heading_plate = ColorRect.new()
	heading_plate.color = Color("#f8f5e9")
	heading_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(heading_plate)
	UiKit.place(heading_plate, Rect2(783, 806, 354, 62))
	UiKit.label("茶香正在路上", loading_layer, Rect2(800, 813, 320, 49), 33, true)
	UiKit.art("UI_036", loading_layer, Rect2(680, 890, 560, 30))
	loading_fill = Control.new()
	loading_fill.clip_contents = true
	loading_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(loading_fill)
	UiKit.place(loading_fill, Rect2(687, 895, 546, 21))
	UiKit.art("UI_037", loading_fill, Rect2(0, 0, 546, 21))
	loading_leaf = UiKit.art("ICO_401", loading_layer, Rect2(665, 874, 35, 27))
	loading_percent = UiKit.label("0%", loading_layer, Rect2(1252, 879, 93, 46), 23)
	UiKit.label("一片新芽，慢慢成为一盏茶", loading_layer, Rect2(684, 951, 552, 45), 25)
	loading_layer.visible = false

func _set_progress(progress: float) -> void:
	loading_fill.size.x = maxf(1.0, progress * 546.0)
	loading_leaf.position.x = 671.0 + progress * 546.0
	UiKit.set_text(loading_percent, str(roundi(progress * 100)) + "%")

func _route(destination: String, with_loading: bool = true) -> void:
	SceneRouter.transitioning = true
	modals.close()
	GameState.paused = true
	if SceneRouter.current != "home" and GameState.started:
		SaveSystem.write_slot(0)
	loading_layer.visible = with_loading
	_set_progress(0.0)
	var path: String = SceneRouter.PATHS[destination]
	var scene: PackedScene
	if with_loading:
		var error: Error = ResourceLoader.load_threaded_request(path, "PackedScene")
		if error != OK:
			scene = load(path)
		else:
			var progress: Array = []
			var minimum: float = 0.12 if GameState.settings.reduced_motion else 0.55
			var began: int = Time.get_ticks_msec()
			while true:
				var status: int = ResourceLoader.load_threaded_get_status(path, progress)
				var time_fraction: float = minf(float(Time.get_ticks_msec() - began) / (minimum * 1000.0), 1.0)
				_set_progress(minf(float(progress[0]) if not progress.is_empty() else 0.0, time_fraction))
				if status == ResourceLoader.THREAD_LOAD_LOADED and time_fraction >= 1.0:
					scene = ResourceLoader.load_threaded_get(path)
					break
				if status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
					break
				await get_tree().process_frame
	else:
		scene = load(path)
	if not scene:
		loading_layer.visible = false
		SceneRouter.transitioning = false
		GameState.paused = false
		_notice("场景载入失败，请返回主页后重试。")
		return
	for child in area_root.get_children():
		area_root.remove_child(child)
		child.queue_free()
	SceneRouter.current = destination
	GameState.in_menu = destination == "home"
	if destination != "home":
		GameState.last_scene = destination
	area_root.add_child(scene.instantiate())
	loading_layer.visible = false
	SceneRouter.transitioning = false
	GameState.paused = false
	if destination != "home" and GameState.started:
		SaveSystem.write_slot(0)
	GameState.changed.emit()

func _autosave(_action: String) -> void:
	if GameState.started:
		if not SaveSystem.write_slot(0):
			_notice(SaveSystem.last_error)

func _notice(message: String) -> void:
	UiKit.set_text(toast, message)
	toast.get_parent().visible = true
	toast_time = 3.8

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			toast.get_parent().visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not modals.visible and not SceneRouter.transitioning:
		SceneRouter.modal("settings")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.started:
			SaveSystem.write_slot(0)
		SaveSystem.save_settings()
		get_tree().quit()
