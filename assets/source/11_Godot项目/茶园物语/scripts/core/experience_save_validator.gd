extends RefCounted
const RECIPES: Array = ["spring","dew","mist","summit","artisan"]
const ACHIEVEMENTS: Array = ["first_harvest","first_craft","first_sale","know_guest","skillful","all_terraces","five_day","tea_meeting"]
static func whole(value: Variant, low: int=0, high: int=1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=low and float(value)<=high
static func string_list(value: Variant, choices: Array) -> bool:
	if not value is Array or value.size()>choices.size():return false
	var seen: Array=[]
	for item in value:
		if not item is String or not choices.has(item) or seen.has(item):return false
		seen.append(item)
	return true
static func validate(state: Dictionary) -> bool:
	var required: Array = ["experience","profession","crafted_batches","precise_orders","best_batches","completed_tasks","daily","unlocked_recipes","recipe_mastery","recipe_taught","claimed_achievements","current_order","order_serial","tasting_guests","meetings","basket_capacity","bag_capacity","quality_tool","decorations","five_day_reviewed","tea_inventory"]
	if not state.has_all(required) or state.plots.size()!=14:return false
	for key in ["experience","crafted_batches","precise_orders","best_batches","completed_tasks","order_serial","tasting_guests","meetings","basket_capacity","bag_capacity"]:
		if not whole(state[key]):return false
	if not whole(state.profession,0,4) or not whole(state.tasting_guests,0,3):return false
	if int(state.basket_capacity)<1 or int(state.bag_capacity)<1:return false
	if not state.quality_tool is bool or not state.five_day_reviewed is bool:return false
	if not state.tea_inventory is Dictionary or state.tea_inventory.size()!=5:return false
	for id in RECIPES:
		if not state.tea_inventory.has(id) or not state.tea_inventory[id] is Array or state.tea_inventory[id].size()!=3:return false
		for amount in state.tea_inventory[id]:
			if not whole(amount):return false
	if state.teas!=state.tea_inventory.spring:return false
	if not string_list(state.unlocked_recipes,RECIPES) or not state.unlocked_recipes.has("spring"):return false
	if not string_list(state.recipe_taught,RECIPES) or not string_list(state.claimed_achievements,ACHIEVEMENTS):return false
	if state.has("pending_recipe_lessons") and not string_list(state.pending_recipe_lessons,RECIPES):return false
	if not state.recipe_mastery is Dictionary or state.recipe_mastery.size()>5:return false
	for id in state.recipe_mastery:
		if not RECIPES.has(id) or not whole(state.recipe_mastery[id]):return false
	if not state.decorations is Array or state.decorations.size()>20:return false
	for item in state.decorations:
		if not item is String:return false
	var daily: Variant=state.daily
	if not daily is Dictionary or not daily.has_all(["counts","claimed","bonus","planted_new","good","coins","optional_claimed"]):return false
	if not daily.counts is Array or daily.counts.size()!=4 or not daily.claimed is Array or daily.claimed.size()!=4:return false
	for count in daily.counts:
		if not whole(count):return false
	for claimed in daily.claimed:
		if not claimed is bool:return false
	if not daily.bonus is bool or not daily.optional_claimed is bool:return false
	for key in ["planted_new","good","coins"]:
		if not whole(daily[key]):return false
	if daily.has("best") and not whole(daily.best):return false
	var order: Variant=state.current_order
	if not order is Dictionary or not order.has_all(["id","recipe","quality","quantity","income","bonus","customer"]):return false
	if not order.recipe is String or not state.unlocked_recipes.has(order.recipe):return false
	if not whole(order.id,1) or not whole(order.quality,0,2) or not whole(order.quantity,1,5) or not whole(order.customer,0,2):return false
	if not whole(order.income) or not whole(order.bonus):return false
	for plot in state.plots:
		if not plot.has("material") or plot.material!="basic":return false
	if not state.batch.is_empty():
		if not state.batch.has_all(["recipe","quantity","tutorial"]):return false
		if not state.unlocked_recipes.has(state.batch.recipe) or not whole(state.batch.quantity,1,5) or not state.batch.tutorial is bool:return false
	return true
