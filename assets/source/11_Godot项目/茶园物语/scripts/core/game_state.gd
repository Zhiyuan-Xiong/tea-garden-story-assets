extends Node
signal changed
signal action_completed(action: String)
signal notice(message: String)
const Orders = preload("res://scripts/core/orders.gd")
var RULES: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_rules.json"))
var GROW_SECONDS: float = float(RULES.ordinary_growth_seconds)
const QUALITIES: Array[String] = ["普通", "良好", "上佳"]
const CHAPTERS: Array[String] = ["初到茶村", "第一篓新芽", "第一炉新茶", "第一位茶客", "茶香满村"]
var started: bool = false
var paused: bool = false
var in_menu: bool = true
var day: int = 1
var copper: int = 30
var seeds: int = 3
var fresh: int = 0
var fertilizer: int = 2
var teas: Array = [0,0,0]
var tea_inventory: Dictionary = {}
var plots: Array = []
var batch: Dictionary = {}
var milestones: Dictionary = {}
var served: int = 0
var customer_index: int = 0
var upgraded: bool = false
var chapter: int = 0
var last_scene: String = "village"
var total_harvested: int = 0
var total_crafted: int = 0
var play_seconds: float = 0.0
var experience: int = 0
var profession: int = 0
var crafted_batches: int = 0
var precise_orders: int = 0
var best_batches: int = 0
var completed_tasks: int = 0
var daily: Dictionary = {}
var unlocked_recipes: Array = ["spring"]
var recipe_mastery: Dictionary = {}
var recipe_taught: Array = []
var pending_recipe_lessons: Array = []
var claimed_achievements: Array = []
var current_order: Dictionary = {}
var order_serial: int = 0
var tasting_guests: int = 0
var meetings: int = 0
var basket_capacity: int = 30
var bag_capacity: int = 30
var quality_tool: bool = false
var decorations: Array = []
var five_day_reviewed: bool = false
var settings: Dictionary = {"sound_volume":0.55,"environment_volume":0.55,"music_volume":0.55,"music_muted":false,"show_hints":true,"reduced_motion":false}
var _refresh_clock: float = 0.0

func _ready() -> void:
	reset(false)

func empty_plot() -> Dictionary:
	return {"planted":false,"age":0.0,"harvested":false,"fertilized":false,"material":"basic"}

func new_daily() -> Dictionary:
	return {"counts":[0,0,0,0],"claimed":[false,false,false,false],"bonus":false,"planted_new":0,"good":0,"coins":0,"optional_claimed":false}

func reset(activate: bool = true) -> void:
	started = activate
	in_menu = not activate
	paused = false
	day = 1
	copper = 30
	seeds = 3
	fresh = 0
	fertilizer = 2
	tea_inventory = {}
	for recipe in RULES.recipes: tea_inventory[recipe.id] = [0,0,0]
	teas = tea_inventory.spring
	plots = []
	for i in range(14): plots.append(empty_plot())
	batch = {}
	milestones = {}
	served = 0
	customer_index = 0
	upgraded = false
	chapter = 0
	last_scene = "village"
	total_harvested = 0
	total_crafted = 0
	play_seconds = 0.0
	experience = 0
	profession = 0
	crafted_batches = 0
	precise_orders = 0
	best_batches = 0
	completed_tasks = 0
	daily = new_daily()
	unlocked_recipes = ["spring"]
	recipe_mastery = {}
	recipe_taught = []
	pending_recipe_lessons = []
	claimed_achievements = []
	order_serial = 0
	tasting_guests = 0
	meetings = 0
	basket_capacity = 30
	bag_capacity = 30
	quality_tool = false
	decorations = []
	five_day_reviewed = false
	refresh_order()
	changed.emit()

func _process(delta: float) -> void:
	if not started or paused or in_menu: return
	advance_time(delta)
	_refresh_clock += delta
	if _refresh_clock >= 0.2:
		_refresh_clock = 0.0
		changed.emit()

func grow_duration(index: int) -> float:
	return GROW_SECONDS if plots[index].harvested else float(RULES.teaching_growth_seconds)

func advance_time(delta: float) -> void:
	if not started or paused or in_menu: return
	play_seconds += maxf(delta,0.0)
	for i in range(plots.size()):
		if plots[i].planted: plots[i].age = minf(grow_duration(i),float(plots[i].age)+maxf(delta,0.0))
	if not batch.is_empty() and int(batch.stage) in [1,2,3]: batch.elapsed = float(batch.elapsed)+maxf(delta,0.0)

func complete_action(action: String, message: String = "") -> void:
	update_progress()
	changed.emit()
	action_completed.emit(action)
	if not message.is_empty(): notice.emit(message)

func unlock(key: String) -> void:
	milestones[key] = true
	if key in ["planted","harvested","crafted","served"]:
		chapter = maxi(chapter,["planted","harvested","crafted","served"].find(key)+1)

func tier_of(index: int) -> int:
	return mini(index / 3,4)

func opened_terraces() -> int:
	return mini(day,5)

func is_plot_open(index: int) -> bool:
	return index >= 0 and index < 14 and tier_of(index) < opened_terraces()

func guide_text() -> String:
	return ["完成一次采摘、制茶与售卖","在新开放的第二层种下一株茶树","制作一批良好及以上的新茶","精准完成一笔客人订单","新茶试饮：接待3位茶客"][mini(day,5)-1] if day <= 5 else "自由经营：提升职业、学习新茶、筹办主题茶会"

func guide_complete() -> bool:
	match day:
		1: return int(daily.counts[0]) >= 1 and int(daily.counts[1]) >= 1 and int(daily.counts[2]) >= 1
		2: return int(daily.planted_new) >= 1
		3: return int(daily.good) >= 1
		4: return int(daily.counts[3]) >= 1
		5: return tasting_guests >= 3
	return true

func objective() -> String:
	return ("今日引导已完成 · 可结束一天，任务自由选择" if guide_complete() else guide_text())

func plot_state(index: int) -> String:
	if not is_plot_open(index): return "locked"
	var plot: Dictionary = plots[index]
	if not plot.planted: return "empty"
	if float(plot.age) >= grow_duration(index): return "ready"
	if float(plot.age) < grow_duration(index)*0.35: return "harvested" if plot.harvested else "seedling"
	return "growing"

func plant(index: int, material: String = "basic") -> bool:
	if not is_plot_open(index) or plots[index].planted or material != "basic": return false
	if seeds < 1:
		notice.emit("种植材料不足，可在茶铺购买；每天新区域开放也会赠送材料。")
		return false
	seeds -= 1
	plots[index] = empty_plot()
	plots[index].planted = true
	if tier_of(index) == day-1: daily.planted_new = int(daily.planted_new)+1
	unlock("planted")
	complete_action("plant","茶树已种在区域中心，首轮嫩芽8秒成熟。")
	return true

func harvest(index: int) -> bool:
	if plot_state(index) != "ready": return false
	if fresh >= basket_capacity:
		notice.emit("茶篓已满，可先加工鲜叶或扩充茶篓；成熟茶芽会一直保留。")
		return false
	fresh += 1
	total_harvested += 1
	experience += 2
	daily.counts[0] += 1
	plots[index].age = 0.0
	plots[index].harvested = true
	plots[index].fertilized = false
	unlock("harvested")
	complete_action("harvest","鲜叶＋1 · 经验＋2，茶树继续生长。")
	return true

func fertilize(index: int) -> bool:
	if plot_state(index) in ["locked","empty","ready"] or plots[index].fertilized or fertilizer < 1: return false
	fertilizer -= 1
	plots[index].fertilized = true
	plots[index].age = float(plots[index].age)+(grow_duration(index)-float(plots[index].age))*0.5
	complete_action("fertilize","本轮剩余成长时间减半，每轮最多施肥一次。")
	return true

func recipe_data(id: String) -> Dictionary:
	for recipe in RULES.recipes:
		if recipe.id == id: return recipe
	return {}

func stock_total() -> int:
	var count: int = 0
	for inventory in tea_inventory.values():
		for amount in inventory: count += int(amount)
	return count

func batch_recipe() -> Dictionary:
	return recipe_data(str(batch.get("recipe","spring")))

func craft_maximum(stage: int) -> int:
	return int(batch_recipe().counts[stage]) if stage in [0,1,2] else 0

func start_batch(id: String = "spring", quantity: int = 1) -> bool:
	var recipe: Dictionary = recipe_data(id)
	if not batch.is_empty() or not unlocked_recipes.has(id) or recipe.is_empty() or quantity < 1 or quantity > 5: return false
	if quantity > 1 and not can_simplify(id): return false
	if fresh < int(recipe.raw)*quantity or stock_total()+quantity > bag_capacity:
		notice.emit("鲜叶或背包空间不足。基础茶为1份鲜叶加工1份茶。")
		return false
	fresh -= int(recipe.raw)*quantity
	batch = {"recipe":id,"quantity":quantity,"stage":0,"elapsed":0.0,"points":0,"count":0,"fire":2,"last_action":-10.0,"quality":0,"tutorial":int(recipe_mastery.get(id,0))==0}
	if not recipe_taught.has(id): recipe_taught.append(id)
	complete_action("processing_start")
	return true

func heat() -> float:
	return 0.5 if batch.is_empty() else clampf(0.5+(int(batch.fire)-2)*0.2+sin(float(batch.elapsed)*0.9)*0.22,0.0,1.0)

func rhythm() -> float:
	return 0.5 if batch.is_empty() else 0.5+0.45*sin(float(batch.elapsed)*1.8)

func set_fire(value: int) -> void:
	if not batch.is_empty() and int(batch.stage)==1:
		batch.fire = clampi(value,1,3)
		changed.emit()

func craft_action() -> bool:
	if batch.is_empty(): return false
	var stage: int = int(batch.stage)
	var elapsed: float = float(batch.elapsed)
	if stage not in [0,1,2] or int(batch.count)>=craft_maximum(stage): return false
	if stage in [1,2] and elapsed-float(batch.last_action)<0.65: return false
	batch.count += 1
	batch.last_action = elapsed
	var window: float = 0.35 if batch.get("tutorial",false) else float(batch_recipe().window)
	if stage==0 or absf((heat() if stage==1 else rhythm())-0.5)<=window: batch.points += 1
	unlock(["spread","kill_green","roll"][stage])
	changed.emit()
	return true

func can_advance_craft() -> bool:
	if batch.is_empty(): return false
	var stage: int = int(batch.stage)
	return int(batch.count)>=craft_maximum(stage) if stage in [0,1,2] else (stage==3 and float(batch.elapsed)>=4.0)

func advance_craft() -> bool:
	if not can_advance_craft(): return false
	if int(batch.stage)==3:
		var recipe: Dictionary = batch_recipe()
		if float(batch.elapsed)>=float(recipe.dry[0]) and float(batch.elapsed)<=float(recipe.dry[1]): batch.points += 3
		var maximum: float = float(int(recipe.counts[0])+int(recipe.counts[1])+int(recipe.counts[2])+3)
		var score: float = (float(batch.points)+(1.0 if upgraded else 0.0)+(2.0 if quality_tool else 0.0))/maximum
		batch.quality = 2 if score>=0.72 else (1 if score>=0.38 else 0)
		if batch.get("tutorial",false): batch.quality = maxi(1,int(batch.quality))
		unlock("dry")
	batch.stage += 1
	batch.elapsed = 0.0
	batch.count = 0
	batch.last_action = -10.0
	complete_action("processing_stage")
	return true

func _store_batch(id: String, quality: int, quantity: int) -> void:
	tea_inventory[id][quality] += quantity
	total_crafted += quantity
	crafted_batches += 1
	recipe_mastery[id] = int(recipe_mastery.get(id,0))+1
	experience += 8
	daily.counts[1] += 1
	if quality>=1: daily.good += 1
	if quality==2:
		best_batches += 1
		daily.best = int(daily.get("best",0))+1
		unlock("best")
	unlock("crafted")

func collect_batch() -> bool:
	if batch.is_empty() or int(batch.stage)!=4: return false
	var id: String = str(batch.get("recipe","spring"))
	var quantity: int = int(batch.get("quantity",1))
	var quality: int = int(batch.quality)
	if stock_total()+quantity>bag_capacity: return false
	_store_batch(id,quality,quantity)
	batch = {}
	complete_action("collect_tea","新茶已入库 · 成功制茶＋1批 · 经验＋8。")
	return true

func can_simplify(id: String) -> bool:
	return profession>=2 and int(recipe_mastery.get(id,0))>=3 and unlocked_recipes.has(id)

func simplified_craft(id: String = "spring", quantity: int = 1) -> bool:
	var recipe: Dictionary = recipe_data(id)
	if not can_simplify(id) or not batch.is_empty() or quantity<1 or quantity>5: return false
	if fresh<int(recipe.raw)*quantity or stock_total()+quantity>bag_capacity: return false
	fresh -= int(recipe.raw)*quantity
	_store_batch(id,1,quantity)
	complete_action("simplified_craft","熟练配方批量入库，良好×"+str(quantity)+"；任务计为1批。")
	return true

func daily_rule() -> Dictionary:
	return RULES.daily[mini(day,5)-1]

func update_progress() -> void:
	var rule: Dictionary = daily_rule()
	for i in range(4):
		if not daily.claimed[i] and int(daily.counts[i])>=int(rule.targets[i]):
			daily.claimed[i] = true
			completed_tasks += 1
			experience += int(rule.rewards[i])
			notice.emit("每日任务完成 · 经验＋"+str(rule.rewards[i])+"（已自动领取）")
	if not daily.bonus and daily.claimed.all(func(value): return bool(value)):
		daily.bonus = true
		experience += int(rule.bonus)
		fertilizer += 1
		notice.emit("四项任务全完成 · 经验＋40 · 肥料×1")
	while profession<4:
		var next: Dictionary = RULES.professions[profession+1]
		if experience<int(next.xp) or int(get(str(next.counter)))<int(next.count): break
		profession += 1
		copper += int(next.coins)
		if profession==4 and not decorations.has("制茶大师题签"):decorations.append("制茶大师题签")
		notice.emit("晋升："+str(next.name)+" · 铜钱＋"+str(next.coins))
	for recipe in RULES.recipes:
		if not unlocked_recipes.has(recipe.id) and profession>=int(recipe.rank) and completed_tasks>=int(recipe.tasks):
			unlocked_recipes.append(recipe.id)
			pending_recipe_lessons.append(recipe.id)
			notice.emit("新茶解锁："+str(recipe.name)+"，到工坊查看首次制作教学。")
	for achievement in RULES.achievements:
		var value: int = opened_terraces() if achievement.counter=="opened_terraces" else int(get(str(achievement.counter)))
		if not claimed_achievements.has(achievement.id) and value>=int(achievement.count):
			claimed_achievements.append(achievement.id)
			copper += int(achievement.coins)
			fertilizer += int(achievement.fertilizer)
			if achievement.id=="all_terraces": decorations.append("满山茶香题签")
			if achievement.id=="five_day": decorations.append("五日新茶纪念雅座"); unlock("five_day")
			notice.emit("成就："+str(achievement.name)+" · "+str(achievement.reward))

func optional_challenge() -> bool:
	if day<5 or daily.optional_claimed or int(daily.get("best",0))<1: return false
	daily.optional_claimed = true
	experience += 20
	complete_action("optional_challenge","自选挑战 · 经验＋20，不影响基础任务奖励。")
	return true

func refresh_order(basic: bool = false) -> void:
	order_serial += 1
	var available: Array = ["spring"]
	if not basic:
		for id in unlocked_recipes:
			if id!="spring" and int(recipe_mastery.get(id,0))>0: available.append(id)
	var id: String = str(available[(order_serial-1)%available.size()])
	var recipe: Dictionary = recipe_data(id)
	var quality: int = 0
	if not basic and int(recipe_mastery.get(id,0))>=3: quality = 1
	if not basic and profession>=3 and int(recipe_mastery.get(id,0))>=8: quality = 2
	var quantity: int = 2 if id!="spring" and order_serial%2==0 else 1
	current_order = {"id":order_serial,"recipe":id,"quality":quality,"quantity":quantity,"income":int(recipe.price)*quantity,"bonus":5,"customer":customer_index}

func swap_order() -> void:
	refresh_order(true)
	complete_action("swap_order","已更换为基础订单，没有等待限制。")

func check_delivery(id: String, quality: int, quantity: int) -> String:
	if id!=str(current_order.recipe): return "茶品不符，请选择订单中的茶品。"
	if quality<0 or quality>2 or quality<int(current_order.quality): return "品质不足，请提供最低品质及以上的新茶。"
	if quantity!=int(current_order.quantity): return "数量不符，请按订单准确交付。"
	if not tea_inventory.has(id) or int(tea_inventory[id][quality])<quantity: return "库存不足，可保留订单或更换基础订单。"
	return "核对通过：茶品正确、品质达标、数量一致，精准完成。"

func deliver(id: String, quality: int, quantity: int) -> bool:
	if id!=str(current_order.recipe) or quality<0 or quality>2 or quality<int(current_order.quality) or quantity!=int(current_order.quantity): return false
	if not tea_inventory.has(id) or int(tea_inventory[id][quality])<quantity: return false
	tea_inventory[id][quality] -= quantity
	var earned: int = int(current_order.income)+int(current_order.bonus)
	copper += earned
	daily.coins += earned
	served += 1
	precise_orders += 1
	experience += 10
	daily.counts[2] += 1
	daily.counts[3] += 1
	if day==5: tasting_guests = mini(tasting_guests+1,3)
	customer_index = (customer_index+1)%3
	unlock("served")
	refresh_order()
	complete_action("serve","精准上茶 · 铜钱＋"+str(earned)+" · 经验＋10，下一位茶客已到。")
	return true

func serve(quality: int) -> bool:
	return deliver(str(current_order.recipe),quality,int(current_order.quantity))

func purchase(kind: String) -> bool:
	var prices: Dictionary = {"seed":5,"fertilizer":6,"upgrade":36,"quality_tool":80,"basket":30,"bag":30,"decor":24}
	var price: int = int(prices.get(kind,-1))
	if price<0 or copper<price: return false
	if kind=="upgrade" and (profession<2 or upgraded): return false
	if kind=="quality_tool" and (profession<3 or quality_tool): return false
	if kind=="decor" and decorations.has("清雅茶桌"): return false
	copper -= price
	match kind:
		"seed": seeds += 1
		"fertilizer": fertilizer += 1
		"upgrade": upgraded = true
		"quality_tool": quality_tool = true
		"basket": basket_capacity += 15
		"bag": bag_capacity += 15
		"decor": decorations.append("清雅茶桌")
	complete_action("purchase","添置完成，经营能力与陈设会保留在存档中。")
	return true

func end_day() -> bool:
	if not guide_complete():
		notice.emit("先完成简短引导："+guide_text()+"。每日任务可以留到以后。")
		return false
	day += 1
	daily = new_daily()
	if day<=5: seeds += int(RULES.terrace_slots[day-1])
	refresh_order(true)
	complete_action("end_day","第"+str(day)+"日开始"+(" · 新梯田开放 · 材料＋"+str(RULES.terrace_slots[day-1]) if day<=5 else " · 自由经营"))
	return true

func tea_meeting() -> bool:
	if profession<4 or meetings>0 or stock_total()<3 or copper<20: return false
	copper -= 20
	var remaining: int = 3
	for id in tea_inventory:
		for quality in range(3):
			var used: int = mini(remaining,int(tea_inventory[id][quality]))
			tea_inventory[id][quality] -= used
			remaining -= used
	meetings += 1
	unlock("tea_meeting")
	complete_action("tea_meeting","主题茶会圆满完成，匠心待客徽章已收入成就记录。")
	return true

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	for key in ["day","copper","seeds","fresh","fertilizer","teas","tea_inventory","plots","batch","milestones","served","customer_index","upgraded","chapter","last_scene","total_harvested","total_crafted","play_seconds","experience","profession","crafted_batches","precise_orders","best_batches","completed_tasks","daily","unlocked_recipes","recipe_mastery","recipe_taught","pending_recipe_lessons","claimed_achievements","current_order","order_serial","tasting_guests","meetings","basket_capacity","bag_capacity","quality_tool","decorations","five_day_reviewed"]:
		var value: Variant = get(key)
		data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data

func restore(data: Dictionary) -> void:
	reset(false)
	for key in snapshot().keys():
		if data.has(key): set(key,data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])
	if not data.has("tea_inventory"):
		tea_inventory.spring = data.teas.duplicate()
		crafted_batches = int(total_crafted/2)
		experience = total_harvested*2+crafted_batches*8+served*5
		# Reimburse new terrace materials that did not exist in the prototype.
		seeds += [3,6,9,12,14][opened_terraces()-1]-3
		if milestones.has("crafted") or not batch.is_empty():recipe_taught.append("spring")
		if not batch.is_empty():
			batch.recipe="spring"
			batch.quantity=2
			batch.tutorial=false
		# Legacy saves keep their earned resources; migration never reclaims old rewards.
		for achievement in RULES.achievements:
			var value: int = opened_terraces() if achievement.counter=="opened_terraces" else int(get(str(achievement.counter)))
			if value>=int(achievement.count):
				claimed_achievements.append(achievement.id)
				if achievement.id=="all_terraces":decorations.append("满山茶香题签")
		for id in ["spring"]: recipe_mastery[id] = crafted_batches
	while plots.size()<14: plots.append(empty_plot())
	for i in range(plots.size()):
		var plot: Dictionary=plots[i]
		if not plot.has("material"): plot.material = "basic"
		plot.age = minf(float(plot.age),grow_duration(i))
	for inventory in tea_inventory.values():
		for i in range(3): inventory[i] = int(inventory[i])
	for i in range(4): daily.counts[i] = int(daily.counts[i])
	for key in ["planted_new","good","coins","best"]:
		if daily.has(key): daily[key] = int(daily[key])
	for key in recipe_mastery: recipe_mastery[key] = int(recipe_mastery[key])
	for key in ["id","quality","quantity","income","bonus","customer"]:
		if current_order.has(key): current_order[key] = int(current_order[key])
	for key in ["stage","points","count","fire","quality","quantity"]:
		if batch.has(key): batch[key] = int(batch[key])
	teas = tea_inventory.spring
	if not data.has("current_order"): refresh_order(true)
	if not data.has("pending_recipe_lessons"):
		for id in unlocked_recipes:
			if id!="spring" and not recipe_taught.has(id):pending_recipe_lessons.append(id)
	started = true
	in_menu = false
	paused = false
	update_progress()
	changed.emit()
