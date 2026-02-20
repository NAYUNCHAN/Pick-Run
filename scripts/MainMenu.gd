extends Control

@onready var coins_label: Label = $MarginContainer/VBoxContainer/CoinsLabel
@onready var start_race_button: Button = $MarginContainer/VBoxContainer/StartRaceButton
@onready var stats_button: Button = $MarginContainer/VBoxContainer/StatsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_race_button.pressed.connect(_on_start_race_pressed)
	stats_button.pressed.connect(_on_stats_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh_ui()

func refresh_ui() -> void:
	coins_label.text = "현재 코인: %d" % GameState.coins

func _on_start_race_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Race.tscn")

func _on_stats_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Stats.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
