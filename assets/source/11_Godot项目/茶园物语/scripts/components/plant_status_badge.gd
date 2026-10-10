extends Button

var caption: Label
var status_icon: TextureRect
var progress: ProgressBar
var plot_index: int = -1

func _ready() -> void:
	flat = false
	add_to_group("plant_status_badges")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal",UiKit.paper_style(6,true))
	add_theme_stylebox_override("hover",UiKit.paper_style(6,true))
	add_theme_stylebox_override("pressed",UiKit.paper_style(6,true))
	status_icon = UiKit.art("ICO_108",self,Rect2(7,4,18,18))
	caption = UiKit.label("",self,Rect2(29,0,86,26),18)
	progress = UiKit.meter(self,Rect2(10,25,102,3),0)

func update_status(index: int, state: String) -> void:
	plot_index = index
	set_meta("plot_index",index)
	visible = state in ["seedling","growing","harvested","ready"]
	if not visible: return
	var ready: bool = state=="ready"
	var remaining: int = maxi(0,ceili(GameState.grow_duration(index)-float(GameState.plots[index].age)))
	var value: String = "可采摘" if ready else str(remaining)+"秒成熟"
	if caption.text != value: UiKit.set_text(caption,value)
	caption.add_theme_color_override("font_color",Color("#476b3f") if ready else UiKit.INK)
	var id: String = "ICO_103" if ready else "ICO_108"
	if status_icon.get_meta("asset_id") != id:
		status_icon.texture = AssetLibrary.texture(id)
		status_icon.set_meta("asset_id",id)
	progress.visible = not ready
	progress.value = clampf(float(GameState.plots[index].age)/GameState.grow_duration(index),0,1)
	tooltip_text = str(index+1)+"号茶田 · "+("成熟了，点击采摘" if ready else "距离成熟还有"+str(remaining)+"秒")
