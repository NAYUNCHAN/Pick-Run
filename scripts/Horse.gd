extends Node2D
class_name Horse

@onready var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
@onready var body: ColorRect = get_node_or_null("Body") as ColorRect
@onready var name_label: Label = get_node_or_null("NameLabel") as Label

var horse_id: int = -1
var horse_data: Dictionary = {}
var race_distance: float = 0.0

func setup(data: Dictionary) -> void:
	horse_data = data.duplicate(true)
	horse_id = int(horse_data.get("id", -1))
	if name_label != null:
		name_label.text = str(horse_data.get("name", "말"))

	var loaded_sprite: bool = false
	if sprite != null:
		var path: String = str(horse_data.get("texture_path", ""))
		if path != "" and ResourceLoader.exists(path):
			var texture: Texture2D = load(path)
			if texture != null:
				sprite.texture = texture
				sprite.visible = true
				loaded_sprite = true

	if body != null:
		body.visible = not loaded_sprite
		body.color = horse_data.get("color", Color.WHITE)

	race_distance = 0.0

func reset_for_race(start_x: float) -> void:
	position.x = start_x
	race_distance = 0.0
