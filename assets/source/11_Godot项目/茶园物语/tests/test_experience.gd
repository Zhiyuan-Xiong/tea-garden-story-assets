extends Node
var checks: int=0
var failures: Array=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:failures.append(message);push_error(message)
func _ready() -> void:
	SaveSystem.base_path="user://experience_tests_only"
	GameState.set_process(false)
	call_deferred("run")
func active() -> void:
	GameState.reset()
	GameState.in_menu=false
func craft(id: String="spring", perfect: bool=true) -> void:
	check(GameState.start_batch(id),"start "+id)
	for stage in range(3):
		for i in range(GameState.craft_maximum(stage)):
			if stage>0:
				GameState.advance_time(0.7)
				if perfect:
					var attempts: int=0
					while absf((GameState.heat() if stage==1 else GameState.rhythm())-0.5)>float(GameState.batch_recipe().window) and attempts<100:
						GameState.advance_time(0.1);attempts+=1
			check(GameState.craft_action(),"craft stage action")
		check(GameState.advance_craft(),"advance craft stage")
	GameState.advance_time(float(GameState.batch_recipe().dry[0])+0.2)
	check(GameState.advance_craft(),"drying done")
	check(GameState.collect_batch(),"collect batch")
func packet() -> Dictionary:
	return {"version":2,"saved_at":"2026-10-09","timestamp":100,"state":GameState.snapshot()}
func equivalent(a: Variant,b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]):return false
		return true
	return a==b
func run() -> void:
	active()
	check(GameState.plots.size()==14,"14 slots")
	for i in range(14):check(GameState.is_plot_open(i)==(i<3),"day1 open only bottom")
	check(not GameState.plant(3),"locked cannot plant")
	check(not GameState.end_day(),"unfinished guide cannot end")
	check(GameState.seeds==3,"day1 free materials")
	check(GameState.plant(0),"plant first plot")
	GameState.advance_time(7.9)
	check(GameState.plot_state(0)!="ready","8 second tutorial")
	GameState.advance_time(0.1)
	check(GameState.harvest(0),"harvest tutorial")
	check(GameState.fresh==1 and GameState.experience==2,"harvest resource and xp")
	check(GameState.grow_duration(0)==55,"regrowth55")
	GameState.advance_time(15)
	var age: float=GameState.plots[0].age
	check(GameState.fertilize(0),"fertilize")
	check(is_equal_approx(GameState.plots[0].age,age+(55-age)*0.5),"halves remaining time")
	check(not GameState.fertilize(0),"fertilize once")
	var before: float=GameState.plots[0].age
	GameState.paused=true
	GameState.advance_time(50)
	check(GameState.plots[0].age==before,"pause stops growth")
	GameState.paused=false
	GameState.last_scene="workshop"
	GameState.advance_time(55)
	check(GameState.plot_state(0)=="ready","grows across scenes")
	GameState.advance_time(1000)
	check(GameState.plot_state(0)=="ready","never wilts")
	craft()
	check(GameState.stock_total()==1 and GameState.total_crafted==1 and GameState.crafted_batches==1,"one fresh yields one tea and one batch")
	var xp: int=GameState.experience
	check(GameState.serve(2),"serve first order")
	check(GameState.experience-xp==10,"sale5 precise extra5")
	check(GameState.daily.counts==[1,1,1,1],"count semantics")
	check(GameState.guide_complete(),"day1 basic loop guide")
	check(not GameState.simplified_craft(),"apprentice cannot simplify")
	for n in range(1,6):
		active();GameState.day=n;GameState.daily=GameState.new_daily()
		GameState.daily.counts=GameState.daily_rule().targets.duplicate()
		GameState.update_progress()
		check(GameState.experience==[160,180,200,220,240][n-1],"exact daily total day"+str(n))
		check(GameState.completed_tasks==4 and GameState.fertilizer==3,"four tasks and fertilizer bonus")
		var snapshot: Dictionary=GameState.snapshot()
		GameState.update_progress()
		check(GameState.snapshot()==snapshot,"no duplicate daily or achievement rewards")
	active()
	GameState.experience=1000;GameState.update_progress()
	check(GameState.profession==0,"xp alone no promotion")
	GameState.crafted_batches=1;GameState.update_progress()
	check(GameState.profession==1,"junior practice plus xp")
	check(not GameState.unlocked_recipes.has("dew"),"recipe requires tasks too")
	GameState.completed_tasks=4;GameState.update_progress()
	check(GameState.unlocked_recipes.has("dew"),"recipe auto unlock two gates")
	GameState.crafted_batches=12;GameState.update_progress()
	check(GameState.profession==2,"middle12 batches")
	GameState.recipe_mastery.spring=3;GameState.fresh=10
	check(GameState.simplified_craft("spring",5),"bulk5 available when practiced")
	check(GameState.fresh==5 and GameState.teas[1]==5 and GameState.daily.counts[1]==1,"bulk counted one batch")
	check(not GameState.can_simplify("dew"),"first recipe retains manual")
	GameState.experience=3000;GameState.update_progress()
	check(GameState.profession==2,"senior practice gate")
	GameState.precise_orders=15;GameState.update_progress()
	check(GameState.profession==3,"senior exact15")
	GameState.best_batches=20;GameState.completed_tasks=40;GameState.update_progress()
	check(GameState.profession==4 and GameState.unlocked_recipes.size()==5,"master and all recipes")
	check(GameState.tea_meeting(),"master meeting")
	check(not GameState.tea_meeting(),"meeting achievement once")
	check(GameState.claimed_achievements.has("tea_meeting"),"meeting badge")
	active();GameState.teas[2]=10
	var old: Dictionary=GameState.snapshot()
	check(not GameState.deliver("dew",2,1),"wrong recipe reject")
	check(not GameState.deliver("spring",2,2),"wrong quantity reject")
	check(GameState.snapshot()==old,"failed delivery atomic")
	GameState.current_order.quality=2
	check(not GameState.deliver("spring",1,1),"quality reject")
	check(GameState.deliver("spring",2,1),"valid precise order")
	for i in range(5):check(GameState.serve(2),"unlimited basic orders")
	GameState.swap_order()
	check(GameState.current_order.recipe=="spring" and GameState.current_order.quality==0,"replace accessible basic order")
	# Full five-day journey without completing optional daily task sets.
	active()
	GameState.plant(0);GameState.advance_time(8);GameState.harvest(0);craft();GameState.serve(2)
	var tree: Dictionary=GameState.plots[0].duplicate(true)
	var materials: int=GameState.seeds
	check(GameState.end_day(),"day1 to2 optional tasks")
	check(GameState.plots[0]==tree and GameState.seeds==materials+3,"preserve tree and gift3")
	check(GameState.plant(3) and GameState.guide_complete(),"day2 plant new terrace guide")
	check(GameState.end_day(),"day2 to3")
	GameState.advance_time(55);GameState.harvest(0);craft()
	check(GameState.guide_complete() and GameState.end_day(),"day3 good batch")
	check(GameState.serve(2) and GameState.guide_complete(),"day4 precise guide")
	check(GameState.end_day(),"day4 to5")
	check(GameState.opened_terraces()==5,"all5 opened")
	for i in range(14):check(GameState.is_plot_open(i),"all14 usable day5")
	for i in range(3):
		GameState.advance_time(55);GameState.harvest(0);craft();GameState.serve(2)
	check(GameState.tasting_guests==3 and GameState.claimed_achievements.has("five_day"),"day5 tasting3 reward")
	check(GameState.guide_complete() and GameState.end_day(),"free business day6")
	check(GameState.seeds==12,"all gifts total14 minus two planted")
	check(GameState.daily.counts==[0,0,0,0] and GameState.crafted_batches==5,"daily reset permanent retained")
	GameState.fresh=1;GameState.start_batch()
	var retained_batch: Dictionary=GameState.batch.duplicate(true)
	check(GameState.end_day() and GameState.batch==retained_batch,"unfinished batch retained across days")
	GameState.batch={}
	check(SaveSystem.validate(packet()),"valid v2 save")
	var original: Dictionary=GameState.snapshot()
	check(SaveSystem.write_slot(1),"write isolated save")
	GameState.reset();check(SaveSystem.load_slot(1),"read isolated save")
	check(equivalent(GameState.snapshot(),original),"v2 round trip no reward duplication; float timer precision tolerated")
	for key in ["daily","tea_inventory","current_order","recipe_mastery"]:
		var bad: Dictionary=packet();bad.state[key]=["bad"]
		check(not SaveSystem.validate(bad),"reject malformed "+key)
	for key in ["experience","profession","basket_capacity","completed_tasks"]:
		var bad: Dictionary=packet();bad.state[key]=-1
		check(not SaveSystem.validate(bad),"reject bad range "+key)
	var legacy: Dictionary=original.duplicate(true)
	for key in ["experience","profession","crafted_batches","precise_orders","best_batches","completed_tasks","daily","unlocked_recipes","recipe_mastery","recipe_taught","pending_recipe_lessons","claimed_achievements","current_order","order_serial","tasting_guests","meetings","basket_capacity","bag_capacity","quality_tool","decorations","five_day_reviewed","tea_inventory"]:legacy.erase(key)
	legacy.plots=legacy.plots.slice(0,3)
	check(SaveSystem.validate({"version":1,"saved_at":"legacy","timestamp":1,"state":legacy}),"v1 accepted")
	GameState.restore(legacy)
	check(GameState.plots.size()==14 and GameState.fresh==int(legacy.fresh) and GameState.teas==legacy.teas,"legacy resource and14 migration")
	check(GameState.seeds==int(legacy.seeds)+11,"legacy missing tier materials reimbursed once")
	var corrupt_legacy: Dictionary={"version":1,"saved_at":"legacy","timestamp":1,"state":legacy.duplicate(true)}
	corrupt_legacy.state.daily="corrupt"
	check(not SaveSystem.validate(corrupt_legacy),"v1 cannot bypass modern field validation")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file:=FileAccess.open("res://docs/五日经营体验/玩法测试报告.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("EXPERIENCE_TEST ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
