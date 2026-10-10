extends Node
var game: Control
var passed: int = 0
var failures: Array[String] = []
var measurements: Array[Dictionary] = []
var decoded_captures: Array[Dictionary] = []

func _ready() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failures.append(message)
		push_error(message)

func settle(frames: int = 5) -> void:
	for index in range(frames): await get_tree().process_frame

func measure(room: String) -> void:
	var intervals: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for index in range(120):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now-previous)/1000.0)
		previous = now
	var duration: float = 0.0
	for value in intervals: duration+=value
	intervals.sort()
	measurements.append({"room":room,"render_fps":120000.0/duration,"p95_frame_ms":intervals[114],"max_frame_ms":intervals[-1]})

func verify_motion(motion: Node, room: String) -> void:
	var video: VideoStreamPlayer = motion.baked_player
	check(is_instance_valid(video),room+" has a prepared video")
	if not is_instance_valid(video): return
	await settle(12)
	check(video.loop and video.is_playing() and not video.paused,room+" continuously plays and loops")
	check(motion.background.material==null,room+" has no realtime background shader")
	check(video.get_global_rect()==motion.background.get_global_rect(),room+" preserves the complete background framing")
	check(video.mouse_filter==Control.MOUSE_FILTER_IGNORE,room+" does not intercept clicks")
	check(video.get_video_texture().get_width()==1920 and video.get_video_texture().get_height()==1080,room+" decodes full HD")
	var initial: float = video.stream_position
	await get_tree().create_timer(.25).timeout
	check(video.stream_position>initial,room+" presentation time advances")
	var image: Image = video.get_video_texture().get_image()
	check(image.get_pixel(960,540).a>.99 and image.get_pixel(960,540).r>.1,room+" decoded picture is opaque and not blank")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/动效调整/视频实际解码"))
	var capture_path: String = "res://docs/动效调整/视频实际解码/"+room+".png"
	check(image.save_png(capture_path)==OK,room+" saves the native decoded picture for color verification")
	decoded_captures.append({"room":room,"seconds":video.stream_position,"path":capture_path})
	await measure(room)
	GameState.settings.reduced_motion = true
	motion._process(.01)
	check(video.paused and not video.visible and motion.background.material==null,room+" reduced motion uses a prepared still")
	GameState.settings.reduced_motion = false
	motion._process(.01)
	check(not video.paused and video.visible,room+" motion can resume")
	game.modals.open("settings")
	motion._process(.01)
	check(video.paused,room+" pauses under a modal")
	var paused_at: float = video.stream_position
	await get_tree().create_timer(.15).timeout
	check(absf(video.stream_position-paused_at)<.02,room+" does not decode while paused")
	game.modals.close()
	motion._process(.01)
	check(not video.paused,room+" resumes after the modal closes")
	motion.set_preview_time(2)
	check(video.paused and not video.visible and motion.background.material==motion.render_material,room+" keeps deterministic keyframe inspection")
	motion.resume_motion()
	motion._process(.01)
	check(motion.background.material==null and video.visible,room+" returns to video after inspection")

func _run() -> void:
	await get_tree().process_frame
	GameState.set_process(false)
	SaveSystem.base_path = "user://baked_video_test_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	GameState.settings.reduced_motion = false
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await settle()
	var home_motion: Node = game.area_root.get_child(0).ambient
	await verify_motion(home_motion,"home")
	var wrapped: bool = false
	var previous: float = home_motion.baked_player.stream_position
	var deadline: int = Time.get_ticks_msec()+9000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		var current: float = home_motion.baked_player.stream_position
		if current<previous-.5:
			wrapped = true
			break
		previous = current
	check(wrapped and home_motion.baked_player.is_playing(),"home crosses the actual eight second loop boundary")
	game.loading_layer.visible = true
	await settle()
	check(home_motion.baked_player.paused,"covered home video pauses during loading")
	await verify_motion(game.loading_motion,"loading")
	game.loading_layer.visible = false
	await settle()
	check(game.loading_motion.baked_player.paused,"hidden loading video stops decoding")
	for room in ["village","garden","workshop","teashop"]:
		SceneRouter.go(room,false)
		await settle()
		var area: Control = game.area_root.get_child(0)
		await verify_motion(area.ambient,room)
		if room in ["workshop","teashop"]:
			area.furniture_editor.enabled = true
			area.ambient._process(.01)
			check(area.ambient.baked_player.paused,room+" furniture edit pauses background playback")
			area.furniture_editor.enabled = false
			area.ambient._process(.01)
			check(not area.ambient.baked_player.paused,room+" furniture edit exit resumes playback")
	var report: Dictionary = {"passed":passed,"failed":failures,"playback_format":"Ogg Theora","resolution":[1920,1080],"encoded_fps":30,"loop_seconds":8,"measurements":measurements,"native_decoded_captures":decoded_captures,"renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("res://docs/动效调整/预渲染播放检查.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BAKED_VIDEO_VERIFICATION: ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
