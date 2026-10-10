extends Node2D
var contacts: PackedVector2Array = []
var radius: float = 6.0
func _draw() -> void:
	for contact in contacts:
		for layer in range(3):
			var polygon := PackedVector2Array()
			var spread: float = radius + float(layer) * 2.5
			for step in range(24):
				var angle: float = TAU * float(step) / 24.0
				polygon.append(contact + Vector2(cos(angle)*spread,sin(angle)*spread*0.26))
			draw_colored_polygon(polygon,Color(0.31,0.35,0.28,0.035))
