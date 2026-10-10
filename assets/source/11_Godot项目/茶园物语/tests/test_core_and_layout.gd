extends Node
var root: Window
var passed: int = 0
var failed: Array[String] = []
var text_issues: Array[Dictionary] = []
var checked_labels: int = 0
var checked_frames: int = 0
var frame_issues: Array[Dictionary] = []
var game: Control
var mouse_notified: bool = false
var missing_glyphs: Dictionary = {}
var original_save_base: String
var report: Dictionary = {}

func _ready() -> void:
	root = get_tree().root
	call_deferred("_run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
	else:
		failed.append(title)
		push_error("CHECK FAILED: " + title)

func _write_json(path: String, data: Variant) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	original_save_base = SaveSystem.base_path
	SaveSystem.base_path = "user://verification_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	_core()
	await _interface()
	report = {"engine": Engine.get_version_info().string, "passed": passed, "failed": failed, "frame_checks":checked_frames,"frame_issues":frame_issues,"text_checks": checked_labels, "text_issues": text_issues, "missing_chinese_glyphs": missing_glyphs, "fonts": {"title": UiKit.title_font.get_font_name(), "body": UiKit.body_font.get_font_name()}, "test_save_directory": ProjectSettings.globalize_path(SaveSystem.base_path), "checked_at": Time.get_datetime_string_from_system()}
	_write_json("res://docs/验证报告.json", report)
	print("VERIFICATION: ", JSON.stringify(report))
	get_tree().quit(0 if failed.is_empty() and frame_issues.is_empty() and text_issues.is_empty() and missing_glyphs.is_empty() else 1)

func _core() -> void:
	GameState.reset()
	check(GameState.plots.size() == 3, "初始化三块茶田")
	check(not GameState.harvest(0), "未成熟茶田不能采摘")
	for index in range(3):
		check(GameState.plant(index), "种植茶田" + str(index))
	check(GameState.seeds == 0, "种植精确扣除3颗种子")
	check(not GameState.plant(0), "重复种植不扣资源")
	check(GameState.plot_state(0) == "seedling", "幼苗状态")
	GameState.paused = true
	GameState.advance_time(30)
	check(GameState.plots[0].age == 0, "暂停不增长")
	GameState.paused = false
	GameState.advance_time(12)
	check(GameState.plot_state(0) == "growing", "生长状态")
	check(GameState.fertilize(0), "肥料缩短本轮")
	check(not GameState.fertilize(0), "同轮不能重复施肥")
	check(GameState.fertilizer == 1, "肥料扣除一次")
	GameState.last_scene = "workshop"
	GameState.advance_time(12)
	check(GameState.plot_state(2) == "ready", "换场景保持成长")
	for index in range(3):
		check(GameState.harvest(index), "第一轮采摘" + str(index))
	check(GameState.fresh == 3 and GameState.total_harvested == 3, "第一轮鲜叶正确")
	check(not GameState.harvest(0), "重复采摘无额外奖励")
	check(GameState.plot_state(0) == "harvested" and GameState.plots[0].planted, "采摘保留茶树")
	GameState.advance_time(24)
	for index in range(3):
		check(GameState.harvest(index), "第二轮采摘" + str(index))
	check(GameState.fresh == 6 and GameState.seeds == 0, "第二轮持续生产无需种子")
	check(GameState.start_batch(), "新批次消耗鲜叶")
	check(GameState.fresh == 3 and not GameState.start_batch(), "不能重复启动同批")
	check(not GameState.advance_craft(), "未完成操作不能跳工序")
	for i in range(3):
		GameState.craft_action()
	check(GameState.advance_craft(), "摊放完成进入杀青")
	GameState.craft_action()
	check(not GameState.craft_action(), "翻叶节奏防连击")
	for i in range(1, 6):
		GameState.advance_time(PI / 0.9)
		GameState.craft_action()
	check(GameState.advance_craft(), "杀青完成进入揉捻")
	for i in range(4):
		if i > 0: GameState.advance_time(PI / 1.8)
		GameState.craft_action()
	check(GameState.advance_craft(), "揉捻完成进入干燥")
	check(not GameState.advance_craft(), "干燥需达到最低时间")
	GameState.advance_time(7)
	check(GameState.advance_craft(), "适时结束干燥")
	check(GameState.collect_batch(), "收取第一批茶")
	check(not GameState.collect_batch(), "同批茶不能重复收取")
	check(int(GameState.teas[2]) == 2, "合适工艺获得上佳2份")
	check(GameState.simplified_craft() and GameState.fresh == 0 and int(GameState.teas[1]) == 2, "体验后解锁简化加工")
	check(not GameState.simplified_craft(), "鲜叶不足时不加工")
	var before: int = GameState.copper
	check(GameState.serve(2) and GameState.copper == before + 24, "村民上茶扣茶并结算")
	check(GameState.customer_index == 1, "旅人接替接待位置")
	check(GameState.serve(2), "接待旅人")
	check(GameState.serve(1) and GameState.customer_index == 0, "第三位熟客后轮换")
	check(not GameState.serve(2), "无库存不能重复提交")
	check(GameState.purchase("upgrade"), "购买器具改善")
	before = GameState.copper
	check(not GameState.purchase("upgrade") and GameState.copper == before, "重复改善不扣铜钱")
	GameState.fresh = 3
	GameState.simplified_craft()
	check(GameState.tea_meeting(), "三次待客后筹办茶会")
	check(not GameState.tea_meeting(), "茶会奖励不能重复")
	check(GameState.copper >= 0 and GameState.fresh >= 0 and int(GameState.teas[1]) >= 0, "资源始终非负")
	GameState.last_scene = "garden"
	GameState.end_day()
	check(GameState.day == 2, "主动结束一天")
	GameState.batch = {"stage": 1, "elapsed": 2.5, "points": 3, "count": 2, "fire": 2, "last_action": 1.0, "quality": 0}
	var snapshot: Dictionary = GameState.snapshot()
	check(SaveSystem.write_slot(1), "手动保存")
	GameState.copper += 7
	check(SaveSystem.write_slot(1), "在Windows覆盖存档")
	check(int(SaveSystem.read_slot(1).state.copper) == int(snapshot.copper) + 7, "覆盖后记录更新")
	GameState.reset()
	check(SaveSystem.load_slot(1), "恢复存档")
	check(GameState.batch.stage == 1 and GameState.batch.count == 2 and GameState.day == 2 and GameState.last_scene == "garden", "工艺、日数、场景完整恢复")
	var valid: Dictionary = SaveSystem.read_slot(1)
	var invalid: Dictionary = valid.duplicate(true)
	invalid.version = 999
	check(not SaveSystem.validate(invalid), "拒绝不支持版本")
	invalid = valid.duplicate(true)
	invalid.state.copper = -1
	check(not SaveSystem.validate(invalid), "拒绝负资源")
	invalid = valid.duplicate(true)
	invalid.state.plots[0].planted = "true"
	check(not SaveSystem.validate(invalid), "拒绝错误布尔字段")
	invalid = valid.duplicate(true)
	invalid.state.copper = 0.5
	check(not SaveSystem.validate(invalid), "拒绝小数资源")
	invalid = valid.duplicate(true)
	invalid.state.batch.elapsed = "invalid"
	check(not SaveSystem.validate(invalid), "拒绝错误工艺字段")
	before = GameState.copper
	_write_json(SaveSystem.slot_path(2), invalid)
	check(not SaveSystem.load_slot(2) and GameState.copper == before, "坏档不改变当前游戏")
	check(SaveSystem.latest_slot() == 1, "继续游戏只选择有效存档")
	GameState.reset()
	GameState.unlock("welcome")

func _interface() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await get_tree().process_frame
	await _audit("主页")
	for destination in ["village", "garden", "workshop", "teashop"]:
		SceneRouter.go(destination, false)
		await get_tree().process_frame
		await _audit(destination)
	check(GameState.last_scene == "teashop", "实际场景导航正常")
	SceneRouter.go("garden", false)
	await get_tree().process_frame
	game.modals.open("plant", {"plot": 0})
	await get_tree().process_frame
	check(GameState.paused, "种植确认暂停背景计时")
	_click_at(Vector2(560, 235))
	check(GameState.seeds == 3, "弹窗遮挡阻止点击背景茶田")
	_click_caption("确认种植")
	await get_tree().process_frame
	check(GameState.plots[0].planted and GameState.seeds == 2, "界面按钮可种植指定茶田")
	game.modals.close()
	GameState.fresh = 3
	GameState.teas = [2, 2, 2]
	GameState.unlock("crafted")
	GameState.unlock("harvested")
	GameState.unlock("spread")
	GameState.unlock("served")
	GameState.changed.emit()
	for kind in ["welcome", "plant", "seeds", "inventory", "basket", "fertilizer", "manual", "recipe", "tools", "order", "shop", "journal", "settings", "saves", "confirm", "info"]:
		var data: Dictionary = {"plot": 1, "title": "操作确认", "text": "确认后会消耗对应材料，并保留其它进度。\n文字须在文本框内完整、居中显示。", "mode": "save"}
		game.modals.open(kind, data)
		await get_tree().process_frame
		await _audit(kind)
	game.modals.open("saves", {"mode": "load", "selected": 1})
	await get_tree().process_frame
	await _audit("读档")
	for index in range(3):
		GameState.customer_index = index
		game.modals.open("order")
		await get_tree().process_frame
		await _audit("顾客" + str(index))
	check(SaveSystem.write_slot(1), "界面测试进度保存")
	GameState.batch = {}
	check(GameState.start_batch(), "界面配方启动")
	for stage in range(5):
		GameState.batch.stage = stage
		GameState.batch.elapsed = 7.0
		GameState.batch.count = 0
		game.modals.open("processing")
		await get_tree().process_frame
		await _audit("工序" + str(stage))
	check(not GameState.paused, "工艺操作时计时继续")
	game.modals.open("inventory")
	check(GameState.paused, "背包打开计时暂停")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await get_tree().process_frame
	check(not game.modals.visible and not GameState.paused, "Esc关闭面板并恢复计时")
	for state in ["seedling", "growing", "ready", "harvested"]:
		GameState.plots[0].age = {"seedling": 0.0, "growing": 12.0, "ready": 24.0, "harvested": 0.0}[state]
		GameState.plots[0].harvested = state == "harvested"
		GameState.changed.emit()
		await get_tree().process_frame
		await _audit("茶树" + state)
	check(UiKit.title_font.resource_path == "res://fonts/Title_TangXianBinSong.otf", "标题字体路径正确")
	check(UiKit.body_font.resource_path == "res://fonts/User_Body.ttf", "正文采用第二款字体")
	SceneRouter.go("home", false)
	await get_tree().process_frame
	check(GameState.in_menu and SaveSystem.read_slot(0).state.last_scene == "garden", "主页冻结成长并保留场景自动存档")
	var loading_target: String = "workshop"
	SceneRouter.go(loading_target, true)
	while SceneRouter.transitioning:
		await get_tree().process_frame
	check(SceneRouter.current == loading_target, "真实载入过场完成场景导航")
	await _audit("载入后的工坊")
	game.modals.close()
	SceneRouter.go("workshop",false)
	await get_tree().process_frame
	for pair in [["FGU_W1","spread"],["FGU_W2","drying"],["FGU_W3","fixation"],["FGU_W4","rolling"],["FGU_W5","sorting"]]:
		var hit: BaseButton
		for candidate in get_tree().get_nodes_in_group("scene_icon_clicks"):
			if candidate.get_meta("badge_id") == pair[0]:
				hit = candidate
		if hit != null:
			_click_at(hit.get_global_rect().get_center())
			await get_tree().process_frame
			check(game.modals.current_kind == "craft_guide" and game.modals.current_data.get("step") == pair[1],"工序图标实际点击 "+pair[0])
			await _audit("工序详解 "+pair[1])
			game.modals.close()
		else:
			check(false,"缺少工序图标 "+pair[0])
	check(UiKit.game_theme.get_stylebox("panel","TooltipPanel") is StyleBoxTexture,"提示框使用image2底板")
	game.loading_layer.visible = true
	game._set_progress(0.65)
	check(is_equal_approx(game.loading_fill.size.x,438.0*0.65),"载入65%使用真实进度条")
	game.loading_layer.visible = false
	for dimensions in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		await get_tree().process_frame
		game.modals.open("inventory")
		await _audit("窗口" + str(dimensions))
		_click_caption("关闭")
		await get_tree().process_frame
		check(not game.modals.visible, "窗口变化后关闭按钮可点击" + str(dimensions))
	game.queue_free()
	await get_tree().process_frame

func _click_caption(caption: String) -> void:
	for label in get_tree().get_nodes_in_group("game_text"):
		if label.text == caption and label.is_visible_in_tree() and label.get_parent() is BaseButton:
			_click_at(label.get_parent().get_global_rect().get_center())
			return
	check(false, "未找到可用按钮：" + caption)

func _click_at(point: Vector2) -> void:
	if not mouse_notified:
		root.notify_mouse_entered()
		mouse_notified = true
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)

func _audit(screen: String) -> void:
	await get_tree().process_frame
	for frame in get_tree().get_nodes_in_group("paper_frames"):
		if not frame.is_visible_in_tree():
			continue
		checked_frames += 1
		var style = frame.get_theme_stylebox("panel")
		if style is StyleBoxTexture and (frame.size.x<style.texture_margin_left+style.texture_margin_right or frame.size.y<style.texture_margin_top+style.texture_margin_bottom):
			frame_issues.append({"screen":screen,"rect":str(frame.get_global_rect()),"reason":"切片边缘超过底板尺寸"})
	for label in get_tree().get_nodes_in_group("game_text"):
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		checked_labels += 1
		for character in label.text:
			var unicode: int = character.unicode_at(0)
			if unicode >= 0x3400 and unicode <= 0x9fff and not label.get_theme_font("font").has_char(unicode):
				missing_glyphs[character] = label.get_theme_font("font").get_font_name()
		var rect: Rect2 = label.get_meta("box")
		var font_size: int = label.get_theme_font_size("font_size")
		var measured: Vector2 = label.get_theme_font("font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, font_size)
		var actual_height: float = label.get_line_count() * label.get_line_height()
		var reason: String = ""
		if label.text.contains("\\n"):
			text_issues.append({"screen":screen,"text":label.text,"reason":"出现字面量反斜杠n"})
		if label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
			reason = "未居中"
		elif measured.x > rect.size.x + 1 or measured.y > rect.size.y + 1 or actual_height > rect.size.y + 2:
			reason = "文本超出边界"
		elif not Rect2(0, 0, 1920, 1080).encloses(label.get_global_rect()):
			reason = "文本框超出画布"
		for character_art in get_tree().get_nodes_in_group("illustration_art"):
			var label_in_modal: bool = game.modals.is_ancestor_of(label)
			var character_in_modal: bool = game.modals.is_ancestor_of(character_art)
			if label_in_modal != character_in_modal or (game.modals.visible and not label_in_modal):
				continue
			var ink_rect := Rect2(label.get_global_rect().position + (label.size-measured)*0.5, measured)
			if character_art.is_visible_in_tree() and ink_rect.intersects(character_art.get_global_rect()):
				var overlap: Rect2 = ink_rect.intersection(character_art.get_global_rect())
				if overlap.size.x>2 and overlap.size.y>2:
					reason = "文本覆盖人物或插图 "+str(character_art.get_meta("asset_id"))
		if not reason.is_empty():
			text_issues.append({"screen": screen, "text": label.text, "reason": reason, "box": str(rect), "actual": str(label.size), "measured": str(measured), "lines_height": actual_height, "font_size": font_size})
