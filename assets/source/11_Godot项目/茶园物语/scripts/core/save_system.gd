extends Node

const VERSION: int = 2
var base_path: String = "user://saves"
var settings_path: String = "user://settings.cfg"
var last_error: String = ""
const AREAS: Array[String] = ["village", "garden", "workshop", "teashop"]

func _ready() -> void:
	var config = ConfigFile.new()
	if config.load(settings_path) == OK:
		for key in GameState.settings:
			GameState.settings[key] = config.get_value("settings", key, GameState.settings[key])

func slot_path(slot: int) -> String:
	if slot < 0 or slot > 2:
		return ""
	return base_path.path_join("slot_" + str(slot) + ".json")

func write_slot(slot: int) -> bool:
	last_error = ""
	if not GameState.started or slot_path(slot).is_empty():
		last_error = "没有可以保存的游戏进度。"
		return false
	var directory: String = ProjectSettings.globalize_path(base_path)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "无法创建存档目录。"
		return false
	var data: Dictionary = {"version": VERSION, "saved_at": Time.get_datetime_string_from_system(false, true), "timestamp": Time.get_unix_time_from_system(), "state": GameState.snapshot()}
	var target: String = slot_path(slot)
	var temporary: String = target + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		last_error = "存档写入失败，请检查磁盘空间。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	if error != OK:
		last_error = "存档替换未完成；原记录保持不变。"
		return false
	return true

func _whole(value: Variant, minimum: float = 0.0, maximum: float = 1000000000.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func validate(data: Variant) -> bool:
	if not data is Dictionary or not _whole(data.get("version"), 1, VERSION):
		return false
	if not data.get("saved_at") is String or not _number(data.get("timestamp"), 0.0, 99999999999.0):
		return false
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return false
	var required: Array[String] = ["day", "copper", "seeds", "fresh", "fertilizer", "teas", "plots", "batch", "milestones", "served", "customer_index", "upgraded", "chapter", "last_scene", "total_harvested", "total_crafted", "play_seconds"]
	if not state.has_all(required):
		return false
	for key in ["day", "copper", "seeds", "fresh", "fertilizer", "served", "total_harvested", "total_crafted"]:
		if not _whole(state[key]):
			return false
	if not _number(state.play_seconds, 0.0, 1000000000.0) or not state.upgraded is bool:
		return false
	if int(state.day) < 1 or not _whole(state.customer_index, 0, 2) or not _whole(state.chapter, 0, 4) or not state.last_scene is String or not AREAS.has(state.last_scene):
		return false
	if not state.teas is Array or state.teas.size() != 3 or not state.plots is Array or state.plots.size() not in [3,14]:
		return false
	for amount in state.teas:
		if not _whole(amount):
			return false
	for plot in state.plots:
		if not plot is Dictionary or not plot.has_all(["planted", "age", "harvested", "fertilized"]):
			return false
		if not _number(plot.age, 0.0, 86400.0):
			return false
		for key in ["planted", "harvested", "fertilized"]:
			if not plot[key] is bool:
				return false
	if not state.batch is Dictionary or not state.milestones is Dictionary:
		return false
	for key in state.milestones:
		if not key is String or not state.milestones[key] is bool:
			return false
	if not state.batch.is_empty():
		var batch: Dictionary = state.batch
		if not batch.has_all(["stage", "elapsed", "points", "count", "fire", "last_action", "quality"]):
			return false
		if not _whole(batch.stage, 0, 4) or not _whole(batch.fire, 1, 3) or not _whole(batch.quality, 0, 2):
			return false
		if not _whole(batch.points, 0, 30) or not _whole(batch.count, 0, 8) or not _number(batch.elapsed, 0, 1000000000) or not _number(batch.last_action, -10, 1000000000):
			return false
	var modern_keys: Array = ["experience", "profession", "crafted_batches", "precise_orders", "best_batches", "completed_tasks", "daily", "unlocked_recipes", "recipe_mastery", "recipe_taught", "pending_recipe_lessons", "claimed_achievements", "current_order", "order_serial", "tasting_guests", "meetings", "basket_capacity", "bag_capacity", "quality_tool", "decorations", "five_day_reviewed", "tea_inventory"]
	if int(data.version)==2 or state.keys().any(func(key):return modern_keys.has(key)):
		if not preload("res://scripts/core/experience_save_validator.gd").validate(state): return false
	return true

func read_slot(slot: int) -> Dictionary:
	var target: String = slot_path(slot)
	if target.is_empty() or not FileAccess.file_exists(target):
		return {}
	var file = FileAccess.open(target, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not validate(parsed):
		return {}
	return parsed

func load_slot(slot: int) -> bool:
	var data: Dictionary = read_slot(slot)
	if data.is_empty():
		last_error = "这份存档为空、损坏或版本不受支持。"
		return false
	GameState.restore(data.state)
	return true

func latest_slot() -> int:
	var latest: int = -1
	var time: float = -1.0
	for slot in range(3):
		var data: Dictionary = read_slot(slot)
		if not data.is_empty() and float(data.get("timestamp", 0)) > time:
			latest = slot
			time = float(data.timestamp)
	return latest

func save_settings() -> void:
	var config = ConfigFile.new()
	for key in GameState.settings:
		config.set_value("settings", key, GameState.settings[key])
	config.save(settings_path)
