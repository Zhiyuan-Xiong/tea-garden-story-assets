extends Node
## One persistent, streamed music player for the menu and every game scene.
const STREAM_PATH: String = "res://assets/20_背景音乐/river_flute_loop.ogg"
const DEFAULT_VOLUME: float = 0.55
var player: AudioStreamPlayer
var _volume_tween: Tween
var _last_volume: float = -1.0
var _last_muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "BackgroundMusic"
	player.volume_db = -80.0
	add_child(player)
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus < 0:
		AudioServer.add_bus()
		music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus, "Music")
		AudioServer.set_bus_send(music_bus, "Master")
	player.bus = "Music"
	if ResourceLoader.exists(STREAM_PATH):
		var music: AudioStreamOggVorbis = load(STREAM_PATH) as AudioStreamOggVorbis
		if music:
			music.loop = true
			player.stream = music
			player.play()
	else:
		push_warning("Background music asset is missing: " + STREAM_PATH)
	GameState.changed.connect(_on_settings_changed)
	_apply_settings(2.0)

func _on_settings_changed() -> void:
	_apply_settings(0.22)

func _apply_settings(fade_seconds: float) -> void:
	var stored: Variant = GameState.settings.get("music_volume", DEFAULT_VOLUME)
	var volume: float = DEFAULT_VOLUME
	if (stored is float or stored is int) and is_finite(float(stored)):
		volume = clampf(float(stored), 0.0, 1.0)
	var muted: bool = bool(GameState.settings.get("music_muted", false))
	GameState.settings["music_volume"] = volume
	if is_equal_approx(volume, _last_volume) and muted == _last_muted:
		return
	_last_volume = volume
	_last_muted = muted
	if _volume_tween and _volume_tween.is_valid():
		_volume_tween.kill()
	var target_db: float = -80.0 if muted or volume <= 0.0 else linear_to_db(volume)
	_volume_tween = create_tween()
	_volume_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_volume_tween.tween_property(player, "volume_db", target_db, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
