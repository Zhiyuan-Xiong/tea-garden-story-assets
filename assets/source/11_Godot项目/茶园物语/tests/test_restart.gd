extends Node
func _ready() -> void:
	GameState.set_process(false)
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/验证报告.json"))
	if not report is Dictionary or not report.has("test_save_directory"):
		push_error("缺少上次验证的隔离存档目录。")
		get_tree().quit(1)
		return
	SaveSystem.base_path = str(report.test_save_directory)
	var saved: Dictionary = SaveSystem.read_slot(1)
	GameState.reset(false)
	var ok: bool = not saved.is_empty() and SaveSystem.load_slot(1)
	if ok:
		var restored: Dictionary = GameState.snapshot()
		for key in restored:
			if key in ["day", "copper", "seeds", "fresh", "fertilizer", "teas", "plots", "batch", "milestones", "served", "customer_index", "upgraded", "chapter", "last_scene", "total_harvested", "total_crafted", "play_seconds"]:
				if restored[key] != saved.state[key]:
					ok = false
					push_error("重启恢复字段不同：" + str(key))
	var result: Dictionary = {"passed": ok, "saved_scene": GameState.last_scene, "saved_day": GameState.day, "engine": Engine.get_version_info().string, "checked_at": Time.get_datetime_string_from_system(), "isolated_from_player_saves": true}
	var file = FileAccess.open("res://docs/重启读档验证.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RESTART VERIFICATION: ", JSON.stringify(result))
	get_tree().quit(0 if ok else 1)
