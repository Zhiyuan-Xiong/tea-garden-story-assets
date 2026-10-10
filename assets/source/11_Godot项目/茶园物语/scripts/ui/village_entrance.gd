extends "res://scripts/ui/paper_icon_button.gd"

var title: String
var detail: String
var plate: TextureRect

func setup(caption: String, status: String, icon_id: String) -> void:
	title = caption
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_to_group("village_entrances")
	set_meta("title", title)
	# The complete pennant is scaled uniformly, so its medallion stays circular.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	plate = UiKit.art("UI_451", self, Rect2(0, 0, 86, 241.875), false)
	UiKit.art(icon_id, self, Rect2(4.4, 3.3, 77.2, 77.2))
	var text := UiKit.label("\n".join(Array(title.split(""))), self, Rect2(18, 89, 50, 121), 22, true)
	text.name = "EntranceTitle"
	update_detail(status)
	mouse_entered.connect(_sync_highlight)
	mouse_exited.connect(_sync_highlight)
	focus_entered.connect(_sync_highlight)
	focus_exited.connect(_sync_highlight)

func update_detail(status: String) -> void:
	detail = status
	tooltip_text = title + "：" + detail

func _sync_highlight() -> void:
	plate.modulate = Color(1.06, 1.06, 1.06) if is_hovered() or has_focus() else Color.WHITE
