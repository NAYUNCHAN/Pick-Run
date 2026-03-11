extends PanelContainer
class_name HorseInfoPopup

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var ability_label: Label = $MarginContainer/VBox/AbilityLabel
@onready var skill_name_label: Label = $MarginContainer/VBox/SkillNameLabel
@onready var skill_desc_label: Label = $MarginContainer/VBox/SkillDescLabel
@onready var close_button: Button = $MarginContainer/VBox/CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func show_horse_info(horse: Dictionary) -> void:
	title_label.text = "%d번 %s 마필 정보" % [int(horse.get("number", 0)), str(horse.get("name", "마필"))]
	var ability_lines: Array[String] = HorseData.get_ability_summary(horse)
	ability_label.text = "능력 평가\n- %s" % "\n- ".join(ability_lines)
	var skill_any: Variant = horse.get("skill", {})
	var skill: Dictionary = skill_any if skill_any is Dictionary else {}
	skill_name_label.text = "고유 스킬: %s" % str(skill.get("name", "-"))
	skill_desc_label.text = str(skill.get("description", "설명이 없습니다."))
	visible = true

func _on_close_pressed() -> void:
	visible = false
