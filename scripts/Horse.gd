extends Node2D
class_name Horse

@onready var body: ColorRect = $Body
@onready var name_label: Label = $NameLabel

var horse_data: Dictionary = {}
var race_distance: float = 0.0

func setup(data: Dictionary) -> void:
	horse_data = data.duplicate(true)
	body.color = horse_data.get("color", Color.WHITE)
	name_label.text = str(horse_data.get("name", "말"))
	race_distance = 0.0

func reset_for_race(start_x: float) -> void:
	position.x = start_x
	race_distance = 0.0
