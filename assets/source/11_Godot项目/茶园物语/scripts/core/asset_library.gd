extends Node

var catalog: Dictionary = {}
var raw_cache: Dictionary = {}
var region_cache: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://data/asset_catalog.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			catalog = parsed

func texture(id: String, crop: bool = true) -> Texture2D:
	var cache: Dictionary = region_cache if crop else raw_cache
	if cache.has(id):
		return cache[id]
	var entry: Dictionary = catalog.get(id, {})
	if entry.is_empty():
		push_error("素材编号不存在：" + id)
		return null
	var source: Texture2D
	if raw_cache.has(id):
		source = raw_cache[id]
	else:
		source = load(entry.path)
		raw_cache[id] = source
	if not crop:
		return source
	var bounds: Array = entry.bbox
	var atlas = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2] - bounds[0] + 1), float(bounds[3] - bounds[1] + 1))
	atlas.filter_clip = true
	region_cache[id] = atlas
	return atlas

func ratio(id: String) -> float:
	var entry: Dictionary = catalog.get(id, {})
	if entry.is_empty():
		return 1.0
	var bounds: Array = entry.bbox
	return float(bounds[3] - bounds[1] + 1) / float(bounds[2] - bounds[0] + 1)
