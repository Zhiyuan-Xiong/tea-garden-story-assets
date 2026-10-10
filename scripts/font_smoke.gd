extends SceneTree

func _initialize() -> void:
	call_deferred("_check_public_fonts")

func _check_public_fonts() -> void:
	var body: Font = load("res://fonts/Body_NotoSansSC.tres")
	var title: Font = load("res://fonts/Title_NotoSansSC.tres")
	var sample := "茶园物语云雾茶园制茶工坊临水茶铺今日待办可采摘库存设置职业成长五日经营ABCxyz0123456789，。！？（）"
	var missing: Array[String] = []
	for character in sample:
		if not body.has_char(character.unicode_at(0)) or not title.has_char(character.unicode_at(0)):
			missing.append(character)
	var report := {"font": "Noto Sans SC", "body_weight": body.variation_opentype.get("wght"), "title_weight": title.variation_opentype.get("wght"), "sample_characters_checked": sample.length(), "missing": missing, "passed": missing.is_empty()}
	print(JSON.stringify(report))
	quit(0 if missing.is_empty() else 1)
