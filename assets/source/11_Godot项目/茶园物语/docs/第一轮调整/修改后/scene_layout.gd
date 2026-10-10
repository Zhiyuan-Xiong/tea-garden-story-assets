extends Node
# 从背景地板的四个实际转角取得坐标，顺序：后、右、前、左。
const FLOORS: Dictionary = {
	"workshop": [Vector2(954,352),Vector2(1878,785),Vector2(1184,959),Vector2(173,550)],
	"teashop": [Vector2(1126,422),Vector2(1773,717),Vector2(799,871),Vector2(119,631)]
}
# 新素材中实测的两组平行边角度（度）。保持立柱垂直的仿射变换只校准地面方向。
const ASSET_AXES: Dictionary = {
	"PRP_421": Vector2(20.0,-24.0),
	"PRP_422": Vector2(22.0,-25.0),
	"PRP_423": Vector2(20.0,-24.0),
	"PRP_424": Vector2(25.0,-25.0),
	"PRP_425": Vector2(25.0,-25.0),
	"PRP_431": Vector2(20.7,-30.8),
	"PRP_432": Vector2(30.7,-22.0),
	"PRP_434": Vector2(27.0,-25.0)
}

const FOOTPRINTS: Dictionary = {
	"PRP_421": [Vector2(0.154229,0.424769),Vector2(0.980810,0.863426),Vector2(0.830135,0.993056),Vector2(0.028429,0.486111)],
	"PRP_422": [Vector2(0.236188,0.703930),Vector2(0.965470,0.921397),Vector2(0.762431,0.997380),Vector2(0.009669,0.777293)],
	"PRP_423": [Vector2(0.293490,0.547826),Vector2(0.960512,0.817391),Vector2(0.676628,0.995031),Vector2(0.057631,0.681988)],
	"PRP_424": [Vector2(0.511664,0.673224),Vector2(0.982893,0.839344),Vector2(0.461897,0.995628),Vector2(0.043546,0.830601)],
	"PRP_425": [Vector2(0.710490,0.641885),Vector2(0.945455,0.841885),Vector2(0.348252,0.995812),Vector2(0.048951,0.764398)],
	"PRP_431": [Vector2(0.210824,0.453515),Vector2(0.966882,0.827664),Vector2(0.771405,0.996599),Vector2(0.034733,0.599773)],
	"PRP_432": [Vector2(0.574824,0.425287),Vector2(1.000880,0.677116),Vector2(0.424296,0.998955),Vector2(0.003521,0.679206)],
	"PRP_433": [Vector2(0.248933,0.770955),Vector2(0.961593,0.859649),Vector2(0.813656,0.999025),Vector2(0.028450,0.909357)],
	"PRP_434": [Vector2(0.354962,0.602136),Vector2(0.926209,0.859813),Vector2(0.622137,1.000000),Vector2(0.076336,0.731642)],
}

func floor_point(room: String, uv: Vector2) -> Vector2:
	var corners: Array = FLOORS[room]
	var a: Vector2 = corners[0]
	var b: Vector2 = corners[1]
	var c: Vector2 = corners[2]
	var d: Vector2 = corners[3]
	return a + uv.x*(b-a) + uv.y*(d-a) + uv.x*uv.y*(c-b-d+a)

func floor_axes(room: String, uv: Vector2) -> Vector2:
	var corners: Array = FLOORS[room]
	var cross: Vector2 = corners[2]-corners[1]-corners[3]+corners[0]
	var u: Vector2 = corners[1]-corners[0]+uv.y*cross
	var v: Vector2 = corners[0]-corners[3]-uv.x*cross
	return Vector2(rad_to_deg(u.angle()),rad_to_deg(v.angle()))

func calibration(id: String, room: String, uv: Vector2) -> Transform2D:
	if not ASSET_AXES.has(id):
		return Transform2D.IDENTITY
	var source: Vector2 = ASSET_AXES[id]
	var target: Vector2 = floor_axes(room,uv)
	var scale_y: float = (tan(deg_to_rad(target.x))-tan(deg_to_rad(target.y))) / (tan(deg_to_rad(source.x))-tan(deg_to_rad(source.y)))
	var shear_y: float = tan(deg_to_rad(target.x))-scale_y*tan(deg_to_rad(source.x))
	return Transform2D(Vector2(1,shear_y),Vector2(0,scale_y),Vector2.ZERO)

func inside_floor(room: String, point: Vector2) -> bool:
	var polygon = PackedVector2Array(FLOORS[room])
	return Geometry2D.is_point_in_polygon(point,polygon)


func anchor(id: String) -> Vector2:
	if not FOOTPRINTS.has(id):
		return Vector2(0.5,1)
	var center = Vector2.ZERO
	for point in FOOTPRINTS[id]:
		center += point
	return center / float(FOOTPRINTS[id].size())
