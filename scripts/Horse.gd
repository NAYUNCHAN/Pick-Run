extends Node2D
class_name Horse

@onready var outline: ColorRect = $Outline
@onready var body: ColorRect = $Body
@onready var number_label: Label = $NumberLabel
@onready var name_label: Label = $NameLabel

var horse_id: int = -1
var horse_number: int = 0
var horse_data: Dictionary = {}
var race_distance_m: float = 0.0

func setup(data: Dictionary) -> void:
	horse_data = data.duplicate(true)
	horse_id = int(horse_data.get("id", -1))
	horse_number = int(horse_data.get("number", 0))

	var body_color: Color = horse_data.get("color", Color.WHITE)
	body.color = body_color
	name_label.text = str(horse_data.get("name", "마필"))
	number_label.text = str(horse_number)

	# TODO(asset-return): Sprite2D 텍스처 적용은 docs/TODO_ASSET_RETURN.md 참고 후 재연결.
	var is_black_horse: bool = horse_number == 4
	outline.visible = is_black_horse

	race_distance_m = 0.0

func reset_for_race(start_pos: Vector2) -> void:
	position = start_pos
	race_distance_m = 0.0
