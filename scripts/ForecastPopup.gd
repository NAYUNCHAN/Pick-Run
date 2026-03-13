extends PanelContainer
class_name ForecastPopup

@onready var ranking_label: Label = $MarginContainer/VBox/RankingLabel
@onready var featured_label: Label = $MarginContainer/VBox/FeaturedLabel
@onready var records_label: Label = $MarginContainer/VBox/RecordsLabel
@onready var close_button: Button = $MarginContainer/VBox/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func show_forecast(ranking_lines: Array[String], featured_lines: Array[String], record_lines: Array[String]) -> void:
	ranking_label.text = "예상 순위\n%s" % "\n".join(ranking_lines)
	featured_label.text = "유력마 소개\n%s" % "\n".join(featured_lines)
	records_label.text = "지난 경주 성적\n%s" % "\n".join(record_lines)
	visible = true

func _on_close_pressed() -> void:
	visible = false
