extends Button

func _make_custom_tooltip(for_text: String) -> Object:
	var measured: Vector2 = UiKit.body_font.get_string_size(for_text,HORIZONTAL_ALIGNMENT_CENTER,-1,23)
	var width: float = clampf(measured.x+48,160,400)
	var root := Control.new()
	root.custom_minimum_size = Vector2(width,60)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := UiKit.flat_card(root,Rect2(0,0,width,60))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.label(for_text,root,Rect2(18,7,width-36,46),23)
	return root
