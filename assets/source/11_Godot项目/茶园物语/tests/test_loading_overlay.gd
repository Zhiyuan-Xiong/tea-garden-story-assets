extends Node
var main: Control
var checks: int = 0
var failures: Array = []
var requested_modals: int = 0
var folder: String = "res://docs/过渡页修复/"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func _ready() -> void:
	SaveSystem.base_path="user://loading_overlay_tests_only"
	SaveSystem.settings_path=SaveSystem.base_path+"/settings.cfg"
	GameState.reset()
	GameState.milestones["welcome"]=true
	GameState.settings.reduced_motion=false
	SceneRouter.modal_requested.connect(func(_kind: String,_data: Dictionary):requested_modals+=1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	call_deferred("run")

func visible_todos() -> int:
	var count: int=0
	for todo in get_tree().get_nodes_in_group("daily_todo_sidebars"):
		if todo.is_visible_in_tree():count+=1
	return count

func snap(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+name+".png")

func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new()
	move.position=point;move.global_position=point
	get_viewport().push_input(move)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point
		get_viewport().push_input(event)
	await get_tree().process_frame

func run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	SceneRouter.go("village",false)
	await get_tree().process_frame
	check(visible_todos()==1,"todo visible in normal village")
	var old: Control=main.area_root.get_child(0)
	old.village_editor.set_enabled(true)
	old.village_editor.context.show()
	SceneRouter.go("garden",true)
	check(main.loading_layer.visible and not main.area_root.visible,"loading hides gameplay area immediately")
	check(not old.village_editor.context.is_visible_in_tree(),"editor context cannot float above loading")
	GameState.changed.emit()
	check(visible_todos()==0,"task refresh cannot resurrect loading sidebar")
	await click(Vector2(71,507))
	check(requested_modals==0,"loading blocks clicks on hidden task controls")
	await snap("01_过渡页无待办")
	while SceneRouter.transitioning:await get_tree().process_frame
	check(main.area_root.visible and not main.loading_layer.visible and visible_todos()==1,"garden UI restored after loading")
	await snap("02_进入茶园恢复待办")
	var starting_age: float=10.0
	GameState.plots[0]={"planted":true,"age":starting_age,"harvested":true,"fertilized":false,"material":"basic"}
	for target in ["workshop","teashop","village","home"]:
		SceneRouter.go(target,true)
		check(SceneRouter.transitioning and main.loading_layer.visible,"real transition begins "+target)
		check(visible_todos()==0,"no todo on loading "+target)
		GameState.changed.emit()
		check(visible_todos()==0,"refresh stays behind loading "+target)
		await get_tree().process_frame
		check(not main.area_root.is_visible_in_tree(),"whole area suppressed during "+target)
		while SceneRouter.transitioning:await get_tree().process_frame
		check(main.area_root.visible and not main.loading_layer.visible,"area visibility restored "+target)
		check(visible_todos()==(0 if target=="home" else 1),"expected todo visibility after "+target)
	check(float(GameState.plots[0].age)>starting_age,"tea production survives transitions")
	GameState.settings.reduced_motion=true
	SceneRouter.go("village",true)
	check(main.loading_layer.visible and visible_todos()==0,"reduced motion loading has no todo")
	while SceneRouter.transitioning:await get_tree().process_frame
	check(visible_todos()==1,"reduced motion restores todo")
	SceneRouter.go("garden",true)
	GameState.changed.emit()
	check(visible_todos()==0,"reduced motion refresh cannot expose sidebar")
	while SceneRouter.transitioning:await get_tree().process_frame
	check(visible_todos()==1,"reduced motion incoming garden restored")
	SceneRouter.go("workshop",false)
	check(main.area_root.visible and not main.loading_layer.visible and visible_todos()==1,"direct route without loading restores gameplay")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"tested_routes":["village → garden","garden → workshop","workshop → teashop","teashop → village","village → home","reduced motion transitions","direct route"],"task_refresh_during_loading":true,"hidden_ui_input_blocked":true}
	var file:=FileAccess.open(folder+"检查报告.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("LOADING_OVERLAY_TEST "+JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
