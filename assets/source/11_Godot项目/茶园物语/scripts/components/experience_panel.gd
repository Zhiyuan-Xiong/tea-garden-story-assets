extends Control
# Native Godot text and controls; illustrations never carry dynamic game numbers.
var host: Control
var mode: String
var data: Dictionary
var bindings: Array[Callable] = []
var selected_recipe: String = "spring"
var quantity: int = 1
var quality: int = 0
var tutorial_seen: bool = false

func setup(manager: Control, kind: String, payload: Dictionary) -> void:
	host = manager
	mode = kind
	data = payload
	selected_recipe = str(data.get("recipe","spring"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.changed.connect(_refresh)

func _exit_tree() -> void:
	if GameState.changed.is_connected(_refresh): GameState.changed.disconnect(_refresh)

func _refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	for update in bindings: update.call()

func _build() -> void:
	bindings.clear()
	for child in get_children(): remove_child(child); child.queue_free()
	match mode:
		"tasks": _tasks()
		"growth": _growth()
		"recipe": _recipes()
		"order": _order()
		"shop": _shop()
		"end_day": _end_day()
		"summary": _summary()
		"seeds", "fertilizer": _plots()
		"inventory": _inventory()
		"plant": _plant()

func text(value: String, box: Rect2, size: int = 24, title: bool = false) -> Label:
	return UiKit.label(value,self,box,size,title)

func bound(read: Callable, box: Rect2, size: int = 24) -> Label:
	var label := text(str(read.call()),box,size)
	bindings.append(func(): UiKit.set_text(label,str(read.call())))
	return label

func button(value: String, box: Rect2, action: Callable, enabled: bool = true) -> TextureButton:
	var node := UiKit.button(value,self,box,action)
	node.disabled = not enabled
	return node

func card(box: Rect2) -> void:
	UiKit.flat_card(self,box).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _tasks() -> void:
	text("第"+str(GameState.day)+"日 · 每日任务可自由选择，奖励完成后自动领取",Rect2(470,253,980,50),25)
	var names: Array = ["成功采茶","成功制茶","完成售卖","精准订单"]
	var unit: Array = ["次","批","笔","笔"]
	var rules: Dictionary = GameState.daily_rule()
	for i in range(4):
		var task: Control = preload("res://scripts/components/daily_task_card.gd").new()
		add_child(task)
		task.position = Vector2(475+(i%2)*490,320+(i/2)*195)
		task.setup(i,str(names[i]),str(unit[i]),int(rules.targets[i]),int(rules.rewards[i]))
	bound(func(): return "全完成奖励：经验＋40 · 肥料×1"+(" · 已领取" if GameState.daily.bonus else " · 未领取")+"\n累计完成每日任务："+str(GameState.completed_tasks)+"项",Rect2(485,724,960,83),24)
	button("职业、配方与成就",Rect2(490,842,340,65),func(): host.open("growth"))
	button("结束一天",Rect2(1100,842,320,65),func(): host.open("end_day"))
	if GameState.day>=5:
		text("自选挑战：制作一批上佳茶（＋20经验），不影响四项全完成奖励",Rect2(490,810,940,28),19)
		button("领取自选挑战",Rect2(860,842,215,65),func(): GameState.optional_challenge(); _build(),int(GameState.daily.get("best",0))>=1 and not GameState.daily.optional_claimed)

func _growth() -> void:
	var next_tier: String = "五层全部开放 · 14个种植位" if GameState.day>=5 else "下一层：第"+str(GameState.day+1)+"日自动开放，赠送基础材料×"+str(GameState.RULES.terrace_slots[GameState.day])
	text(next_tier,Rect2(475,248,970,45),25,true)
	card(Rect2(475,310,465,233))
	text("职业成长",Rect2(490,322,435,45),27,true)
	bound(func(): return GameState.RULES.professions[GameState.profession].name+" · 累计经验 "+str(GameState.experience),Rect2(490,371,435,39),23)
	if GameState.profession<4:
		var next: Dictionary = GameState.RULES.professions[GameState.profession+1]
		bound(func(): return "下一称号："+str(next.name)+"\n经验："+str(GameState.experience)+" / "+str(next.xp)+"\n实践："+str(next.practice)+"（"+str(GameState.get(str(next.counter)))+" / "+str(next.count)+"）",Rect2(490,411,435,116),22)
	else: text("主题茶会已开放\n大师题签与陈设可用于茶铺布置",Rect2(490,420,435,98),23)
	card(Rect2(975,310,465,233))
	text("新茶配方",Rect2(990,322,435,45),27,true)
	var upcoming: Dictionary = {}
	for recipe in GameState.RULES.recipes:
		if not GameState.unlocked_recipes.has(recipe.id): upcoming = recipe; break
	if not upcoming.is_empty():
		text(str(upcoming.name)+"\n职业："+str(GameState.RULES.professions[int(upcoming.rank)].name)+"\n累计任务："+str(GameState.completed_tasks)+" / "+str(upcoming.tasks)+"项\n两项达成后自动解锁",Rect2(990,373,435,148),23)
	else: text("五款新茶全部解锁\n继续练习手工品质与精品待客",Rect2(990,389,435,112),25)
	text("永久成就 · 奖励只领取一次",Rect2(475,553,970,44),26,true)
	for i in range(8):
		var record: Dictionary = GameState.RULES.achievements[i]
		var col: int = i%2
		var y: int = 603+(i/2)*56
		card(Rect2(475+col*500,y,465,50))
		text(("✓ " if GameState.claimed_achievements.has(record.id) else "○ ")+str(record.name)+" · "+str(record.reward),Rect2(485+col*500,y+4,445,42),20)
	button("每日任务",Rect2(540,857,310,63),func(): host.open("tasks"))
	button("学习新茶",Rect2(1070,857,310,63),func(): host.open("recipe"))

func _recipes() -> void:
	text("种植原料与制茶配方分别设置；任意开放梯田均可种基础茶树",Rect2(475,252,965,46),23)
	for i in range(5):
		var recipe: Dictionary = GameState.RULES.recipes[i]
		var available: bool = GameState.unlocked_recipes.has(recipe.id)
		card(Rect2(475,319+i*101,350,90))
		button(str(recipe.name)+( " · 已开放" if available else " · 待学习"),Rect2(484,330+i*101,332,63),func(): selected_recipe=str(recipe.id); quantity=1; tutorial_seen=false; _build())
	var chosen: Dictionary = GameState.recipe_data(selected_recipe)
	var open: bool = GameState.unlocked_recipes.has(selected_recipe)
	text(str(chosen.name),Rect2(863,322,570,52),32,true)
	if not open:
		text("职业要求："+str(GameState.RULES.professions[int(chosen.rank)].name)+"\n累计每日任务："+str(GameState.completed_tasks)+" / "+str(chosen.tasks)+"\n\n两项同时达成后自动开放配方。",Rect2(855,390,580,240),27)
		return
	text(str(chosen.method)+"\n\n用途："+str(chosen.use)+"\n熟练度：已完成 "+str(GameState.recipe_mastery.get(selected_recipe,0))+"批",Rect2(855,388,580,203),25)
	bound(func(): return "鲜叶："+str(GameState.fresh)+"份 · 背包："+str(GameState.stock_total())+" / "+str(GameState.bag_capacity),Rect2(853,599,585,43),23)
	var learned: bool = GameState.recipe_taught.has(selected_recipe)
	text("首次制作教学：先读配方，操作偏差只影响品质，原料不会整批丢失。" if not learned else "手工制茶可追求上佳品质；中级且熟练3批后可批量简化加工。",Rect2(855,653,580,87),23)
	var count: SpinBox = _spin(Rect2(1015,751,160,52),1,5,quantity)
	count.editable = GameState.can_simplify(selected_recipe)
	count.value_changed.connect(func(value: float): quantity=int(value))
	text("加工份数",Rect2(853,757,160,40),23)
	button("继续制作" if not GameState.batch.is_empty() else ("查看首次教学" if not learned else "手工开始"),Rect2(855,843,290,67),func():
		if not GameState.batch.is_empty(): host.open("processing")
		elif not learned and not tutorial_seen:
			tutorial_seen=true
			host.open("confirm",{"title":str(chosen.name)+" · 首次教学","text":str(chosen.method)+"\n\n每次翻炒或揉捻间隔0.65秒。完成工序后进入下一步，最后收取入库。\n首次教学范围较宽，至少获得良好品质。","action":"start_recipe","recipe":selected_recipe,"quantity":quantity})
		elif GameState.start_batch(selected_recipe,quantity): host.open("processing"))
	button("熟练批量加工",Rect2(1160,843,275,67),func(): GameState.simplified_craft(selected_recipe,quantity); _build(),GameState.can_simplify(selected_recipe) and GameState.batch.is_empty())

func _spin(rect: Rect2, minimum: int, maximum: int, value: int) -> SpinBox:
	var node := SpinBox.new()
	node.min_value=minimum
	node.max_value=maximum
	node.step=1
	node.value=value
	add_child(node)
	UiKit.place(node,rect)
	var field: LineEdit=node.get_line_edit()
	field.add_theme_stylebox_override("normal",UiKit.paper_style(8,true))
	field.add_theme_stylebox_override("focus",UiKit.paper_style(8,true))
	field.add_theme_color_override("font_color",UiKit.INK)
	field.add_theme_font_size_override("font_size",24)
	return node

func _order() -> void:
	var order: Dictionary=GameState.current_order.duplicate(true)
	selected_recipe=str(order.recipe)
	quantity=int(order.quantity)
	quality=int(order.quality)
	UiKit.prop(GameState.Orders.PROFILES[GameState.customer_index].portrait,self,Vector2(485,340),180)
	card(Rect2(735,282,700,236))
	text(str(GameState.Orders.PROFILES[GameState.customer_index].name),Rect2(760,295,650,49),28,true)
	text(GameState.recipe_data(selected_recipe).name+" × "+str(quantity)+"\n最低品质："+GameState.QUALITIES[quality]+"及以上\n基础收入："+str(order.income)+"铜钱\n精准奖励：＋"+str(order.bonus)+"铜钱、＋5经验",Rect2(760,350,650,151),27)
	text("茶客没有等待期限，未完成订单可以保留或更换",Rect2(480,548,960,45),23)
	for i in range(3):
		card(Rect2(730+i*238,607,222,130))
		bound(func(): return GameState.QUALITIES[i]+"\n库存 × "+str(GameState.tea_inventory[selected_recipe][i]),Rect2(741+i*238,614,200,57),23)
		button("选择此品质",Rect2(741+i*238,675,200,49),func(): quality=i; _refresh())
	text("交付数量",Rect2(733,758,165,45),23)
	var spin:=_spin(Rect2(905,756,140,49),1,5,quantity)
	spin.value_changed.connect(func(value:float):quantity=int(value);_refresh())
	bound(func():return "已选品质："+GameState.QUALITIES[quality]+" · "+GameState.check_delivery(selected_recipe,quality,quantity),Rect2(735,811,700,53),21)
	button("更换基础订单",Rect2(490,868,300,62),func():GameState.swap_order();_build())
	button("核对并交付",Rect2(1085,868,350,62),func():
		if GameState.deliver(selected_recipe,quality,quantity):
			if GameState.day==5 and GameState.tasting_guests>=3 and not GameState.five_day_reviewed: host.open("summary")
			else: _build()
		else: GameState.notice.emit(GameState.check_delivery(selected_recipe,quality,quantity)))
	if GameState.day==5: bound(func():return "新茶试饮："+str(GameState.tasting_guests)+" / 3位",Rect2(477,813,225,43),23)

func _shop() -> void:
	bound(func():return "铜钱："+str(GameState.copper)+" · 职业："+str(GameState.RULES.professions[GameState.profession].name),Rect2(475,251,965,44),25)
	var products: Array = [["基础茶树材料","5铜钱 · 种一株茶树","seed",true],["肥料×1","6铜钱 · 剩余时间减半","fertilizer",true],["制茶器具升级","36铜钱 · 中级开放","upgrade",GameState.profession>=2 and not GameState.upgraded],["品质工具","80铜钱 · 高级开放","quality_tool",GameState.profession>=3 and not GameState.quality_tool],["扩充茶篓","30铜钱 · 容量＋15","basket",true],["扩充背包","30铜钱 · 容量＋15","bag",true]]
	for i in range(6):
		var product: Array=products[i]
		var x: int=475+(i%3)*326
		var y: int=320+(i/3)*210
		card(Rect2(x,y,305,190))
		text(str(product[0]),Rect2(x+12,y+15,281,42),26,true)
		text(str(product[1]),Rect2(x+12,y+63,281,45),22)
		button("添置",Rect2(x+20,y+119,265,56),func():GameState.purchase(str(product[2]));_build(),bool(product[3]))
	text("国风陈设：清雅茶桌24铜钱；大师解锁主题茶会（3份茶＋20铜钱）",Rect2(475,765,970,63),23)
	button("添置清雅茶桌",Rect2(490,850,305,66),func():GameState.purchase("decor");_build(),not GameState.decorations.has("清雅茶桌"))
	button("主题茶会",Rect2(1110,850,310,66),func():
		if GameState.tea_meeting():host.open("info",{"title":"匠心待客","text":"茶村的朋友齐聚茶铺，共品新茶。\n专属成就徽章已保存。\n\n之后仍可继续精品待客、追求上佳品质。"}),GameState.profession>=4 and GameState.meetings==0)

func _end_day() -> void:
	text("第"+str(GameState.day)+"日经营成果",Rect2(475,273,970,54),32,true)
	text("采摘 "+str(GameState.daily.counts[0])+"次 · 制茶 "+str(GameState.daily.counts[1])+"批\n售卖 "+str(GameState.daily.counts[2])+"笔 · 精准 "+str(GameState.daily.counts[3])+"笔\n售茶收入 "+str(GameState.daily.coins)+"铜钱",Rect2(475,342,970,132),29)
	var unfinished: Array=[]
	var names: Array=["采茶","制茶","售卖","精准订单"]
	for i in range(4):
		if not GameState.daily.claimed[i]:unfinished.append(str(names[i])+" "+str(GameState.daily.counts[i])+" / "+str(GameState.daily_rule().targets[i]))
	text("未完成任务："+("无" if unfinished.is_empty() else "、".join(unfinished))+"\n任务可自由选择，不影响进入下一日。",Rect2(485,498,950,113),25)
	text(("✓ 引导完成：" if GameState.guide_complete() else "请先完成引导：")+GameState.guide_text()+"\n鲜叶、成熟嫩芽、茶树、制茶进度、经验与成就全部保留。",Rect2(485,631,950,111),26)
	button("继续经营",Rect2(570,826,320,73),host.close)
	button("确认结束一天",Rect2(1030,826,355,73),func():
		if GameState.day==5 and not GameState.five_day_reviewed: host.open("summary")
		elif GameState.end_day(): host.close(),GameState.guide_complete())

func _summary() -> void:
	text("五日新茶 · 第一段旅程完成",Rect2(480,265,960,68),34,true)
	text("五层梯田全部开放，14个种植位可持续生产。\n职业："+str(GameState.RULES.professions[GameState.profession].name)+" · 累计经验 "+str(GameState.experience)+"\n已学习新茶："+str(GameState.unlocked_recipes.size())+"款\n累计接待："+str(GameState.served)+"位 · 精准订单 "+str(GameState.precise_orders)+"笔\n第五日试饮："+str(GameState.tasting_guests)+" / 3位\n\n五日新茶纪念陈设与剧情手记已收入记录。\n接下来可继续提升职业、学习配方、完成精品订单，\n成为大师后筹办主题茶会。",Rect2(495,358,930,412),29)
	button("进入自由经营",Rect2(780,835,370,76),func():
		GameState.five_day_reviewed=true
		GameState.complete_action("five_day_review")
		if GameState.day==5:GameState.end_day()
		host.close(),GameState.tasting_guests>=3)

func _plots() -> void:
	bound(func():return ("基础种植材料："+str(GameState.seeds)+"份" if mode=="seeds" else "肥料："+str(GameState.fertilizer)+"份 · 每轮最多施肥一次"),Rect2(475,251,970,53),26)
	for i in range(14):
		var col: int=i%3
		var row: int=i/3
		var rect:=Rect2(477+col*327,327+row*103,306,86)
		var state: String=GameState.plot_state(i)
		var title: String="第"+str(GameState.tier_of(i)+1)+"层 · "+str(i+1)+"号"
		var available: bool=state=="empty" if mode=="seeds" else state in ["seedling","growing","harvested"] and not GameState.plots[i].fertilized and GameState.fertilizer>0
		button(title+"\n"+({"empty":"可种植","locked":"第"+str(GameState.tier_of(i)+1)+"日开放","ready":"已成熟","seedling":"幼苗","growing":"生长中","harvested":"再生长"}[state]),rect,func():
			if mode=="seeds":host.open("plant",{"plot":i})
			else:GameState.fertilize(i);_build(),available)
	text("种植位置固定在每块区域中心；跨日、切换场景均保留生产进度。",Rect2(477,866,970,52),23)

func _plant() -> void:
	var index: int=int(data.get("plot",0))
	UiKit.prop("PRP_102",self,Vector2(840,283),240)
	text("基础茶树材料 × "+str(GameState.seeds)+"\n第"+str(GameState.tier_of(index)+1)+"层 · "+str(index+1)+"号种植区\n消耗1份材料，茶树根部固定在椭圆区域中心。\n首轮8秒成熟，采摘后每55秒再次生长。",Rect2(525,603,870,165),27)
	button("确认种植",Rect2(790,834,340,72),func():if GameState.plant(index):host.close(),GameState.is_plot_open(index) and not GameState.plots[index].planted and GameState.seeds>0)

func _inventory() -> void:
	bound(func():return "基础材料 "+str(GameState.seeds)+" · 鲜叶 "+str(GameState.fresh)+" / "+str(GameState.basket_capacity)+" · 肥料 "+str(GameState.fertilizer)+"\n成品背包："+str(GameState.stock_total())+" / "+str(GameState.bag_capacity)+"份",Rect2(475,253,970,84),25)
	for i in range(5):
		var recipe: Dictionary=GameState.RULES.recipes[i]
		var y: int=369+i*89
		card(Rect2(477,y,966,78))
		text(str(recipe.name)+( "" if GameState.unlocked_recipes.has(recipe.id) else " · 未解锁"),Rect2(491,y+9,340,60),25,true)
		bound(func():return "普通×"+str(GameState.tea_inventory[recipe.id][0])+"    良好×"+str(GameState.tea_inventory[recipe.id][1])+"    上佳×"+str(GameState.tea_inventory[recipe.id][2]),Rect2(840,y+9,577,60),24)
	text("陈设收藏："+("暂无" if GameState.decorations.is_empty() else "、".join(GameState.decorations)),Rect2(480,843,960,70),23)
