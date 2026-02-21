extends Control

@onready var coins_label: Label = get_node_or_null("%CoinsLabel") as Label
@onready var start_race_button: Button = $MarginContainer/VBoxContainer/StartRaceButton
@onready var stats_button: Button = $MarginContainer/VBoxContainer/StatsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton

var _coins_label_error_logged: bool = false

func _ready() -> void:
	if coins_label == null:
		coins_label = find_child("CoinsLabel", true, false) as Label
	start_race_button.pressed.connect(_on_start_race_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh_ui()

func refresh_ui() -> void:
	if not is_node_ready():
		return
	if coins_label == null:
		coins_label = find_child("CoinsLabel", true, false) as Label
	if coins_label == null:
		if not _coins_label_error_logged:
			push_error("MainMenu: CoinsLabel not found. Check MainMenu.tscn node name + Unique Name in Owner.")
			_coins_label_error_logged = true
		return
	coins_label.text = "현재 코인: %d" % int(GameState.coins)

func _on_start_race_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Race.tscn")

func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Stats.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
