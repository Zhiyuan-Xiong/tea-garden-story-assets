extends Control

var frame: Panel
var content: Control
var heading: Label
var guide: Label
var guide_status: Label
var rows: Array[Dictionary] = []
var finish: TextureButton
var folded: bool = false

func _ready() -> void:
	name = "DailyTodoSidebar"
	add_to_group("daily_todo_sidebars")
	z_index = 15
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self,Rect2(20,130,236,474))
	frame = UiKit.flat_card(self,Rect2(0,0,236,474))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	heading = UiKit.label("",self,Rect2(13,12,182,34),23,true)
	var fold := Button.new()
	fold.name = "FoldTodo"
	fold.flat = true
	fold.text = "−"
	fold.add_theme_font_override("font",UiKit.body_font)
	fold.add_theme_font_size_override("font_size",24)
	fold.add_theme_color_override("font_color",UiKit.INK)
	fold.tooltip_text = "收起 / 展开待办事项"
	add_child(fold)
	UiKit.place(fold,Rect2(199,13,26,32))
	fold.pressed.connect(func():
		folded = not folded
		fold.text = "+" if folded else "−"
		content.visible = not folded
		frame.size.y = 58 if folded else 474
		size.y = frame.size.y)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	guide = UiKit.label("",content,Rect2(17,54,202,62),20)
	guide_status = UiKit.label("",content,Rect2(17,118,202,25),18,false,UiKit.MUTED)
	for i in range(4):
		var y: float = 150 + i*48
		var icon: TextureRect = UiKit.art(["ICO_103","ICO_201","ICO_457","ICO_456"][i],content,Rect2(17,y+4,25,25))
		var caption := UiKit.label("",content,Rect2(49,y,171,32),20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var progress := UiKit.meter(content,Rect2(49,y+34,167,5),0)
		rows.append({"caption":caption,"progress":progress,"icon":icon})
	_small_button("任务",Rect2(14,354,102,46),func():SceneRouter.modal("tasks"))
	_small_button("成长",Rect2(120,354,102,46),func():SceneRouter.modal("growth"))
	finish = _small_button("结束一天",Rect2(14,412,208,47),func():SceneRouter.modal("end_day"))
	GameState.changed.connect(refresh)
	refresh()

func _small_button(text: String, box: Rect2, action: Callable) -> TextureButton:
	var button := UiKit.button(text,content,box,action,false)
	var caption: Label = button.get_meta("caption")
	var bounds := Rect2(12,6,box.size.x-24,box.size.y-12)
	caption.set_meta("box",bounds)
	caption.set_meta("requested_size",21)
	caption.custom_maximum_size = bounds.size
	UiKit.place(caption,bounds)
	UiKit.set_text(caption,text)
	return button

func _text(label: Label, value: String) -> void:
	if label.text != value: UiKit.set_text(label,value)

func refresh() -> void:
	if not is_inside_tree(): return
	visible = true
	for editor in get_tree().get_nodes_in_group("furniture_editors"):
		if get_parent().is_ancestor_of(editor) and editor.enabled: visible = false
	_text(heading,"今日待办 · 第"+str(GameState.day)+"日")
	var completed: bool = GameState.guide_complete()
	var guides: Array[String] = ["完成一次采茶\n制茶与售卖","在新开放的第二层\n种下一株茶树","制作一批\n良好及以上的新茶","精准完成\n一笔茶客订单","新茶试饮\n接待3位茶客","自由经营\n提升手艺、学习新茶"]
	_text(guide,guides[mini(GameState.day-1,5)] if GameState.settings.show_hints else "每日任务可自由选择\n完成后自动领取奖励")
	_text(guide_status,"引导完成 · 可结束一天" if completed else "今日引导 · 待完成")
	guide_status.add_theme_color_override("font_color",Color("#527449") if completed else UiKit.MUTED)
	var rule: Dictionary = GameState.daily_rule()
	for i in range(4):
		var target: int = int(rule.targets[i])
		var amount: int = mini(int(GameState.daily.counts[i]),target)
		_text(rows[i].caption,["采茶","制茶","售卖","精准待客"][i]+"  "+str(amount)+" / "+str(target))
		rows[i].caption.add_theme_color_override("font_color",Color("#527449") if amount==target else UiKit.INK)
		rows[i].caption.tooltip_text = "已完成 · 奖励已领取" if GameState.daily.claimed[i] else "完成后自动领取经验奖励"
		rows[i].progress.value = float(amount)/target
	finish.disabled = not completed
	finish.tooltip_text = "结束一天并查看经营成果" if completed else "先完成一次今日引导，其他任务可以自由选择"

func _exit_tree() -> void:
	if GameState.changed.is_connected(refresh): GameState.changed.disconnect(refresh)
