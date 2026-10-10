extends Control
signal finished
var shown_stage: int = -1
var status: Label
var meter: ProgressBar
var marker: ColorRect
var next_button: TextureButton
var action_button: TextureButton
var fire_label: Label
const STAGES: Array[String] = ["鲜叶检查与摊放", "杀青", "揉捻", "干燥", "整理入库"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.changed.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	if GameState.changed.is_connected(_refresh):
		GameState.changed.disconnect(_refresh)

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	status = null
	meter = null
	marker = null
	next_button = null
	action_button = null
	fire_label = null

func _refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if GameState.batch.is_empty():
		finished.emit()
		return
	var stage: int = int(GameState.batch.stage)
	if stage != shown_stage:
		shown_stage = stage
		_build(stage)
	if stage < 3:
		var maximum: int = GameState.craft_maximum(stage)
		UiKit.set_text(status, "已完成 " + str(GameState.batch.count) + " / " + str(maximum) + " 次")
		action_button.disabled = int(GameState.batch.count) >= maximum
	elif stage == 3:
		var elapsed: float = float(GameState.batch.elapsed)
		UiKit.set_text(status, "已干燥 "+str(snappedf(elapsed,0.1))+" 秒\n"+str(GameState.batch_recipe().dry[0])+"—"+str(GameState.batch_recipe().dry[1])+"秒结束，可获得较好的游戏评价")
		meter.value = minf(elapsed / 12.0, 1.0)
	else:
		UiKit.set_text(status, str(GameState.batch_recipe().name)+" × "+str(GameState.batch.get("quantity",1))+"\n游戏品质："+GameState.QUALITIES[int(GameState.batch.quality)])
	if stage in [1, 2]:
		var value: float = GameState.heat() if stage == 1 else GameState.rhythm()
		marker.position.x = 376 + 378 * value
		if fire_label:
			UiKit.set_text(fire_label, "当前火力：" + ["轻火", "中火", "旺火"][int(GameState.batch.fire) - 1])
	if next_button:
		next_button.disabled = not GameState.can_advance_craft()

func _build(stage: int) -> void:
	_clear()
	UiKit.label(str(stage + 1) + " / 5  " + STAGES[stage], self, Rect2(195, 0, 660, 65), 36, true)
	var descriptions: Array[String] = [
		"观察鲜叶，将叶片轻轻摊开。\n按配方次数点击，让这一批鲜叶铺得更均匀。",
		"调整火力，在指针经过浅绿区时翻动。\n每次翻动间隔至少0.65秒；偏差只影响游戏品质。",
		"在指针进入浅绿区时轻轻揉捻。\n按配方要求完成揉捻，让叶片逐渐形成条索。",
		"观察叶片的变化，选择合适时机结束。\n这是一段压缩的游戏操作，并非真实制茶时长。",
		"这一炉新茶已经完成。\n收取后即可送到临水茶铺；品质评价仅用于游戏。"
	]
	UiKit.label(descriptions[stage], self, Rect2(230, 70, 750, 101), 25)
	var props: Array[String] = ["PRP_202", "PRP_203", "PRP_206", "PRP_207", "PRP_209"]
	var prop_width: float = minf(280.0,340.0/AssetLibrary.ratio(props[stage]))
	UiKit.prop(props[stage], self, Vector2(40+(280-prop_width)*0.5,175), prop_width)
	status = UiKit.label("", self, Rect2(370, 190, 585, 85), 28)
	if stage in [1, 2]:
		meter = UiKit.meter(self, Rect2(380, 294, 380, 22), 1.0, Color("#cfcec1"))
		var band = ColorRect.new()
		band.color = Color("#98b589")
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		UiKit.place(band, Rect2(520 if stage == 1 else 486, 294, 100 if stage == 1 else 168, 22))
		marker = ColorRect.new()
		marker.color = UiKit.INK
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		UiKit.place(marker, Rect2(560, 286, 7, 38))
		UiKit.label("等待指针进入浅绿区", self, Rect2(380, 326, 380, 38), 21)
	if stage == 1:
		fire_label = UiKit.label("", self, Rect2(370, 371, 585, 37), 22)
		for fire in range(1, 4):
			UiKit.button(["轻火", "中火", "旺火"][fire - 1], self, Rect2(365 + (fire - 1) * 195, 419, 181, 60), func(): GameState.set_fire(fire), false)
	if stage < 3:
		action_button = UiKit.button(["轻轻摊开", "翻动鲜叶", "轻轻揉捻"][stage], self, Rect2(350, 505, 285, 67), func(): GameState.craft_action())
		next_button = UiKit.button("下一工序", self, Rect2(670, 505, 285, 67), func(): GameState.advance_craft(), false)
	elif stage == 3:
		meter = UiKit.meter(self, Rect2(370, 315, 585, 25), 0)
		next_button = UiKit.button("结束干燥", self, Rect2(465, 505, 385, 67), func(): GameState.advance_craft())
	else:
		UiKit.button("收取新茶", self, Rect2(465, 505, 385, 67), func(): GameState.collect_batch(); finished.emit())
	UiKit.label("关闭面板会保留这批茶的进度，可稍后继续", self, Rect2(145, 590, 805, 38), 20)

func _process(_delta: float) -> void:
	if marker and not GameState.batch.is_empty() and shown_stage in [1, 2]:
		var value: float = GameState.heat() if shown_stage == 1 else GameState.rhythm()
		marker.position.x = 376 + 378 * value

