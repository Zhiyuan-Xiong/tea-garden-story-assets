extends Node
const FPS: int = 30
const FRAMES: int = 240
const OUTPUT: String = "res://assets/14_预渲染动效"
var game: Control

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	get_tree().set_meta("baking_ambient_video",true)
	GameState.set_process(false)
	SaveSystem.base_path = "user://video_bake_"+str(Time.get_ticks_usec())
	SaveSystem.settings_path = SaveSystem.base_path.path_join("settings.cfg")
	GameState.reset()
	GameState.unlock("welcome")
	GameState.settings.reduced_motion = false
	get_tree().root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/动效调整/视频参考帧"))
	for room in ["home","loading","village","garden","workshop","teashop"]:
		var source: TextureRect
		if room=="loading":
			source = game.loading_motion.background
		else:
			if room!="home":
				SceneRouter.go(room,false)
				await get_tree().process_frame
			source = game.area_root.get_child(0).ambient.background
		# Render the original painted background only. No people, furniture or text.
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1920,1080)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var owner_view := Control.new()
		owner_view.size = Vector2(1920,1080)
		viewport.add_child(owner_view)
		var background := TextureRect.new()
		background.texture = source.texture
		background.material = source.material.duplicate()
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		background.size = Vector2(1920,1080)
		owner_view.add_child(background)
		var motion: Node = load("res://scripts/components/ambient_motion.gd").new()
		owner_view.add_child(motion)
		motion.setup(background,owner_view,room)
		GameState.settings.reduced_motion = true
		motion.set_preview_time(0)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var still := viewport.get_texture().get_image()
		still.convert(Image.FORMAT_RGB8)
		assert(still.save_png(OUTPUT.path_join(room+"_still.png"))==OK)
		GameState.settings.reduced_motion = false
		var socket := StreamPeerTCP.new()
		assert(socket.connect_to_host("127.0.0.1",38473)==OK)
		while socket.get_status()==StreamPeerTCP.STATUS_CONNECTING:
			socket.poll()
			await get_tree().process_frame
		assert(socket.get_status()==StreamPeerTCP.STATUS_CONNECTED)
		var header := JSON.stringify({"room":room,"width":1920,"height":1080,"fps":FPS,"frames":FRAMES})+"\n"
		assert(socket.put_data(header.to_utf8_buffer())==OK)
		for index in range(FRAMES):
			motion.set_preview_time(float(index)/FPS)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			if index in [0,60,120,180,239]:
				assert(image.save_png("res://docs/动效调整/视频参考帧/"+room+"_%03d.png"%index)==OK)
			assert(socket.put_data(image.get_data())==OK)
			if index%60==0: print("VIDEO_BAKE ",room," ",index,"/",FRAMES)
		socket.disconnect_from_host()
		viewport.queue_free()
		await get_tree().process_frame
	print("VIDEO_BAKE_COMPLETE")
	get_tree().quit()
