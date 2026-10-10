extends RefCounted
# 首版三位客人共用“一份云雾春芽”的订单；库存与结算由 GameState 一次完成。
const PROFILES: Array[Dictionary] = [
	{"name": "常来的村民", "portrait": "CHR_201", "sprite": "CHR_202", "quantity": 1, "preferred_quality": 0},
	{"name": "路过的旅人", "portrait": "CHR_203", "sprite": "CHR_204", "quantity": 1, "preferred_quality": 1},
	{"name": "认真品茶的熟客", "portrait": "CHR_205", "sprite": "CHR_206", "quantity": 1, "preferred_quality": 2}
]

static func reward(quality: int, customer: int) -> int:
	if quality not in [0, 1, 2] or customer not in [0, 1, 2]:
		return 0
	return 12 + quality * 6 + customer * 3
