extends RefCounted
static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_rules.json"))
