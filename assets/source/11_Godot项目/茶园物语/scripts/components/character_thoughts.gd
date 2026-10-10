extends Node2D
var room: String
var view: Control
var speakers: Array[Dictionary] = []
var bubble: Panel
var caption: Label
var next_thought: float = 8.0
var remaining: float = 0.0
var cursor: int = 0
var active_head := Vector2.ZERO
var current_speaker: String = ""

func setup(owner_room: String, owner_view: Control) -> void:
	room = owner_room
	view = owner_view
	add_to_group("character_thought_layers")
	for image in get_tree().get_nodes_in_group("character_art"):
		if not view.is_ancestor_of(image) or image.get_parent().get_meta("room","") != room: continue
		var role: String = image.name
		var hit: Button = preload("res://scripts/ui/paper_icon_button.gd").new()
		hit.name = role+"_ThoughtClick"
		hit.flat = true
		hit.tooltip_text = "看看心里话"
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.add_to_group("character_clicks")
		view.add_child(hit)
		hit.pressed.connect(func(): show_thought(role))
		speakers.append({"role":role,"image":image,"hit":hit,"count":0})
	bubble = UiKit.flat_card(self,Rect2(0,0,260,90))
	bubble.name = "CharacterInnerThought"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = UiKit.label("",bubble,Rect2(12,10,236,70),22)
	bubble.visible = false
	_refresh_hits()

func _editing() -> bool:
	for editor in get_tree().get_nodes_in_group("furniture_editors"):
		if editor.room == room and editor.enabled: return true
	return false

func _blocked() -> bool:
	var modal: Node = get_tree().root.find_child("Modals",true,false)
	return GameState.paused or (modal != null and modal.visible)

func _refresh_hits() -> void:
	for speaker in speakers:
		speaker.hit.visible = speaker.image.is_visible_in_tree()
		var rect: Rect2 = speaker.image.get_global_rect()
		UiKit.place(speaker.hit,Rect2(rect.position+Vector2(rect.size.x*.12,0),Vector2(rect.size.x*.76,rect.size.y)))
		speaker.hit.mouse_filter = Control.MOUSE_FILTER_IGNORE if _editing() else Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not is_instance_valid(bubble): return
	_refresh_hits()
	if _blocked() or _editing():
		bubble.visible = false
		remaining = 0
		queue_redraw()
		return
	if remaining>0:
		remaining -= delta
		if remaining<=0:
			bubble.visible = false
			queue_redraw()
	else:
		next_thought -= delta
		if next_thought<=0 and not speakers.is_empty():
			show_thought(speakers[cursor%speakers.size()].role)
			cursor += 1

func text_for(role: String, index: int) -> String:
	var lines: Array[String]
	match role:
		"GardenCompanion": lines = ["这几片嫩芽，长得真精神。","轻轻采下嫩芽，茶树还能再长。"]
		"GardenPicker": lines = ["把春天的清香，带回工坊吧。","今天也想\n制出一盏好茶。"]
		"WorkshopCompanion": lines = ["把鲜叶摊匀，清香就留得住。","慢慢来，手艺都是练出来的。"]
		"WorkshopMaker":
			if not GameState.batch.is_empty():
				lines = ["这炉新茶，得仔细照看。","火候稳一些，茶香才干净。"]
			else: lines = ["叶子还带着\n山里的清香。","想把今天的新芽\n制成好茶。"]
		"TeashopServer": lines = ["把这一盏清香，好好递给客人。","一杯热茶，能让人慢下来。"]
		"TeashopGuest":
			match GameState.customer_index:
				0: lines = ["这股茶香，像家乡的春天。","坐一会儿，再回村里去。"]
				1: lines = ["走了这么远，想喝一盏热茶。","这家小茶铺，真让人安心。"]
				_: lines = ["今天的新茶，会是什么滋味呢？","这次要细细品一品回甘。"]
		_: lines = ["山里的一天，过得真慢。"]
	return lines[index%lines.size()].replace("，","，\n")

func _penalty(rect: Rect2, own_image: TextureRect) -> float:
	var cost: float = 0
	for text in get_tree().get_nodes_in_group("game_text"):
		if text == caption or not text.is_visible_in_tree() or not view.is_ancestor_of(text): continue
		cost += rect.intersection(text.get_global_rect().grow(8)).get_area()*5
	for image in get_tree().get_nodes_in_group("character_art"):
		if not view.is_ancestor_of(image): continue
		cost += rect.intersection(image.get_global_rect().grow(10)).get_area()*4
	for badge in get_tree().get_nodes_in_group("world_badge_visuals"):
		if view.is_ancestor_of(badge): cost += rect.intersection(badge.get_global_rect().grow(6)).get_area()*5
	return cost

func show_thought(role: String) -> void:
	if _blocked() or _editing(): return
	for speaker in speakers:
		if speaker.role != role: continue
		var image: TextureRect = speaker.image
		var rect: Rect2 = image.get_global_rect()
		active_head = Vector2(rect.get_center().x,rect.position.y+10)
		var size := Vector2(260,90)
		var candidates: Array[Vector2] = [Vector2(active_head.x-130,rect.position.y-112),Vector2(rect.end.x+18,rect.position.y-30),Vector2(rect.position.x-278,rect.position.y-30),Vector2(rect.end.x+18,rect.position.y+rect.size.y*.4),Vector2(rect.position.x-278,rect.position.y+rect.size.y*.4),Vector2(active_head.x-130,rect.position.y-210),Vector2(rect.end.x+18,rect.position.y-130),Vector2(rect.position.x-278,rect.position.y-130)]
		var best := Vector2.ZERO
		var score: float = INF
		for at in candidates:
			at = Vector2(clampf(at.x,350,1570),clampf(at.y,183,805))
			var penalty: float = _penalty(Rect2(at,size),image)*1000.0+(at+size*.5).distance_to(active_head)
			if penalty<score:
				score = penalty
				best = at
		if _penalty(Rect2(best,size),image)>0:
			for y in range(190,791,40):
				for x in range(350,1551,50):
					var at := Vector2(x,y)
					if at.distance_to(active_head)>380: continue
					var penalty: float = _penalty(Rect2(at,size),image)*1000.0+(at+size*.5).distance_to(active_head)
					if penalty<score:
						score = penalty
						best = at
		# A crowded room can defer an automatic bubble instead of covering existing text.
		if _penalty(Rect2(best,size),image)>0:
			next_thought = 4.0
			return
		UiKit.place(bubble,Rect2(best,size))
		UiKit.set_text(caption,text_for(role,speaker.count))
		speaker.count += 1
		current_speaker = role
		bubble.visible = true
		remaining = 5.5
		next_thought = 11.0
		queue_redraw()
		return

func _draw() -> void:
	if not is_instance_valid(bubble) or not bubble.visible: return
	var rect: Rect2 = bubble.get_rect()
	var closest := Vector2(clampf(active_head.x,rect.position.x+8,rect.end.x-8),clampf(active_head.y,rect.position.y+8,rect.end.y-8))
	for value in [.25,.55]:
		var point: Vector2 = active_head.lerp(closest,float(value))
		var radius: float = 3.0 if value == .25 else 5.0
		draw_circle(point,radius,UiKit.PAPER)
		draw_arc(point,radius,0,TAU,20,Color(0.61,0.62,0.46,0.7),1,true)
