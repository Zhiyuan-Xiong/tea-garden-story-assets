extends Button
var ellipse: bool=false
func _has_point(point: Vector2) -> bool:
	if not ellipse:return Rect2(Vector2.ZERO,size).has_point(point)
	var local: Vector2=(point-size*0.5)/(size*0.5)
	return local.length_squared()<=1.0
