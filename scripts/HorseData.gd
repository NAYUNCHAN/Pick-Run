extends RefCounted
class_name HorseData

# 고정 말 데이터(MVP) - 승부가 고정되지 않도록 기본 스탯 간 격차를 완화
const HORSES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "콩콩이",
		"base_speed": 203.0,
		"stamina": 0.98,
		"luck": 61,
		"color": Color(0.95, 0.35, 0.35, 1.0),
		"texture_path": "res://assets/sprites/horses/kongkong.png"
	},
	{
		"id": 1,
		"name": "말랑이",
		"base_speed": 201.0,
		"stamina": 1.03,
		"luck": 54,
		"color": Color(0.35, 0.80, 0.95, 1.0),
		"texture_path": "res://assets/sprites/horses/mallang.png"
	},
	{
		"id": 2,
		"name": "두근이",
		"base_speed": 205.0,
		"stamina": 0.95,
		"luck": 70,
		"color": Color(0.60, 0.90, 0.35, 1.0),
		"texture_path": "res://assets/sprites/horses/dugeun.png"
	},
	{
		"id": 3,
		"name": "반짝이",
		"base_speed": 202.0,
		"stamina": 1.00,
		"luck": 58,
		"color": Color(0.92, 0.85, 0.30, 1.0),
		"texture_path": "res://assets/sprites/horses/banjjak.png"
	}
]

static func get_all_horses() -> Array[Dictionary]:
	return HORSES.duplicate(true)

static func get_horse(index: int) -> Dictionary:
	if index < 0 or index >= HORSES.size():
		return HORSES[0].duplicate(true)
	return HORSES[index].duplicate(true)
