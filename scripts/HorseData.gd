extends RefCounted
class_name HorseData

# 고정 말 데이터(이번 MVP)
const HORSES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "콩콩이",
		"base_speed": 205.0,
		"stamina": 0.92,
		"luck": 62,
		"color": Color(0.95, 0.35, 0.35, 1.0)
	},
	{
		"id": 1,
		"name": "말랑이",
		"base_speed": 198.0,
		"stamina": 1.05,
		"luck": 48,
		"color": Color(0.35, 0.80, 0.95, 1.0)
	},
	{
		"id": 2,
		"name": "두근이",
		"base_speed": 212.0,
		"stamina": 0.87,
		"luck": 74,
		"color": Color(0.60, 0.90, 0.35, 1.0)
	},
	{
		"id": 3,
		"name": "반짝이",
		"base_speed": 201.0,
		"stamina": 0.98,
		"luck": 58,
		"color": Color(0.92, 0.85, 0.30, 1.0)
	}
]

static func get_all_horses() -> Array[Dictionary]:
	return HORSES.duplicate(true)

static func get_horse(index: int) -> Dictionary:
	if index < 0 or index >= HORSES.size():
		return HORSES[0].duplicate(true)
	return HORSES[index].duplicate(true)
