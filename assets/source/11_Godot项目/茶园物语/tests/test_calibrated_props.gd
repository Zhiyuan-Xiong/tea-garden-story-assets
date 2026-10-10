extends Node
func _ready() -> void:
	var file = FileAccess.open("res://docs/第一轮调整/可拖入的分件清单.json",FileAccess.READ)
	var items: Array = JSON.parse_string(file.get_as_text())
	var issues: Array[String] = []
	for item in items:
		var packed: PackedScene = load(item.path)
		if not packed:
			issues.append(item.id+" 分件载入失败")
			continue
		var prop: Node2D = packed.instantiate()
		var image: TextureRect = prop.get_child(0)
		var center = Vector2.ZERO
		for foot in SceneLayout.FOOTPRINTS[item.id]:
			center += prop.transform*(image.position+foot*image.size)
		center /= 4.0
		if center.length() > 1.0:
			issues.append(item.id+" 落地点中心偏移")
		if image.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			issues.append(item.id+" 缩小过滤配置不一致")
		prop.free()
	print("CALIBRATED_PREFABS: ",items.size()," issues=",issues)
	get_tree().quit(0 if issues.is_empty() else 1)
