extends Node
var checks: int = 0
var failures: Array = []
var main: Control
var folder: String = "res://docs/背景音乐接入/"
var capture: AudioEffectCapture

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	# Exercise the real mixer without sending test audio to the user's speakers.
	AudioServer.set_bus_mute(0, true)
	SaveSystem.base_path = "user://music_integration_tests_only"
	SaveSystem.settings_path = SaveSystem.base_path + "/settings.cfg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveSystem.base_path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	GameState.reset()
	GameState.milestones["welcome"] = true
	GameState.settings.music_volume = 0.55
	GameState.settings.music_muted = false
	GameState.changed.emit()
	call_deferred("run")

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position=point;move.global_position=point
	get_viewport().push_input(move)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=point;event.global_position=point
		get_viewport().push_input(event)
	await get_tree().process_frame

func snap() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+"设置与音乐控制.png")

func max_audio_sample() -> float:
	var result: float = 0.0
	var buffer: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	for sample in buffer:
		result=maxf(result,maxf(absf(sample.x),absf(sample.y)))
	return result

func run() -> void:
	var player: AudioStreamPlayer = MusicPlayer.player
	check(player != null and player.playing, "persistent player starts automatically")
	check(player.stream is AudioStreamOggVorbis, "compressed Vorbis stream")
	check(player.stream.loop, "native looping enabled")
	check(player.stream.get_length() > 1100.0, "long ambient track avoids short repeated phrases")
	check(player.bus == "Music", "independent music bus")
	var identity: int = player.get_instance_id()
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.15
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), capture)
	await wait(2.2)
	check(is_equal_approx(player.volume_db,linear_to_db(0.55)), "default gain applied")
	capture.clear_buffer()
	await wait(0.1)
	check(max_audio_sample()>0.0001, "music produces nonzero mixed audio")
	main=load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var last_position: float = player.get_playback_position()
	for target in ["village", "garden", "workshop", "teashop", "home"]:
		SceneRouter.go(target,true)
		check(player.playing and player.get_instance_id()==identity,"one player through loading "+target)
		while SceneRouter.transitioning:
			await get_tree().process_frame
		var next_position: float=player.get_playback_position()
		check(next_position>last_position,"music position advances without restart "+target)
		last_position=next_position
		if target != "home":
			check(not main.loading_layer.visible and main.area_root.visible,"gameplay restored "+target)
	main.modals.open("settings")
	check(GameState.paused,"settings pauses production")
	var position_before_pause: float=player.get_playback_position()
	await wait(0.5)
	check(player.get_playback_position()>position_before_pause,"music continues gently in settings")
	var slider: HSlider=main.modals.get_node("MusicVolume")
	check(slider.min_value==0.0 and slider.max_value==100.0,"full volume control range")
	await click(Vector2(986,355))
	await wait(0.3)
	check(slider.value>40 and slider.value<60,"native slider responds to mouse")
	check(is_equal_approx(float(GameState.settings.music_volume),slider.value/100.0),"slider writes live music settings")
	check(is_equal_approx(player.volume_db,linear_to_db(slider.value/100.0)),"slider changes actual playback gain")
	var mute: CheckButton
	for child in main.modals.get_children():
		if child is CheckButton:
			for label in child.get_children():
				if label is Label and label.text=="静音背景音乐":mute=child
	check(mute!=null,"separate mute switch exists")
	await click(Vector2(680,433))
	await wait(0.3)
	check(GameState.settings.music_muted and player.volume_db<=-79.9,"mute switch silences player")
	check(player.playing,"muting preserves playback position")
	capture.clear_buffer()
	await wait(0.1)
	check(max_audio_sample()<0.0001,"muted audio is inaudible")
	await click(Vector2(680,433))
	await wait(0.3)
	check(not GameState.settings.music_muted and player.volume_db>-20.0,"unmute restores selected volume")
	slider.value=0.0
	await wait(0.3)
	check(player.volume_db<=-79.9 and player.playing,"zero volume mutes without restarting")
	slider.value=55.0
	await wait(0.3)
	var credits: RichTextLabel=main.modals.get_node("MusicCredits")
	check(credits.text.contains("Kevin MacLeod") and credits.text.contains("https://creativecommons.org/licenses/by/4.0/"),"visible music attribution and license links")
	check(credits.get_content_height()<=credits.size.y,"music credits fit panel")
	await snap()
	main.modals.close()
	check(not GameState.paused,"closing settings resumes game")
	var config:=ConfigFile.new()
	check(config.load(SaveSystem.settings_path)==OK,"settings saved successfully")
	check(is_equal_approx(float(config.get_value("settings","music_volume")),0.55),"saved volume persists")
	check(config.get_value("settings","music_muted")==false,"saved mute preference persists")
	GameState.settings.music_volume=0.2
	GameState.settings.music_muted=true
	var saved_reader=load("res://scripts/core/save_system.gd").new()
	saved_reader.settings_path=SaveSystem.settings_path
	add_child(saved_reader)
	check(is_equal_approx(float(GameState.settings.music_volume),0.55) and not GameState.settings.music_muted,"saved preferences reload")
	saved_reader.queue_free()
	var old_config:=ConfigFile.new()
	old_config.set_value("settings","show_hints",false)
	old_config.save(SaveSystem.base_path+"/old_settings.cfg")
	GameState.settings.music_volume=MusicPlayer.DEFAULT_VOLUME
	GameState.settings.music_muted=false
	var legacy_reader=load("res://scripts/core/save_system.gd").new()
	legacy_reader.settings_path=SaveSystem.base_path+"/old_settings.cfg"
	add_child(legacy_reader)
	check(is_equal_approx(float(GameState.settings.music_volume),0.55) and not GameState.settings.music_muted,"legacy settings gain music defaults")
	check(not GameState.settings.show_hints,"legacy preferences retained")
	legacy_reader.queue_free()
	GameState.settings.show_hints=true
	GameState.changed.emit()
	player.seek(player.stream.get_length()-0.25)
	await wait(0.8)
	check(player.playing and player.get_playback_position()<2.0,"end of track loops automatically")
	var invalid_values: Array=[-5.0,5.0,NAN,"bad"]
	for value in invalid_values:
		GameState.settings.music_volume=value
		GameState.changed.emit()
		var normalized: float=float(GameState.settings.music_volume)
		check(is_finite(normalized) and normalized>=0.0 and normalized<=1.0,"invalid saved volume handled "+str(value))
	GameState.settings.music_volume=0.55
	GameState.changed.emit()
	AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"), 0)
	capture = null
	player.stop()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"routes":["home","village","garden","workshop","teashop"],"audio_mixing_verified":true,"isolated_settings_and_saves":SaveSystem.base_path}
	var file:=FileAccess.open(folder+"检查报告.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("MUSIC_INTEGRATION_TEST "+JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
